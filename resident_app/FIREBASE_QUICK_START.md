# Firebase Quick Start Guide

## ✅ Firebase is Already Integrated!

Your app has Firebase fully configured and ready to use.

## Quick Reference

### 1. Authentication

```dart
import 'package:resident_app/src/services/firebase_auth_service.dart';

final auth = FirebaseAuthService();

// Phone OTP Login
await auth.signInWithPhone(
  phoneNumber: '+919876543210',
  onCodeSent: (verificationId) {
    // Navigate to OTP screen
  },
  onError: (error) {
    // Show error message
  },
);

// Verify OTP
final result = await auth.verifyOtp(
  smsCode: '123456',
  verificationId: verificationId,
);

// Email/Password Login
final result = await auth.signInWithEmail(
  email: 'user@example.com',
  password: 'SecurePass123',
);

// Check result
if (result.success) {
  // Success - navigate to home
  print('User: ${result.user?.email}');
} else {
  // Error - show message
  print('Error: ${result.message}');
}

// Get current user
final user = auth.getCurrentUser();

// Sign out
await auth.signOut();
```

### 2. Database (Firestore)

```dart
import 'package:resident_app/src/services/database_service.dart';
import 'package:resident_app/src/models/user_model.dart';

final db = DatabaseService();

// Create User
final user = UserModel(
  id: 'user123',
  fullName: 'John Doe',
  email: 'john@example.com',
  phoneNumber: '+919876543210',
  role: 'resident',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createUser(user);

// Get User
final result = await db.getUser('user123');
if (result.success) {
  print('User: ${result.data?.fullName}');
}

// Update User
await db.updateUser('user123', {
  'fullName': 'John Smith',
  'photoURL': 'https://example.com/photo.jpg',
});

// Stream Users (Real-time)
db.streamUsers().listen((users) {
  print('Total users: ${users.length}');
});

// Get Bills
final bills = await db.getBillsByFlat('flat123');

// Stream Bills (Real-time)
db.streamBillsByFlat('flat123').listen((bills) {
  print('Pending bills: ${bills.where((b) => b.status == 'pending').length}');
});

// Create Visitor
final visitor = VisitorModel(
  id: '',
  flatId: 'flat123',
  hostUserId: 'user123',
  visitorName: 'Jane Smith',
  purpose: 'Personal visit',
  expectedArrival: DateTime.now().add(Duration(hours: 2)),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

await db.createVisitor(visitor);
```

### 3. Using in Widgets

```dart
// StreamBuilder for real-time updates
StreamBuilder<List<BillModel>>(
  stream: DatabaseService().streamBillsByFlat('flat123'),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    if (!snapshot.hasData) {
      return CircularProgressIndicator();
    }
    
    final bills = snapshot.data!;
    return ListView.builder(
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return ListTile(
          title: Text(bill.type),
          subtitle: Text('₹${bill.amount}'),
          trailing: Text(bill.status),
        );
      },
    );
  },
)

// FutureBuilder for one-time fetch
FutureBuilder<DatabaseResult<UserModel>>(
  future: DatabaseService().getUser('user123'),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.success) {
      final user = snapshot.data!.data!;
      return Text('Welcome, ${user.fullName}');
    }
    return CircularProgressIndicator();
  },
)
```

## Available Collections

1. **users** - User profiles
2. **buildings** - Building information
3. **flats** - Apartment details
4. **residents** - Resident-flat relationships
5. **bills** - Billing information
6. **payments** - Payment records
7. **visitors** - Visitor management
8. **notices** - Announcements
9. **complaints** - Complaint tracking

## Error Handling Pattern

```dart
final result = await db.createUser(user);

if (result.success) {
  // Success
  print('Created: ${result.data?.fullName}');
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message ?? 'Success')),
  );
} else {
  // Error
  print('Error: ${result.message}');
  print('Code: ${result.errorCode}');
  // Show error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message ?? 'An error occurred'),
      backgroundColor: Colors.red,
    ),
  );
}
```

## Validation Helpers

```dart
final auth = FirebaseAuthService();

// Validate phone number
if (auth.validatePhoneNumber('9876543210')) {
  // Valid
}

// Format phone number
final formatted = auth.formatPhoneNumber('9876543210');
// Returns: +919876543210

// Validate email
if (auth.validateEmail('user@example.com')) {
  // Valid
}

// Validate password
final error = auth.validatePassword('weak');
if (error != null) {
  print('Password error: $error');
}
```

## Configuration Files

### Already Configured ✅
- `pubspec.yaml` - Firebase dependencies
- `android/build.gradle.kts` - Google Services plugin
- `android/app/build.gradle.kts` - Firebase dependencies
- `android/app/google-services.json` - Firebase config
- `android/app/src/main/res/values/strings.xml` - Firebase values
- `lib/main.dart` - Firebase initialization

## Next Steps

1. **Test Authentication**
   - Try phone OTP login
   - Try email/password login
   - Test forgot password

2. **Test Database**
   - Create a user
   - Fetch data
   - Try real-time streams

3. **Configure Security Rules**
   - Go to Firebase Console
   - Set up Firestore rules
   - Test permissions

4. **Add Analytics Events**
   ```dart
   import 'package:firebase_analytics/firebase_analytics.dart';
   
   final analytics = FirebaseAnalytics.instance;
   await analytics.logEvent(
     name: 'user_login',
     parameters: {'method': 'phone'},
   );
   ```

## Documentation

- **Full Auth Guide:** `FIREBASE_AUTH_INTEGRATION.md`
- **Full Database Guide:** `FIRESTORE_INTEGRATION.md`
- **Auth Flow Details:** `DUAL_AUTH_SYSTEM.md`
- **Integration Status:** `FIREBASE_INTEGRATION_STATUS.md`

## Support

If you encounter issues:
1. Check Firebase Console for errors
2. Review security rules
3. Verify package name matches
4. Check internet connection
5. Review documentation files

## Firebase Console

Access your project:
- URL: https://console.firebase.google.com
- Project ID: lyvo-app-9f0ca
- Package: com.marantrix.lyvo

---

**Firebase is ready to use! Start building your features.** 🚀
