# White Status Bar with Scrollable Headers - Implementation Guide

## Overview
Status bar background is white (#FFFFFF) with dark icons, and headers scroll with content on all screens.

## Changes Required

### 1. Main.dart - Set Status Bar Color
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set status bar to white with dark icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  
  runApp(const MyApp());
}
```

### 2. All Screens - Standard Pattern

**Structure:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    body: SafeArea(  // ← Add SafeArea here
      child: SingleChildScrollView(  // or Column with Expanded(SingleChildScrollView)
        child: Column(
          children: [
            _buildHeader(),  // ← Header scrolls with content
            // ... rest of content
          ],
        ),
      ),
    ),
  );
}
```

**Header (remove SafeArea from inside):**
```dart
Widget _buildHeader() {
  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
    ),
    child: Padding(  // ← No SafeArea here
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 20),
      child: Row(
        children: [
          // Back button and title
        ],
      ),
    ),
  );
}
```

## Files to Update

### Dashboard
- **File**: `lib/dashboard_screen.dart`
- **Status**: ✓ Updated
- **Changes**: 
  - Added SafeArea wrapper on body
  - Removed SafeArea from header
  - Header inside scroll view

### Events & Announcements
- **File**: `lib/events_announcements_screen.dart`
- **Status**: ✓ Updated
- **Changes**:
  - Added SafeArea wrapper on body
  - Removed SafeArea from header
  - Header inside scroll view

### Remaining Screens (Apply Same Pattern)

1. **Visitor Management** (`lib/visitor_management_screen.dart`)
2. **Maintenance & Billing** (`lib/maintenance_billing_screen.dart`)
3. **Community Wall** (`lib/community_wall_screen.dart`)
4. **Complaints** (`lib/complaints_screen.dart`)
5. **Messages** (`lib/messages_screen.dart`)
6. **Marketplace** (`lib/src/screens/marketplace_screen.dart`)
7. **Amenities Booking** (`lib/src/screens/amenities_booking_screen.dart`)

## Update Pattern for Each Screen

### Step 1: Wrap body with SafeArea
```dart
// Before
body: Column(
  children: [...]
)

// After
body: SafeArea(
  child: Column(
    children: [...]
  ),
)
```

### Step 2: Move header inside scroll view
```dart
// Before
body: SafeArea(
  child: Column(
    children: [
      _buildHeader(),  // Outside scroll
      Expanded(
        child: SingleChildScrollView(
          child: Column(children: [...]),
        ),
      ),
    ],
  ),
)

// After
body: SafeArea(
  child: SingleChildScrollView(
    child: Column(
      children: [
        _buildHeader(),  // Inside scroll
        // ... rest of content
      ],
    ),
  ),
)
```

### Step 3: Remove SafeArea from header
```dart
// Before
child: SafeArea(
  bottom: false,
  child: Padding(...)
)

// After
child: Padding(...)
```

## Visual Result

### Status Bar
- **Background**: White (#FFFFFF)
- **Icons**: Dark (time, battery, signal)
- **Position**: Fixed at top (system UI)

### Header
- **Background**: Blue gradient
- **Position**: Scrolls with content
- **Behavior**: Disappears when scrolling up

### Content
- **Position**: Below header
- **Behavior**: Scrolls normally

## Benefits

1. **Clean Status Bar**: White background matches app design
2. **More Screen Space**: Header scrolls away when not needed
3. **Standard Behavior**: Matches modern app patterns
4. **Better UX**: More content visible when scrolling

## Testing Checklist

- [ ] Status bar is white on all screens
- [ ] Status bar icons are dark (visible on white)
- [ ] Headers scroll with content
- [ ] No content overlap with status bar
- [ ] Smooth scrolling on all screens
- [ ] Bottom navigation (if present) stays fixed

## Summary

**Status Bar**: White background, dark icons, fixed at top
**Headers**: Blue gradient, scroll with content
**Pattern**: SafeArea on body, header inside scroll view

This creates a clean, modern UI with maximum screen space utilization.
