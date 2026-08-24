# Hominode Phase 2B: resident OTP registration

## Routing after successful OTP

Every manual OTP, automatic Android verification, resend verification, splash,
and cold-start session follows the same state mapping:

| Profile state | Route |
|---|---|
| No `users/{firebaseAuthUid}` | `/resident-registration` |
| `approvalStatus: pending` | `/awaiting-approval` |
| `approvalStatus: rejected` | `/resident-access-blocked` with rejection message |
| `approvalStatus: blocked`, inactive approved profile, wrong role, missing/inactive tenant | `/resident-access-blocked` |
| `approvalStatus: approved`, `isActive: true`, role `resident`, active community | `/home` |
| Invalid/expired OTP or authentication failure | Remain in authentication flow |

Missing and pending profiles retain the verified phone session so registration
and status checks can work. A non-resident role or invalid tenant never reaches
resident application data.

## Invite-code contract

Invite codes are normalized to uppercase letters, digits, hyphen, and underscore
and looked up directly by document ID; the client never lists communities:

```text
communityInvites/{NORMALIZED_CODE}
  communityId: string
  isActive: boolean
  expiresAt: timestamp|null
  maxUses: number|null
  useCount: number
  createdAt: timestamp
  updatedAt: timestamp
```

The service validates the invite, then gets the referenced
`communities/{communityId}` document and verifies `isActive`. Only its name and
logo are shown. The proposed rules permit authenticated profile-less users to
get a known invite and its referenced community, while denying collection list
operations. Codes must be high-entropy and distributed privately.

## Resident registration document

Registration creates exactly `users/{firebaseAuthUid}`:

```text
uid: Firebase Auth UID
phoneNumber: verified E.164 Firebase phone
phone: verified E.164 Firebase phone       # legacy-compatible alias
name: string
fullName: string                           # legacy-compatible alias
email: string|null
communityId: string
communityInviteCode: string
role: resident
isActive: false
approvalStatus: pending
buildingReference: string                  # resident-supplied tower/building
unitReference: string                      # resident-supplied flat/unit
buildingId: null                           # admin resolves canonical reference
unitId: null
flatId: null                               # legacy-compatible canonical unit
createdAt: server timestamp
updatedAt: server timestamp
```

The write is transactional, refuses to overwrite an existing profile, checks
that the Firebase UID and phone match the verified session, and rechecks that
the invite still points to the selected community. No password or Auth account
is created; Firebase Phone Auth has already established the identity.

Building/unit values intentionally remain resident-supplied references until
admin review. Allowing an unapproved user to browse tenant building and flat
collections would expose community data and weaken tenant isolation.

## Admin-side work still required

1. Add trusted invite management that creates/revokes high-entropy
   `communityInvites` documents and maintains expiry/use counters. The client
   reads invites but cannot create or modify them.
2. Add a pending-resident queue filtered by `communityId`, `role: resident`, and
   `approvalStatus: pending`.
3. On approval, verify identity/building/unit; populate canonical `buildingId`,
   `unitId`/`flatId`; set `approvalStatus: approved`, `isActive: true`, and
   `updatedAt` atomically.
4. On rejection, set `approvalStatus: rejected`, keep `isActive: false`, and
   optionally store trusted audit fields such as `reviewedBy`, `reviewedAt`, and
   a non-sensitive rejection reason.
5. On suspension, set `approvalStatus: blocked` and `isActive: false`.
6. Ensure admins can operate only on their authorized communities and cannot
   change a resident to another tenant during approval.
7. Add notifications for submission and review decisions in a later phase.
8. Backfill legacy active residents with `approvalStatus: approved` before the
   proposed rules are deployed. Legacy active profiles remain compatible in the
   client because missing approval status is interpreted as approved.

`firestore.rules` was updated only as a proposed ruleset for invite reads and a
tightly constrained self-registration create. It was compiled locally but was
not deployed. No production data was migrated.
