import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'main_navigation.dart';
import 'src/providers/language_provider.dart';
import 'src/providers/localization_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/screens/simple_login_screen.dart';
import 'src/screens/splash_screen_clean.dart';
import 'src/screens/resident_registration_screen.dart';
import 'src/screens/awaiting_approval_screen.dart';
import 'src/screens/access_blocked_screen.dart';
import 'src/services/firebase_auth_service.dart';
import 'src/services/resident_auth_routing.dart';
import 'src/services/tenant_resolution_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();

  // Set system UI to light mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ta'),
        Locale('hi'),
        Locale('es'),
        Locale('ar'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()),
          ChangeNotifierProvider(create: (_) => TenantResolutionService()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_title'.tr(),
      debugShowCheckedModeBanner: false,

      // Localization configuration
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        EasyLocalization.of(context)!.delegate,
      ],
      supportedLocales: EasyLocalization.of(context)!.supportedLocales,
      locale: context.locale,

      // Apply light theme only
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,

      home: const AuthCheckScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(
              builder: (context) => CleanSplashScreen(
                logoAssetPath: 'assets/logo1.png',
                appName: 'Hominode',
                tagline: 'Your Community, Connected',
                duration: const Duration(milliseconds: 3000),
                onFinish: () async {
                  final result = await FirebaseAuthService()
                      .restoreResidentSession(
                        context.read<TenantResolutionService>(),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed(
                      ResidentAuthRouting.routeFor(result),
                      arguments: result.message,
                    );
                  }
                },
              ),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const SimpleLoginScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (context) => const MainNavigation(),
            );
          case '/resident-registration':
            return MaterialPageRoute(
              builder: (context) => const ResidentRegistrationScreen(),
            );
          case '/awaiting-approval':
            return MaterialPageRoute(
              builder: (context) => const AwaitingApprovalScreen(),
            );
          case '/resident-access-blocked':
            return MaterialPageRoute(
              builder: (context) => AccessBlockedScreen(
                message:
                    settings.arguments as String? ??
                    'Resident access is unavailable. Contact your community administrator.',
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const SimpleLoginScreen(),
            );
        }
      },
    );
  }
}

// Auth Check Screen - Determines initial route based on login state
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (mounted) {
      final result = await FirebaseAuthService().restoreResidentSession(
        context.read<TenantResolutionService>(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          ResidentAuthRouting.routeFor(result),
          arguments: result.message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo1.png', width: 100, height: 100),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}
