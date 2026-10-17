# Production Hosting deployment note

Admin Web must be deployed from the sibling `hominode-admin-web` repository
using its `npm run deploy:hosting` procedure. That command builds `dist` and
explicitly selects project `hominode-prod` and Hosting target `hominode_app`
(site `hominode-app-prod`).

Do not deploy the root `hominode_app` target for Admin Web. In this repository,
`firebase.json` maps that same target/site to `hominode_web/build/web`; deploying
it can overwrite the Admin Web artifact. The root target is retained for its
existing purpose and must not be used as the Admin Web deployment procedure.

## SEC-003 visitor gate release checklist

1. Deploy the App Check enforced Functions exports in `asia-southeast1`:
   `resolveVisitorQr`, `transitionVisitorFromQr`, and
   `dispatchVisitorDecisionNotification`. Verify both callables and the visitor
   update trigger are healthy before enabling the new client flow.
2. Release the Admin Flutter update. Admin approval/rejection remains enabled;
   approval leaves the visitor in `approved`. Admin cannot record gate entry.
   Its legacy QR screen directs check-in to Security and retains checkout.
3. Release the Security Flutter update and require the supported version before
   applying the restrictive visitor rules. Older TestFlight builds use direct
   Firestore visitor reads/writes; after the rules update, they cannot load
   pending requests or approve/check in visitors. Enforce an upgrade or accept
   that older builds lose entry processing.
4. Deploy `firestore.rules` only after the Security upgrade gate is in place.
   Admin approval/rejection and permitted checkout remain rule-authorized.
   Security check-in/approval/rejection use the callable. The QR token equality
   lookup needs no composite index; verify the existing visitor community/status
   indexes before rollout.
5. Verify on real devices: Admin approval leaves `actualArrival` unset;
   Security QR check-in works for pending and Admin-approved requests; rejection,
   duplicate/expired/cross-community QR, Mark Out/history, and host-only
   notifications work. Confirm older Security builds receive the planned upgrade
   path before rules enforcement.

### SEC-003 rollback

Keep restrictive visitor rules during rollback; do not restore direct Admin or
Security check-in permissions. If the callable or new client flow fails, pause
rollout and repair or roll forward Functions/client code. A rules rollback is
acceptable only to a version that still denies direct transitions to `inside`.
No visitor data migration is required.
