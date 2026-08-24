# Sign Out Fix - Implementation

## Issue
Sign out was not properly navigating to the login screen according to the flow function.

## Root Cause
The app uses an AuthWrapper as the home screen, but manual navigation was conflicting with the auth state stream.

## Solution Implemented

### Updated Sign Out Flow:
```dart
void _showSignOutDialog() {
  // 1. Show confirmation dialog
  // 2. User confirms
  // 3. Show loading indicator
  // 4. Call AuthService().signOut()
  // 5. Wait for Firebase to process (300ms delay)
  // 6. Navigate to /login route and clear all previous routes
  // 7. Close loading dialog
}
```

### Key Changes:

1. **Added delay after sign out**:
   ```dart
   await AuthService().signOut();
   await Future.delayed(const Duration(milliseconds: 300));
   ```
   This ensures Firebase has time to process the sign out before navigation.

2. **Use named route navigation**:
   ```dart
   Navigator.of(context).pushNamedAndRemoveUntil(
     '/login',
     (route) => false,
   );
   ```
   This clears all routes and navigates to the login screen.

3. **Added WillPopScope to loading dialog**:
   ```dart
   WillPopScope(
     onWillPop: () async => false,
     child: const Center(child: CircularProgressIndicator()),
   )
   ```
   Prevents user from dismissing the loading dialog during sign out.

## Sign Out Flow Diagram

```
User clicks "Sign Out"
        ↓
Confirmation Dialog
        ↓
User confirms
        ↓
Show Loading Dialog (non-dismissible)
        ↓
Call AuthService().signOut()
        ↓
Firebase processes sign out
        ↓
Wait 300ms for state update
        ↓
Close Loading Dialog
        ↓
Navigate to /login (clear all routes)
        ↓
Login Screen displayed
```

## Testing Steps

1. **Login to the app**:
   - Email: admin@lyvo.com / Password: test@123
   - OR Phone: 1234567890 / Password: test@123

2. **Navigate to Settings**:
   - From dashboard, go to Settings screen
   - Scroll to bottom

3. **Sign Out**:
   - Click "Sign Out"
   - Confirm in dialog
   - Loading indicator appears
   - After sign out, login screen appears

4. **Verify**:
   - Login screen is displayed
   - No back button to return to dashboard
   - Can login again successfully

## Expected Behavior

✅ Sign out button works  
✅ Confirmation dialog appears  
✅ Loading indicator shows during sign out  
✅ Firebase auth session cleared  
✅ Navigation to login screen  
✅ All previous routes cleared  
✅ Cannot navigate back to dashboard  
✅ Can login again  

## Files Modified

- `lib/settings_screen.dart` - Updated `_showSignOutDialog()` method

## Technical Details

### AuthService.signOut()
```dart
Future<void> signOut() async {
  await _auth.signOut();
}
```

This calls Firebase Auth's signOut method which:
- Clears the current user session
- Removes auth tokens
- Triggers authStateChanges stream
- Updates auth state to null

### Navigation Strategy
Using `pushNamedAndRemoveUntil` with `(route) => false`:
- Pushes the login route
- Removes all routes from the stack
- Ensures clean navigation state
- Prevents back navigation to authenticated screens

## Error Handling

If sign out fails:
- Loading dialog is closed
- Error message shown in SnackBar
- User remains on settings screen
- Can try again

## Notes

- The 300ms delay ensures Firebase has processed the sign out
- WillPopScope prevents accidental dismissal during sign out
- Named routes provide cleaner navigation
- All routes are cleared to prevent back navigation
