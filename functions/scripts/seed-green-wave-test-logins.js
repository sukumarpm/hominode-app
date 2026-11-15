
'use strict';

// Run from lyvo1/functions:
// node scripts/seed-green-wave-test-logins.js --project hominode-prod
// Add --apply only after reviewing the dry-run output.

const admin = require('firebase-admin');
const {
    approveResidentRegistrationCore,
} = require('../src/resident_identity');

const PROJECT = 'hominode-prod';
const COMMUNITY = 'GREEN-WAVE';
const BATCH = 'green-wave-2027-v1';
const ACTOR_UID = 'demo-admin-green-wave';

const ACCOUNTS = [
    {
        phone: '+916505553434',
        name: 'Aditi Rao',
        key: 'test-login:1',
    },
    {
        phone: '+916505554567',
        name: 'Rohan Mehta',
        key: 'test-login:2',
    },
];

function fail(message) {
    throw new Error(message);
}

async function main() {
    const args = process.argv;
    const p = args.indexOf('--project');

    if (p < 0 || args[p + 1] !== PROJECT) {
        fail('Explicit --project hominode-prod required');
    }

    const apply = args.includes('--apply');

    if (
        args.some(
            (x) =>
                x.startsWith('--') &&
                !['--project', '--apply'].includes(x)
        )
    ) {
        fail('Unknown argument');
    }

    admin.initializeApp({ projectId: PROJECT });

    const db = admin.firestore();
    const auth = admin.auth();

    const [community, actor] = await Promise.all([
        db.doc(`communities/${COMMUNITY}`).get(),
        db.doc(`admins/${ACTOR_UID}`).get(),
    ]);

    if (
        !community.exists ||
        community.get('isActive') !== true ||
        community.get('isDemoData') !== true ||
        community.get('seedBatch') !== BATCH
    ) {
        fail('Expected active GREEN-WAVE demo community not found');
    }

    if (
        !actor.exists ||
        actor.get('role') !== 'admin' ||
        actor.get('isActive') !== true ||
        actor.get('isDemoData') !== true ||
        actor.get('seedBatch') !== BATCH ||
        !actor.get('authorizedCommunityIds')?.includes(COMMUNITY)
    ) {
        fail('Expected GREEN-WAVE seed admin not found');
    }

    const [flatSnap, buildingSnap, residentSnap] =
        await Promise.all([
            db.collection('flats')
                .where('communityId', '==', COMMUNITY)
                .get(),

            db.collection('buildings')
                .where('communityId', '==', COMMUNITY)
                .get(),

            db.collection('users')
                .where('communityId', '==', COMMUNITY)
                .get(),
        ]);

    const buildings = new Map(
        buildingSnap.docs.map((d) => [d.id, d.data()])
    );

    const allResidents = residentSnap.docs.filter(
        (d) => d.get('role') === 'resident'
    );

    const claimedFlats = new Set(
        allResidents
            .map((d) => d.get('flatId'))
            .filter(Boolean)
    );

    const candidates = flatSnap.docs
        .filter((d) => {
            const f = d.data();

            return (
                f.status === 'vacant' &&
                !f.residentUserId &&
                !f.residentUid &&
                !f.reservedOnboardingId &&
                !claimedFlats.has(d.id) &&
                buildings.has(f.buildingId) &&
                buildings.get(f.buildingId).seedBatch === BATCH
            );
        })
        .sort((a, b) =>
            `${a.get('buildingId')}:${a.get('flatLabel') || a.id}`
                .localeCompare(
                    `${b.get('buildingId')}:${b.get('flatLabel') || b.id}`
                )
        );

    const plans = [];
    const allocated = new Set();

    for (const item of ACCOUNTS) {
        let existingAuth = null;

        try {
            existingAuth = await auth.getUserByPhoneNumber(item.phone);
        } catch (e) {
            if (e.code !== 'auth/user-not-found') {
                throw e;
            }
        }

        const matching = allResidents.filter(
            (d) =>
                d.get('phoneNumber') === item.phone ||
                d.get('phone') === item.phone ||
                d.get('seedKey') === item.key
        );

        if (matching.length > 1) {
            fail(`Conflicting resident profiles for ${item.phone}`);
        }

        const existingDoc = matching[0] || null;

        if (existingAuth) {
            const uidDoc = await db
                .doc(`users/${existingAuth.uid}`)
                .get();

            if (
                uidDoc.exists &&
                (!existingDoc || existingDoc.id !== uidDoc.id)
            ) {
                fail(
                    `Auth UID ${existingAuth.uid} already belongs to a different user profile`
                );
            }

            if (
                existingDoc &&
                existingDoc.id !== existingAuth.uid
            ) {
                fail(`Auth UID mismatch for ${item.phone}`);
            }
        }

        if (existingDoc) {
            if (
                existingDoc.get('communityId') !== COMMUNITY ||
                existingDoc.get('role') !== 'resident' ||
                existingDoc.get('isDemoData') !== true ||
                existingDoc.get('seedBatch') !== BATCH ||
                existingDoc.get('seedKey') !== item.key ||
                existingDoc.get('phoneNumber') !== item.phone
            ) {
                fail(`Conflicting existing demo user for ${item.phone}`);
            }

            if (!existingAuth) {
                fail(
                    `Firestore profile exists without matching Firebase Auth user for ${item.phone}`
                );
            }
        }

        const existingFlat = existingDoc?.get('flatId');

        let flat = existingFlat
            ? flatSnap.docs.find((d) => d.id === existingFlat)
            : null;

        if (existingFlat && !flat) {
            fail(`Assigned flat missing for ${item.phone}`);
        }

        if (!flat) {
            flat = candidates.find(
                (d) => !allocated.has(d.id)
            );
        }

        if (!flat) {
            fail('No safe vacant flats available');
        }

        if (allocated.has(flat.id)) {
            fail('Duplicate flat selection');
        }

        allocated.add(flat.id);

        const state = existingDoc
            ? `${existingDoc.get('approvalStatus')}/${existingDoc.get('status')}`
            : 'new';

        if (
            existingDoc &&
            !['pending', 'approved'].includes(
                existingDoc.get('approvalStatus')
            )
        ) {
            fail(`Unexpected approval status for ${item.phone}`);
        }

        if (
            existingDoc?.get('approvalStatus') === 'approved' &&
            (
                existingDoc.get('isActive') !== true ||
                existingDoc.get('occupancyStatus') !== 'current' ||
                flat.get('residentUserId') !== existingDoc.id
            )
        ) {
            fail(`Existing account inconsistent for ${item.phone}`);
        }

        if (
            existingDoc?.get('approvalStatus') !== 'approved' &&
            (
                flat.get('status') !== 'vacant' ||
                flat.get('residentUserId') ||
                (
                    claimedFlats.has(flat.id) &&
                    existingFlat !== flat.id
                )
            )
        ) {
            fail(`Flat unavailable for ${item.phone}`);
        }

        plans.push({
            ...item,
            auth: existingAuth,
            doc: existingDoc,
            flat,
            building: buildings.get(flat.get('buildingId')),
            state,
        });
    }

    console.log(
        `Project: ${PROJECT} | Community: ${COMMUNITY} | ` +
        `${apply ? 'APPLY' : 'DRY RUN'}`
    );

    for (const plan of plans) {
        console.log(
            `${plan.phone} -> ${plan.name} | ` +
            `${plan.building.name ||
            plan.building.buildingName ||
            plan.flat.get('buildingId')} / ` +
            `${plan.flat.get('flatLabel') || plan.flat.id} | ` +
            `Auth: ${plan.auth ? 'exists' : 'create'} | ` +
            `Profile: ${plan.state}`
        );
    }

    if (!apply) {
        console.log(
            'No changes made. Review before running with --apply.'
        );
        return;
    }

    for (const plan of plans) {
        let user = plan.auth;

        if (!user) {
            user = await auth.createUser({
                phoneNumber: plan.phone,
                displayName: plan.name,
                disabled: false,
            });
        }

        const userRef = db.doc(`users/${user.uid}`);

        let userDoc = await userRef.get();

        if (!userDoc.exists) {
            if (plan.doc) {
                fail(
                    `Existing profile UID mismatch for ${plan.phone}`
                );
            }

            await userRef.create({
                uid: user.uid,
                residentId: `GW-TEST-${plan.key.slice(-1)}`,

                name: plan.name,
                fullName: plan.name,

                phoneNumber: plan.phone,
                phone: plan.phone,

                role: 'resident',
                communityId: COMMUNITY,

                declaredResidentType: 'owner',
                residentType: 'owner',
                ownershipType: 'owner',

                approvalStatus: 'pending',
                isActive: false,
                status: 'pending',
                occupancyStatus: 'pending',

                identityVerified: true,
                identityVerificationStatus: 'verified',

                buildingId: plan.flat.get('buildingId'),
                buildingName:
                    plan.building.name ||
                    plan.building.buildingName,

                flatId: plan.flat.id,
                flatLabel:
                    plan.flat.get('flatLabel') ||
                    plan.flat.id,

                unitId:
                    plan.flat.get('unitId') ||
                    plan.flat.get('flatId') ||
                    plan.flat.id,

                familyMembers: 0,
                creationSource: 'demo_test_login',

                isDemoData: true,
                seedBatch: BATCH,
                seedVersion: 1,
                seedKey: plan.key,

                createdBy: ACTOR_UID,

                createdAt:
                    admin.firestore.FieldValue.serverTimestamp(),

                updatedAt:
                    admin.firestore.FieldValue.serverTimestamp(),
            });

            userDoc = await userRef.get();
        }

        if (
            userDoc.get('seedKey') !== plan.key ||
            userDoc.get('phoneNumber') !== plan.phone ||
            userDoc.get('communityId') !== COMMUNITY
        ) {
            fail(`Conflicting user document for ${plan.phone}`);
        }

        if (userDoc.get('approvalStatus') === 'pending') {
            await approveResidentRegistrationCore({
                db,
                auth: {
                    uid: ACTOR_UID,
                    token: {
                        phone_number: actor.get('phoneNumber'),
                        firebase: {
                            sign_in_provider: 'phone',
                        },
                    },
                },
                data: {
                    communityId: COMMUNITY,
                    userId: user.uid,
                    buildingId: plan.flat.get('buildingId'),
                    flatId: plan.flat.id,
                    residentType: 'owner',
                },
            });
        }

        const verified = await userRef.get();

        if (
            verified.get('approvalStatus') !== 'approved' ||
            verified.get('isActive') !== true ||
            verified.get('occupancyStatus') !== 'current'
        ) {
            fail(`Verification failed for ${plan.phone}`);
        }

        console.log(
            `READY ${plan.phone}: Auth UID ${user.uid}, ` +
            `flat ${plan.flat.id}`
        );
    }
}

main().catch((e) => {
    console.error('FAILED:', e.message);
    process.exitCode = 1;
});
