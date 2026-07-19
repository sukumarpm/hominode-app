# Header Standardization - Complete ✅

## What Was Created

### 1. Standard Header Component
**File**: `lib/src/components/standard_header.dart`

A single, reusable header component with 4 variants:
- `StandardHeader` - Basic (title + back button)
- `StandardHeaderWithSearch` - With search icon
- `StandardHeaderWithMenu` - With menu icon  
- `StandardHeaderWithNotification` - With notification bell

### 2. Specifications

**Visual Standards:**
- Gradient: #2563EB → #1E40AF
- Title: 18px, Semibold, White
- Back Icon: iOS style, 20px
- Border Radius: 18px (bottom)
- Padding: 10px top, 14px bottom
- Safe Area: Automatic

## How to Use

### Replace Existing Headers

**Before (Inconsistent):**
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
    ),
    borderRadius: BorderRadius.only(
      bottomLeft: Radius.circular(20),
      bottomRight: Radius.circular(20),
    ),
  ),
  child: SafeArea(
    bottom: false,
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        Text('Title', style: TextStyle(fontSize: 22, color: Colors.white)),
      ],
    ),
  ),
)
```

**After (Standard):**
```dart
import 'package:your_app/src/components/standard_header.dart';

StandardHeader(
  title: 'Title',
)
```

### Screen Layout Pattern

```dart
Scaffold(
  body: Column(
    children: [
      // Header (fixed)
      StandardHeader(
        title: 'Screen Title',
      ),
      
      // Content (scrollable)
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: // Your content
        ),
      ),
    ],
  ),
)
```

## Examples for Common Screens

### Auth Screens
```dart
// Create Account
StandardHeader(title: 'Create Account')

// Setup Profile  
StandardHeader(title: 'Setup Your Profile')

// Login (no back button)
StandardHeader(title: 'Login', showBackButton: false)
```

### Main Screens
```dart
// Emergency SOS
StandardHeader(title: 'Emergency SOS')

// Settings
StandardHeader(title: 'Settings')

// Notifications
StandardHeaderWithNotification(
  title: 'Notifications',
  hasUnread: true,
)
```

### Feature Screens
```dart
// Events with Search
StandardHeaderWithSearch(
  title: 'Events',
  onSearchPressed: () => _showSearch(),
)

// Community with Menu
StandardHeaderWithMenu(
  title: 'Community',
  onMenuPressed: () => _showMenu(),
)
```

## Benefits

### Consistency
- ✅ Same gradient everywhere
- ✅ Same title size (18px)
- ✅ Same padding (10px/14px)
- ✅ Same border radius (18px)
- ✅ Same back button style

### Maintenance
- ✅ Update once, applies everywhere
- ✅ No code duplication
- ✅ Single source of truth
- ✅ Easy to modify globally

### Development
- ✅ Quick to implement
- ✅ Less code to write
- ✅ No need to remember specs
- ✅ Copy-paste ready

## Migration Checklist

### Step 1: Import Component
```dart
import 'package:your_app/src/components/standard_header.dart';
```

### Step 2: Replace Header
Find your existing header code and replace with:
```dart
StandardHeader(
  title: 'Your Title',
)
```

### Step 3: Test
- [ ] Header appears correctly
- [ ] Back button works
- [ ] Title is visible
- [ ] Gradient is correct
- [ ] Safe area is respected

## Screens to Update

### High Priority (User-Facing)
1. ✅ Create Account Screen
2. ✅ Setup Profile Screen  
3. ✅ Emergency SOS Screen
4. Settings Screen
5. Profile Screen
6. Notifications Screen

### Medium Priority (Features)
7. Events Screen
8. Community Wall Screen
9. Marketplace Screen
10. Messages Screen
11. Complaints Screen
12. Visitor Management Screen

### Low Priority (Secondary)
13. Documents Screen
14. Amenities Booking Screen
15. Family & Vehicles Screen
16. Domestic Staff Screen
17. My Bookings Screen
18. Edit Profile Screen
19. Change Password Screen
20. Language Settings Screen

## Quick Commands

### Find All Headers
```bash
# Search for existing header implementations
grep -r "Container.*gradient" lib/src/screens/
grep -r "AppBar" lib/src/screens/
```

### Replace Pattern
1. Find: Custom header Container
2. Replace with: `StandardHeader(title: 'Title')`
3. Remove: Old header code
4. Test: Screen functionality

## Visual Comparison

### Before
- Different gradients
- Different title sizes (19px, 20px, 22px)
- Different padding (12px, 16px, 20px)
- Different border radius (16px, 20px, 24px)
- Different back button styles

### After
- ✅ Same gradient (#2563EB → #1E40AF)
- ✅ Same title size (18px)
- ✅ Same padding (10px/14px)
- ✅ Same border radius (18px)
- ✅ Same back button (iOS style)

## Troubleshooting

### Header Not Showing
```dart
// Make sure it's in a Column
Column(
  children: [
    StandardHeader(title: 'Title'), // ✅
    Expanded(child: // Content),
  ],
)
```

### Back Button Not Working
```dart
// Default behavior pops navigation
StandardHeader(title: 'Title') // ✅ Auto pops

// Custom behavior
StandardHeader(
  title: 'Title',
  onBackPressed: () {
    // Your custom logic
    Navigator.pop(context);
  },
)
```

### Title Too Long
```dart
// Automatically truncates with ellipsis
StandardHeader(
  title: 'Very Long Title That Will Be Truncated',
) // ✅ Shows "Very Long Title Tha..."
```

## Next Steps

1. **Import** the standard header component
2. **Replace** existing headers one screen at a time
3. **Test** each screen after replacement
4. **Verify** consistency across all screens
5. **Document** any custom requirements

---

**Status**: ✅ Complete - Standard header component ready
**File**: `lib/src/components/standard_header.dart`
**Documentation**: `STANDARD_HEADER_GUIDE.md`
**Next**: Replace headers in existing screens
**Impact**: Consistent UI across entire app
