# Hominode web reference redesign

The supplied Admin and Resident dashboard references guide the presentation. This change preserves existing routes, callbacks, data sources and authorization. Reference-only datasets and destinations have not been invented.

## Route coverage

### hominode_web Admin

| Route | Presentation |
| --- | --- |
| `/admin` | Collection snapshot, compact operational metrics, community summary, visitors, complaints, quick actions, decorative community banner |
| `/admin/community` | Community identity, details and status with a cool white header |
| `/admin/buildings` | Inventory overview, search, operational table and mobile cards |
| `/admin/residents` | Resident summary, filters, management table/cards and existing import/action controls |
| `/admin/visitors` | Visitor summary, filters, queue/table and mobile cards |
| `/admin/complaints` | Management summary, filters, queue and existing status/actions |
| `/admin/amenities` | Facility configuration and booking management |
| `/admin/billing` | Collections summary, bill/payment management and review actions |
| `/admin/events` | Events/notices publishing interface |
| `/admin/reports` | Existing reporting summaries |
| `/admin/settings` | Existing community, account and access settings |

All navigation pages retain their individual content layouts and functions. Shared changes apply to cards, forms, dialogs, table headings and buttons; the page headers and summary pills use the Admin palette.

### hominode_web Resident

| Route | Presentation |
| --- | --- |
| `/resident` | Photographic community hero, apartment details, personal metrics, announcements, events, bills and all six existing quick actions |
| `/resident/unit` | Warm photographic page heading and apartment detail card |
| `/resident/bills` | Warm page heading, personal bill summaries and existing payment actions |
| `/resident/visitors` | Warm page heading, friendly visitor rows/status and existing invite form |
| `/resident/complaints` | Warm page heading, personal ticket history/filter/status and existing create form |
| `/resident/notices` | Warm page heading and existing announcement feed |
| `/resident/events` | Warm page heading and existing dated event feed |

Resident navigation-page styling is inherited through `ResidentPageLayout`, role theme and shared card/list primitives. Their service calls, filters, payment/visitor/complaint submissions and Back handlers are untouched.

### Separate Admin app

The desktop shell/dashboard and shared module frame/theme cover all 12 existing modules:

`/dashboard`, `/buildings`, `/residents`, `/billing`, `/visitors`, `/complaints`, `/events`, `/parking`, `/resident-vehicles`, `/amenities`, `/profile`, `/settings`.

Legacy URL aliases remain unchanged. Individual module management content is retained. The existing routing breakpoint continues to use the existing mobile presentations below 1024px; this change does not replace the mobile app or alter the guarded route resolver.

## Design system and responsive behavior

- Admin: navy sidebar, bright blue selected item, light-blue ambient canvas, white cards, navy text, pale blue summary pills.
- Resident: charcoal/warm sidebar, cream/gold selected item, warm canvas, photographic hero, tan and green accents, resident identity at sidebar bottom.
- Role-scoped theme and card tokens leave platform/Super Admin styling intact. Shared stat values scale down when needed without truncating the value.
- `hominode_web`: drawer below 720px, compact rail at intermediate widths, persistent/collapsible sidebar from 1100px. Dashboard columns stack at available-content breakpoints. Cards grow with promotional text; header actions stack when necessary.
- Existing mobile table/card variants, keyboard button behavior, status text, navigation callbacks and browser routing are retained.
- Toolbar search is explicitly page search over existing destinations. It does not claim to search resident data or introduce new backend queries.
- The existing Admin tenant selector remains wired to its existing callback; Resident continues to show its authorized community.

## Validation

- `dart format`: completed for every changed Dart file; scoped `git diff --check` passed.
- `hominode_web`: all 45 tests passed, including existing responsive/navigation/session/import tests and 16 new role dashboard, drawer and page-search checks. New dashboard widths: 360, 390, 430, 768, 1280, 1536 and 1920px.
- Separate Admin app: all 29 selected dashboard, desktop module, navigation, route mapping and routing-guard tests passed.
- Targeted analysis: the eight changed/new core web presentation/test files and four changed Admin desktop files report no issues.
- Full `hominode_web` analysis: no errors or warnings; four pre-existing `avoid_types_as_parameter_names` info lints remain in Buildings and Reports. Their declarations were verified in HEAD. The analyzer exits nonzero for these info lints.
- Full Admin app analysis: 2459 existing legacy issues remain outside the changed desktop files, including invalid library directives, missing models/getters and deprecated API usage. This full analyzer run is not clean; unrelated code was not rewritten.
- `flutter build web --release --no-pub`: successful for both apps, including a final web build after the last presentation adjustment. Both builds reported WebAssembly dry-run incompatibilities in the existing `image` dependency; normal release JavaScript web builds succeeded.
- Rendered desktop fixture previews were inspected to verify role distinction, image loading, active navigation contrast and content density. These are not live Firebase acceptance tests.

