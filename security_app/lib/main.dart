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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    // ignore: deprecated_member_use
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    // ignore: deprecated_member_use
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
  try {
    final appCheckToken = await FirebaseAppCheck.instance.getToken(true);

    debugPrint(
      '🔐 SECURITY APP CHECK TOKEN AVAILABLE: '
      '${appCheckToken?.isNotEmpty == true}',
    );
  } catch (e) {
    debugPrint('❌ SECURITY APP CHECK TOKEN ERROR: $e');
  }
  try {
    await HominodePushNotifications.instance.initialize(
      onAuthorizedTap: SecurityNotificationRouter.handle,
    );
  } catch (error, stackTrace) {
    debugPrint('Notification initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const SecurityApp());
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
      home: const SecurityAuthGate(),
      routes: {'/dashboard': (_) => const SecurityAuthGate()},
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return PageRouteBuilder<void>(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const SecurityAuthGate(),
          );
        }

        return null;
      },
    );
  }
}

class SecurityAuthGate extends StatefulWidget {
  const SecurityAuthGate({super.key});

  @override
  State<SecurityAuthGate> createState() => _SecurityAuthGateState();
}

class _SecurityAuthGateState extends State<SecurityAuthGate> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (authSnapshot.data == null) {
          return const LoginScreen();
        }

        return FutureBuilder<SecurityUserModel>(
          future: _authService.requireSecurityProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (profileSnapshot.hasError || !profileSnapshot.hasData) {
              return _SecurityAccessError(
                error: profileSnapshot.error,
                onSignOut: _authService.logout,
              );
            }

            return const HominodeLegalAcceptanceGate(
              profileCollection: 'securityStaff',
              loadingWidget: _SecurityLegalLoadingScreen(),
              child: SecurityDashboardScreen(),
            );
          },
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
      backgroundColor: const Color(0xFF02102B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/assets/images/security_login_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA02102B),
                  Color(0xCC031632),
                  Color(0xE603132D),
                ],
              ),
            ),
          ),
          const SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF30D3FF),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
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
        ],
      ),
    );
  }
}

class _SecurityAccessError extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onSignOut;

  const _SecurityAccessError({required this.error, required this.onSignOut});

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
                ElevatedButton(
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
