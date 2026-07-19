# Migration Guide: AppSegmentedControl

## Overview
This guide helps you migrate from the old `SegmentedControl` to the new premium `AppSegmentedControl` component.

## Quick Comparison

### Old Component
```dart
SegmentedControl(
  tabs: ['Tab 1', 'Tab 2'],
  selectedIndex: _index,
  onTabChanged: (index) => setState(() => _index = index),
)
```

### New Component
```dart
AppSegmentedControl(
  segments: ['Tab 1', 'Tab 2'],
  selectedIndex: _index,
  onChanged: (index) => setState(() => _index = index),
)
```

## Key Differences

| Feature | Old | New |
|---------|-----|-----|
| Parameter name | `tabs` | `segments` |
| Callback name | `onTabChanged` | `onChanged` |
| Background color | #F5F5F5 | #F0F1F3 |
| Border radius | 24px | 30px (pill) |
| Animation duration | 200ms | 220ms |
| Shadow | Basic | Premium (rgba) |
| Active text weight | 600 | 700 (bolder) |

## Step-by-Step Migration

### 1. Update Import
```dart
// Old
import 'src/components/segmented_control.dart';

// New
import 'src/components/app_segmented_control.dart';
```

### 2. Update Widget Name
```dart
// Old
SegmentedControl(...)

// New
AppSegmentedControl(...)
```

### 3. Update Parameters
```dart
// Old
tabs: ['Events', 'Notices', 'Polls'],
onTabChanged: (index) { ... },

// New
segments: ['Events', 'Notices', 'Polls'],
onChanged: (index) { ... },
```

## Screen-by-Screen Migration

### Messages Screen
**File**: `lib/messages_screen.dart`

**Before**:
```dart
SegmentedControl(
  tabs: ['Chats', 'Notifications'],
  selectedIndex: _selectedTab,
  onTabChanged: (index) {
    setState(() => _selectedTab = index);
  },
)
```

**After**:
```dart
AppSegmentedControl(
  segments: ['Chats', 'Notifications'],
  selectedIndex: _selectedTab,
  onChanged: (index) {
    setState(() => _selectedTab = index);
  },
)
```

### Marketplace Screen
**File**: `lib/src/screens/marketplace_screen.dart`

**Before**:
```dart
SegmentedControl(
  tabs: ['All', 'Furniture', 'Electronics', 'Other'],
  selectedIndex: _categoryIndex,
  onTabChanged: (index) {
    setState(() => _categoryIndex = index);
  },
)
```

**After**:
```dart
AppSegmentedControl(
  segments: ['All', 'Furniture', 'Electronics', 'Other'],
  selectedIndex: _categoryIndex,
  onChanged: (index) {
    setState(() => _categoryIndex = index);
  },
)
```

### Events Module Screen
**File**: `lib/src/screens/events_module_screen.dart`

**Before**:
```dart
SegmentedControl(
  tabs: ['Events', 'Notices', 'Polls'],
  selectedIndex: _selectedTab,
  onTabChanged: (index) {
    setState(() => _selectedTab = index);
  },
)
```

**After**:
```dart
AppSegmentedControl(
  segments: ['Events', 'Notices', 'Polls'],
  selectedIndex: _selectedTab,
  onChanged: (index) {
    setState(() => _selectedTab = index);
  },
)
```

### Visitor Management Screen
**File**: `lib/visitor_management_screen.dart`

**Before**:
```dart
SegmentedControl(
  tabs: ['Pending', 'Approved', 'Deliveries'],
  selectedIndex: _selectedTab,
  onTabChanged: (index) {
    setState(() => _selectedTab = index);
  },
)
```

**After**:
```dart
AppSegmentedControl(
  segments: ['Pending', 'Approved', 'Deliveries'],
  selectedIndex: _selectedTab,
  onChanged: (index) {
    setState(() => _selectedTab = index);
  },
)
```

### Family & Vehicles Screen
**File**: `lib/src/screens/family_vehicles_screen.dart`

**Note**: This screen uses a custom implementation. Consider migrating to AppSegmentedControl for consistency.

**Current**:
```dart
// Custom segmented control in _buildSegmentedControl()
```

**Recommended**:
```dart
AppSegmentedControl(
  segments: ['Family Members', 'Vehicles'],
  selectedIndex: _selectedTab,
  onChanged: (index) {
    if (_selectedTab != index) {
      setState(() => _selectedTab = index);
      _tabAnimationController.reset();
      _tabAnimationController.forward();
    }
  },
)
```

## Enhanced Content Transitions

For smoother content transitions, use `AnimatedSwitcher`:

```dart
AppSegmentedControl(
  segments: ['Tab 1', 'Tab 2', 'Tab 3'],
  selectedIndex: _selectedIndex,
  onChanged: (index) {
    setState(() => _selectedIndex = index);
  },
),
const SizedBox(height: 16),
Expanded(
  child: AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
    child: _buildContent(),
  ),
),
```

## Testing Checklist

After migration, verify:

- [ ] Segments display correctly
- [ ] Tapping switches segments smoothly
- [ ] Animation is smooth (220ms)
- [ ] Active segment is clearly visible
- [ ] Content below updates correctly
- [ ] Works on both iOS and Android
- [ ] No console errors or warnings
- [ ] Proper spacing maintained
- [ ] Touch targets are comfortable

## Rollback Plan

If issues occur, you can temporarily revert:

1. Change import back to old component
2. Rename `AppSegmentedControl` to `SegmentedControl`
3. Update parameter names back
4. Report issues for investigation

## Benefits of Migration

✅ **Smoother animations** - 220ms easeOut curve
✅ **Better visual design** - Premium shadow and colors
✅ **Consistent across app** - Same component everywhere
✅ **Better performance** - Optimized animations
✅ **Future-proof** - Active maintenance and updates
✅ **Accessibility** - Improved contrast and touch targets

## Support

For issues or questions:
- Check `APP_SEGMENTED_CONTROL_README.md` for detailed docs
- Review `app_segmented_control_demo.dart` for examples
- Test with `flutter run lib/app_segmented_control_demo.dart`

## Timeline

Recommended migration order:
1. **Week 1**: Messages, Marketplace (high traffic)
2. **Week 2**: Events, Visitor Management
3. **Week 3**: Family & Vehicles, other screens
4. **Week 4**: Testing and refinement

## Notes

- Old `SegmentedControl` can remain for backward compatibility
- Both components can coexist during migration
- No breaking changes to existing functionality
- Visual improvements are immediately noticeable
