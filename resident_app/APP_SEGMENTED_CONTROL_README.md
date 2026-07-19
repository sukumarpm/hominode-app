# App Segmented Control - Premium Component

## Overview
A high-end, reusable segmented control component with smooth animations matching Airbnb/Apple level design standards.

## Design Specifications

### Visual Design
- **Track Background**: #F0F1F3 (light grey)
- **Height**: 48px
- **Corner Radius**: 30px (pill shape)
- **Active Pill**: White background
- **Shadow**: rgba(16, 24, 40, 0.12), blur 12px, offset y=3px
- **Animation**: 220ms with easeOut curve

### Typography
- **Active Text**: 
  - Color: #0F172A (dark slate)
  - Weight: 700 (Bold)
  - Size: 15px
- **Inactive Text**:
  - Color: #9AA0A6 (medium grey)
  - Weight: 500 (Medium)
  - Size: 15px

### Interaction
- Smooth sliding animation between segments
- Tapping animates the white pill to the selected segment
- Content below fades and swaps after animation
- Supports 2-5 segments dynamically

## Basic Usage

```dart
import 'package:flutter/material.dart';
import 'src/components/app_segmented_control.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSegmentedControl(
          segments: ['All', 'Active', 'Completed'],
          selectedIndex: _selectedIndex,
          onChanged: (index) {
            setState(() => _selectedIndex = index);
          },
        ),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return AllItemsView();
      case 1:
        return ActiveItemsView();
      case 2:
        return CompletedItemsView();
      default:
        return Container();
    }
  }
}
```


## Usage Examples

### 1. Messages Screen (Chats / Notifications)

