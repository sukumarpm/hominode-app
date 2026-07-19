# OTP Screen - Complete Integration Guide

## Overview
Complete guide to integrate the OTP verification screen into your authentication flow.

## Complete Auth Flow

```
┌─────────────────┐
│  Splash Screen  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Login Screen   │ ← Enter mobile number
└────────┬────────┘
         │ Send OTP
         ↓
┌─────────────────┐
│   OTP Screen    │ ← Enter 6-digit code
└────────┬────────┘
         │ Verify
         ↓
┌─────────────────┐
│  Home Screen    │
└─────────────────┘
```

## Step 1: Update Main App Routes

### Option A: Named Routes
```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/screens/animated_splash_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/verify_otp_screen.dart';
import 'main_navigation.dart';
import 'src/providers/theme_provider.dart';

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
        '/verify-otp': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          return VerifyOTPScreen(
            mobileNumber: args?['mobile'] as String?,
          );
        },
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}
```

### Option B: GoRouter (Recommended for Complex Apps)
```dart
// pubspec.yaml
dependencies:
  go_router: ^13.0.0

// lib/main.dart
import 'package:go_router/go_router.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => AnimatedSplashScreen(
        onAnimationComplete: () => context.go('/login'),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final mobile = state.extra as String?;
        return VerifyOTPScreen(mobileNumber: mobile);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigation(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
```

## Step 2: Update Login Screen

```dart
// lib/src/screens/login_screen.dart
import '../services/auth_service.dart';

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  
  void _handleSendOTP() async {
    final mobile = _mobileController.text.trim();
    
    // Validate mobile number
    if (mobile.isEmpty) {
      _showError('Please enter your mobile number');
      return;
    }
    
    if (mobile.length != 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Send OTP via API
      final success = await _authService.sendOTP(mobile);
      
      setState(() => _isLoading = false);
      
      if (success) {
        // Navigate to OTP screen
        Navigator.pushNamed(
          context,
          '/verify-otp',
          arguments: {'mobile': mobile},
        );
      } else {
        _showError('Failed to send OTP. Please try again.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('An error occurred. Please try again.');
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing code
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLoginUI(),
    );
  }
}
```

## Step 3: Update OTP Screen

```dart
// lib/src/screens/verify_otp_screen.dart
import '../services/auth_service.dart';

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  
  void _handleVerify() async {
    if (!_isOTPComplete()) {
      _showError('Please enter complete OTP');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final otp = _getOTP();
      final mobile = widget.mobileNumber ?? '';
      
      // Verify OTP via API
      final success = await _authService.verifyOTP(mobile, otp);
      
      setState(() => _isLoading = false);
      
      if (success) {
        // Navigate to home and clear stack
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
      } else {
        setState(() => _errorMessage = 'Invalid OTP. Please try again.');
        _clearOTP();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }
  
  void _handleResend() async {
    try {
      final mobile = widget.mobileNumber ?? '';
      final success = await _authService.resendOTP(mobile);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully')),
        );
        _clearOTP();
      } else {
        _showError('Failed to resend OTP');
      }
    } catch (e) {
      _showError('An error occurred');
    }
  }
  
  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
    setState(() {});
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

## Step 4: Create Auth Service

```dart
// lib/src/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl = 'YOUR_API_BASE_URL';
  
  /// Send OTP to mobile number
  Future<bool> sendOTP(String mobile) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mobile': mobile}),
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      
      print('Send OTP failed: ${response.body}');
      return false;
    } catch (e) {
      print('Send OTP error: $e');
      return false;
    }
  }
  
  /// Verify OTP
  Future<bool> verifyOTP(String mobile, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mobile': mobile,
          'otp': otp,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save auth token
        await _saveAuthToken(data['token']);
        
        // Save user data
        await _saveUserData(data['user']);
        
        return true;
      }
      
      print('Verify OTP failed: ${response.body}');
      return false;
    } catch (e) {
      print('Verify OTP error: $e');
      return false;
    }
  }
  
  /// Resend OTP
  Future<bool> resendOTP(String mobile) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mobile': mobile}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Resend OTP error: $e');
      return false;
    }
  }
  
  /// Save auth token
  Future<void> _saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  
  /// Save user data
  Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(user));
  }
  
  /// Get auth token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
  
  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }
}
```

## Step 5: Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP requests
  http: ^1.1.0
  
  # Local storage
  shared_preferences: ^2.2.2
  
  # Secure storage (optional, for tokens)
  flutter_secure_storage: ^9.0.0
  
  # State management (optional)
  provider: ^6.1.1
  # OR
  riverpod: ^2.4.9
```

