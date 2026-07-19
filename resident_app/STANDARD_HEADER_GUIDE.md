# Standard Header Implementation Guide ✅

## Overview
A single, reusable header component to ensure consistency across ALL screens in the app.

## Standard Header Specifications

### Visual Design
- **Gradient**: #2563EB → #1E40AF (blue gradient)
- **Height**: Auto (based on content + safe area)
- **Border Radius**: 18px (bottom corners)
- **Title Size**: 18px (AppTextSizes.screenTitle)
- **Title Weight**: Semibold (FontWeight.w600)
- **Title Color**: White
- **Back Icon**: iOS style (arrow_back_ios), 20px, white
- **Padding Top**: 10px (AppSizes.headerPaddingVertical)
- **Padding Bottom**: 14px (AppSizes.headerPaddingBottom)
- **Safe Area**: Respects status bar

### Component Variants

1. **StandardHeader** - Basic header with title and back button
2. **StandardHeaderWithSearch** - Header with search icon
3. **StandardHeaderWithMenu** - Header with menu/options icon
4. **StandardHeaderWithNotification** - Header with notification bell

## Usage Examples

### 1. Basic Header (Most Common)
```dart
import 'package:your_app/src/components/standard_header.dart';

Scaffold(
  body: Column(
    children: [
      StandardHeader(
        title: 'Screen Title',
        onBackPressed: () => Navigator.pop(context),
      ),
      Expanded(
        child: // Your content
      ),
    ],
  ),
)
```

### 2. Header Without Back Button
```dart
StandardHeader(
  title: 'Home',
  showBackButton: false,
)
```

### 3. Header with Search
```dart
StandardHeaderWithSearch(
  title: 'Search Items',
  onSearchPressed: () {
    // Open search
  },
)
```

### 4. Header with Menu
```dart
StandardHeaderWithMenu(
  title: 'Settings',
  onMenuPressed: () {
    // Show menu
  },
)
```

### 5. Header with Notification
```dart
StandardHeaderWithNotification(
  title: 'Dashboard',
  showBackButton: false,
  hasUnread: true, // Shows red dot
  onNotificationPressed: () {
    Navigator.pushNamed(context, '/notifications');
  },
)
```

### 6. Header with Custom Actions
```dart
StandardHeader(
  title: 'Custom',
  actions: [
    IconButton(
      icon: Icon(Icons.share, color: Colors.white),
      onPressed: () {
        // Share action
      },
    ),
    IconButton(
      icon: Icon(Icons.favorite, color: Colors.white),
      onPressed: () {
        // Favorite action
      },
    ),
  ],
)
```

## Screen-by-Screen Implementation

### Auth Screens
```dart
// Create Account
StandardHeader(
  title: 'Create Account',
)

// Setup Profile
StandardHeader(
  title: 'Setup Your Profile',
)
```

### Main App Screens
```dart
// Emergency SOS
StandardHeader(
  title: 'Emergency SOS',
)

// Settings
StandardHeader(
  title: 'Settings',
)

// Profile
StandardHeader(
  title: 'Profile',
  showBackButton: false,
)

// Notifications
StandardHeader(
  title: 'Notifications',
)
```

### Feature Screens
```dart
// Events
StandardHeaderWithSearch(
  title: 'Events',
  showBackButton: false,
  onSearchPressed: () => _showSearch(),
)

// Community Wall
StandardHeaderWithMenu(
  title: 'Community',
  showBackButton: false,
  onMenuPressed: () => _showMenu(),
)

// Marketplace
StandardHeaderWithSearch(
  title: 'Marketplace',
  onSearchPressed: () => _showSearch(),
)
```

## Migration Guide

### Before (Inconsistent Headers)
```dart
// Different implementations across screens
Container(
  padding: EdgeInsets.all(16), // ❌ Inconsistent
  decoration: BoxDecoration(
    gradient: LinearGradient(...), // ❌ Repeated code
  ),
  child: Row(
    children: [
      IconButton(...), // ❌ Different styling
      Text('Title', style: TextStyle(fontSize: 20)), // ❌ Wrong size
    ],
  ),
)
```

