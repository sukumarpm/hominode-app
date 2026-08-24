import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'community_wall_screen.dart';
import 'complaints_screen.dart';
import 'src/screens/messages_screen.dart';
import 'src/screens/marketplace_screen.dart';
import 'src/screens/amenities_booking_screen.dart';
import 'src/screens/emergency_sos_screen.dart';
import 'src/screens/notifications_screen.dart';
import 'src/services/user_data_service.dart';
import 'src/services/bill_firestore_service.dart';
import 'src/services/visitor_firestore_service.dart';
import 'src/services/complaint_firestore_service.dart';
import 'src/services/organization_service.dart';
import 'src/services/apartment_images_service.dart';
import 'src/services/recent_activity_flow_function.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main Dashboard Screen - Resident App
/// Recreates the exact UI from the reference image
class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const DashboardScreen({super.key, this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _userDataService = UserDataService();
  final _billService = BillFirestoreService();
  final _visitorService = VisitorFirestoreService();
  final _complaintService = ComplaintFirestoreService();
  final _organizationService = OrganizationService();
  final _apartmentImagesService = ApartmentImagesService();
  
  String _userName = 'User';
  String _userFlat = 'Not Set';
  String _organizationName = 'Your Apartment'; // Default fallback
  bool _isLoading = true;
  
  // Real data from Firestore
  double _pendingBillAmount = 0;
  int _visitorTodayCount = 0;
  int _openComplaintCount = 0;
  
  // Apartment images from Firestore
  List<String> _bannerImages = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadApartmentImages();
    // Auto-scroll every 5 seconds
    Future.delayed(const Duration(seconds: 5), _autoScroll);
  }

  Future<void> _loadDashboardData() async {
    print('🔵 Dashboard: Loading dashboard data from Firestore users collection...');
    
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Step 1: Get stored user ID from SharedPreferences
      print('📥 Dashboard: Step 1 - Getting stored user ID...');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) {
        print('❌ Dashboard: No user ID found in SharedPreferences');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      
      print('✅ Dashboard: User ID found: $userId');
      
      // Step 2: Fetch user document directly from Firestore users collection
      print('📥 Dashboard: Step 2 - Fetching user document from users collection...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        print('❌ Dashboard: User document not found in users collection');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      print('✅ Dashboard: User document fetched successfully');
      print('   Name: ${userData['name']}');
      print('   Flat: ${userData['flatLabel'] ?? userData['flatId']}');
      print('   FlatId: ${userData['flatId']}');
      print('   Organization: ${userData['organization']}');
      
      // Step 3: Extract all required data from user document
      final userName = userData['name'] ?? 'User';
      final userFlat = userData['flatLabel'] ?? userData['flatId'] ?? 'Not Set';
      final organizationName = userData['organization'] ?? 'Your Apartment';
      
      // Step 4: Fetch billing data
      print('📥 Dashboard: Step 3 - Loading billing data...');
      final currentBill = await _billService.getCurrentBill();
      final billAmount = currentBill != null 
          ? (currentBill['amount'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      print('✅ Dashboard: Billing data loaded - Amount: ₹$billAmount');
      
      // Step 5: Fetch visitors and complaints in parallel
      print('📥 Dashboard: Step 4 - Loading visitors and complaints...');
      final results = await Future.wait<dynamic>([
        _visitorService.getMyVisitors(),
        _complaintService.getMyComplaints(),
      ]);
      
      final visitors = results[0] as List<Map<String, dynamic>>;
      final complaints = results[1] as List;
      
      // Step 6: Count visitors today
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      final visitorsToday = visitors.where((visitor) {
        final expectedArrival = visitor['expectedArrival'];
        DateTime? visitDate;
        
        if (expectedArrival is Timestamp) {
          visitDate = expectedArrival.toDate();
        } else if (expectedArrival is DateTime) {
          visitDate = expectedArrival;
        }
        
        if (visitDate == null) return false;
        return visitDate.isAfter(todayStart) && visitDate.isBefore(todayEnd);
      }).length;
      
      // Step 7: Count open complaints (pending or in-progress)
      final openComplaints = complaints.where((complaint) {
        // Handle both Complaint objects and Map
        if (complaint is Map) {
          final status = complaint['status'] as String?;
          return status == 'pending' || status == 'in-progress' || status == 'inProgress';
        } else {
          // Complaint object - access status property
          final status = (complaint as dynamic).status?.toString() ?? '';
          return status == 'pending' || status == 'in-progress' || status == 'inProgress';
        }
      }).length;
      
      print('✅ Dashboard: Summary data calculated');
      print('   Pending Bill: ₹$billAmount');
      print('   Visitors Today: $visitorsToday');
      print('   Open Complaints: $openComplaints');
      
      if (mounted) {
        setState(() {
          _userName = userName;
          _userFlat = userFlat;
          _organizationName = organizationName;
          _pendingBillAmount = billAmount;
          _visitorTodayCount = visitorsToday;
          _openComplaintCount = openComplaints;
          _isLoading = false;
        });
        
        print('✅ Dashboard: UI updated with real data from users collection');
      }
    } catch (e, stackTrace) {
      print('❌ Dashboard: Error loading data: $e');
      print('❌ Dashboard: Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadApartmentImages() async {
    try {
      print('🔵 Dashboard: Loading apartment images...');
      
      final result = await _apartmentImagesService.getApartmentImages();
      
      if (!result.success) {
        print('❌ Dashboard: Failed to load images: ${result.message}');
        if (mounted) {
          setState(() {
            _bannerImages = [];
          });
        }
        return;
      }
      
      final images = result.imageUrls ?? [];
      print('✅ Dashboard: Service returned ${images.length} images');
      
      if (images.isEmpty) {
        print('⚠️ Dashboard: No apartment images found - showing empty state');
        if (mounted) {
          setState(() {
            _bannerImages = [];
          });
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _bannerImages = images;
        });
        print('✅ Dashboard: Apartment images loaded and UI updated');
        print('   Images: $_bannerImages');
      }
    } catch (e, stackTrace) {
      print('❌ Dashboard: Error loading apartment images: $e');
      print('❌ Dashboard: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _bannerImages = [];
        });
      }
    }
  }

  void _autoScroll() {
    if (!mounted) return;
    
    final nextPage = (_currentPage + 1) % _bannerImages.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    
    // Schedule next auto-scroll
    Future.delayed(const Duration(seconds: 5), _autoScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black, // Black status bar background
        statusBarIconBrightness: Brightness.light, // White icons on black
        statusBarBrightness: Brightness.dark, // For iOS (dark status bar)
      ),
      child: Scaffold(
        backgroundColor: Colors.black, // Black background extends to status bar
        body: Column(
          children: [
            // Status bar spacer (black background)
            Container(
              color: Colors.black,
              height: MediaQuery.of(context).padding.top,
            ),
            
            // Main content
            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Blue header section with gradient
                      _buildHeader(),
            
                  // Apartment image banner
                  _buildImageBanner(),
                  
                  // Summary cards (Pending Bill, Visitor Today, Open Complaint)
                  _buildSummaryCards(),
                
                  // Quick Access section
                  _buildQuickAccessSection(),
                  
                  // Recent Activity section
                  _buildRecentActivitySection(),
                  
                      // Emergency SOS button
                      _buildEmergencyButton(),
                      
                      const SizedBox(height: 100), // Extra padding for bottom nav
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Blue gradient header with greeting and apartment info
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1E40AF),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with time and notification
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '9:41',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Good Morning text
            Text(
              'good_morning'.tr(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Hi, [User Name]! with wave emoji
            Row(
              children: [
                Text(
                  'Hi, $_userName! ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  '👋',
                  style: TextStyle(fontSize: 24),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Apartment info card
            Container(
              padding: const EdgeInsets.all(16),
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
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userFlat,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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

  /// Auto-scrolling banner carousel
  Widget _buildImageBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _bannerImages.isEmpty
                  ? Container(
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 60, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'no_images_available'.tr(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        if (mounted) {
                          setState(() {
                            _currentPage = index;
                          });
                        }
                      },
                      itemCount: _bannerImages.length,
                      itemBuilder: (context, index) {
                        print('🖼️ Loading image $index: ${_bannerImages[index]}');
                        return Image.network(
                          _bannerImages[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ Error loading image $index: $error');
                            return Container(
                              color: Colors.grey[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 60, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'failed_to_load_image'.tr(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Page indicators
          if (_bannerImages.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _bannerImages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Three summary cards: Pending Bill, Visitor Today, Open Complaint
  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.receipt_long,
              iconColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFFE8FDEB),
              value: _pendingBillAmount > 0 ? '₹${_pendingBillAmount.toStringAsFixed(0)}' : '₹0',
              label: 'billing'.tr(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF8B5CF6),
              backgroundColor: const Color(0xFFEDE9FF),
              value: '$_visitorTodayCount',
              label: 'visitors'.tr(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.build_outlined,
              iconColor: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFFEAF1FF),
              value: '$_openComplaintCount',
              label: 'complaints'.tr(),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual summary card widget
  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: iconColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Quick Access section with 8 icon buttons
  Widget _buildQuickAccessSection() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'quick_access'.tr(),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              // First row of quick access icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.people_outline,
                    label: 'visitors'.tr(),
                    iconColor: const Color(0xFF3B82F6),
                    backgroundColor: const Color(0xFFEAF1FF),
                  ),
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'billing'.tr(),
                    iconColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFFE8FDEB),
                  ),
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    label: 'events'.tr(),
                    iconColor: const Color(0xFF8B5CF6),
                    backgroundColor: const Color(0xFFEDE9FF),
                  ),
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.build_outlined,
                    label: 'complaints'.tr(),
                    iconColor: const Color(0xFFF97316),
                    backgroundColor: const Color(0xFFFFF3E8),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Second row of quick access icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: 'messages'.tr(),
                    iconColor: const Color(0xFFF97316),
                    backgroundColor: const Color(0xFFFFF3E8),
                  ),
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.groups_outlined,
                    label: 'community_wall'.tr(),
                    iconColor: const Color(0xFF8B5CF6),
                    backgroundColor: const Color(0xFFEDE9FF),
                  ),
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.fitness_center_outlined,
                    label: 'amenities'.tr(),
                    iconColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFFE8FDEB),
                  ),
                  _buildQuickAccessItem(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    label: 'marketplace'.tr(),
                    iconColor: const Color(0xFF3B82F6),
                    backgroundColor: const Color(0xFFEAF1FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MarketplaceScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  /// Individual quick access icon button
  Widget _buildQuickAccessItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color backgroundColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {
        print('🔵 Dashboard: Quick access tapped - Label: $label');
        
        try {
          // Get translated labels for comparison
          final visitorsLabel = 'visitors'.tr();
          final billingLabel = 'billing'.tr();
          final eventsLabel = 'events'.tr();
          final communityLabel = 'community_wall'.tr();
          final complaintsLabel = 'complaints'.tr();
          final messagesLabel = 'messages'.tr();
          final amenitiesLabel = 'amenities'.tr();
          
          // Switch to tab for main screens (Visitors, Bills, Events)
          if (label == visitorsLabel || label == 'Visitors') {
            print('✅ Dashboard: Navigating to Visitors tab');
            widget.onTabChange?.call(1); // Switch to Visitors tab
          }
          else if (label == billingLabel || label == 'Billing') {
            print('✅ Dashboard: Navigating to Billing tab');
            widget.onTabChange?.call(2); // Switch to Bills tab
          }
          else if (label == eventsLabel || label == 'Events') {
            print('✅ Dashboard: Navigating to Events tab');
            widget.onTabChange?.call(3); // Switch to Events tab
          }
          // Navigate to sub-screens (Community, Complaints, Messages, Amenities)
          else if (label == communityLabel || label == 'Community Wall' || label == 'Community') {
            print('✅ Dashboard: Navigating to Community Wall screen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CommunityWallScreen(),
              ),
            );
          }
          else if (label == complaintsLabel || label == 'Complaints') {
            print('✅ Dashboard: Navigating to Complaints screen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ComplaintsScreen(),
              ),
            );
          }
          else if (label == messagesLabel || label == 'Messages') {
            print('✅ Dashboard: Navigating to Messages screen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MessagesScreenEnhanced(),
              ),
            );
          }
          else if (label == amenitiesLabel || label == 'Amenities') {
            print('✅ Dashboard: Navigating to Amenities screen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AmenitiesBookingScreen(),
              ),
            );
          }
          else {
            print('⚠️ Dashboard: Unknown quick access label: $label');
          }
        } catch (e) {
          print('❌ Dashboard: Error in quick access navigation: $e');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent Activity section with real data from Firestore
  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          // Section header with "View All" button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'recent_activity'.tr(),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'view_details'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Fetch real activities from Firestore
          FutureBuilder(
            future: _fetchRecentActivities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                print('❌ Error fetching activities: ${snapshot.error}');
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading activities: ${snapshot.error}'),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('No recent activities'),
                );
              }

              return Column(
                children: List.generate(
                  activities.length,
                  (index) {
                    final activity = activities[index];
                    return Column(
                      children: [
                        _buildActivityItemFromData(activity),
                        if (index < activities.length - 1)
                          const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Fetch recent activities from Firestore
  Future<List<dynamic>> _fetchRecentActivities() async {
    print('🔵 Fetching recent activities from Firestore...');
    try {
      final result = await RecentActivityFlowFunction.instance.fetchRecentActivities(limit: 5);
      
      if (result.success) {
        print('✅ Fetched ${result.activities.length} activities');
        return result.activities;
      } else {
        print('❌ Error: ${result.message}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching activities: $e');
      return [];
    }
  }

  /// Build activity item from real data
  Widget _buildActivityItemFromData(dynamic activity) {
    // Get icon and colors based on activity type
    IconData icon;
    Color iconColor;
    Color iconBackground;

    if (activity.activityType == 'booking') {
      icon = Icons.calendar_today;
      iconColor = const Color(0xFF8B5CF6);
      iconBackground = const Color(0xFFEDE9FF);
    } else if (activity.activityType == 'visitor') {
      icon = Icons.shield_outlined;
      iconColor = const Color(0xFFF97316);
      iconBackground = const Color(0xFFFFF3E8);
    } else if (activity.activityType == 'complaint') {
      icon = Icons.warning_outlined;
      iconColor = const Color(0xFFEF4444);
      iconBackground = const Color(0xFFFEE2E2);
    } else {
      icon = Icons.info_outlined;
      iconColor = const Color(0xFF3B82F6);
      iconBackground = const Color(0xFFEAF1FF);
    }

    // Get status color
    Color statusColor;
    Color statusBackground;

    final status = activity.statusText.toLowerCase();
    if (status.contains('confirmed') || status.contains('approved') || status.contains('received')) {
      statusColor = const Color(0xFF10B981);
      statusBackground = const Color(0xFFD1FAE5);
    } else if (status.contains('pending')) {
      statusColor = const Color(0xFFF59E0B);
      statusBackground = const Color(0xFFFEF3C7);
    } else if (status.contains('rejected') || status.contains('cancelled')) {
      statusColor = const Color(0xFFEF4444);
      statusBackground = const Color(0xFFFEE2E2);
    } else {
      statusColor = const Color(0xFF3B82F6);
      statusBackground = const Color(0xFFDBEAFE);
    }

    return _buildActivityItem(
      icon: icon,
      iconColor: iconColor,
      iconBackground: iconBackground,
      title: activity.title,
      subtitle: activity.subtitle,
      statusText: activity.statusText,
      statusColor: statusColor,
      statusBackground: statusBackground,
    );
  }

  /// Individual activity item widget
  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required String statusText,
    required Color statusColor,
    required Color statusBackground,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Emergency SOS button
  Widget _buildEmergencyButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencySosScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Emergency SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