## Step 6: Add State Management (Optional)

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
  String? _currentMobile;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentMobile => _currentMobile;
  
  /// Send OTP
  Future<bool> sendOTP(String mobile) async {
    _isLoading = true;
    _error = null;
    _currentMobile = mobile;
    notifyListeners();
    
    final success = await _authService.sendOTP(mobile);
    
    _isLoading = false;
    if (!success) {
      _error = 'Failed to send OTP';
    }
    notifyListeners();
    
    return success;
  }
  
  /// Verify OTP
  Future<bool> verifyOTP(String otp) async {
    if (_currentMobile == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final success = await _authService.verifyOTP(_currentMobile!, otp);
    
    _isLoading = false;
    _isAuthenticated = success;
    if (!success) {
      _error = 'Invalid OTP';
    }
    notifyListeners();
    
    return success;
  }
  
  /// Resend OTP
  Future<bool> resendOTP() async {
    if (_currentMobile == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final success = await _authService.resendOTP(_currentMobile!);
    
    _isLoading = false;
    if (!success) {
      _error = 'Failed to resend OTP';
    }
    notifyListeners();
    
    return success;
  }
  
  /// Check authentication status
  Future<void> checkAuthStatus() async {
    _isAuthenticated = await _authService.isAuthenticated();
    notifyListeners();
  }
  
  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentMobile = null;
    notifyListeners();
  }
}
```

### Wrap App with Provider

```dart
// lib/main.dart
import 'package:provider/provider.dart';
import 'src/providers/auth_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
```

### Use in Screens

```dart
// lib/src/screens/login_screen.dart
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class _LoginScreenState extends State<LoginScreen> {
  void _handleSendOTP() async {
    final mobile = _mobileController.text.trim();
    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.sendOTP(mobile);
    
    if (success) {
      Navigator.pushNamed(context, '/verify-otp');
    } else {
      _showError(authProvider.error ?? 'Failed to send OTP');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          body: authProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLoginUI(),
        );
      },
    );
  }
}

// lib/src/screens/verify_otp_screen.dart
class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  void _handleVerify() async {
    final otp = _getOTP();
    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.verifyOTP(otp);
    
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } else {
      _showError(authProvider.error ?? 'Invalid OTP');
    }
  }
  
  void _handleResend() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.resendOTP();
  }
}
```

## Step 7: Add Error Handling

```dart
// lib/src/utils/error_handler.dart
class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is http.ClientException) {
      return 'Network error. Please check your connection.';
    } else if (error is FormatException) {
      return 'Invalid response from server.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else {
      return 'An unexpected error occurred.';
    }
  }
}

// Use in auth service
try {
  // API call
} catch (e) {
  final message = ErrorHandler.getErrorMessage(e);
  throw Exception(message);
}
```

## Step 8: Add Loading States

```dart
// lib/src/components/loading_overlay.dart
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  
  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

// Use in screens
LoadingOverlay(
  isLoading: _isLoading,
  child: _buildContent(),
)
```

## Testing

### Unit Tests
```dart
// test/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/auth_service.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;
    
    setUp(() {
      authService = AuthService();
    });
    
    test('sendOTP returns true on success', () async {
      final result = await authService.sendOTP('1234567890');
      expect(result, isTrue);
    });
    
    test('verifyOTP returns true on success', () async {
      final result = await authService.verifyOTP('1234567890', '123456');
      expect(result, isTrue);
    });
  });
}
```

### Widget Tests
```dart
// test/verify_otp_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/verify_otp_screen.dart';

void main() {
  testWidgets('OTP screen displays correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VerifyOTPScreen(),
      ),
    );
    
    expect(find.text('Enter OTP'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsOneWidget);
    expect(find.byType(OTPInputBox), findsNWidgets(6));
  });
}
```

## Checklist

- [ ] Routes configured
- [ ] Login screen updated
- [ ] OTP screen updated
- [ ] Auth service created
- [ ] Dependencies added
- [ ] State management added (optional)
- [ ] Error handling implemented
- [ ] Loading states added
- [ ] Navigation flow tested
- [ ] Backend connected
- [ ] Unit tests written
- [ ] Widget tests written

---

**Complete!** Your OTP verification is now fully integrated.
