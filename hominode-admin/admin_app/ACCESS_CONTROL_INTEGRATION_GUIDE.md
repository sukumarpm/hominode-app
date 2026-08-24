# Access Control Integration Guide

## Quick Start

### Step 1: Add Access Control to Resident App Login

**File**: `resident_app/lib/auth_wrapper.dart` (or your login screen)

```dart
import 'package:admin_app/services/access_control_service.dart';

class AuthWrapper extends StatelessWidget {
  final accessControlService = AccessControlService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;
        
        // Validate access on login
        return FutureBuilder<AccessValidationResult>(
          future: accessControlService.validateUserAccess(user.uid),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (accessSnapshot.hasData) {
              final result = accessSnapshot.data!;
              
              if (result.success) {
                // User has valid access
                return const HomeScreen();
              } else {
                // User access restricted
                return AccessRestrictedScreen(
                  reason: result.message,
                  onLogout: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                );
              }
            }

            return const ErrorScreen();
          },
        );
      },
    );
  }
}
```

---

### Step 2: Add Real-Time Access Monitoring

**File**: `resident_app/lib/screens/home_screen.dart`

```dart
import 'package:admin_app/services/access_control_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late StreamSubscription<AccessValidationResult> _accessSubscription;
  final accessControlService = AccessControlService();

  @override
  void initState() {
    super.initState();
    _setupAccessMonitoring();
  }

  void _setupAccessMonitoring() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Listen to real-time access changes
    _accessSubscription = accessControlService
        .listenToAccessChanges(userId)
        .listen((result) {
      if (!result.success) {
        // User lost access - redirect to restricted screen
        Navigator.of(context).pushReplacementNamed(
          '/access-restricted',
          arguments: result.message,
        );
      }
    });
  }

  @override
  void dispose() {
    _accessSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Welcome to the app')),
    );
  }
}
```

---

### Step 3: Add Access Restricted Screen Route

**File**: `resident_app/lib/main.dart`

```dart
import 'package:admin_app/access_restricted_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resident App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/access-restricted': (context) {
          final reason = ModalRoute.of(context)?.settings.arguments as String?;
          return AccessRestrictedScreen(
            reason: reason,
            onLogout: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          );
        },
      },
    );
  }
}
```

---

### Step 4: Update Building Deletion in Admin App

**File**: `admin_app/lib/manage_buildings_page.dart`

```dart
// When delete button is clicked
void _deleteBuilding(String buildingId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Building?'),
      content: const Text(
        'This will delete all flats and unassign all residents. '
        'Residents will lose access to the app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await _buildingService.deleteBuilding(buildingId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh buildings list
      setState(() {});
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

### Step 5: Update Resident Deletion in Admin App

**File**: `admin_app/lib/resident_management_screen.dart`

```dart
import 'package:admin_app/services/resident_deletion_service.dart';

