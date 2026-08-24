# Navigation Guide

## Standard Bottom Navigation Bar

All screens in the admin app now use a standardized bottom navigation bar component located at `lib/widgets/standard_bottom_nav.dart`.

### Usage

```dart
import 'widgets/standard_bottom_nav.dart';

// In your Scaffold
bottomNavigationBar: const StandardBottomNav(selectedIndex: 0),
```

### Navigation Indices

- **0** - Home (Admin Dashboard)
- **1** - Buildings (Manage Buildings Page)
- **2** - Residents (Coming Soon)
- **3** - Billing (Coming Soon)
- **4** - Profile (Coming Soon)

### Navigation Flow

- **From Home to Buildings**: Uses `Navigator.push()` to maintain back navigation
- **From Buildings to Home**: Uses `Navigator.pushAndRemoveUntil()` to clear stack
- **Between other tabs**: Uses `Navigator.pushReplacement()` for smooth transitions
- **Same tab tap**: Does nothing (prevents unnecessary navigation)

### Implemented Screens

1. **AdminDashboardPage** - `selectedIndex: 0`
2. **ManageBuildingsPage** - `selectedIndex: 1`

### Adding New Screens

When creating new screens (Residents, Billing, Profile):

1. Import the standard bottom nav:
   ```dart
   import 'widgets/standard_bottom_nav.dart';
   ```

2. Add it to your Scaffold:
   ```dart
   bottomNavigationBar: const StandardBottomNav(selectedIndex: X),
   ```

3. Update the navigation logic in `standard_bottom_nav.dart`:
   ```dart
   case X: // Your Tab
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const YourPage()),
     );
     break;
   ```

### UI Consistency

All bottom nav bars follow the same design:
- Height: 60px
- Active color: #2563EB (Blue)
- Inactive color: #6A6A6A (Gray)
- Icon size: 24px
- Font size: 11px
- Font weight: w500 (active), w400 (inactive)
