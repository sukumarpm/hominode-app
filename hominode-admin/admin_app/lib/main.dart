import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

import 'admin_login_screen.dart';
import 'auth_wrapper.dart';
import 'firebase_options.dart';
import 'navigation/admin_module_destinations.dart';
import 'navigation/admin_module_routes.dart';
import 'services/admin_notification_router.dart';
import 'super_admin_admins_screen.dart';
import 'super_admin_communities_screen.dart';
import 'super_admin_home_screen.dart';
import 'theme/hominode_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean web URLs such as:
  // https://admin.hominode.com/dashboard
  // instead of hash-based URLs.
  usePathUrlStrategy();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAppCheck.instance.activate(
      // Keep the existing Android / Apple providers for now.
      // They are deprecated parameter names, but they remain functional.
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,

      // Required for admin.hominode.com.
      providerWeb: ReCaptchaEnterpriseProvider(
        '6LfLtJstAAAAAFM2jk9KvFB-2f7zUr9DCNIl7HqN',
      ),
    );

    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(true);

      debugPrint(
        'APP CHECK TOKEN AVAILABLE: '
        '${appCheckToken?.isNotEmpty == true}',
      );
    } catch (error, stackTrace) {
      debugPrint('APP CHECK TOKEN ERROR: $error');

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    try {
      await HominodePushNotifications.instance.initialize(
        onAuthorizedTap: AdminNotificationRouter.handle,
      );
    } catch (error, stackTrace) {
      debugPrint('Notification initialization failed: $error');

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    debugPrint(
      'Firebase initialized: project=${Firebase.app().options.projectId}',
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Firebase/App Check initialization failed: '
      '${error.runtimeType}: $error',
    );

    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }

    // Firebase/App Check is required for this application.
    // Do not launch the UI with an incomplete Firebase startup.
    rethrow;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: adminNotificationNavigatorKey,
          title: 'Hominode Admin',
          debugShowCheckedModeBanner: false,
          theme: HominodeTheme.light,
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const AdminLoginScreen(),

            adminDashboardRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.dashboard),
            adminBuildingsRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.buildings),
            adminResidentsRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.residents),
            adminBillingRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.billing),
            adminVisitorsRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.visitors),
            adminComplaintsRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.complaints),
            adminEventsRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.events),
            adminParkingRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.parking),
            adminResidentVehiclesRoute: (context) => const AuthWrapper(
              requestedModule: AdminModuleId.residentVehicles,
            ),
            adminAmenitiesRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.amenities),
            adminProfileRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.profile),
            adminSettingsRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.settings),

            // Legacy named routes continue to resolve through the same guard.
            adminVisitorsLegacyRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.visitors),
            adminParkingLegacyRoute: (context) =>
                const AuthWrapper(requestedModule: AdminModuleId.parking),
            adminResidentVehiclesLegacyRoute: (context) => const AuthWrapper(
              requestedModule: AdminModuleId.residentVehicles,
            ),

            // Existing Super Admin routes remain protected
            // through AuthWrapper.
            SuperAdminHomeScreen.routeName: (context) => const AuthWrapper(),

            SuperAdminHomeScreen.communitiesRouteName: (context) =>
                const AuthWrapper(
                  superAdminDestination: SuperAdminCommunitiesScreen(),
                ),

            SuperAdminHomeScreen.adminsRouteName: (context) =>
                const AuthWrapper(
                  superAdminDestination: SuperAdminAdminsScreen(),
                ),

            SuperAdminHomeScreen.overviewRouteName: (context) =>
                const AuthWrapper(
                  superAdminDestination: SuperAdminPlaceholderScreen(
                    title: 'Platform Overview',
                  ),
                ),
          },
        );
      },
    );
  }
}
