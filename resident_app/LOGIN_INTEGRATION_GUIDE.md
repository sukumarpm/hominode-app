# Login Screen Integration Guide

## Overview
This guide shows how to integrate the new login screen into your existing Resident App.

## Integration Options

### Option 1: Replace Splash Screen Flow

Update `main.dart` to show login before main navigation:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/screens/animated_splash_screen.dart';
import 'src/screens/login_screen.dart';
import 'main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyvo - Your Community, Connected',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => AnimatedSplashScreen(
          onAnimationComplete: () {
            Navigator.of(context).pushReplacementNamed('/login');
          },
        ),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}
```

### Option 2: Add to Existing Routes

Add login as a named route:

```dart
routes: {
  '/splash': (context) => const AnimatedSplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(), // Create this
  '/otp': (context) => const OTPScreen(), // Create this
  '/home': (context) => const MainNavigation(),
},
```

### Option 3: Conditional Initial Route

Check authentication status and route accordingly:

```dart
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<bool>(
        future: _checkAuthStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AnimatedSplashScreen();
          }
          
          if (snapshot.data == true) {
            return const MainNavigation();
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
  
  Future<bool> _checkAuthStatus() async {
    // Check if user is logged in
    // Return true if authenticated, false otherwise
    await Future.delayed(const Duration(seconds: 2)); // Splash duration
    return false; // Not authenticated
  }
}
```

## Navigation Flow

### From Login to OTP
```dart
// In login_screen.dart
void _handleSendOTP() {
  final mobile = _mobileController.text.trim();
  
  if (mobile.isEmpty || mobile.length != 10) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter valid mobile number')),
    );
    return;
  }
  
  // Navigate to OTP screen
  Navigator.pushNamed(
    context,
    '/otp',
    arguments: {'mobile': mobile},
  );
}
```

### From Login to Register
```dart
// In login_screen.dart
void _handleRegister() {
  Navigator.pushNamed(context, '/register');
}
```

### From OTP to Home
```dart
// In otp_screen.dart (to be created)
void _handleVerifyOTP() async {
  // Verify OTP
  final success = await _verifyOTP();
  
  if (success) {
    // Navigate to home and clear stack
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }
}
```

## Create OTP Screen

Create a matching OTP verification screen:

```dart
// lib/src/screens/otp_screen.dart
import 'package:flutter/material.dart';
import '../components/auth_primary_button.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({Key? key}) : super(key: key);

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (_) => TextEditingController());
  
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final mobile = args?['mobile'] ?? '';
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2F80ED), Color(0xFF2563EB)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 120),
                const Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the code sent to $mobile',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFF0F0F0),
                  ),
                ),
                const SizedBox(height: 48),
                // Add OTP input fields here
                // Add verify button here
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## Backend Integration

### Create Auth Service

```dart
// lib/src/services/auth_service.dart
class AuthService {
  static const String _baseUrl = 'YOUR_API_BASE_URL';
  
  Future<bool> sendOTP(String mobile) async {
    try {
      // Call your API
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        body: {'mobile': mobile},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }
  
  Future<bool> verifyOTP(String mobile, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        body: {'mobile': mobile, 'otp': otp},
      );
      
      if (response.statusCode == 200) {
        // Save auth token
        final data = json.decode(response.body);
        await _saveAuthToken(data['token']);
        return true;
      }
      return false;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }
  
  Future<void> _saveAuthToken(String token) async {
    // Save to secure storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
```

### Use in Login Screen

```dart
// Update login_screen.dart
import '../services/auth_service.dart';

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  
  void _handleSendOTP() async {
    final mobile = _mobileController.text.trim();
    
    if (mobile.isEmpty || mobile.length != 10) {
      _showError('Please enter valid mobile number');
      return;
    }
    
    setState(() => _isLoading = true);
    
    final success = await _authService.sendOTP(mobile);
    
    setState(() => _isLoading = false);
    
    if (success) {
      Navigator.pushNamed(
        context,
        '/otp',
        arguments: {'mobile': mobile},
      );
    } else {
      _showError('Failed to send OTP. Please try again.');
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
```

## Add Dependencies

Update `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Existing dependencies...
  
  # Add for HTTP requests
  http: ^1.1.0
  
  # Add for secure storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
```

## State Management (Optional)

### Using Provider

```dart
// lib/src/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<bool> sendOTP(String mobile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final success = await _authService.sendOTP(mobile);
    
    _isLoading = false;
    if (!success) {
      _error = 'Failed to send OTP';
    }
    notifyListeners();
    
    return success;
  }
  
  Future<bool> verifyOTP(String mobile, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final success = await _authService.verifyOTP(mobile, otp);
    
    _isLoading = false;
    _isAuthenticated = success;
    if (!success) {
      _error = 'Invalid OTP';
    }
    notifyListeners();
    
    return success;
  }
  
  Future<void> logout() async {
    _isAuthenticated = false;
    notifyListeners();
  }
}
```

### Wrap App with Provider

```dart
// main.dart
import 'package:provider/provider.dart';
import 'src/providers/auth_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Add other providers...
      ],
      child: const MyApp(),
    ),
  );
}
```

### Use in Login Screen

```dart
// login_screen.dart
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class _LoginScreenState extends State<LoginScreen> {
  void _handleSendOTP() async {
    final mobile = _mobileController.text.trim();
    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.sendOTP(mobile);
    
    if (success) {
      Navigator.pushNamed(context, '/otp', arguments: {'mobile': mobile});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          // ... existing code
          body: authProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLoginUI(),
        );
      },
    );
  }
}
```

## Testing

### Test Login Flow
```bash
# Run the app
flutter run

# Test sequence:
# 1. Splash screen appears
# 2. Login screen shows
# 3. Enter mobile number
# 4. Tap "Send OTP"
# 5. Navigate to OTP screen
# 6. Enter OTP
# 7. Navigate to home
```

### Test Error Handling
- Empty mobile number
- Invalid mobile format
- Network errors
- Invalid OTP
- Expired OTP

## Security Considerations

1. **Store tokens securely**: Use `flutter_secure_storage`
2. **Validate input**: Check mobile format before API call
3. **Handle errors gracefully**: Show user-friendly messages
4. **Implement rate limiting**: Prevent OTP spam
5. **Add timeout**: Auto-logout after inactivity
6. **Use HTTPS**: Secure API communication

## Checklist

- [ ] Login screen integrated
- [ ] OTP screen created
- [ ] Register screen created
- [ ] Auth service implemented
- [ ] State management added
- [ ] Error handling implemented
- [ ] Loading states added
- [ ] Navigation flow tested
- [ ] Backend connected
- [ ] Security measures in place

---

**Next**: Create OTP and Register screens following the same design pattern!
