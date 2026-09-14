# Hominode SOS Feature

## Overview

Hominode SOS provides a trusted emergency-alert workflow between Residents, Security, and authorized Admin users within the same community.

The SOS lifecycle is:

triggered -> acknowledged -> responding -> resolved

A Resident may cancel only while the alert is still in the triggered state.

## Backend

Primary implementation:

- functions/src/sos.js
- functions/src/sos_notifications.js
- functions/src/notifications.js
- functions/src/resident_identity.js
- functions/src/index.js

Callable functions:

- getSosContext
- triggerSos
- transitionSos

Firestore notification trigger:

- dispatchSosNotifications

All SOS callables are protected by Firebase Authentication and App Check.

Resident identity, role, community, building, and unit context are derived from trusted backend data rather than client-provided authority fields.

## SOS State

Primary collection:

- sosAlerts

Internal backend-only collections:

- sosActive
- sosRequests
- sosNotificationEvents
- sosDeliveries

Only one active SOS is allowed per Resident.

Active states:

- triggered
- acknowledged
- responding

Terminal states:

- resolved
- cancelled

Direct client writes to SOS state are denied by Firestore Rules.

## Resident

The Resident app can:

- deliberately trigger SOS
- optionally attach one-time device location
- trigger SOS without GPS permission
- view live SOS status
- cancel only before acknowledgement
- call trusted Security/emergency contact numbers
- open SOS from trusted push notifications
- view current and historical SOS alerts

No continuous location tracking is used.

## Security

The Security app can:

- view active SOS alerts for its own community
- acknowledge a triggered SOS
- mark an acknowledged SOS as responding
- resolve an acknowledged/responding SOS
- open SOS details from trusted notifications

Security access is restricted to its authenticated active community.

## Admin

Authorized Admin users can:

- view SOS alerts for the selected authorized community
- view active and historical SOS alerts
- acknowledge/respond/resolve when backend role authorization permits
- open trusted SOS notifications

Admin tenant context is fail-closed.

## Notifications

SOS notifications reuse the Hominode notification infrastructure.

On trigger:

- active Security recipients in the same community are notified
- authorized Admin recipients may be notified

On SOS status change:

- the owning Resident is notified

Notification delivery uses durable delivery state and retry behavior.

Notification failure does not roll back authoritative SOS state.

Stale tokens are removed and multiple registered devices are deduplicated.

## Firestore Security

sosAlerts:

- Admin reads are community-scoped
- Security reads are community-scoped
- Resident reads are restricted to their own Resident UID and community
- all direct writes are denied

The following collections deny all client access:

- sosActive
- sosRequests
- sosNotificationEvents
- sosDeliveries

## Indexes

Composite indexes exist for:

- communityId + status + triggeredAt ascending
- communityId + status + triggeredAt descending
- communityId + residentUid + status + triggeredAt ascending
- communityId + residentUid + status + triggeredAt descending

## Resident Lifecycle Protection

Active SOS alerts block trusted lifecycle actions that could invalidate the Resident's active emergency context, including:

- deactivate resident
- reassign resident
- move out resident
- identity-review state changes that could deactivate an active Resident

## Validation

Backend SOS tests cover:

- trusted canonical context
- generalized housing/unit types
- authentication and community isolation
- optional one-time GPS
- duplicate and rapid trigger protection
- legal state transitions
- acknowledgement/cancellation races
- multiple responder races
- notification targeting
- notification retries
- stale-token cleanup
- resident status notifications
- App Check registration

Shared Flutter SOS package:

- flutter analyze: clean
- flutter test: all tests passing

Admin web production build:

- flutter build web --release --source-maps --base-href /
- successful

## Deployment

Production Firebase project:

- hominode-prod

Deploy SOS Functions selectively:

- getSosContext
- triggerSos
- transitionSos
- dispatchSosNotifications
- deactivateResident
- reassignResident
- reviewResidentIdentityProof
- moveOutResident

Also deploy:

- Firestore Rules
- Firestore indexes

Admin hosting target:

- hominode_app

Mobile Resident and Security releases should be published only after production end-to-end SOS smoke testing.
