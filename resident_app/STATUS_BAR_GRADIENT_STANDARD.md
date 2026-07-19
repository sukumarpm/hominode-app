# Status Bar + Header Gradient Standard ✅

## Overview
Standardized status bar and header implementation where the gradient extends seamlessly into the status bar area across ALL screens.

## Visual Result

```
┌─────────────────────────────────┐
│ 🔋 9:41  📶 📡 🔋              │ ← Status Bar (gradient background)
├─────────────────────────────────┤
│ ← Screen Title                  │ ← Header (same gradient)
└─────────────────────────────────┘
      ↑ Seamless gradient flow
```

## Implementation

### Method 1: StandardScreen Wrapper (Recommended)

**Easiest way - Everything handled for you:**

```dart
import 'package:your_app/src/components/standard_screen.dart';

StandardScreen(
  title: 'Edit Profile',
  body: Column(
    children: [
      // Your content here
    ],
  ),
)
```

**That's it!** The wrapper handles:
- ✅ Transparent status bar
- ✅ White status bar icons
- ✅ Gradient extends into status bar
- ✅ Standard header
- ✅ Scrollable content
- ✅ Consistent padding

### Method 2: Manual Implementation

**If you need more control:**

```dart
import 'package:flutter/services.dart';
import 'package:your_app/src/components/standard_header.dart';

AnnotatedRegion<SystemUiOverlayStyle>(
  value: const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ),
  child: Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: Column(
      children: [
        StandardHeader(
          title: 'Screen Title',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: // Your content
          ),
        ),
      ],
    ),
  ),
)
```

## Key Features

### Status Bar
- **Color**: Transparent (shows gradient through)
- **Icons**: White/Light (Brightness.light)
- **iOS**: Brightness.dark for proper contrast

### Header
- **Gradient**: #2563EB → #1E40AF
- **Extends**: Into status bar area
- **Rounded**: Bottom corners (18px)
- **Title**: 18px, Semibold, White
- **Back Button**: iOS style, 20px

### Content Area
- **Background**: #F7F7F7 (light grey)
- **Padding**: 16px (standard)
- **Scrollable**: By default
- **Physics**: Bouncing scroll

## Usage Examples

### Basic Screen
```dart
StandardScreen(
  title: 'Edit Profile',
  body: YourContentWidget(),
)
```

### Screen Without Back Button
```dart
StandardScreen(
  title: 'Home',
  showBackButton: false,
  body: YourContentWidget(),
)
```

### Screen with Search
```dart
StandardScreenWithSearch(
  title: 'Search Items',
  onSearchPressed: () => _showSearch(),
  body: YourContentWidget(),
)
```

### Screen with Menu
```dart
StandardScreenWithMenu(
  title: 'Settings',
  onMenuPressed: () => _showMenu(),
  body: YourContentWidget(),
)
```

### Non-Scrollable Content
```dart
StandardScreen(
  title: 'Fixed Layout',
  isScrollable: false,
  body: YourFixedLayoutWidget(),
)
```

### Custom Padding
```dart
StandardScreen(
  title: 'Custom Padding',
  padding: EdgeInsets.all(24),
  body: YourContentWidget(),
)
```

## Screen-by-Screen Examples

### Edit Profile Screen
```dart
StandardScreen(
  title: 'Edit Profile',
  body: Column(
    children: [
      // Avatar picker
      // Form fields
      // Save button
    ],
  ),
)
```

### Settings Screen
```dart
StandardScreen(
  title: 'Settings',
  body: Column(
    children: [
      SettingTile(...),
      SettingTile(...),
      SettingTile(...),
    ],
  ),
)
```

### Emergency SOS Screen
```dart
StandardScreen(
  title: 'Emergency SOS',
  body: Column(
    children: [
      WarningBox(),
      EmergencyContactCard(),
      EmergencyContactCard(),
    ],
  ),
)
```

### Notifications Screen
```dart
StandardScreen(
  title: 'Notifications',
  body: ListView.builder(
    itemCount: notifications.length,
    itemBuilder: (context, index) => NotificationCard(...),
  ),
)
```

## Visual Specifications

### Status Bar Area
- Height: Dynamic (based on device)
- Background: Gradient (transparent status bar)
- Icons: White
- Time/Battery: White

### Header Area
- Height: Auto (content + padding)
- Background: Same gradient (seamless)
- Padding Top: 10px
- Padding Bottom: 14px
- Border Radius: 18px (bottom)

### Content Area
- Background: #F7F7F7
- Padding: 16px (default)
- Scroll: Enabled (default)
- Physics: Bouncing

## Benefits

### Visual Consistency
- ✅ Same gradient everywhere
- ✅ Seamless status bar integration
- ✅ No white gap at top
- ✅ Professional appearance

### Development Speed
- ✅ One line of code
- ✅ No manual status bar setup
- ✅ No manual header setup
- ✅ Automatic scrolling

### Maintainability
- ✅ Single source of truth
- ✅ Easy global updates
- ✅ Consistent behavior
- ✅ Less code duplication

## Migration Guide

### Before (Inconsistent)
```dart
Scaffold(
  appBar: AppBar(
    title: Text('Title'),
    backgroundColor: Colors.blue,
  ),
  body: // Content
)
```

### After (Standard)
```dart
StandardScreen(
  title: 'Title',
  body: // Content
)
```

## Common Patterns

### Pattern 1: List Screen
```dart
StandardScreen(
  title: 'Items List',
  body: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ItemCard(items[index]),
  ),
)
```

### Pattern 2: Form Screen
```dart
StandardScreen(
  title: 'Edit Form',
  body: Column(
    children: [
      TextField(...),
      TextField(...),
      ElevatedButton(...),
    ],
  ),
)
```

### Pattern 3: Detail Screen
```dart
StandardScreen(
  title: 'Item Details',
  body: Column(
    children: [
      Image(...),
      Text(...),
      Text(...),
      ActionButtons(),
    ],
  ),
)
```

## Troubleshooting

### Status Bar Not Showing Gradient
**Solution**: Make sure you're using `StandardScreen` or `AnnotatedRegion` with transparent status bar.

### White Gap at Top
**Solution**: Remove `SafeArea` wrapper - `StandardHeader` handles it internally.

### Content Behind Header
**Solution**: Use `Column` with `StandardHeader` at top and `Expanded` for content.

### Wrong Icon Color
**Solution**: Use `Brightness.light` for white icons on gradient background.

## Testing Checklist

- [ ] Status bar is transparent
- [ ] Status bar icons are white
- [ ] Gradient extends into status bar
- [ ] No white gap between status bar and header
- [ ] Header gradient matches status bar
- [ ] Title is visible and white
- [ ] Back button works
- [ ] Content scrolls properly
- [ ] Rounded bottom corners visible
- [ ] Consistent across all screens

## Files

- `lib/src/components/standard_header.dart` - Header component
- `lib/src/components/standard_screen.dart` - Screen wrapper
- `lib/src/constants/app_sizes.dart` - Size constants

## Import Statements

```dart
// For screen wrapper (recommended)
import 'package:your_app/src/components/standard_screen.dart';

// For manual implementation
import 'package:flutter/services.dart';
import 'package:your_app/src/components/standard_header.dart';
```

---

**Status**: ✅ Complete - Status bar gradient standard ready
**Usage**: Replace screens with StandardScreen wrapper
**Result**: Seamless gradient from status bar through header
**Consistency**: All screens follow same pattern
