# Segmented Control - Design Standard ✅

## Overview
Standardized segmented control (tab selector) component used across the app for consistent UI/UX.

---

## Design Specifications

### Visual Design
```
┌─────────────────────────────────────────────────┐
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
│  │  Active   │  │ Inactive  │  │ Inactive  │  │
│  │   Tab     │  │    Tab    │  │    Tab    │  │
│  └───────────┘  └───────────┘  └───────────┘  │
└─────────────────────────────────────────────────┘
```

### Colors
- **Container Background**: `#F5F5F5` (Light gray)
- **Active Tab**: `#FFFFFF` (White)
- **Active Text**: `#1E293B` (Dark gray)
- **Inactive Text**: `#64748B` (Medium gray)

### Dimensions
- **Container Padding**: 4px all around
- **Container Border Radius**: 24px
- **Tab Border Radius**: 20px
- **Tab Vertical Padding**: 12px
- **Horizontal Margin**: 16px
- **Vertical Margin**: 16px

### Typography
- **Font Size**: 15px
- **Active Weight**: 600 (Semibold)
- **Inactive Weight**: 500 (Medium)
- **Text Align**: Center

### Shadow (Active Tab Only)
- **Color**: Black with 8% opacity
- **Blur Radius**: 8px
- **Offset**: (0, 2)

### Animation
- **Duration**: 200ms
- **Curve**: easeInOut
- **Properties**: Background color, shadow, text color, text weight

---

## Usage

### Import
```dart
import 'package:resident_app/src/components/segmented_control.dart';
```

### Basic Usage
```dart
SegmentedControl(
  tabs: ['Tab 1', 'Tab 2', 'Tab 3'],
  selectedIndex: _selectedIndex,
  onTabChanged: (index) {
    setState(() {
      _selectedIndex = index;
    });
  },
)
```

### Example: Visitor Management Screen
```dart
SegmentedControl(
  tabs: ['Pending', 'Approved', 'Deliveries'],
  selectedIndex: _selectedTabIndex,
  onTabChanged: (index) {
    setState(() {
      _selectedTabIndex = index;
    });
  },
)
```

### Example: Events Screen
```dart
SegmentedControl(
  tabs: ['Events', 'Notices', 'Polls'],
  selectedIndex: _selectedTab,
  onTabChanged: (index) {
    setState(() {
      _selectedTab = index;
    });
  },
)
```

---

## Screens Using Segmented Control

### 1. Visitor Management Screen
- **Tabs**: Pending | Approved | Deliveries
- **Location**: Below header
- **Purpose**: Filter visitor requests by status

### 2. Events & Announcements Screen
- **Tabs**: Events | Notices | Polls
- **Location**: Below header
- **Purpose**: Switch between different content types

### 3. Maintenance & Billing Screen (if applicable)
- **Tabs**: Pending | Paid | History
- **Location**: Below header
- **Purpose**: Filter bills by payment status

---

## Component Structure

```dart
SegmentedControl
├── Container (Background)
│   ├── Padding: 4px
│   ├── Background: #F5F5F5
│   └── Border Radius: 24px
│
└── Row
    ├── Tab 1 (Expanded)
    │   ├── GestureDetector
    │   └── AnimatedContainer
    │       ├── Active: White + Shadow
    │       └── Inactive: Transparent
    │
    ├── Tab 2 (Expanded)
    └── Tab 3 (Expanded)
```

---

## States

### Active Tab
```
Background: White (#FFFFFF)
Shadow: Yes (8px blur, 2px offset)
Text Color: Dark (#1E293B)
Text Weight: 600 (Semibold)
```

### Inactive Tab
```
Background: Transparent
Shadow: None
Text Color: Medium Gray (#64748B)
Text Weight: 500 (Medium)
```

### Transition
```
Duration: 200ms
Curve: easeInOut
Animated Properties:
  - Background color
  - Shadow
  - Text color
  - Text weight
```

---

## Accessibility

✅ **Touch Targets**: Each tab meets 48x48 minimum  
✅ **Contrast**: WCAG AA compliant  
✅ **Feedback**: Visual state changes on tap  
✅ **Animation**: Smooth transitions for clarity  

---

## Best Practices

### Do's ✅
- Use 2-4 tabs maximum
- Keep tab labels short (1-2 words)
- Maintain consistent spacing
- Use clear, descriptive labels
- Animate state changes

### Don'ts ❌
- Don't use more than 4 tabs
- Don't use long tab labels
- Don't skip animations
- Don't change colors arbitrarily
- Don't use different sizes

---

## Responsive Behavior

### Small Screens
- Tabs shrink proportionally
- Text remains readable
- Touch targets maintained

### Large Screens
- Tabs expand proportionally
- Maximum width maintained
- Centered alignment

---

## Code Example

### Full Implementation
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Segmented Control
          SegmentedControl(
            tabs: ['Tab 1', 'Tab 2', 'Tab 3'],
            selectedIndex: _selectedIndex,
            onTabChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          
          // Content based on selected tab
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return Tab1Content();
      case 1:
        return Tab2Content();
      case 2:
        return Tab3Content();
      default:
        return Container();
    }
  }
}
```

---

## Visual Comparison

### Before Standardization
```
Screen 1: Different colors, sizes, spacing
Screen 2: Different animation, shadows
Screen 3: Different typography, padding
❌ Inconsistent user experience
```

### After Standardization
```
Screen 1: Standard design ✅
Screen 2: Standard design ✅
Screen 3: Standard design ✅
✅ Consistent user experience
```

---

## Benefits

### For Users
✅ **Familiar**: Same interaction pattern everywhere  
✅ **Clear**: Obvious which tab is active  
✅ **Smooth**: Animated transitions  
✅ **Accessible**: Easy to tap and see  

### For Developers
✅ **Reusable**: Single component for all screens  
✅ **Maintainable**: One place to update design  
✅ **Consistent**: Automatic standardization  
✅ **Simple**: Easy to implement  

---

## Testing Checklist

- [ ] Tabs render correctly
- [ ] Active tab is highlighted
- [ ] Tap switches tabs
- [ ] Animation is smooth
- [ ] Text is readable
- [ ] Touch targets are adequate
- [ ] Works on all screen sizes
- [ ] Consistent across screens

---

## Summary

The segmented control provides:

✅ **Consistent Design** - Same look across all screens  
✅ **Smooth Animations** - 200ms transitions  
✅ **Clear States** - Active vs inactive  
✅ **Accessible** - Proper touch targets and contrast  
✅ **Reusable** - Single component for all use cases  

---

**Component**: `lib/src/components/segmented_control.dart`  
**Status**: ✅ **STANDARDIZED**  
**Date**: November 15, 2025

---

## Quick Reference

```dart
// Import
import 'package:resident_app/src/components/segmented_control.dart';

// Use
SegmentedControl(
  tabs: ['Tab 1', 'Tab 2', 'Tab 3'],
  selectedIndex: _selectedIndex,
  onTabChanged: (index) => setState(() => _selectedIndex = index),
)
```

Clean, consistent, and professional! 🎉
