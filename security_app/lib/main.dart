import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hominode_legal/hominode_legal.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

import 'firebase_options.dart';
import 'models/security_user_model.dart';
import 'screens/login_screen.dart';
import 'screens/security_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/security_notification_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SecurityApp());
}

@visibleForTesting
class SecurityStartupInitializer {
  SecurityStartupInitializer({
    required this.initializeFirebase,
    required this.activateAppCheck,
    required this.verifyAppCheckToken,
    this.retryDelays = const [
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ],
    this.tokenAttemptTimeout = const Duration(seconds: 8),
  });

  final Future<void> Function() initializeFirebase;
  final Future<void> Function() activateAppCheck;
  final Future<void> Function() verifyAppCheckToken;

  /// Only retry startup; do not weaken the authorization checks that follow.
  /// Injected values also let tests run without waiting for real delays.
  final List<Duration> retryDelays;
  final Duration tokenAttemptTimeout;

  Future<void>? _inFlight;
  bool _firebaseReady = false;
  bool _appCheckReady = false;

  Future<void> initialize() {
    final running = _inFlight;
    if (running != null) return running;

    late final Future<void> attempt;
    attempt = _initialize().whenComplete(() {
      if (identical(_inFlight, attempt)) _inFlight = null;
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<void> _initialize() async {
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      var stage = 'firebase';
      try {
        if (!_firebaseReady) {
          await initializeFirebase();
          _firebaseReady = true;
        }
        stage = 'app-check-activation';
        if (!_appCheckReady) {
          await activateAppCheck();
          _appCheckReady = true;
        }
        stage = 'app-check-token';
        // A fresh iOS App Attest token may not be immediately available on a
        // cold start. Retry only a bounded number of times; never proceed
        // without a verified nonempty token.
        await verifyAppCheckToken().timeout(tokenAttemptTimeout);
        return;
      } catch (error, stackTrace) {
        final code = error is FirebaseException
            ? error.code
            : error.runtimeType.toString();
        debugPrint(
          'Security startup $stage attempt '
          '${attempt + 1}/${retryDelays.length + 1} failed ($code).',
        );
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        if (attempt == retryDelays.length) rethrow;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }
}

final SecurityStartupInitializer _securityStartupInitializer =
    SecurityStartupInitializer(
      initializeFirebase: () async {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      },
      activateAppCheck: () => FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        // ignore: deprecated_member_use
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttest,
      ),
      verifyAppCheckToken: _verifyAppCheckToken,
    );

Future<void> _verifyAppCheckToken() async {
  try {
    final appCheckToken = await FirebaseAppCheck.instance.getToken();
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw StateError('App Check did not provide an attestation token.');
    }
  } catch (error, stackTrace) {
    debugPrint('App Check token acquisition failed (${error.runtimeType}).');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
    // An invalid/missing token must never be accepted in debug OR release.
    rethrow;
  }
}

Future<void> _initializeNotificationsSafely() async {
  try {
    await HominodePushNotifications.instance.initialize(
      onAuthorizedTap: SecurityNotificationRouter.handle,
    );
  } catch (error, stackTrace) {
    debugPrint('Notification initialization failed (${error.runtimeType}).');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class SecurityApp extends StatelessWidget {
  const SecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: securityNotificationNavigatorKey,
      title: 'Hominode Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E4778)),
        useMaterial3: true,
      ),
      home: _securityStartupGate(const SecurityAuthGate()),
      routes: {
        '/dashboard': (_) => _securityStartupGate(const SecurityAuthGate()),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return PageRouteBuilder<void>(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) =>
                _securityStartupGate(const SecurityAuthGate()),
          );
        }

        return null;
      },
    );
  }
}

Widget _securityStartupGate(Widget child) => SecurityStartupGate(
  initialize: _securityStartupInitializer.initialize,
  onReady: _initializeNotificationsSafely,
  child: child,
);

class SecurityStartupGate extends StatefulWidget {
  const SecurityStartupGate({
    required this.initialize,
    required this.child,
    this.onReady,
    super.key,
  });

  final Future<void> Function() initialize;
  final Future<void> Function()? onReady;
  final Widget child;

  @override
  State<SecurityStartupGate> createState() => _SecurityStartupGateState();
}

class _SecurityStartupGateState extends State<SecurityStartupGate> {
  static const _startupTimeout = Duration(seconds: 30);