## Remaining manual review

- Review with real tenant data: long community/unit names, empty and error states, large record counts, dialogs and existing CRUD/payment/import actions.
- Verify browser refresh/back and tenant switching on actual tenant slug URLs; automated route/session tests do not replace a browser session with Firebase.
- Review keyboard focus, screen readers, zoom, currency font rendering, and touch behavior in Chrome/Safari/Firefox.
- The separate Admin app keeps its existing mobile presentations under 1024px. Its redesigned desktop module layouts were checked from 800px available workspace upward.
- Reference-only deliveries, service requests, reservations, expense trends and occupancy percentages are not present in the existing dashboard repositories. No new routes or invented values were added for them.
- No deployment was performed. Backend, Firebase configuration, App Check/auth, rules, notifications and SOS implementation were not edited in this redesign.

## Image provenance

`hominode_web/assets/images/community_morning.png` was generated with the built-in imagegen tool as decorative community imagery, not a photograph of the resident's actual community. Existing role logos were copied into the web asset bundle without edits.

Prompt: “Use case: photorealistic-natural. Create a single wide landscape architectural photograph for the Hominode resident community dashboard hero. Upscale contemporary Indian apartment community in gentle warm morning sunlight, landscaped gardens and leafy trees, elegant cream stone mid-rise apartment buildings receding towards the right, blue sky with pale gold haze. Camera at human eye level from a garden walkway. Left third is softly shaded foliage with uncluttered darker tones for white overlay text; right side has sunlit apartments and garden detail. Natural credible architectural photography, welcoming lived-in community, restrained warm cream, sage green, soft sky blue palette. Wide 3:2 image that can also be cropped to a 5:1 banner. No lettering, logos, UI, borders, collages, watermarks or dramatic neon effects.”

## Files changed in this redesign

- `hominode_web/pubspec.yaml`
- `hominode_web/lib/src/theme/web_design_system.dart`
- `hominode_web/lib/src/widgets/web_shell.dart`
- `hominode_web/lib/src/widgets/dashboard_components.dart`
- `hominode_web/lib/src/widgets/resident_page_components.dart`
- `hominode_web/lib/src/widgets/community_visuals.dart`
- `hominode_web/lib/src/pages/admin_dashboard.dart`
- `hominode_web/lib/src/pages/resident_dashboard.dart`
- `hominode_web/lib/src/pages/admin_amenities_page.dart`
- `hominode_web/lib/src/pages/admin_billing_page.dart`
- `hominode_web/lib/src/pages/admin_buildings_page.dart`
- `hominode_web/lib/src/pages/admin_complaints_page.dart`
- `hominode_web/lib/src/pages/admin_events_notices_page.dart`
- `hominode_web/lib/src/pages/admin_my_community_page.dart`
- `hominode_web/lib/src/pages/admin_reports_page.dart`
- `hominode_web/lib/src/pages/admin_residents_page.dart`
- `hominode_web/lib/src/pages/admin_settings_page.dart`
- `hominode_web/lib/src/pages/admin_visitors_page.dart`
- `hominode_web/test/role_dashboard_design_test.dart`
- `hominode_web/assets/images/community_morning.png`
- `hominode_web/assets/images/hominode_admin.png`
- `hominode_web/assets/images/hominode_resident.png`
- `hominode-admin/admin_app/lib/admin_desktop_shell.dart`
- `hominode-admin/admin_app/lib/admin_dashboard_desktop_content.dart`
- `hominode-admin/admin_app/lib/desktop/admin_desktop_design.dart`
- `hominode-admin/admin_app/lib/desktop/admin_desktop_page_frame.dart`
- `docs/hominode-web-redesign.md`
