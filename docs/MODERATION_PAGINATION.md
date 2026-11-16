# Content moderation: bounded Admin Web queries

The Community overview displays three open reports followed by three latest decisions. “View all reports” and “View all history” replace the overview with ten-record pages. Decisions still use `resolveWallModerationReport`; a successful decision refreshes the current view from page one. No historical records are modified or deleted by pagination.

## Callable contract

The existing App Check protected `listWallModerationReports` export remains in `functions/src/index.js`. The opt-in request is:

```json
{
  "communityId": "authorized-community",
  "view": "history",
  "pageSize": 10,
  "searchField": "action",
  "search": "hide",
  "cursor": "opaque-server-returned-token"
}
```

- `view`: `summary`, `history`, or `reports`. `summary` fixes page size at 3; other views fix it at 10. `pageSize` may be omitted. Other sizes are rejected.
- `searchField`: `action` (default), `reasonCode`, `postId`, or `reportId`; history only. `search` defaults to empty, with a maximum of 128 characters. Values must already be trimmed. Search applies to the whole community query before pagination.
- `cursor`: optional, only for full views. Omit to start a fresh session; pass a returned token unchanged to navigate. Invalid tokens and tokens from another community, view, size, or search are rejected.
- Response: `reports` and `history` arrays, plus `reportsPage` and `historyPage`. The unrequested array is empty and its metadata is null.
- Metadata: `total` is the count matching the dated boundary and filters, across all pages; `totalCurrent` counts all current matches, including newer/undated records. `snapshotAtMs` labels the dated boundary. `pageCursor` reproduces the current page; `nextCursor` is null at the end and on the overview. The client retains prior page cursors for Previous.
- Page data and both aggregation counts are read within one read-only transaction, together with operational Admin authorization. Summary sections share that transaction.

Every request checks verified phone authentication, active Admin membership in `authorizedCommunityIds`, and an active selected community. All queries filter `communityId` on the server. New responses allowlist fields and omit reporter IDs and notification recipients. Internal notes remain scoped Admin-only audit fields and are displayed behind an explicitly labeled disclosure. Resident notification behavior is unchanged.

### Ordering, concurrency and read costs

Queries use `createdAt DESC, __name__ DESC`, `startAfter(timestamp, documentId)`, and `limit(pageSize + 1)`. Cursor timestamps retain seconds and nanoseconds, preserving Firestore's stored sub-millisecond precision. They do not require the cursor's source document still to exist or remain open.

The first request uses the authorization document's Firestore transaction read time as a server-clock date boundary. Cursors retain that boundary, so newly committed reports/decisions do not move existing pages. Refresh, changing view/search, switching community, and completing a decision start a new boundary. The boundary is a created-time filter, not a historical database snapshot across requests: open reports may disappear as another Admin resolves them. A page can consequently become empty; Previous remains available. Counts reflect the current transaction's matching records rather than a cached original count. No numeric record ranges are inferred from stale offsets.

Cursor tokens are base64url query positions with a version and query-context hash, not signed credentials. Authorization and community/search filters are reapplied independently of cursor contents. Tokens contain only query positions and an opaque context digest, never notes or reporter identities.

