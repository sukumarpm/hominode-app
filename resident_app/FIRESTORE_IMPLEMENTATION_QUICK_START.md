# ⚡ Firestore Implementation - Quick Start

## 5-Minute Setup

### Step 1: Deploy Firestore Rules (1 min)

Firebase Console → Firestore → Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function userBuildingId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    match /users/{userId} {
      allow read: if true;
      allow write: if isAuthenticated() && (userId == request.auth.uid);
    }
    
    match /amenities/{amenityId} {
      allow read: if isAuthenticated() && 
        resource.data.buildingId == userBuildingId();
      allow write: if false;
    }
    
    match /bookings/{bookingId} {
      allow read: if isAuthenticated() && 
        (resource.data.userId == request.auth.uid || 
         resource.data.buildingId == userBuildingId());
      allow write: if isAuthenticated() && 
        request.resource.data.userId == request.auth.uid;
    }
    
    match /announcements/{announcementId} {
      allow read: if isAuthenticated() && 
        resource.data.buildingId == userBuildingId();
      allow write: if false;
    }
    
    match /{document=**} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

Click **Publish**

### Step 2: Create Login Service (2 min)

Create `lib/src/services/login_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginService {
  static final LoginService _instance = LoginService._internal();
  factory LoginService() => _instance;
  LoginService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user!.uid;
      
      // Get user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        await _auth.signOut();
        return LoginResult.failure('User not found');
      }
      
      // Check buildingId
      final buildingId = userDoc.get('buildingId') as String?;
      
      if (buildingId == null || buildingId.isEmpty) {
        await _auth.signOut();
        return LoginResult.accessRestricted('No building assigned');
      }
      
      return LoginResult.success(
        uid: uid,
        buildingId: buildingId,
        role: userDoc.get('role') as String? ?? 'resident',
      );
    } catch (e) {
      return LoginResult.failure(e.toString());
    }
  }
}

class LoginResult {
  final bool success;
  final String? uid;
  final String? buildingId;
  final String? role;
  final String? message;
  final bool isAccessRestricted;
  
  LoginResult({
    required this.success,
    this.uid,
    this.buildingId,
    this.role,
    this.message,
    this.isAccessRestricted = false,
  });
  
  factory LoginResult.success({
    required String uid,
    required String buildingId,
    required String role,
  }) => LoginResult(
    success: true,
    uid: uid,
    buildingId: buildingId,
    role: role,
    isAccessRestricted: false,
  );
  
  factory LoginResult.failure(String message) => LoginResult(
    success: false,
    message: message,
    isAccessRestricted: false,
  );
  
  factory LoginResult.accessRestricted(String message) => LoginResult(
    success: false,
    message: message,
    isAccessRestricted: true,
  );
}
```

### Step 3: Update Login Screen (1 min)

```dart
Future<void> _handleLogin() async {
  setState(() => _isLoading = true);
  
  try {
    final result = await LoginService().login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    
    if (!mounted) return;
    
    if (result.isAccessRestricted) {
      Navigator.of(context).pushReplacementNamed('/access-restricted');
    } else if (result.success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Login failed')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Step 4: Create Amenities Service (1 min)

Create `lib/src/services/amenities_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AmenitiesService {
  static final AmenitiesService _instance = AmenitiesService._internal();
  factory AmenitiesService() => _instance;
  AmenitiesService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Stream<List<Map<String, dynamic>>> streamAmenities() async* {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        yield [];
        return;
      }
      
      // Get user's buildingId
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final buildingId = userDoc.get('buildingId') as String?;
      
      if (buildingId == null) {
        yield [];
        return;
      }
      
      // Stream amenities for this building
      yield* _firestore
          .collection('amenities')
          .where('buildingId', isEqualTo: buildingId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print('Error: $e');
      yield [];
    }
  }
}
```

---

## Key Points

✅ **Firestore Rules**: Enforce buildingId filtering at database level  
✅ **Login Service**: Validates buildingId, returns access restricted if null  
✅ **Queries**: Always filter by buildingId or userId  
✅ **UI States**: Handle loading, empty, error, and data states  

---

## Testing

1. **Deploy rules** → Click Publish
2. **Test login** → User without buildingId → Access Restricted
3. **Test amenities** → Should show only building's amenities
4. **Test bookings** → Should show only user's bookings
5. **Test announcements** → Should show only building's announcements

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Permission denied | Check Firestore rules are deployed |
| Empty screens | Check buildingId is set in user document |
| Wrong data showing | Check queries filter by buildingId |
| Slow loading | Check Firestore indexes are created |

---

## Next Steps

1. Deploy Firestore rules
2. Create LoginService
3. Update login screen
4. Create AmenitiesService
5. Update amenities screen with StreamBuilder
6. Test all screens

**All done!** 🚀

