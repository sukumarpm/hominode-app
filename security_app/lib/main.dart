import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/security_user_model.dart';
import 'screens/login_screen.dart';
import 'screens/security_dashboard_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SecurityApp());
}

class SecurityApp extends StatelessWidget {
  const SecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hominode Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E4778)),
        useMaterial3: true,
      ),
      home: const SecurityAuthGate(),
      routes: {
        '/login': (_) => const SecurityAuthGate(),
        '/dashboard': (_) => const SecurityAuthGate(),
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

            return const SecurityDashboardScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying Security access...'),
          ],
        ),
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
