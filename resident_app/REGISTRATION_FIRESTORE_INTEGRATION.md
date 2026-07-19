# Registration Firestore Integration - Complete

User registration data is now automatically stored in Firestore database after successful account creation.

## What Was Updated

### 1. UserModel Enhanced
**File:** `lib/src/models/user_model.dart`

Added JSON serialization methods:
- `toJson()` - Serialize to JSON
- `fromJson()` - Deserialize from JSON
- `fromFirestore()` - Create from Firestore DocumentSnapshot

### 2. ResidentDatabaseService Enhanced
**File:** `lib/src/services/resident_database_service.dart`

Added new methods:
- `createUser()` - Create user document in Firestore
- `userExists()` - Check if user already exists

### 3. Create Account Screen Updated
**File:** `lib/src/screens/create_account_screen.dart`

Enhanced registration flow:
1. Creates Firebase Authentication account
2. Updates user display name
3. **NEW:** Creates user document in Firestore with all registration data
4. Handles errors gracefully

---

## Registration Flow

### Step-by-Step Process

1. **User fills registration form:**
   - Full Name
   - Email or Phone Number
   - Password
   - Block
   - Flat Number

2. **Form validation:**
   - All fields required
   - Email/phone format validation
   - Password strength validation (min 6 characters)

3. **Firebase Authentication:**
   - Creates auth account with email/password
   - For phone numbers: converts to email format (`phone@resident.app`)
   - Updates user display name

4. **Firestore Database:**
   - Creates user document in `users` collection
   - Stores: userId, fullName, email, phoneNumber, role, timestamps
   - Document ID = Firebase Auth UID

5. **Navigation:**
   - Success: Navigate to Setup Profile screen
   - Error: Show error message

---

## Data Structure

### Firestore Collection: `users`

```
users/
  └── {userId}/
      ├── id: string (Firebase Auth UID)
      ├── fullName: string
      ├── email: string
      ├── phoneNumber: string? (optional)
      ├── photoURL: string? (optional)
      ├── role: string (default: 'resident')
      ├── createdAt: timestamp
      ├── updatedAt: timestamp
      └── isActive: boolean (default: true)
```

### Example Document

```json
{
  "id": "abc123xyz789",
  "fullName": "John Doe",
  "email": "john.doe@example.com",
  "phoneNumber": "9876543210",
  "photoURL": null,
  "role": "resident",
  "createdAt": "2026-02-15T10:30:00Z",
  "updatedAt": "2026-02-15T10:30:00Z",
  "isActive": true
}
```

---

## Code Examples

### Creating a User (Automatic during registration)

```dart
final dbResult = await _databaseService.createUser(
  userId: result.user!.uid,
  fullName: 'John Doe',
  email: 'john.doe@example.com',
  phoneNumber: '9876543210',
  role: 'resident',
);

if (dbResult.success) {
  print('User created: ${dbResult.data?.fullName}');
} else {
  print('Error: ${dbResult.message}');
}
```

### Checking if User Exists

```dart
final exists = await _databaseService.userExists(userId);
if (exists) {
  print('User already exists in Firestore');
}
```

### Getting User Profile

```dart
final result = await _databaseService.getMyProfile();
if (result.success && result.data != null) {
  final user = result.data!;
  print('Welcome ${user.fullName}!');
  print('Email: ${user.email}');
  print('Role: ${user.role}');
}
```

### Streaming User Profile (Real-time)

```dart
_databaseService.streamMyProfile().listen((user) {
  if (user != null) {
    print('Profile updated: ${user.fullName}');
  }
});
```

---

## Error Handling

The registration process handles various error scenarios:

### Authentication Errors
- Invalid email format
- Weak password
- Email already in use
- Network errors

### Firestore Errors
- Permission denied
- Network unavailable
- Document creation failed

### User Feedback
- Success: Green snackbar with success message
- Error: Red snackbar with specific error message
- Loading: Circular progress indicator on button

---

## Security Rules

Recommended Firestore security rules for the `users` collection:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow user to read their own document
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow user creation during registration
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // Allow user to update their own document (except role)
      allow update: if request.auth != null 
                    && request.auth.uid == userId
                    && request.resource.data.role == resource.data.role;
      
      // Only admins can delete users
      allow delete: if false;
    }
  }
}
```

---

## Testing the Registration Flow

### Test Scenario 1: Email Registration
1. Open app and navigate to Create Account screen
2. Enter:
   - Full Name: "Test User"
   - Email: "test@example.com"
   - Password: "Test123!"
   - Block: "A"
   - Flat: "101"
3. Tap Continue
4. Verify:
   - Success message appears
   - User document created in Firestore
   - Navigation to Setup Profile screen

### Test Scenario 2: Phone Registration
1. Open app and navigate to Create Account screen
2. Enter:
   - Full Name: "Test User"
   - Phone: "9876543210"
   - Password: "Test123!"
   - Block: "B"
   - Flat: "202"
3. Tap Continue
4. Verify:
   - Success message appears
   - User document created with phoneNumber field
   - Email stored as "9876543210@resident.app"

### Test Scenario 3: Error Handling
1. Try registering with existing email
2. Verify error message is displayed
3. Try with weak password (< 6 characters)
4. Verify validation error appears

---

## Firebase Console Verification

After successful registration, verify in Firebase Console:

1. **Authentication Tab:**
   - User appears in Users list
   - UID matches document ID
   - Display name is set

2. **Firestore Tab:**
   - Navigate to `users` collection
   - Find document with matching UID
   - Verify all fields are populated correctly
   - Check timestamps are set

---

## Next Steps

### Recommended Enhancements

1. **Add Flat Assignment:**
   - Create flat document during registration
   - Link user to flat via flatId
   - Store block and flat number

2. **Email Verification:**
   - Send verification email after registration
   - Require verification before full access

3. **Profile Completion:**
   - Add profile photo upload
   - Collect additional details (emergency contact, etc.)
   - Set up preferences

4. **Admin Approval:**
   - Mark new users as "pending approval"
   - Admin reviews and approves registrations
   - Send notification on approval

5. **Analytics:**
   - Track registration completion rate
   - Monitor registration errors
   - Analyze user demographics

---

## Troubleshooting

### Issue: User created in Auth but not in Firestore
**Solution:** Check Firestore security rules and network connectivity

### Issue: "Permission denied" error
**Solution:** Verify security rules allow user creation with matching UID

### Issue: Phone number not stored
**Solution:** Ensure phone validation passes and phoneNumber field is set

### Issue: Duplicate users
**Solution:** Check `userExists()` before creating new user document

---

## API Reference

### ResidentDatabaseService.createUser()

```dart
Future<ResidentDataResult<UserModel>> createUser({
  required String userId,        // Firebase Auth UID
  required String fullName,      // User's full name
  required String email,         // User's email
  String? phoneNumber,           // Optional phone number
  String? photoURL,              // Optional profile photo URL
  String role = 'resident',      // User role (default: 'resident')
})
```

**Returns:** `ResidentDataResult<UserModel>`
- `success`: true if user created successfully
- `message`: Success or error message
- `data`: Created UserModel object
- `errorCode`: Firebase error code (if any)

---

## Summary

Registration data is now fully integrated with Firestore:
- ✅ User documents automatically created during registration
- ✅ All registration data stored securely
- ✅ Proper error handling and user feedback
- ✅ Real-time data access available
- ✅ Ready for profile management features
