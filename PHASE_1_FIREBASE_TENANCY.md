# Hominode Phase 1: Firebase tenant foundation

This phase adds a tenant contract without changing screens, navigation, or
existing collection paths. The repository currently contains only
`resident_app`; its source also includes admin screens/services. There is no
separate `admin_app` platform project in this checkout.

## Firestore schema

Canonical community document:

```text
communities/{communityId}
  name: string
  slug: string                         // unique, lowercase URL-safe identifier
  logoUrl: string|null
  primaryColor: string|null            // e.g. #2563EB; app does not consume it yet
  secondaryColor: string|null
  bannerUrls: string[]
  supportPhone: string|null
  supportEmail: string|null
  address: string|null
  isActive: boolean
  createdAt: timestamp
  updatedAt: timestamp
  features:
    visitors: boolean
    amenities: boolean
    complaints: boolean
    notices: boolean
    chat: boolean
    marketplace: boolean
    maintenance: boolean
    payments: boolean
```

Resident profile (`users/{firebaseAuthUid}`) and admin profile
(`admins/{firebaseAuthUid}`):

```text
communityId: string
role: resident|admin|superAdmin|security
isActive: boolean
authorizedCommunityIds: string[]       // admin only; optional additional tenants
```

Every tenant-owned operational document remains in its current root collection
and gains `communityId`. This includes users/residents, admins, buildings,
flats/units, visitors, amenities, bookings/amenityBookings, complaints, notices,
announcements/events, chats/adminChats and their messages, maintenance, bills,
payments, marketplace/listings, community wall/posts, notifications, and staff.
Nested documents such as chat messages and comments also require `communityId`;
this makes collection-group queries independently enforceable.

## Runtime contract

`TenantResolutionService` is registered once at app root. It requires a Firebase
Auth user, reads `users/{uid}` (falling back to `admins/{uid}`), validates
`communityId`, `role`, and profile `isActive`, then loads and validates the
community. Missing or inactive data fails closed with a typed
`TenantResolutionException`. The resulting `TenantContext` exposes community
branding metadata and feature flags. UI consumption is intentionally deferred.

Use `TenantFirestore.stamp(communityId, data)` for new writes and
`TenantFirestore.scope(collection, communityId)` for migrated queries. Firestore
rules are not filters, so all list queries must explicitly filter by the resolved
`communityId`.

## Rules and indexes

`firestore.rules` is the new canonical, deny-by-default ruleset. It does not
replace the historical `.txt` rule examples, including the unsafe development
file that allows all access. Do not deploy the new rules until profiles and
operational documents used by the release have been backfilled; documents
without `communityId` are deliberately inaccessible.

`firestore.indexes.json` contains initial compound indexes for common tenant
queries. Firebase may request additional indexes as individual legacy queries
are converted. Always make `communityId` the first equality constraint.

Community creation, slug uniqueness, admin authorization changes, and tenant
deactivation are denied to clients. Perform them through a trusted Admin SDK
environment or Firebase Console until a privileged backend is added.

## Manual Firebase setup

1. Choose or create one Firebase project for all Hominode clients. Enable
   Authentication providers, Firestore, and any other already-used products.
2. Register distinct Firebase apps in that same project:
   - Android resident: `com.marantrix.hominode.resident`
   - Android admin: `com.marantrix.hominode.admin`
   - iOS resident/admin bundle IDs using the same Hominode reverse-domain names
   - Web: `hominode-web`
3. Download each platform config. Put the resident `google-services.json` in
   `resident_app/android/app/`; put `GoogleService-Info.plist` in the resident
   Xcode Runner target. Configure the separate admin project likewise when it is
   added to this checkout. Do not combine Android config files by hand.
4. Run FlutterFire CLI once per actual app directory against the same project,
   producing each app's `lib/firebase_options.dart`, then initialize with
   `DefaultFirebaseOptions.currentPlatform`. The current project relies on
   native default configuration, so this is still manual.
5. Only after replacement config files exist, change Android `namespace` and
   `applicationId`, Android manifest packages, and iOS bundle identifiers from
   the current Lyvo/example IDs to the target Hominode IDs.
6. Copy `.firebaserc.example` to `.firebaserc` and replace the placeholder project
   ID. Then deploy indexes and rules from the repository root:
   `firebase deploy --only firestore:indexes` followed by
   `firebase deploy --only firestore:rules`.
7. Create at least one active community, then backfill profiles first. Ensure
   every Firebase Auth UID exactly matches its `users/{uid}` or `admins/{uid}`
   document ID. Backfill operational collections in batches and validate counts
   before enabling the strict rules.
8. Add `hominode.com` and planned subdomains to Firebase Auth authorized domains.
   Configure DNS/Hosting rewrites separately. The included hosting fallback
   supports `/c/{slug}`; wildcard `community.hominode.com` needs DNS, TLS, and a
   host-to-slug resolver in a later phase.

## Migration risks and remaining work

- Existing documents generally lack `communityId`; strict rules will hide them.
- Many services query entire root collections and must be migrated to
  `TenantFirestore.scope` before rules deployment. Highest-risk areas are users,
  admin statistics, buildings/flats, visitors, amenities/bookings, complaints,
  notices/events, chats/messages, bills/payments, and marketplace/community wall.
- Current login code queries Firestore by email/phone and handles plaintext
  password fields before Firebase Auth. Strict rules cannot safely permit that
  unauthenticated lookup. Migrate login to Firebase Auth first and remove
  plaintext passwords before production.
- Some records use `buildingId` as the security boundary. Keep it for business
  relationships, but do not treat it as a tenant identifier.
- Collection names have aliases (`bookings`/`amenityBookings`,
  `marketplace`/`listings`, `chats`/`adminChats`). Inventory live production data
  before backfill; do not merge or delete aliases during Phase 1.
- Admin authorization is security-sensitive. Populate `authorizedCommunityIds`
  only through trusted tooling and keep `communityId` as the active/default
  tenant selected at sign-in.
- Slug uniqueness is not enforceable by Firestore rules alone. Reserve slugs in
  trusted backend logic before host/path resolution is enabled.