```dart
import 'package:flutter/material.dart';
import 'src/components/app_segmented_control.dart';

class MessagesScreen extends StatefulWidget {
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Text(
                  'Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Segmented Control
          AppSegmentedControl(
            segments: ['Chats', 'Notifications'],
            selectedIndex: _selectedTab,
            onChanged: (index) {
              setState(() => _selectedTab = index);
            },
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedTab == 0
                  ? ChatsListView(key: ValueKey('chats'))
                  : NotificationsListView(key: ValueKey('notifications')),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 2. Marketplace Screen (All / Furniture / Electronics / Other)

```dart
class MarketplaceScreen extends StatefulWidget {
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  int _categoryIndex = 0;
  final List<String> _categories = ['All', 'Furniture', 'Electronics', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),
          // Segmented Control
          AppSegmentedControl(
            segments: _categories,
            selectedIndex: _categoryIndex,
            onChanged: (index) {
              setState(() => _categoryIndex = index);
            },
          ),
          const SizedBox(height: 16),
          // Products Grid
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildProductGrid(_categories[_categoryIndex]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(String category) {
    return GridView.builder(
      key: ValueKey(category),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 10,
      itemBuilder: (context, index) => ProductCard(category: category),
    );
  }
}
```

### 3. Events Screen (Events / Notices / Polls)

```dart
class EventsModuleScreen extends StatefulWidget {
  @override
  State<EventsModuleScreen> createState() => _EventsModuleScreenState();
}

class _EventsModuleScreenState extends State<EventsModuleScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Events', 'Notices', 'Polls'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios, 
                            color: Colors.white, size: 20),
                        ),
                        const Text(
                          'Events & Announcements',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Segmented Control
          AppSegmentedControl(
            segments: _tabs,
            selectedIndex: _selectedTab,
            onChanged: (index) {
              setState(() => _selectedTab = index);
            },
          ),
          const SizedBox(height: 16),
          // Tab Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return EventsTab(key: ValueKey('events'));
      case 1:
        return NoticesTab(key: ValueKey('notices'));
      case 2:
        return PollsTab(key: ValueKey('polls'));
      default:
        return Container();
    }
  }
}
```


### 4. Visitor Management (Pending / Approved / Deliveries)

```dart
class VisitorManagementScreen extends StatefulWidget {
  @override
  State<VisitorManagementScreen> createState() => _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          AppSegmentedControl(
            segments: ['Pending', 'Approved', 'Deliveries'],
            selectedIndex: _selectedTab,
            onChanged: (index) {
              setState(() => _selectedTab = index);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildVisitorList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorList() {
    return ListView.builder(
      key: ValueKey(_selectedTab),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 10,
      itemBuilder: (context, index) => VisitorCard(status: _selectedTab),
    );
  }
}
```

### 5. Family & Vehicles (Family Members / Vehicles)

```dart
class FamilyVehiclesScreen extends StatefulWidget {
  @override
  State<FamilyVehiclesScreen> createState() => _FamilyVehiclesScreenState();
}

class _FamilyVehiclesScreenState extends State<FamilyVehiclesScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          AppSegmentedControl(
            segments: ['Family Members', 'Vehicles'],
            selectedIndex: _selectedTab,
            onChanged: (index) {
              setState(() => _selectedTab = index);
            },
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedTab == 0
                  ? FamilyMembersList(key: ValueKey('family'))
                  : VehiclesList(key: ValueKey('vehicles')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _selectedTab == 0 
                ? 'Manage your family members' 
                : 'Manage your vehicles',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddModal,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
```

## Advanced Features

### Custom Height and Margins

```dart
AppSegmentedControl(
  segments: ['Tab 1', 'Tab 2'],
  selectedIndex: _selectedIndex,
  onChanged: (index) => setState(() => _selectedIndex = index),
  height: 52, // Custom height
  horizontalMargin: 16, // Custom margin
)
```

### With Fade Animation for Content

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 250),
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeIn,
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  },
  child: _buildContent(),
)
```

### With Slide Animation for Content

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));
    return SlideTransition(
      position: offsetAnimation,
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  },
  child: _buildContent(),
)
```

## Component Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `segments` | `List<String>` | Yes | - | List of segment labels (2-5 items) |
| `selectedIndex` | `int` | Yes | - | Currently selected segment index |
| `onChanged` | `ValueChanged<int>` | Yes | - | Callback when segment is tapped |
| `height` | `double?` | No | 48.0 | Custom height for the control |
| `horizontalMargin` | `double?` | No | 20.0 | Horizontal margin from screen edges |

## Design Principles

1. **Smooth Animations**: 220ms easeOut curve for premium feel
2. **Clear Visual Hierarchy**: Bold active text, muted inactive text
3. **Touch-Friendly**: 48px height for comfortable tapping
4. **Responsive**: Adapts to different segment counts
5. **Accessible**: High contrast ratios and clear states
6. **Consistent**: Same design across all screens

## Platform Support

- ✅ iOS
- ✅ Android
- ✅ Web (responsive)

## Performance Notes

- Uses `AnimatedBuilder` for efficient animations
- Minimal rebuilds with proper state management
- Hardware-accelerated animations
- No jank or frame drops

## Migration from Old SegmentedControl

Replace:
```dart
SegmentedControl(
  tabs: ['Tab 1', 'Tab 2'],
  selectedIndex: _index,
  onTabChanged: (index) => setState(() => _index = index),
)
```

With:
```dart
AppSegmentedControl(
  segments: ['Tab 1', 'Tab 2'],
  selectedIndex: _index,
  onChanged: (index) => setState(() => _index = index),
)
```

## Best Practices

1. **Use 2-4 segments** for optimal UX (5 max)
2. **Keep labels short** (1-2 words)
3. **Pair with AnimatedSwitcher** for content transitions
4. **Use ValueKey** for proper widget identification
5. **Maintain consistent spacing** (20px top, 16px bottom)
6. **Test on different screen sizes**

## Troubleshooting

**Issue**: Animation not smooth
- Ensure parent widget doesn't rebuild unnecessarily
- Use `const` constructors where possible

**Issue**: Text overflow
- Keep segment labels concise
- Component handles overflow with ellipsis

**Issue**: Wrong segment selected
- Verify `selectedIndex` is updated in `setState`
- Check callback is properly connected
