# Login Fix Summary

## Problem
Login was failing because the authentication flow didn't properly handle the Firestore staff collection structure where passwords are stored in plain text.

## Solution
Updated the `AuthService.loginWithEmailOrPhone()` method to:

1. **Query Firestore** - Find staff member by email or phone
2. **Verify Password** - Compare entered password with stored password in Firestore
3. **Authenticate with Firebase** - Use Firebase Auth for session management
4. **Auto-Create Firebase User** - If Firebase Auth user doesn't exist, create one automatically
5. **Update UID** - Store the Firebase UID in the staff document for future logins

## Updated Flow

```
User enters email/phone + password
    ↓
Query Firestore staff collection
    ↓
Find matching email or phone
    ↓
Compare password with stored password
    ↓
If password matches:
    ├─ Try Firebase Auth login
    ├─ If user not found in Firebase:
    │  ├─ Create Firebase Auth user
    │  └─ Update staff document with UID
    └─ Return success with UID
    ↓
If password doesn't match:
    └─ Return error: "Incorrect password"
    ↓
Navigate to Dashboard
```

## Key Changes

### AuthService (`lib/services/auth_service.dart`)

**Before:**
- Only used Firebase Auth
- Failed if user didn't exist in Firebase Auth

**After:**
- Queries Firestore first to find staff member
- Verifies password against Firestore data
- Automatically creates Firebase Auth user if needed
- Updates staff document with Firebase UID
- Provides better error messages

## Test Credentials

From the Firestore screenshot:
```
Email: sibi@gmail.com
Phone: +91 9234567891
Password: BCDEFGHIJKLM
```

## How to Test

1. Launch the app
2. On login screen, enter:
   - Email or Phone: `sibi@gmail.com`
   - Password: `BCDEFGHIJKLM`
3. Click Login
4. Should navigate to dashboard showing staff details

## Files Modified

- `lib/services/auth_service.dart` - Updated login logic
- `lib/screens/login_screen.dart` - Uses updated AuthService
- `lib/screens/security_dashboard_screen.dart` - Displays real user data
- `lib/screens/profile_screen.dart` - Displays real staff details

## Error Handling

The updated flow handles these scenarios:

| Scenario | Error Message |
|----------|---------------|
| Email/phone not in Firestore | "Staff member not found" |
| Password doesn't match | "Incorrect password" |
| Firebase Auth error | "Authentication error: [error details]" |
| Account creation fails | "Failed to create account: [error details]" |
| Other errors | "An error occurred: [error details]" |

## Security Notes

⚠️ **Important**: Passwords are stored in plain text in Firestore. For production:
1. Implement proper password hashing
2. Use Firebase Authentication for password management
3. Never store plain text passwords
4. Implement password reset functionality
5. Add rate limiting for login attempts

## Next Steps

1. Test login with provided credentials
2. Verify dashboard displays correct user data
3. Test profile screen shows staff details
4. Implement password hashing for production
5. Add additional security measures

## Troubleshooting

### Still Getting "Login failed"
- Verify email/phone exists in Firestore staff collection
- Check password matches exactly (case-sensitive)
- Ensure Firestore collection is named `staff`
- Check network connectivity

### Dashboard Shows "Loading..."
- Verify user is authenticated
- Check Firestore security rules
- Ensure staff document has all required fields
- Check browser console for errors

### Profile Data Not Showing
- Verify `uid` field is populated in staff document
- Check Firestore security rules allow read access
- Ensure all required fields exist in staff document
