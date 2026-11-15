
'use strict';

const admin = require('firebase-admin');
const {
    createSecurityStaffCore,
} = require('../src/security_management');

const PROJECT = 'hominode-prod';
const COMMUNITY = 'GREEN-WAVE';
const BATCH = 'green-wave-2027-v1';
const PHONE = '+916505556789';
const NAME = 'Vikram Nair';
const SECURITY_ID = 'GW-SEC-TEST-001';
const ACTOR_UID = 'demo-admin-green-wave';

async function main() {
    const args = process.argv;
    const index = args.indexOf('--project');

    if (
        index < 0 ||
        args[index + 1] !== PROJECT ||
        args.some(
            (arg) =>
                arg.startsWith('--') &&
                !['--project', '--apply'].includes(arg)
        )
    ) {
        throw new Error('Use --project hominode-prod [--apply]');
    }

    const apply = args.includes('--apply');

    admin.initializeApp({ projectId: PROJECT });

    const db = admin.firestore();
    const authAdmin = admin.auth();

    const [community, actor, staffByPhone] = await Promise.all([
        db.doc(`communities/${COMMUNITY}`).get(),
        db.doc(`admins/${ACTOR_UID}`).get(),
        db.collection('securityStaff')
            .where('phoneNumber', '==', PHONE)
            .get(),
    ]);

    if (
        !community.exists ||
        community.get('isActive') !== true ||
        community.get('isDemoData') !== true ||
        community.get('seedBatch') !== BATCH
    ) {
        throw new Error('GREEN-WAVE demo community validation failed');
    }

    if (
        !actor.exists ||
        actor.get('role') !== 'admin' ||
        actor.get('isActive') !== true ||
        !actor.get('authorizedCommunityIds')?.includes(COMMUNITY)
    ) {
        throw new Error('GREEN-WAVE admin validation failed');
    }

    let existingAuth = null;

    try {
        existingAuth = await authAdmin.getUserByPhoneNumber(PHONE);
    } catch (error) {
        if (error.code !== 'auth/user-not-found') {
            throw error;
        }
    }

    if (staffByPhone.size > 1) {
        throw new Error('Duplicate security phone profiles detected');
    }

    if (staffByPhone.size === 1) {
        const doc = staffByPhone.docs[0];

        if (
            !existingAuth ||
            doc.id !== existingAuth.uid ||
            doc.get('role') !== 'security' ||
            doc.get('communityId') !== COMMUNITY ||
            doc.get('isActive') !== true
        ) {
            throw new Error('Conflicting security account detected');
        }

        console.log(`READY: ${PHONE} / UID ${existingAuth.uid}`);
        return;
    }

    if (existingAuth) {
        const uid = existingAuth.uid;

        const [resident, administrator, security] =
            await Promise.all([
                db.doc(`users/${uid}`).get(),
                db.doc(`admins/${uid}`).get(),
                db.doc(`securityStaff/${uid}`).get(),
            ]);

        if (
            resident.exists ||
            administrator.exists ||
            security.exists
        ) {
            throw new Error(
                'Existing Firebase Auth UID has a conflicting profile'
            );
        }
    }

    const sameSecurityId = await db.collection('securityStaff')
        .where('securityId', '==', SECURITY_ID)
        .get();

    if (!sameSecurityId.empty) {
        throw new Error('Security ID is already in use');
    }

    console.log(`Project: ${PROJECT}`);
    console.log(`Community: ${COMMUNITY}`);
    console.log(`Name: ${NAME}`);
    console.log(`Phone: ${PHONE}`);
    console.log(`Role: security`);
    console.log(`Status: active`);
    console.log(`Gate: unassigned`);
    console.log(`Auth: ${existingAuth ? 'exists' : 'create'}`);
    console.log(`Mode: ${apply ? 'APPLY' : 'DRY RUN'}`);

    if (!apply) {
        console.log('No changes made.');
        return;
    }

    const result = await createSecurityStaffCore({
        db,
        authAdmin,
        auth: {
            uid: ACTOR_UID,
            token: {
                phone_number: actor.get('phoneNumber'),
                firebase: { sign_in_provider: 'phone' },
            },
        },
        data: {
            communityId: COMMUNITY,
            phoneNumber: PHONE,
            name: NAME,
            securityId: SECURITY_ID,
            buildingId: null,
            gateId: null,
            shift: null,
            isActive: true,
        },
    });

    const verified = await db
        .doc(`securityStaff/${result.uid}`)
        .get();

    if (
        !verified.exists ||
        verified.get('role') !== 'security' ||
        verified.get('isActive') !== true ||
        verified.get('phoneNumber') !== PHONE ||
        verified.get('communityId') !== COMMUNITY
    ) {
        throw new Error('Security profile verification failed');
    }

    console.log(`READY: ${PHONE} / UID ${result.uid}`);
}

main().catch((error) => {
    console.error('FAILED:', error.message);
    process.exitCode = 1;
});
