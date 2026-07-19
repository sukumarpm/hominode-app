# Firestore User Data Flow - Complete Implementation ✅

## Overview

All user data is now fetched from Firestore `users` collection and displayed throughout the app according to the flow.

## Architecture

### 1. Authentication Flow (Firestore-based)

```
Login Screen
     ↓
Enter phone/email + password
     ↓
FirestoreAuthService.signIn()
     ↓
Search Firestore users collection
     ↓
Validate password from Firestore
     ↓
Save user ID to SharedPreferences
     ↓
Redirect to Dashboard
```

### 2. User Data Flow

```
Any Screen
     ↓
UserDataService.getCurrentUserData()
     ↓
Get user ID from SharedPreferences
     ↓
Fetch from Firestore users/{userId}
     ↓
Cache data in memory
     ↓
Return user data to screen
     ↓
Display in UI
```

## Services

### FirestoreAuthService
**Location**: `lib/src/services/firestore_auth_service.dart`

**Purpose**: Handles authentication using Firestore

**Key Methods**:
- `signIn(identifier, password)` - Login with phone/email
- `isLoggedIn()` - Check if user is logged in
- `getCurrentUserId()` - Get logged in user ID
- `signOut()` - Logout user

**Flow**:
1. User enters phone/email and password
2. Search Firestore for matching user
3. Validate password from Firestore document
4. Save user ID to SharedPreferences
5. Return success/failure

### UserDataService
**Location**: `lib/src/services/user_data_service.dart`

**Purpose**: Fetches and manages user data from Firestore

**Key Methods**:
- `getCurrentUserData()` - Get all user data
- `getUserName()` - Get user name
- `getUserEmail()` - Get user email
- `getUserPhone()` - Get user phone
- `getUserFlat()` - Get user flat
- `getUserRole()` - Get user role
- `updateUserData(updates)` - Update user data
- `streamUserData()` - Real-time user data stream

**Features**:
- Automatic caching for performance
- Force refresh option
- Real-time updates via streams
- Easy-to-use helper methods

## Usage Examples

### 1. Get User Data in Any Screen

```dart
import 'package:your_app/src/services/user_data_service.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _userDataService = UserDataService();
  String _userName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await _userDataService.getCurrentUserData();
    
    if (userData != null) {
      setState(() {
        _userName = userData['name'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text('Welcome, $_userName');
  }
}
```

### 2. Get Specific User Fields

```dart
// Get user name
final name = await _userDataService.getUserName();

// Get user email
final email = await _userDataService.getUserEmail();

// Get user phone
final phone = await _userDataService.getUserPhone();

// Get user flat
final flat = await _userDataService.getUserFlat();

// Get user role
final role = await _userDataService.getUserRole();
```

### 3. Update User Data

```dart
// Update specific fields
await _userDataService.updateUserData({
  'name': 'New Name',
  'phone': '9876543210',
});

// Or use helper method
await _userDataService.updateProfile(
  name: 'New Name',
  phone: '9876543210',
);
```

### 4. Real-time User Data (Stream)

```dart
StreamBuilder<Map<String, dynamic>?>(
  stream: _userDataService.streamUserData(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return CircularProgressIndicator();
    }
    
    final userData = snapshot.data!;
    return Text('Welcome, ${userData['name']}');
  },
)
```

## Firestore Structure

### users Collection

Each user document should have:

```json
{
  "name": "Preetham",
  "email": "preethampriyadharshan07@gmail.com",
  "phone": "7010678124",
  "password": "121456",
  "flatId": "1402",
  "flatLabel": "1402",
  "residentId": "RES1046",
  "role": "resident",
  "status": "active",
  "ownershipType": "Owner",
  "familyMembers": 4,
  "profileImage": "url_to_image",
  "photoURL": "url_to_image",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Updated Screens

### ✅ Dashboard Screen
- Fetches user name and flat from Firestore
- Displays in header
- Uses UserDataService

### ✅ Profile Screen
- Fetches complete user profile
- Displays all user information
- Uses UserDataService

### ✅ Login Screen
- Validates credentials from Firestore
- Uses FirestoreAuthService

## How to Use in Other Screens

### Step 1: Import the Service

```dart
import 'package:your_app/src/services/user_data_service.dart';
```

### Step 2: Create Instance

```dart
final _userDataService = UserDataService();
```

### Step 3: Fetch Data

```dart
Future<void> _loadData() async {
  final userData = await _userDataService.getCurrentUserData();
  
  // Use the data
  final name = userData?['name'];
  final email = userData?['email'];
  final phone = userData?['phone'];
  final flat = userData?['flatLabel'];
}
```

### Step 4: Display in UI

```dart
Text('Name: ${userData['name']}')
Text('Email: ${userData['email']}')
Text('Phone: ${userData['phone']}')
Text('Flat: ${userData['flatLabel']}')
```

## Testing

### Test Login

```bash
flutter run lib/test_firestore_login.dart -d chrome
```

This will:
- Test phone login
- Test email login
- Show user data after login
- Verify Firestore connection

### Test User Data Fetch

```dart
// In any screen
final userData = await UserDataService().getCurrentUserData();
print('User data: $userData');
```

## Console Output

When everything works correctly:

```
🔐 Starting Firestore authentication...
   Identifier: 7010678124
📱 Detected phone number, searching in Firestore...
   Searching for phone: 7010678124
   Trying: 7010678124
   ✅ Found user with phone: 7010678124
   User ID: Z8XxYhbPAwqXqGbRN8ZQv
   User Name: Preetham
   Verifying password...
✅ Password verified successfully
💾 Login state saved
✅ Login successful!
   Welcome: Preetham

🔵 Dashboard: Loading user profile from Firestore...
✅ Dashboard: User data loaded successfully
   Name: Preetham
   Flat: 1402
✅ Dashboard: UI updated - Name: Preetham, Flat: 1402
```

## Benefits

1. **Single Source of Truth**: All data comes from Firestore
2. **Consistent**: Same service used across all screens
3. **Cached**: Data is cached for performance
4. **Real-time**: Supports real-time updates via streams
5. **Easy to Use**: Simple API for common operations
6. **Type-safe**: Returns Map with all user fields

## Next Steps

To use this in other screens:

1. Import `UserDataService`
2. Call `getCurrentUserData()` or specific getters
3. Display the data in your UI
4. Update data using `updateUserData()` when needed

## Files Modified/Created

### Created:
- ✅ `lib/src/services/firestore_auth_service.dart` - Firestore authentication
- ✅ `lib/src/services/user_data_service.dart` - User data management
- ✅ `lib/test_firestore_login.dart` - Test script

### Modified:
- ✅ `lib/src/screens/simple_login_screen.dart` - Uses FirestoreAuthService
- ✅ `lib/dashboard_screen.dart` - Uses UserDataService
- ✅ `lib/profile_screen.dart` - Uses UserDataService

## Your Credentials

- **Phone**: 7010678124
- **Email**: preethampriyadharshan07@gmail.com
- **Password**: 121456

---

**Status**: ✅ COMPLETE - All user data flows from Firestore
**Date**: February 23, 2026