Each selected section reads at most 4 overview documents or 11 full-list documents, including the lookahead. Enrichment reads are also bounded by the returned page, with per-request caches; modern self-contained audit snapshots skip report enrichment. Two `count()` queries per section read index entries and return counts without downloading every document. Aggregations have index-read costs proportional to the matching index size; they are not free constant-cost counters. See [Firestore aggregation documentation](https://firebase.google.com/docs/firestore/query-data/aggregation-queries).

### Compatibility and older records

Requests without `view` retain the existing `communityId` / `historyOffset` contract, response arrays, truncation flags, and bounded 500-report/1,000-history compatibility behavior. Existing Flutter consumers therefore need no coordinated update. Admin Web always sends `view` and never takes that compatibility path. Migrating older clients to cursors is separate work; their previous read cost remains until migration.

All current report/decision writers set `createdAt`. Firestore date ordering excludes documents without that field. The UI discloses when `totalCurrent` exceeds the dated count rather than silently claiming the dated view is the entire collection. Newer records enter after Refresh; undated legacy records remain accessible through the compatibility client. No production audit, timestamp backfill, or data mutation was performed. If historical undated records exist, an independently reviewed timestamp repair would be needed to include them in chronological pages. See [Firestore ordering and field existence](https://firebase.google.com/docs/firestore/query-data/order-limit-data).

## Search scope

This phase supports exact, case-sensitive equality searches on existing indexed fields:

| Field | Example | Behavior |
| --- | --- | --- |
| action | `hide`, `dismiss` | Valid decision action only |
| reasonCode | `spam`, `harassment`, `no_violation` | Exact stored code |
| postId | post document ID | Decisions for that post, including comments |
| reportId | report document ID | Decisions for that report |

No substring, prefix, fuzzy, content, name, internal-note, or reporter search is implemented. There is no collection scan or client-side filtering of a fetched corpus. Earlier decisions missing the selected field cannot match it. Broader full-text search requires a separately designed search index/provider or an explicitly enabled compatible Firestore Enterprise text-search setup, with community isolation and note/reporter redaction built into indexing and query authorization. The installed Core query implementation does not implement arbitrary substring search. See [Firestore text-search documentation](https://firebase.google.com/docs/firestore/enterprise/text-search).

## Required indexes

Six collection-scope composite indexes are added to `firestore.indexes.json`:

| Collection | Equality fields (ascending) | Ordered fields (descending) |
| --- | --- | --- |
| moderationReports | communityId, status | createdAt, __name__ |
| moderationAudit | communityId | createdAt, __name__ |
| moderationAudit | communityId, action | createdAt, __name__ |
| moderationAudit | communityId, reasonCode | createdAt, __name__ |
| moderationAudit | communityId, postId | createdAt, __name__ |
| moderationAudit | communityId, reportId | createdAt, __name__ |

Existing indexes and single-field indexing are retained. Emulator tests exercise query semantics; the emulator does not prove production composite-index readiness. Wait for the new indexes to be ready before enabling the new UI.

## Verification

From `lyvo1/functions`:

```sh
node --test test/contentModeration.unit.test.js test/moderationDecisions.unit.test.js test/moderationPagination.unit.test.js
./node_modules/.bin/firebase emulators:exec --project demo-hominode-moderation-pagination --only firestore 'node --test --test-concurrency=1 test/moderationPagination.emulator.test.js test/contentModeration.rules.emulator.test.js test/moderationDecisionNotifications.emulator.test.js'
```

From `hominode-admin-web`:

```sh
npx vitest run src/test/ModerationQueue.test.tsx
npm run test
npm run typecheck
npm run build
npm run test:e2e -- e2e/moderation.spec.ts
```

Shared unit/emulator cases cover 0, 3, 10, 100 and 1,001 records in each collection; all pages and exact counts; timestamp ties and sub-millisecond ordering; first-page replay; invalid/cross-query cursors; concurrent inserts and report resolution; community isolation and protected response fields. Existing moderation tests cover decisions and notification privacy. Component cases cover both full views, search/clear, page replacement, stable Previous, failed-page Retry, stale community responses, decision validation and first-page refresh after a decision. Offline browser cases use all five sizes at 360, 768 and 1,440 pixels, check overflow and pagination/search/decision flows, and exercise error Retry. Browser fixture adapters cannot be built as a production bundle.

Validated on 2026-11-16:

| Check | Result |
| --- | --- |
| Moderation backend unit tests | 31 passed |
| Firestore emulator moderation, privacy/rules and pagination tests | 17 passed |
| Admin Web moderation component tests | 8 passed |
| Responsive moderation browser tests | 16 passed |
| TypeScript and production build | Passed; existing large-chunk advisory remains |
| Full Admin Web component suite | 767 passed, 12 existing failures |
| Index JSON and whitespace checks | Passed |

The complete Admin Web suite currently has 12 existing failures: 11 payment-settings tests lack router context; one registration-review test expects a prevented dialog cancel event. These same failures reproduce from untouched branch HEAD in a temporary directory. They are outside this moderation change.

## Minimal safe deployment order (not executed)

1. Add only the six moderation indexes; retain unrelated deployed indexes and wait for readiness. Review any unrelated index diffs before using a repository-wide index deployment.
2. Deploy only the existing `listWallModerationReports` callable with the additive `view` contract. Its wrapper, App Check configuration and resolution/notification functions remain unchanged. Check scoped summary/history/reports requests and a legacy request in the intended test environment.
3. Deploy the tested Admin Web production build. Check a scoped overview, search, Previous/Next, and an authorized moderation decision in the intended test environment. Roll back Admin Web first if needed; the additive backend can remain compatible with the old web/mobile clients.

No deploy, commit, push, new branch, production read, or production data write was performed for this work.

## Files changed

In `lyvo1`:

- `functions/src/content_moderation.js`
- `firestore.indexes.json`
- `functions/test/moderationPagination.unit.test.js`
- `functions/test/moderationPagination.emulator.test.js`
- `functions/test/helpers/moderation_pagination_cases.js`
- `functions/test/helpers/moderation_store.js`
- `docs/MODERATION_PAGINATION.md`

In `hominode-admin-web`:

- `src/ModerationQueue.tsx`
- `src/styles.css`
- `src/test/ModerationQueue.test.tsx`
- `e2e/firebase.ts`
- `e2e/moderationFixture.ts`
- `e2e/moderation.spec.ts`

The pre-existing local modification to `functions/test/visitorPolicy.firestore.emulator.test.js` and `.chat-ui-backup/` were left untouched. Both repositories remain on their original current branches.