// When delete button is clicked
void _deleteResident(String userId, String residentName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Resident?'),
      content: Text(
        'This will delete $residentName and all their data. '
        'They will lose access to the app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final residentDeletionService = ResidentDeletionService();
    final result = await residentDeletionService.deleteResident(userId);
    
    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.residentName} deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh residents list
      setState(() {});
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## Data Flow Diagram

### Login Flow
```
User Login
    ↓
Validate Firebase Auth
    ↓
Fetch User Document
    ↓
Check buildingId exists
    ↓
Check flatId exists
    ↓
Validate Building Document exists
    ↓
Validate Flat Document exists
    ↓
All checks pass?
    ├─ YES → Show Home Screen
    └─ NO → Show Access Restricted Screen
```

### Building Deletion Flow
```
Admin clicks Delete Building
    ↓
Confirm deletion
    ↓
Delete all flats
    ↓
Update all users (set buildingId=null, flatId=null, status=unassigned)
    ↓
Remove building from admin document
    ↓
Delete building document
    ↓
All users immediately lose access
    ↓
Real-time listener detects change
    ↓
Redirect to Access Restricted Screen
```

### Resident Deletion Flow
```
Admin clicks Delete Resident
    ↓
Confirm deletion
    ↓
Remove resident from flat
    ↓
Delete all notifications
    ↓
Delete all messages
    ↓
Delete all complaints
    ↓
Delete all visitor requests
    ↓
Delete all amenity bookings
    ↓
Delete user document
    ↓
User immediately loses access
    ↓
Real-time listener detects change
    ↓
Redirect to Access Restricted Screen
```

---

## Testing Scenarios

### Scenario 1: Valid User Login
1. User has valid buildingId and flatId
2. Building document exists
3. Flat document exists
4. ✅ User can access app

### Scenario 2: User Without Building
1. User has no buildingId
2. ❌ Access restricted - "User not assigned to building"

### Scenario 3: User Without Flat
1. User has buildingId but no flatId
2. ❌ Access restricted - "User not assigned to flat"

### Scenario 4: Building Deleted
1. User has valid buildingId and flatId
2. Building document deleted
3. ❌ Access restricted - "Building has been deleted"

### Scenario 5: Flat Deleted
1. User has valid buildingId and flatId
2. Flat document deleted
3. ❌ Access restricted - "Flat has been deleted"

### Scenario 6: Real-Time Access Loss
1. User logged in and accessing app
2. Admin deletes building
3. Real-time listener detects change
4. ✅ User immediately redirected to access restricted screen

### Scenario 7: Resident Deletion
1. Admin deletes resident
2. All resident data deleted
3. Flat status set to "vacant"
4. ✅ User immediately loses access

---

## Console Logs

### Successful Login
```
🔵 ACCESS VALIDATION FLOW: Starting...
🔐 STEP 1: Validating user authentication...
✅ STEP 1 PASSED: User authenticated - user_123

📋 STEP 2: Fetching user document...
   - buildingId: building_123
   - flatId: flat_456
   - status: assigned
✅ STEP 2 PASSED: User document fetched

📋 STEP 3: Validating building assignment...
✅ STEP 3 PASSED: Building exists and is valid

📋 STEP 4: Validating flat assignment...
✅ STEP 4 PASSED: Flat exists and is valid

✅ ACCESS VALIDATION FLOW: COMPLETE
   - User has valid access
   - Building: Ashoka Towers
   - Flat: A001
```

### Building Deletion
```
🔵 BUILDING DELETION FLOW: Starting...
📋 STEP 1: Validating building...
✅ STEP 1 PASSED: Building validated - Ashoka Towers

📝 STEP 2: Deleting all flats...
   - Found 6 flats to delete
✅ STEP 2 PASSED: All flats deleted

🔔 STEP 3: Updating users assigned to building...
   - Found 3 users to update
✅ STEP 3 PASSED: All users updated - status set to unassigned

📋 STEP 4: Removing building from admin document...
✅ STEP 4 PASSED: Building removed from admin document

📝 STEP 5: Deleting building document...
✅ STEP 5 PASSED: Building document deleted

✅ BUILDING DELETION FLOW: COMPLETE
   - Building: Ashoka Towers
   - Flats deleted: 6
   - Users updated: 3
```

---

## Troubleshooting

### Issue: User can access app without building assignment
**Solution**: Ensure access validation is called on login and real-time listener is active

### Issue: User still has access after building deletion
**Solution**: Ensure real-time listener is active and user is redirected on access loss

### Issue: Orphaned data after resident deletion
**Solution**: Ensure all collections are queried and deleted (notifications, messages, complaints, etc.)

### Issue: Flat not marked as vacant after resident deletion
**Solution**: Ensure flat update is called before user document deletion

---

## Summary

✅ Access control validation implemented
✅ Real-time access monitoring implemented
✅ Building deletion with cascading deletes implemented
✅ Resident deletion with cascading deletes implemented
✅ Access restricted screen UI implemented
✅ Integration guide provided
✅ Testing scenarios documented
✅ Troubleshooting guide provided

**Status**: READY FOR INTEGRATION ✅

---

**Last Updated**: March 25, 2026
**Version**: 1.0.0