### After (Standard Header)
```dart
// Consistent across all screens
StandardHeader(
  title: 'Title', // ✅ Consistent
)
```

## Benefits

### Consistency
- ✅ Same gradient across all screens
- ✅ Same title size and weight
- ✅ Same padding and spacing
- ✅ Same back button style
- ✅ Same border radius

### Maintainability
- ✅ Single source of truth
- ✅ Easy to update globally
- ✅ Less code duplication
- ✅ Centralized styling

### Development Speed
- ✅ Quick to implement
- ✅ No need to remember specs
- ✅ Copy-paste ready
- ✅ Variants for common patterns

## Customization

### Change Title Size
```dart
StandardHeader(
  title: 'Large Title',
  titleSize: 20, // Override default 18px
)
```

### Change Background Color
```dart
StandardHeader(
  title: 'Custom Color',
  backgroundColor: Colors.purple, // Override gradient
)
```

### Custom Back Action
```dart
StandardHeader(
  title: 'Custom Back',
  onBackPressed: () {
    // Custom logic before going back
    _saveData();
    Navigator.pop(context);
  },
)
```

## Screen Layout Pattern

### Standard Pattern
```dart
Scaffold(
  body: Column(
    children: [
      // 1. Header (fixed at top)
      StandardHeader(
        title: 'Screen Title',
      ),
      
      // 2. Content (scrollable)
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              // Your content here
            ],
          ),
        ),
      ),
    ],
  ),
)
```

### With Safe Area
```dart
Scaffold(
  body: SafeArea( // Optional: if header doesn't handle safe area
    child: Column(
      children: [
        StandardHeader(title: 'Title'),
        Expanded(child: // Content),
      ],
    ),
  ),
)
```

## Accessibility

### Built-in Features
- ✅ Semantic labels for back button
- ✅ Semantic labels for action buttons
- ✅ Proper touch targets (44x44 minimum)
- ✅ High contrast (white on blue)
- ✅ Screen reader support

### Usage
```dart
// Automatically accessible
StandardHeader(
  title: 'Accessible Screen', // Read by screen readers
)
```

## Testing Checklist

- [ ] Header appears on all screens
- [ ] Gradient is consistent (#2563EB → #1E40AF)
- [ ] Title size is 18px
- [ ] Title is white and semibold
- [ ] Back button works correctly
- [ ] Back button icon is iOS style
- [ ] Bottom corners are rounded (18px)
- [ ] Safe area is respected (no status bar overlap)
- [ ] Padding is consistent (10px top, 14px bottom)
- [ ] Action buttons work correctly
- [ ] Touch targets are accessible
- [ ] Screen readers announce correctly

## Common Screens to Update

### Priority 1 (Auth Flow)
- [ ] Login Screen
- [ ] Create Account Screen
- [ ] Setup Profile Screen

### Priority 2 (Main Features)
- [ ] Emergency SOS Screen
- [ ] Settings Screen
- [ ] Profile Screen
- [ ] Notifications Screen

### Priority 3 (Feature Screens)
- [ ] Events Screen
- [ ] Community Wall Screen
- [ ] Marketplace Screen
- [ ] Messages Screen
- [ ] Complaints Screen
- [ ] Visitor Management Screen
- [ ] Documents Screen
- [ ] Amenities Booking Screen
- [ ] Family & Vehicles Screen
- [ ] Domestic Staff Screen
- [ ] My Bookings Screen

## File Location
`lib/src/components/standard_header.dart`

## Import Statement
```dart
import 'package:your_app/src/components/standard_header.dart';
```

## Quick Reference

| Variant | Use Case | Example |
|---------|----------|---------|
| StandardHeader | Basic screen | Settings, Profile |
| StandardHeaderWithSearch | Searchable content | Events, Marketplace |
| StandardHeaderWithMenu | Options menu | Community, Messages |
| StandardHeaderWithNotification | Notification bell | Dashboard, Home |

---

**Status**: ✅ Complete - Standard header component ready
**Next Step**: Replace existing headers with StandardHeader
**Impact**: Consistent UI across all screens
**Maintenance**: Single file to update for global changes
