# Apply Standard Header to All Screens - Implementation Guide ✅

## Screens to Update

You want the standard header (with status bar gradient) applied to these screens:

1. ✅ Home Screen (Dashboard)
2. ✅ Visitor Management Screen
3. ✅ Maintenance & Billing Screen
4. ✅ Events & Announcements Screen
5. ✅ Complaints & Requests Screen
6. ✅ Community Wall Screen
7. ✅ Amenities Booking Screen
8. ✅ Marketplace Screen
9. ✅ Edit Profile Screen (already done as example)

## The Standard Pattern

### Import Statement
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/standard_screen.dart';
```

### Replace Entire Screen Structure

**Before (Old Pattern):**
```dart
Scaffold(
  appBar: AppBar(
    title: Text('Title'),
    backgroundColor: Colors.blue,
  ),
  body: SingleChildScrollView(
    child: // Content
  ),
)
```

**After (Standard Pattern):**
```dart
StandardScreen(
  title: 'Title',
  showBackButton: false, // For main screens without back button
  body: Column(
    children: [
      // Your content here
    ],
  ),
)
```

## Screen-by-Screen Implementation

### 1. Home Screen (Dashboard)
**File**: `lib/dashboard_screen.dart` or `lib/src/screens/dashboard_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'src/components/standard_screen.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Home',
      showBackButton: false, // No back button on home
      body: Column(
        children: [
          // Banner carousel
          // Quick access grid
          // Recent activities
          // Your existing dashboard content
        ],
      ),
    );
  }
}
```

### 2. Visitor Management Screen
**File**: `lib/visitor_management_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'src/components/standard_screen.dart';

class VisitorManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Visitor Management',
      body: Column(
        children: [
          // Add visitor button
          // Visitor list
          // Your existing content
        ],
      ),
    );
  }
}
```

### 3. Maintenance & Billing Screen
**File**: `lib/maintenance_billing_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'src/components/standard_screen.dart';

class MaintenanceBillingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Maintenance & Billing',
      body: Column(
        children: [
          // Current bill card
          // Payment history
          // Your existing content
        ],
      ),
    );
  }
}
```

### 4. Events & Announcements Screen
**File**: `lib/events_announcements_screen.dart` or `lib/src/screens/events_module_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../components/standard_screen.dart';

class EventsAnnouncementsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreenWithSearch(
      title: 'Events & Announcements',
      showBackButton: false,
      onSearchPressed: () {
        // Show search
      },
      body: Column(
        children: [
          // Tabs (Events, Notices, Polls)
          // Event cards
          // Your existing content
        ],
      ),
    );
  }
}
```

### 5. Complaints & Requests Screen
**File**: `lib/complaints_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'src/components/standard_screen.dart';

class ComplaintsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Complaints & Requests',
      body: Column(
        children: [
          // Add complaint button
          // Complaint list
          // Your existing content
        ],
      ),
    );
  }
}
```

### 6. Community Wall Screen
**File**: `lib/community_wall_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'src/components/standard_screen.dart';

class CommunityWallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreenWithMenu(
      title: 'Community Wall',
      showBackButton: false,
      onMenuPressed: () {
        // Show menu options
      },
      body: Column(
        children: [
          // Add post button
          // Post feed
          // Your existing content
        ],
      ),
    );
  }
}
```

### 7. Amenities Booking Screen
**File**: `lib/src/screens/amenities_booking_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../components/standard_screen.dart';

class AmenitiesBookingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Amenities Booking',
      body: Column(
        children: [
          // Amenity cards
          // Booking calendar
          // Your existing content
        ],
      ),
    );
  }
}
```

### 8. Marketplace Screen
**File**: `lib/src/screens/marketplace_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../components/standard_screen.dart';

class MarketplaceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreenWithSearch(
      title: 'Marketplace',
      showBackButton: false,
      onSearchPressed: () {
        // Show search
      },
      body: Column(
        children: [
          // Filter chips
          // Product grid
          // Your existing content
        ],
      ),
    );
  }
}
```

### 9. Edit Profile Screen
**File**: `lib/src/screens/edit_profile_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../components/standard_screen.dart';

class EditProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Edit Profile',
      body: Column(
        children: [
          // Avatar picker
          // Form fields
          // Save button
          // Your existing content
        ],
      ),
    );
  }
}
```

## Quick Migration Steps

### Step 1: Add Import
At the top of each screen file:
```dart
import '../components/standard_screen.dart';
// or
import 'src/components/standard_screen.dart';
```

### Step 2: Replace Scaffold
Find your `Scaffold` widget and replace with `StandardScreen`:

**Find:**
```dart
Scaffold(
  appBar: AppBar(...),
  body: ...
)
```

**Replace with:**
```dart
StandardScreen(
  title: 'Your Title',
  body: ...
)
```

### Step 3: Remove Old Header Code
Delete any custom header/AppBar code:
- Remove `AppBar` widget
- Remove custom gradient containers
- Remove `SafeArea` wrappers (StandardScreen handles it)
- Remove `AnnotatedRegion` (StandardScreen handles it)

### Step 4: Adjust Content
Your content should be in a `Column` or `ListView`:
```dart
body: Column(
  children: [
    // Your widgets here
  ],
)
```

### Step 5: Test
- Check status bar gradient
- Check header appearance
- Check back button (if applicable)
- Check content scrolling

## Common Patterns

### Main Screen (No Back Button)
```dart
StandardScreen(
  title: 'Home',
  showBackButton: false,
  body: // Content
)
```

### Detail Screen (With Back Button)
```dart
StandardScreen(
  title: 'Details',
  // showBackButton: true is default
  body: // Content
)
```

### Screen with Search
```dart
StandardScreenWithSearch(
  title: 'Search Items',
  onSearchPressed: () => _showSearch(),
  body: // Content
)
```

### Screen with Menu
```dart
StandardScreenWithMenu(
  title: 'Options',
  onMenuPressed: () => _showMenu(),
  body: // Content
)
```

## What You Get

After applying StandardScreen to all screens:

✅ **Consistent Status Bar**
- Transparent with gradient showing through
- White icons
- Same across all screens

✅ **Consistent Header**
- Same gradient (#2563EB → #1E40AF)
- Same title size (18px)
- Same padding
- Same rounded corners

✅ **Consistent Content Area**
- Same background (#F7F7F7)
- Same padding (16px)
- Scrollable by default
- Bouncing physics

✅ **Professional Appearance**
- Seamless gradient flow
- No white gaps
- Modern design
- Polished look

## Testing Checklist

For each screen, verify:
- [ ] Status bar shows gradient (no white bar)
- [ ] Status bar icons are white
- [ ] Header title is visible
- [ ] Back button works (if applicable)
- [ ] Content scrolls properly
- [ ] Rounded corners visible
- [ ] No layout issues
- [ ] All functionality works

## Files to Modify

1. `lib/dashboard_screen.dart` - Home
2. `lib/visitor_management_screen.dart` - Visitor Management
3. `lib/maintenance_billing_screen.dart` - Billing
4. `lib/events_announcements_screen.dart` - Events
5. `lib/complaints_screen.dart` - Complaints
6. `lib/community_wall_screen.dart` - Community
7. `lib/src/screens/amenities_booking_screen.dart` - Amenities
8. `lib/src/screens/marketplace_screen.dart` - Marketplace
9. `lib/src/screens/edit_profile_screen.dart` - Edit Profile

## Priority Order

1. **Start with Edit Profile** (as example)
2. **Then Home Screen** (most visible)
3. **Then main features** (Visitor, Events, Community, Marketplace)
4. **Then secondary** (Billing, Complaints, Amenities)

## Need Help?

If a screen has complex layout:
1. Keep the content as-is
2. Just wrap it in StandardScreen
3. Remove old header code
4. Test and adjust

---

**Status**: ✅ Ready to implement
**Pattern**: StandardScreen wrapper
**Result**: Consistent UI across all screens
**Time**: ~5 minutes per screen
