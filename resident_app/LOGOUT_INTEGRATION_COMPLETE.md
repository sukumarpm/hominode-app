# Logout Functionality - Complete Integration

## ✅ What's Been Implemented

The logout functionality is now fully integrated with proper navigation flow back to the login screen.

## 🔄 Logout Flow

### 1. User Taps Logout Button
**Location**: Profile Screen → Logout Button (bottom)

### 2. Confirmation Dialog
- Shows "Are you sure you want to logout?"
- Options: Cancel or Logout
- Clean, rounded dialog design

### 3. Logout Process
```dart
Future<void> _handleLogout(BuildContext context) async {
  // 1. Show confirmation dialog
  final confirmed = await showDialog<bool>(...);
  
  if (confirmed == true) {
    // 2. Clear auth tokens/data
    // await AuthService.logout();
    
    // 3. Navigate to login screen
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false, // Clear all previous routes
    );
  }
}
```

### 4. Navigation to Login
- Clears entire navigation stack
- User cannot go back to app screens
- Shows login screen
- Ready for new login

## 📁 Files Modified

### 1. `lib/profile_screen.dart`
**Changes**:
- Updated `_buildLogoutButton()` to call `_handleLogout()`
- Added `_handleLogout()` method with confirmation dialog
- Proper navigation with `pushNamedAndRemoveUntil()`
- Clears all previous routes

### 2. `lib/main.dart`
**Changes**:
- Added `/login` route
- Imported `LoginScreen`
- Route configuration:
  ```dart
  routes: {
    '/splash': (context) => AnimatedSplashScreen(...),
    '/login': (context) => const LoginScreen(),
    '/home': (context) => const MainNavigation(),
  }
  ```

## 🚀 How It Works

### Step-by-Step Flow

1. **User in Profile Screen**
   - Scrolls to bottom
   - Sees "Logout" button (outlined, blue)

2. **Taps Logout**
   - Confirmation dialog appears
   - "Are you sure you want to logout?"

3. **User Confirms**
   - Dialog closes
   - Auth data cleared (TODO: implement in AuthService)
   - Navigation stack cleared
   - Login screen appears

4. **User at Login Screen**
   - Can login again
   - Cannot go back to app (back button exits app)
   - Fresh start

## 🔧 Integration with AuthService

### Current Implementation
```dart
// In profile_screen.dart
if (confirmed == true) {
  // TODO: Call your auth service to clear tokens
  // await AuthService.logout();
  
  if (context.mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
}
```

### To Connect with Backend

Update `lib/src/services/auth_service.dart`:

```dart
class AuthService {
  static Future<void> logout() async {
    try {
      // 1. Call backend API to invalidate token
      final response = await http.post(
        Uri.parse('YOUR_API_URL/auth/logout'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      // 2. Clear stored tokens
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'user_data');

      // 3. Clear local cache/database
      await _clearLocalData();

      print('Logout successful');
    } catch (e) {
      print('Logout error: $e');
      // Clear local data even if API fails
      await _clearLocalData();
    }
  }

  static Future<void> _clearLocalData() async {
    // Clear secure storage
    await _secureStorage.deleteAll();
    
    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Clear Hive/SQLite if using
    // await Hive.deleteFromDisk();
  }
}
```

### Then Update Profile Screen

```dart
Future<void> _handleLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(...);

  if (confirmed == true) {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Call auth service
    await AuthService.logout();

    if (context.mounted) {
      // Close loading
      Navigator.pop(context);
      
      // Navigate to login
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }
}
```

## 🎨 UI Design

### Logout Button
```dart
OutlinedButton(
  onPressed: () => _handleLogout(context),
  style: OutlinedButton.styleFrom(
    foregroundColor: kPrimaryBlue,
    side: const BorderSide(color: kPrimaryBlue, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: const Text('Logout'),
)
```

### Confirmation Dialog
```dart
AlertDialog(
  title: const Text('Logout'),
  content: const Text('Are you sure you want to logout?'),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: const Text('Cancel'),
    ),
    TextButton(
      onPressed: () => Navigator.pop(context, true),
      child: const Text('Logout'),
    ),
  ],
)
```

## 📱 Testing

### Test Scenarios

1. **Cancel Logout**
   - Tap Logout button
   - Tap Cancel in dialog
   - Should stay on Profile screen
   - No navigation

2. **Confirm Logout**
   - Tap Logout button
   - Tap Logout in dialog
   - Should navigate to Login screen
   - Cannot go back to app

3. **Back Button After Logout**
   - After logout, on Login screen
   - Tap device back button
   - Should exit app (not go back to Profile)

4. **Login Again**
   - After logout, on Login screen
   - Enter credentials
   - Tap Login
   - Should navigate to Dashboard
   - Fresh session

## 🔐 Security Considerations

### What to Clear on Logout

1. **Authentication Tokens**
   - Access token
   - Refresh token
   - Session ID

2. **User Data**
   - User profile
   - Cached data
   - Preferences (optional)

3. **Local Storage**
   - Secure storage
   - Shared preferences
   - Local database

4. **Backend Session**
   - Invalidate token on server
   - Clear server-side session
   - Revoke refresh tokens

### Best Practices

```dart
static Future<void> logout() async {
  try {
    // 1. Invalidate on backend FIRST
    await _invalidateTokenOnServer();
    
    // 2. Then clear local data
    await _clearLocalData();
    
    // 3. Log the event
    await _logLogoutEvent();
  } catch (e) {
    // Even if backend fails, clear local data
    await _clearLocalData();
    rethrow;
  }
}
```

## ⚡ Quick Integration

### Minimal Setup (Already Done)

1. ✅ Logout button in Profile screen
2. ✅ Confirmation dialog
3. ✅ Navigation to login screen
4. ✅ Clear navigation stack
5. ✅ Login route configured

### To Complete

1. **Implement AuthService.logout()**
   - Add token clearing logic
   - Add API call to invalidate token
   - Add local data clearing

2. **Test Flow**
   - Test logout → login → dashboard
   - Test back button behavior
   - Test session persistence

3. **Add Loading State** (Optional)
   - Show loading during logout
   - Better UX for slow networks

## 🎯 Current Status

### ✅ Working
- Logout button visible and styled
- Confirmation dialog shows
- Navigation to login screen works
- Navigation stack cleared properly
- Cannot go back after logout

### 🔄 TODO
- Connect to AuthService.logout()
- Implement token clearing
- Add backend API call
- Add loading indicator (optional)
- Test with real authentication

## 📝 Usage

### From Profile Screen
```dart
// User taps logout button
// Confirmation dialog appears
// User confirms
// Navigates to login screen
```

### Programmatic Logout
```dart
// From anywhere in the app
await AuthService.logout();

if (context.mounted) {
  Navigator.of(context).pushNamedAndRemoveUntil(
    '/login',
    (route) => false,
  );
}
```

## ✅ Complete

The logout functionality is now:
- ✅ Integrated in Profile screen
- ✅ Shows confirmation dialog
- ✅ Navigates to login screen
- ✅ Clears navigation stack
- ✅ Follows app flow
- ✅ Ready for backend integration

Just connect it to your AuthService and you're done!
