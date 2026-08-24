// lib/profile_screen.dart
// Profile / Settings screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_wall_screen.dart';
import 'src/screens/marketplace_screen.dart';
import 'src/screens/family_vehicles_screen.dart';
import 'src/screens/app_settings_screen.dart';
import 'src/screens/domestic_staff_screen.dart';
import 'src/screens/notifications_settings_screen.dart';
import 'src/screens/edit_profile_screen.dart';
import 'src/screens/my_bookings_screen.dart';
import 'src/screens/documents_circulars_screen.dart';
import 'src/services/user_data_service.dart';
import 'src/services/firebase_auth_service.dart';
import 'src/services/tenant_resolution_service.dart';
import 'src/services/organization_service.dart';
import 'src/services/profile_image_service.dart';
import 'src/providers/language_provider.dart';

// ============================================================================
// THEME CONSTANTS
// ============================================================================
const Color kPrimaryBlue = Color(0xFF2563EB);
const Color kCardWhite = Color(0xFFFFFFFF);
const Color kBackgroundGrey = Color(0xFFF7F7F7);
const Color kBorderColor = Color(0xFFE6E6E6);
const Color kTextPrimary = Color(0xFF111111);
const Color kTextMuted = Color(0xFF9B9B9B);
const double kPadding = 16.0;
const double kGap = 12.0;
const double kCardRadius = 12.0;