  Timer? _timeout;
  int _attempt = 0;
  bool _isLoading = true;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _beginInitialization();
  }

  void _beginInitialization() {
    final attempt = ++_attempt;
    _timeout?.cancel();
    _timeout = Timer(_startupTimeout, () {
      if (!mounted || attempt != _attempt || _isReady) return;
      setState(() {
        _isLoading = false;
      });
    });

    Future<void>.sync(widget.initialize).then(
      (_) {
        if (!mounted || attempt != _attempt) return;
        _timeout?.cancel();
        setState(() {
          _isLoading = false;
          _isReady = true;
        });
        final onReady = widget.onReady;
        if (onReady != null) unawaited(onReady());
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || attempt != _attempt) return;
        _timeout?.cancel();
        debugPrint('Security startup failed (${error.runtimeType}).');
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  void _retry() {
    setState(() {
      _isLoading = true;
    });
    _beginInitialization();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return widget.child;
    if (_isLoading) return const _LoadingScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF063D35),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: Color(0xFF58E3BE),
                  size: 56,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Secure startup could not complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Check your connection and retry. Security access stays locked until verification succeeds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecurityAuthGate extends StatefulWidget {
  const SecurityAuthGate({
    this.authService,
    this.authorizedContentBuilder,
    super.key,
  });

  @visibleForTesting
  final AuthService? authService;

  @visibleForTesting
  final Widget Function(BuildContext, SecurityUserModel)?
  authorizedContentBuilder;

  @override
  State<SecurityAuthGate> createState() => _SecurityAuthGateState();
}

class _SecurityAuthGateState extends State<SecurityAuthGate> {
  static const _authStartupTimeout = Duration(seconds: 30);
  static const _profileTimeout = Duration(seconds: 30);

  late final AuthService _authService = widget.authService ?? AuthService();
  StreamSubscription<User?>? _authSubscription;
  Timer? _authTimeout;
  int _authGeneration = 0;
  int _profileGeneration = 0;
  bool _isAuthLoading = true;
  User? _currentUser;
  Object? _authError;
  Future<SecurityUserModel>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _subscribeToAuthChanges();
  }

  void _subscribeToAuthChanges() {
    final generation = ++_authGeneration;
    unawaited(_authSubscription?.cancel());
    _authTimeout?.cancel();
    _isAuthLoading = true;
    _currentUser = null;
    _authError = null;
    _profileFuture = null;

    _authTimeout = Timer(_authStartupTimeout, () {
      if (!mounted || generation != _authGeneration || !_isAuthLoading) return;
      setState(() {
        _isAuthLoading = false;
        _authError = TimeoutException('Authentication startup timed out.');
      });
    });

    _authSubscription = _authService.authStateChanges.listen(
      (user) {
        if (!mounted || generation != _authGeneration) return;
        _authTimeout?.cancel();
        final profileGeneration = ++_profileGeneration;
        setState(() {
          _isAuthLoading = false;
          _authError = null;
          _currentUser = user;
          _profileFuture = user == null
              ? null
              : _loadSecurityProfile(user, profileGeneration);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || generation != _authGeneration) return;
        _authTimeout?.cancel();
        setState(() {
          _isAuthLoading = false;
          _authError = error;
        });
      },
    );
  }

  Future<SecurityUserModel> _loadSecurityProfile(
    User user,
    int profileGeneration,
  ) => _authService
      .requireSecurityProfile(
        isSessionCurrent: () =>
            mounted &&
            profileGeneration == _profileGeneration &&
            _currentUser?.uid == user.uid,
      )
      .timeout(_profileTimeout);

  void _retryAuthentication() {
    _profileGeneration++;
    setState(() {
      _isAuthLoading = true;
      _currentUser = null;
      _authError = null;
      _profileFuture = null;
    });
    _subscribeToAuthChanges();
  }

  void _retryProfile() {
    final user = _currentUser;
    if (user == null) return;
    final profileGeneration = ++_profileGeneration;
    setState(() {
      _profileFuture = _loadSecurityProfile(user, profileGeneration);
    });
  }

  @override
  void dispose() {
    _authTimeout?.cancel();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthLoading) return const _LoadingScreen();
    if (_authError != null) {
      return _SecurityAccessError(
        error: _authError,
        onRetry: _retryAuthentication,
        onSignOut: _authService.logout,
      );
    }
    if (_currentUser == null) return const LoginScreen();

    return FutureBuilder<SecurityUserModel>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (profileSnapshot.hasError || !profileSnapshot.hasData) {
          return _SecurityAccessError(
            error: profileSnapshot.error,
            onRetry: _retryProfile,
            onSignOut: _authService.logout,
          );
        }

        final authorizedBuilder = widget.authorizedContentBuilder;
        if (authorizedBuilder != null) {
          return authorizedBuilder(context, profileSnapshot.data!);
        }

        return const HominodeLegalAcceptanceGate(
          profileCollection: 'securityStaff',
          loadingWidget: _SecurityLegalLoadingScreen(),
          child: SecurityDashboardScreen(),
        );
      },
    );
  }
}

class _SecurityLegalLoadingScreen extends StatelessWidget {
  const _SecurityLegalLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF073B35),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF58E3BE),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Preparing Security workspace...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF063D35),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF063D35), Color(0xFF052F2A), Color(0xFF021F1C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/branding/security_transparent.png',
                  width: 125,
                  height: 125,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF58E3BE),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verifying Security access...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityAccessError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  const _SecurityAccessError({
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final message = error is SecurityAuthException
        ? (error as SecurityAuthException).message
        : 'Security access could not be verified.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Access unavailable',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (error is! SecurityAuthException) ...[
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Back to Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
