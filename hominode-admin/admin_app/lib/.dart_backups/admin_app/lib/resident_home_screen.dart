import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/resident_home_service.dart';
import 'services/user_service.dart';
import 'services/admin_service.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final ResidentHomeService _homeService = ResidentHomeService();
  final UserService _userService = UserService();
  final AdminService _adminService = AdminService();
  bool _isInitialized = false;
  String? _buildingId;
  String? _residentName;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      print('🔵 RESIDENT HOME SCREEN: Starting initialization...');

      // STEP 1: Validate User Authentication
      print('🔐 STEP 1: Validating user authentication...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      print('✅ STEP 1 PASSED: User authenticated - ${user.uid}');

      // STEP 2: Fetch User Profile
      print('📋 STEP 2: Fetching user profile...');
      final userProfile = await _userService.getUserProfile(user.uid);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      _buildingId = userProfile['buildingId'] as String?;
      _residentName = userProfile['name'] as String?;
      print('✅ STEP 2 PASSED: User profile fetched - Building: $_buildingId');

      // STEP 3: Check if User is Admin
      print('🔐 STEP 3: Checking admin status...');
      final adminProfile = await _adminService.getAdminProfile();
      _isAdmin = adminProfile != null;
      print('✅ STEP 3 PASSED: Admin status checked - $_isAdmin');

      // STEP 4: Initialize Data Streams
      print('🔄 STEP 4: Initializing data streams...');
      if (_buildingId == null || _buildingId!.isEmpty) {
        throw Exception('Building ID not found');
      }
      print('✅ STEP 4 PASSED: Data streams ready');

      // STEP 5: Update UI State
      print('🔔 STEP 5: Updating UI state...');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      print('✅ STEP 5 PASSED: UI state updated');
      print('✅ RESIDENT HOME SCREEN: Initialization COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing home: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: const Color(0xFF2563EB),
            elevation: 0,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Images & Posters',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      