import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'main_navigation.dart';
import 'src/providers/theme_provider.dart';
import 'src/providers/language_provider.dart';
import 'src/providers/localization_provider.dart';
import 'src/screens/splash_screen_clean.dart';
import 'src/screens/simple_login_screen.dart';
import 'src/screens/create_account_screen.dart';
import 'src/screens/setup_profile_screen.dart';
import 'src/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
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
                appName: 'Lyvo',
                tagline: 'Your Community, Connected',
                duration: const Duration(milliseconds: 3000),
                onFinish: () async {
                  final authService = AuthService();
                  final isLoggedIn = await authService.isLoggedIn();
                  if (context.mounted) {
                    if (isLoggedIn) {
                      Navigator.of(context).pushReplacementNamed('/home');
                    } else {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  }
                },
              ),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const SimpleLoginScreen(),
            );
          case '/register':
            return MaterialPageRoute(
              builder: (context) => const CreateAccountScreen(),
            );
          case '/setup-profile':
            return MaterialPageRoute(
              builder: (context) => const SetupProfileScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (context) => const MainNavigation(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const MainNavigation(),
            );
        }
      },
    );
  }
}

// Auth Check Screen - Determines initial route based on login state
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

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
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      
      if (mounted) {
        if (isLoggedIn) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/login');
        }
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
            Image.asset(
              'assets/logo1.png',
              width: 100,
              height: 100,
            ),
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
