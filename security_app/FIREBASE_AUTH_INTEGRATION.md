# Firebase Authentication Integration

## Overview
The security app now uses Firebase Authentication for login and fetches complete staff details from Firestore. All demo data has been removed and replaced with real data from the database.

## Architecture

### Authentication Flow
1. User enters email/phone and password on login screen
2. System finds staff member by email or phone in Firestore 'staff' collection
3. Authenticates with Firebase Auth using the staff member's email
4. On success: Stores Firebase UID and fetches full staff details
5. Navigates to dashboard with real user data
6. All screens display dynamic data from Firestore

### Key Components

#### AuthService (`lib/services/auth_service.dart`)
Central service for all authentication operations:

**Methods:**
- `loginWithEmailOrPhone(emailOrPhone, password)` - Authenticates user
- `getStaffDetails(staffId)` - Fetches staff details by document ID
- `getStaffDetailsByUid(uid)` - Fetches staff details by Firebase UID
- `getStaffDetailsStream(staffId)` - Real-time staff details stream
- `logout()` - Signs out current user
- `isLoggedIn()` - Checks if user is authenticated
- `currentUser` - Gets current Firebase user
- `authStateChanges` - Stream of auth state changes

#### SecurityUserModel (`lib/models/security_user_model.dart`)
Data model for staff members with fields:
- `uid` - Firebase Authentication UID
- `securityId` - Staff ID (e.g., "SEC-001")
- `name` - Full name
- `email` - Email address
- `phone` - Phone number
- `buildingId` - Building assignment
- `buildingName` - Building name
- `organization` - Organization name
- `role` - Staff role
- `shift` - Shift timing
- `gate` - Gate assignment

## Firestore Structure

### Staff Collection
```
staff/
  {staffDocId}/
    uid: "firebase-uid-here"
    securityId: "SEC-001"
    name: "Rajesh Kumar"
    email: "rajesh.kumar@society.com"
    phone: "+91 98765 43210"
    buildingId: "building-001"
    buildingName: "Main Building"
    organization: "Security Corp"
    role: "Security Guard"
    shift: "Morning Shift (6:00 AM - 2:00 PM)"
    gate: "Main Gate A"
```

## Login Screen
- Accepts email or phone number
- Validates against Firestore staff collection
- Authenticates with Firebase Auth
- Shows error messages for invalid credentials
- Loading state during authentication
- Haptic feedback for user interactions

## Data Display

### Dashboard Screen
- Displays logged-in user's name
- Shows assigned gate
- Fetches real visitor statistics from Firestore
- Updates dynamically with real data

### Profile Screen
- Shows full staff details
- Displays shift timing from Firestore
- Shows gate assignment
- Displays contact information (phone, email)
- All data fetched from Firestore staff collection

## Setup Instructions

### 1. Firebase Project Setup
```bash
# Ensure Firebase is initialized in your project
# Run: flutter pub get
```

### 2. Create Staff in Firebase Auth
For each staff member, create a Firebase Auth account:
```
Email: rajesh.kumar@society.com
Password: (secure password)
```

### 3. Add Staff to Firestore
Create documents in 'staff' collection with the structure above.
**Important:** The `uid` field must match the Firebase Auth UID.

### 4. Update Security Rules
Set Firestore security rules to allow authenticated users to read their own data:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /staff/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.uid;
    }
    match /visitors/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Data Flow

### Login Process
```
User Input (email/phone + password)
    ↓
AuthService.loginWithEmailOrPhone()
    ↓
Query Firestore staff collection
    ↓
Find matching email/phone
    ↓
Firebase Auth signInWithEmailAndPassword()
    ↓
Success → Store UID → Navigate to Dashboard
    ↓
Failure → Show error message
```

### Data Fetching
```
Dashboard/Profile Screen loads
    ↓
Get current Firebase user
    ↓
AuthService.getStaffDetailsByUid()
    ↓
Query Firestore by UID
    ↓
Return SecurityUserModel
    ↓
Display in UI
```

## Security Features

### Implemented
- Firebase Authentication for secure login
- Email/phone validation against Firestore
- Password hashing by Firebase Auth
- Session management via Firebase
- Firestore security rules
- Logout functionality with confirmation

### Recommendations for Production
1. Enable Multi-Factor Authentication (MFA)
2. Implement rate limiting on login attempts
3. Add audit logging for all authentication events
4. Use Firebase App Check for additional security
5. Implement password reset functionality
6. Add email verification
7. Monitor suspicious login attempts

## Files Modified/Created

### New Files
- `lib/services/auth_service.dart` - Authentication service
- `security_app/FIREBASE_AUTH_INTEGRATION.md` - This documentation

### Modified Files
- `lib/main.dart` - Added login screen and routes
- `lib/screens/login_screen.dart` - Updated to use Firebase Auth
- `lib/screens/security_dashboard_screen.dart` - Removed demo data, added real data
- `lib/screens/profile_screen.dart` - Removed demo data, added real data
- `lib/models/security_user_model.dart` - Added uid field

## Testing

### Test Credentials
Create a test staff member in Firebase:
```
Email: test@security.com
Password: Test@123456
```

Add to Firestore staff collection:
```
{
  "uid": "firebase-uid-from-auth",
  "securityId": "SEC-TEST",
  "name": "Test Guard",
  "email": "test@security.com",
  "phone": "+91 99999 99999",
  "buildingId": "test-building",
  "buildingName": "Test Building",
  "organization": "Test Org",
  "role": "Security Guard",
  "shift": "Test Shift",
  "gate": "Test Gate"
}
```

### Test Cases
1. Login with valid email and password
2. Login with valid phone and password
3. Login with invalid credentials
4. Verify dashboard shows correct user data
5. Verify profile shows correct staff details
6. Test logout functionality
7. Verify session persistence

## Troubleshooting

### Login Fails
- Verify Firebase Auth account exists
- Check Firestore staff document has matching email/phone
- Ensure `uid` field in Firestore matches Firebase Auth UID
- Check Firestore security rules allow read access

### Data Not Displaying
- Verify user is authenticated
- Check Firestore staff collection has required fields
- Verify security rules allow data access
- Check network connectivity

### Session Issues
- Clear app cache and reinstall
- Verify Firebase initialization
- Check internet connection
- Review Firebase console for errors

## Future Enhancements
- Biometric authentication
- Social login integration
- Password reset functionality
- Email verification
- Two-factor authentication
- Session timeout handling
- Offline data caching