// ============================================================================
// PROFILE SCREEN
// ============================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static MaterialPageRoute route() {
    return MaterialPageRoute(builder: (_) => const ProfileScreen());
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userDataService = UserDataService();
  final _authService = FirebaseAuthService();
  final _organizationService = OrganizationService();
  Map<String, dynamic>? _userProfile;
  String _organizationName = 'Your Apartment'; // Default fallback
  bool _isLoading = true;
  String? _userId; // Track user ID for image streaming

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    print('🔵 PROFILE SCREEN LOAD FLOW: Starting...');
    setState(() => _isLoading = true);

    try {
      // STEP 1: Fetch user data from Firestore
      print('📥 STEP 1: Fetching user data from Firestore...');
      var userData = await _userDataService.getCurrentUserData(
        forceRefresh: true,
      );

      // If first attempt fails, try getting from SharedPreferences user_id
      if (userData == null) {
        print('⚠️  First attempt failed, trying alternative method...');
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');

        if (userId != null) {
          print('   Trying to fetch with user_id: $userId');
          userData = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get()
              .then((doc) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }
                return null;
              });
        }
      }

      if (userData == null) {
        print('❌ STEP 1 FAILED: No user data found');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'User profile not found. Please contact administrator.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print('✅ STEP 1 PASSED: User data loaded');
      print('   Name: ${userData['name']}');
      print('   Email: ${userData['email']}');
      print('   Phone: ${userData['phone']}');
      print('   Flat: ${userData['flatLabel'] ?? userData['flatId']}');

      // STEP 2: Get user ID for organization and image streaming
      print('🔍 STEP 2: Getting user ID for organization lookup...');
      String? userId;
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');

      if (userId == null) {
        // Try to get from Firebase Auth
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          userId = firebaseUser.uid;
          await prefs.setString('user_id', userId);
        }
      }

      print('✅ STEP 2 PASSED: User ID: $userId');

      // STEP 3: Fetch organization name
      print('🏢 STEP 3: Fetching organization name...');
      String organizationName = 'Your Apartment'; // Default
      if (userId != null) {
        try {
          organizationName = await _organizationService
              .getOrganizationNameForUser(userId);
          print('✅ STEP 3 PASSED: Organization name: $organizationName');
        } catch (e) {
          print('⚠️  STEP 3 WARNING: Could not fetch organization name: $e');
          print('   Using default: $organizationName');
        }
      }

      // STEP 4: Update UI with data
      print('🎨 STEP 4: Updating UI with profile data...');
      if (mounted) {
        setState(() {
          _userId = userId; // Store user ID for image streaming
          _userProfile = {
            'name': userData?['name'] ?? 'User',
            'email': userData?['email'] ?? '',
            'phone': userData?['phone'] ?? '',
            'flatNumber':
                userData?['flatLabel'] ?? userData?['flatId'] ?? 'Not Set',
          };
          _organizationName = organizationName;
          _isLoading = false;
        });

        print('✅ STEP 4 PASSED: UI updated with data');
        print('');
        print('✅ PROFILE SCREEN LOAD FLOW: COMPLETE');
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in PROFILE SCREEN LOAD FLOW: $e');
      print('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String get _userName => _userProfile?['name'] ?? 'User';
  String get _userPhone => _userProfile?['phone'] ?? '';
  String get _userFlat => _userProfile?['flatNumber'] ?? 'Not Set';

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                Container(
                  color: Colors.black,
                  height: MediaQuery.of(context).padding.top,
                ),
                Expanded(
                  child: Container(
                    color: kBackgroundGrey,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildHeader(),
                                _buildStatsRow(),
                                Padding(
                                  padding: const EdgeInsets.all(kPadding),
                                  child: Column(
                                    children: [
                                      _buildSettingCard(
                                        icon: Icons.person_outline,
                                        iconBg: const Color(0xFFDBEAFE),
                                        iconColor: const Color(0xFF3B82F6),
                                        title: 'edit_profile'.tr(),
                                        onTap: () => _showEditProfile(context),
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.people_outline,
                                        iconBg: const Color(0xFFEDE9FF),
                                        iconColor: const Color(0xFF8B5CF6),
                                        title: 'Family Members',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const FamilyVehiclesScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.directions_car_outlined,
                                        iconBg: const Color(0xFFE8FDEB),
                                        iconColor: const Color(0xFF10B981),
                                        title: 'My Vehicles',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const FamilyVehiclesScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.cleaning_services_outlined,
                                        iconBg: const Color(0xFFFFF3E8),
                                        iconColor: const Color(0xFFF97316),
                                        title: 'Domestic Staff',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const DomesticStaffScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.bookmark_outline,
                                        iconBg: const Color(0xFFFCE7F3),
                                        iconColor: const Color(0xFFEC4899),
                                        title: 'My Bookings',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MyBookingsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.description_outlined,
                                        iconBg: const Color(0xFFDCFCE7),
                                        iconColor: const Color(0xFF16A34A),
                                        title: 'Documents & Circulars',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const DocumentsCircularsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.groups_outlined,
                                        iconBg: const Color(0xFFEDE9FF),
                                        iconColor: const Color(0xFF8B5CF6),
                                        title: 'community_wall'.tr(),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CommunityWallScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.shopping_bag_outlined,
                                        iconBg: const Color(0xFFFFF9E6),
                                        iconColor: const Color(0xFFFDB022),
                                        title: 'marketplace'.tr(),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MarketplaceScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.notifications_outlined,
                                        iconBg: const Color(0xFFF3F4F6),
                                        iconColor: const Color(0xFF6B7280),
                                        title: 'notifications'.tr(),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const NotificationsSettingsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: kGap),
                                      _buildSettingCard(
                                        icon: Icons.settings_outlined,
                                        iconBg: const Color(0xFFF3F4F6),
                                        iconColor: const Color(0xFF6B7280),
                                        title: 'settings'.tr(),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const AppSettingsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      _buildLogoutButton(
                                        context,
                                        languageProvider,
                                      ),
                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            // Time and status bar placeholder
            const SizedBox(height: 8),

            // Avatar and user info with real-time image streaming
            Row(
              children: [
                // StreamBuilder for real-time image fetching
                _userId != null
                    ? StreamBuilder<ProfileImageResult>(
                        stream: ProfileImageService.instance.streamProfileImage(
                          userId: _userId!,
                        ),
                        builder: (context, snapshot) {
                          print('🔵 ProfileScreen: Image stream update');

                          // Loading state
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            print('⏳ ProfileScreen: Image stream loading...');
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            );
                          }

                          // Error or no data state
                          if (!snapshot.hasData || snapshot.data == null) {
                            print('⚠️ ProfileScreen: No image data in stream');
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.person,
                                size: 32,
                                color: Color(0xFF2563EB),
                              ),
                            );
                          }

                          final result = snapshot.data!;

                          // Success state - image found
                          if (result.success && result.imageUrl != null) {
                            print(
                              '✅ ProfileScreen: Image URL received: ${result.imageUrl}',
                            );
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              backgroundImage: NetworkImage(result.imageUrl!),
                            );
                          }

                          // Failure state - no image
                          print('❌ ProfileScreen: ${result.message}');
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.person,
                              size: 32,
                              color: Color(0xFF2563EB),
                            ),
                          );
                        },
                      )
                    : CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.person,
                          size: 32,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_userPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _userPhone,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Apartment card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _organizationName, // Dynamic organization name
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userFlat,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.all(kPadding),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              value: '145',
              label: 'Points',
              gradient: const LinearGradient(
                colors: [Color(0xFFE8FDEB), Color(0xFFD1FAE5)],
              ),
              textColor: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: kGap),
          Expanded(
            child: _buildStatTile(
              value: '12',
              label: 'Events',
              gradient: const LinearGradient(
                colors: [Color(0xFFF3E8FF), Color(0xFFEDE9FF)],
              ),
              textColor: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: kGap),
          Expanded(
            child: _buildStatTile(
              value: '3',
              label: 'Badges',
              gradient: const LinearGradient(
                colors: [Color(0xFFDBEAFE), Color(0xFFDBEAFE)],
              ),
              textColor: const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String value,
    required String label,
    required Gradient gradient,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: kCardWhite,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: kBorderColor, width: 1),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: kTextMuted, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () => _handleLogout(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryBlue,
          side: const BorderSide(color: kPrimaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
        ),
        child: Text(
          'logout'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kPrimaryBlue),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear login state using Firestore auth service
      await _authService.signOut(context.read<TenantResolutionService>());

      if (context.mounted) {
        // Navigate to login screen and clear all previous routes
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _showEditProfile(BuildContext context) async {
    // Navigate to Edit Profile screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );

    // Reload profile if changes were made
    if (result == true) {
      _loadUserProfile();
    }
  }
}

// ============================================================================
// USAGE
// ============================================================================
// 1. File location: lib/profile_screen.dart
// 2. Assets: None required (uses Material Icons)
// 3. Usage: Navigator.push(context, ProfileScreen.route());
