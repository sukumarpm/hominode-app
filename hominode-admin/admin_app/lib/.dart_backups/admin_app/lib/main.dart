import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'admin_residents_page_firestore.dart';
import 'manage_buildings_page.dart';
import 'billing_screen.dart';
import 'events_announcements_screen.dart';
import 'admin_login_screen.dart';
import 'visitor_management_screen.dart';
import 'complaint_management_screen.dart';
import 'parking_management_screen.dart';
import 'resident_vehicle_management_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized: project=${Firebase.app().options.projectId}');
  } on FirebaseException catch (error, stackTrace) {
    print(
      'Firebase initialization failed: plugin=${error.plugin}, '
      'code=${error.code}, message=${error.message}\n$stackTrace',
    );
    rethrow;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocietyConnect Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const AuthWrapper(),
        '/buildings': (context) => const ManageBuildingsPage(),
        '/residents': (context) => const AdminResidentsPageFirestore(),
        '/billing': (context) => const BillingScreen(),
        '/events': (context) => const EventsAnnouncementsScreen(),
        '/visitor_management': (context) => const VisitorManagementScreen(),
        '/complaints': (context) => const ComplaintManagementScreen(),
        '/parking_management': (context) =>
            const ParkingManagementScreenEnhanced(),
        '/resident_vehicles': (context) =>
            const ResidentVehicleManagementScreen(),
      },
    );
  }
}
