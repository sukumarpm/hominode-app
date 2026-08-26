// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'community_wall_screen.dart';
// import 'complaints_screen.dart';
// import 'src/screens/amenities_booking_screen.dart';
// import 'src/screens/emergency_sos_screen.dart';
// import 'src/screens/marketplace_screen.dart';
// import 'src/screens/messages_screen.dart';
// import 'src/screens/notifications_screen.dart';
// import 'src/services/apartment_images_service.dart';
// import 'src/services/bill_firestore_service.dart';
// import 'src/services/complaint_firestore_service.dart';
// import 'src/services/organization_service.dart';
// import 'src/services/recent_activity_flow_function.dart';
// import 'src/services/user_data_service.dart';
// import 'src/services/visitor_firestore_service.dart';

// /// Main Dashboard Screen - Resident App
// /// Recreates the exact UI from the reference image
// class DashboardScreen extends StatefulWidget {
//   final Function(int)? onTabChange;

//   const DashboardScreen({super.key, this.onTabChange});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;
//   final _userDataService = UserDataService();
//   final _billService = BillFirestoreService();
//   final _visitorService = VisitorFirestoreService();
//   final _complaintService = ComplaintFirestoreService();
//   final _organizationService = OrganizationService();
//   final _apartmentImagesService = ApartmentImagesService();

//   String _userName = 'User';
//   String _userFlat = 'Not Set';
//   String _organizationName = 'Your Apartment'; // Default fallback
//   bool _isLoading = true;

//   // Real data from Firestore
//   double _pendingBillAmount = 0;
//   int _visitorTodayCount = 0;
//   int _openComplaintCount = 0;

//   // Apartment images from Firestore
//   List<String> _bannerImages = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadDashboardData();
//     _loadApartmentImages();
//     // Auto-scroll every 5 seconds
//     Future.delayed(const Duration(seconds: 5), _autoScroll);
//   }

//   Future<void> _loadDashboardData() async {
//     print(
//       '🔵 Dashboard: Loading dashboard data from Firestore users collection...',
//     );

//     if (mounted) {
//       setState(() => _isLoading = true);
//     }

//     try {
//       // Step 1: Get stored user ID from SharedPreferences
//       print('📥 Dashboard: Step 1 - Getting stored user ID...');
//       final prefs = await SharedPreferences.getInstance();
//       final userId = prefs.getString('user_id');

//       if (userId == null) {
//         print('❌ Dashboard: No user ID found in SharedPreferences');
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//         return;
//       }

//       print('✅ Dashboard: User ID found: $userId');

//       // Step 2: Fetch user document directly from Firestore users collection
//       print(
//         '📥 Dashboard: Step 2 - Fetching user document from users collection...',
//       );
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(userId)
//           .get();

//       if (!userDoc.exists) {
//         print('❌ Dashboard: User document not found in users collection');
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//         return;
//       }

//       final userData = userDoc.data() as Map<String, dynamic>;

//       print('✅ Dashboard: User document fetched successfully');
//       print('   Name: ${userData['name']}');
//       print('   Flat: ${userData['flatLabel'] ?? userData['flatId']}');
//       print('   FlatId: ${userData['flatId']}');
//       print('   Organization: ${userData['organization']}');

//       // Step 3: Extract all required data from user document
//       final userName = userData['name'] ?? 'User';
//       final userFlat = userData['flatLabel'] ?? userData['flatId'] ?? 'Not Set';
//       final organizationName = userData['organization'] ?? 'Your Apartment';

//       // Step 4: Fetch billing data
//       print('📥 Dashboard: Step 3 - Loading billing data...');
//       final currentBill = await _billService.getCurrentBill();
//       final billAmount = currentBill != null
//           ? (currentBill['amount'] as num?)?.toDouble() ?? 0.0
//           : 0.0;
//       print('✅ Dashboard: Billing data loaded - Amount: ₹$billAmount');

//       // Step 5: Fetch visitors and complaints in parallel
//       print('📥 Dashboard: Step 4 - Loading visitors and complaints...');
//       final results = await Future.wait<dynamic>([
//         _visitorService.getMyVisitors(),
//         _complaintService.getMyComplaints(),
//       ]);

//       final visitors = results[0] as List<Map<String, dynamic>>;
//       final complaints = results[1] as List;

//       // Step 6: Count visitors today
//       final now = DateTime.now();
//       final todayStart = DateTime(now.year, now.month, now.day);
//       final todayEnd = todayStart.add(const Duration(days: 1));

//       final visitorsToday = visitors.where((visitor) {
//         final expectedArrival = visitor['expectedArrival'];
//         DateTime? visitDate;

//         if (expectedArrival is Timestamp) {
//           visitDate = expectedArrival.toDate();
//         } else if (expectedArrival is DateTime) {
//           visitDate = expectedArrival;
//         }

//         if (visitDate == null) return false;
//         return visitDate.isAfter(todayStart) && visitDate.isBefore(todayEnd);
//       }).length;

//       // Step 7: Count open complaints (pending or in-progress)
//       final openComplaints = complaints.where((complaint) {
//         // Handle both Complaint objects and Map
//         if (complaint is Map) {
//           final status = complaint['status'] as String?;
//           return status == 'pending' ||
//               status == 'in-progress' ||
//               status == 'inProgress';
//         } else {
//           // Complaint object - access status property
//           final status = (complaint as dynamic).status?.toString() ?? '';
//           return status == 'pending' ||
//               status == 'in-progress' ||
//               status == 'inProgress';
//         }
//       }).length;

//       print('✅ Dashboard: Summary data calculated');
//       print('   Pending Bill: ₹$billAmount');
//       print('   Visitors Today: $visitorsToday');
//       print('   Open Complaints: $openComplaints');

//       if (mounted) {
//         setState(() {
//           _userName = userName;
//           _userFlat = userFlat;
//           _organizationName = organizationName;
//           _pendingBillAmount = billAmount;
//           _visitorTodayCount = visitorsToday;
//           _openComplaintCount = openComplaints;
//           _isLoading = false;
//         });

//         print('✅ Dashboard: UI updated with real data from users collection');
//       }
//     } catch (e, stackTrace) {
//       print('❌ Dashboard: Error loading data: $e');
//       print('❌ Dashboard: Stack trace: $stackTrace');
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _loadApartmentImages() async {
//     try {
//       print('🔵 Dashboard: Loading apartment images...');

//       final result = await _apartmentImagesService.getApartmentImages();

//       if (!result.success) {
//         print('❌ Dashboard: Failed to load images: ${result.message}');
//         if (mounted) {
//           setState(() {
//             _bannerImages = [];
//           });
//         }
//         return;
//       }

//       final images = result.imageUrls ?? [];
//       print('✅ Dashboard: Service returned ${images.length} images');

//       if (images.isEmpty) {
//         print('⚠️ Dashboard: No apartment images found - showing empty state');
//         if (mounted) {
//           setState(() {
//             _bannerImages = [];
//           });
//         }
//         return;
//       }

//       if (mounted) {
//         setState(() {
//           _bannerImages = images;
//         });
//         print('✅ Dashboard: Apartment images loaded and UI updated');
//         print('   Images: $_bannerImages');
//       }
//     } catch (e, stackTrace) {
//       print('❌ Dashboard: Error loading apartment images: $e');
//       print('❌ Dashboard: Stack trace: $stackTrace');
//       if (mounted) {
//         setState(() {
//           _bannerImages = [];
//         });
//       }
//     }
//   }

//   void _autoScroll() {
//     if (!mounted) return;

//     // Do not auto-scroll if there are fewer than 2 banner images.
//     if (_bannerImages.length < 2) {
//       Future.delayed(const Duration(seconds: 5), _autoScroll);
//       return;
//     }

//     final nextPage = (_currentPage + 1) % _bannerImages.length;

//     if (_pageController.hasClients) {
//       _pageController.animateToPage(
//         nextPage,
//         duration: const Duration(milliseconds: 400),
//         curve: Curves.easeInOut,
//       );
//     }

//     Future.delayed(const Duration(seconds: 5), _autoScroll);
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: const SystemUiOverlayStyle(
//         statusBarColor: Colors.black, // Black status bar background
//         statusBarIconBrightness: Brightness.light, // White icons on black
//         statusBarBrightness: Brightness.dark, // For iOS (dark status bar)
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.black, // Black background extends to status bar
//         body: Column(
//           children: [
//             // Status bar spacer (black background)
//             Container(
//               color: Colors.black,
//               height: MediaQuery.of(context).padding.top,
//             ),

//             // Main content
//             Expanded(
//               child: Container(
//                 color: const Color(0xFFF8F9FA),
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Blue header section with gradient
//                       _buildHeader(),

//                       // Apartment image banner
//                       _buildImageBanner(),

//                       // Summary cards (Pending Bill, Visitor Today, Open Complaint)
//                       _buildSummaryCards(),

//                       // Quick Access section
//                       _buildQuickAccessSection(),

//                       // Recent Activity section
//                       _buildRecentActivitySection(),

//                       // Emergency SOS button
//                       _buildEmergencyButton(),

//                       SizedBox(height: 100.h), // Extra padding for bottom nav
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Blue gradient header with greeting and apartment info
//   Widget _buildHeader() {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(24.r),
//           bottomRight: Radius.circular(24.r),
//         ),
//       ),
//       child: Padding(
//         padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top bar with time and notification
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   '9:41',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 15.sp,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => const NotificationsScreen(),
//                       ),
//                     );
//                   },
//                   child: Container(
//                     padding: EdgeInsets.all(8.w),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(8.r),
//                     ),
//                     child: Icon(
//                       Icons.notifications_outlined,
//                       color: Colors.white,
//                       size: 20.w,
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 16.h),

//             // Good Morning text
//             Text(
//               'good_morning'.tr(),
//               style: TextStyle(
//                 color: Colors.white.withOpacity(0.9),
//                 fontSize: 13.sp,
//                 fontWeight: FontWeight.w400,
//               ),
//             ),

//             SizedBox(height: 4.h),

//             // Hi, [User Name]! with wave emoji
//             Row(
//               children: [
//                 Text(
//                   'Hi, $_userName! ',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24.sp,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 Text('👋', style: TextStyle(fontSize: 24.sp)),
//               ],
//             ),

//             SizedBox(height: 16.h),

//             // Apartment info card
//             Container(
//               padding: EdgeInsets.all(16.w),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(12.r),
//                 border: Border.all(
//                   color: Colors.white.withOpacity(0.2),
//                   width: 1,
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     _organizationName, // Dynamic organization name
//                     style: TextStyle(
//                       color: Colors.white.withOpacity(0.8),
//                       fontSize: 12.sp,
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                   SizedBox(height: 4.h),
//                   Text(
//                     _userFlat,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Auto-scrolling banner carousel
//   Widget _buildImageBanner() {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
//       child: Column(
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(16.r),
//             child: Container(
//               height: 140.h,
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.08),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: _bannerImages.isEmpty
//                   ? Container(
//                       color: Colors.grey[300],
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.image_not_supported,
//                             size: 60.w,
//                             color: Colors.grey[600],
//                           ),
//                           SizedBox(height: 8.h),
//                           Text(
//                             'no_images_available'.tr(),
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 14.sp,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                   : PageView.builder(
//                       controller: _pageController,
//                       onPageChanged: (index) {
//                         if (mounted) {
//                           setState(() {
//                             _currentPage = index;
//                           });
//                         }
//                       },
//                       itemCount: _bannerImages.length,
//                       itemBuilder: (context, index) {
//                         print(
//                           '🖼️ Loading image $index: ${_bannerImages[index]}',
//                         );
//                         return Image.network(
//                           _bannerImages[index],
//                           fit: BoxFit.cover,
//                           loadingBuilder: (context, child, loadingProgress) {
//                             if (loadingProgress == null) return child;
//                             return Container(
//                               color: Colors.grey[300],
//                               child: Center(
//                                 child: CircularProgressIndicator(
//                                   value:
//                                       loadingProgress.expectedTotalBytes != null
//                                       ? loadingProgress.cumulativeBytesLoaded /
//                                             loadingProgress.expectedTotalBytes!
//                                       : null,
//                                 ),
//                               ),
//                             );
//                           },
//                           errorBuilder: (context, error, stackTrace) {
//                             print('❌ Error loading image $index: $error');
//                             return Container(
//                               color: Colors.grey[300],
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.broken_image,
//                                     size: 60.w,
//                                     color: Colors.grey[600],
//                                   ),
//                                   SizedBox(height: 8.h),
//                                   Text(
//                                     'failed_to_load_image'.tr(),
//                                     style: TextStyle(
//                                       color: Colors.grey[600],
//                                       fontSize: 12.sp,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         );
//                       },
//                     ),
//             ),
//           ),
//           SizedBox(height: 12.h),
//           // Page indicators
//           if (_bannerImages.isNotEmpty)
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: List.generate(
//                 _bannerImages.length,
//                 (index) => AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   margin: EdgeInsets.symmetric(horizontal: 4.w),
//                   width: _currentPage == index ? 24 : 8,
//                   height: 8,
//                   decoration: BoxDecoration(
//                     color: _currentPage == index
//                         ? const Color(0xFF0E4778)
//                         : const Color(0xFFD1D5DB),
//                     borderRadius: BorderRadius.circular(4.r),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   /// Three summary cards: Pending Bill, Visitor Today, Open Complaint
//   Widget _buildSummaryCards() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 16.w),
//       child: Row(
//         children: [
//           Expanded(
//             child: _buildSummaryCard(
//               icon: Icons.receipt_long,
//               iconColor: const Color(0xFF10B981),
//               backgroundColor: const Color(0xFFE8FDEB),
//               value: _pendingBillAmount > 0
//                   ? '₹${_pendingBillAmount.toStringAsFixed(0)}'
//                   : '₹0',
//               label: 'billing'.tr(),
//             ),
//           ),
//           SizedBox(width: 12.w),
//           Expanded(
//             child: _buildSummaryCard(
//               icon: Icons.people_outline,
//               iconColor: const Color(0xFF8B5CF6),
//               backgroundColor: const Color(0xFFEDE9FF),
//               value: '$_visitorTodayCount',
//               label: 'visitors'.tr(),
//             ),
//           ),
//           SizedBox(width: 12.w),
//           Expanded(
//             child: _buildSummaryCard(
//               icon: Icons.build_outlined,
//               iconColor: const Color(0xFF3B82F6),
//               backgroundColor: const Color(0xFFEAF1FF),
//               value: '$_openComplaintCount',
//               label: 'complaints'.tr(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Individual summary card widget
//   Widget _buildSummaryCard({
//     required IconData icon,
//     required Color iconColor,
//     required Color backgroundColor,
//     required String value,
//     required String label,
//   }) {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Container(
//             padding: EdgeInsets.all(12.w),
//             decoration: BoxDecoration(
//               color: backgroundColor,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: iconColor, size: 24.w),
//           ),
//           SizedBox(height: 12.h),
//           Text(
//             value,
//             style: TextStyle(
//               color: iconColor,
//               fontSize: 18.sp,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           SizedBox(height: 4.h),
//           Text(
//             label,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Color(0xFF64748B),
//               fontSize: 12.sp,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Quick Access section with 8 icon buttons
//   Widget _buildQuickAccessSection() {
//     return Builder(
//       builder: (context) {
//         return Padding(
//           padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'quick_access'.tr(),
//                 style: TextStyle(
//                   color: Color(0xFF1E293B),
//                   fontSize: 18.sp,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               SizedBox(height: 16.h),

//               // First row of quick access icons
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.people_outline,
//                     label: 'visitors'.tr(),
//                     iconColor: const Color(0xFF3B82F6),
//                     backgroundColor: const Color(0xFFEAF1FF),
//                   ),
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.receipt_long_outlined,
//                     label: 'billing'.tr(),
//                     iconColor: const Color(0xFF10B981),
//                     backgroundColor: const Color(0xFFE8FDEB),
//                   ),
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.calendar_today_outlined,
//                     label: 'events'.tr(),
//                     iconColor: const Color(0xFF8B5CF6),
//                     backgroundColor: const Color(0xFFEDE9FF),
//                   ),
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.build_outlined,
//                     label: 'complaints'.tr(),
//                     iconColor: const Color(0xFFF97316),
//                     backgroundColor: const Color(0xFFFFF3E8),
//                   ),
//                 ],
//               ),

//               SizedBox(height: 16.h),

//               // Second row of quick access icons
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.chat_bubble_outline,
//                     label: 'messages'.tr(),
//                     iconColor: const Color(0xFFF97316),
//                     backgroundColor: const Color(0xFFFFF3E8),
//                   ),
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.groups_outlined,
//                     label: 'community_wall'.tr(),
//                     iconColor: const Color(0xFF8B5CF6),
//                     backgroundColor: const Color(0xFFEDE9FF),
//                   ),
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.fitness_center_outlined,
//                     label: 'amenities'.tr(),
//                     iconColor: const Color(0xFF10B981),
//                     backgroundColor: const Color(0xFFE8FDEB),
//                   ),
//                   _buildQuickAccessItem(
//                     context,
//                     icon: Icons.shopping_bag_outlined,
//                     label: 'marketplace'.tr(),
//                     iconColor: const Color(0xFF3B82F6),
//                     backgroundColor: const Color(0xFFEAF1FF),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const MarketplaceScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   /// Individual quick access icon button
//   Widget _buildQuickAccessItem(
//     BuildContext context, {
//     required IconData icon,
//     required String label,
//     required Color iconColor,
//     required Color backgroundColor,
//     VoidCallback? onTap,
//   }) {
//     return InkWell(
//       onTap:
//           onTap ??
//           () {
//             print('🔵 Dashboard: Quick access tapped - Label: $label');

//             try {
//               // Get translated labels for comparison
//               final visitorsLabel = 'visitors'.tr();
//               final billingLabel = 'billing'.tr();
//               final eventsLabel = 'events'.tr();
//               final communityLabel = 'community_wall'.tr();
//               final complaintsLabel = 'complaints'.tr();
//               final messagesLabel = 'messages'.tr();
//               final amenitiesLabel = 'amenities'.tr();

//               // Switch to tab for main screens (Visitors, Bills, Events)
//               if (label == visitorsLabel || label == 'Visitors') {
//                 print('✅ Dashboard: Navigating to Visitors tab');
//                 widget.onTabChange?.call(1); // Switch to Visitors tab
//               } else if (label == billingLabel || label == 'Billing') {
//                 print('✅ Dashboard: Navigating to Billing tab');
//                 widget.onTabChange?.call(2); // Switch to Bills tab
//               } else if (label == eventsLabel || label == 'Events') {
//                 print('✅ Dashboard: Navigating to Events tab');
//                 widget.onTabChange?.call(3); // Switch to Events tab
//               }
//               // Navigate to sub-screens (Community, Complaints, Messages, Amenities)
//               else if (label == communityLabel ||
//                   label == 'Community Wall' ||
//                   label == 'Community') {
//                 print('✅ Dashboard: Navigating to Community Wall screen');
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const CommunityWallScreen(),
//                   ),
//                 );
//               } else if (label == complaintsLabel || label == 'Complaints') {
//                 print('✅ Dashboard: Navigating to Complaints screen');
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const ComplaintsScreen(),
//                   ),
//                 );
//               } else if (label == messagesLabel || label == 'Messages') {
//                 print('✅ Dashboard: Navigating to Messages screen');
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const MessagesScreenEnhanced(),
//                   ),
//                 );
//               } else if (label == amenitiesLabel || label == 'Amenities') {
//                 print('✅ Dashboard: Navigating to Amenities screen');
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const AmenitiesBookingScreen(),
//                   ),
//                 );
//               } else {
//                 print('⚠️ Dashboard: Unknown quick access label: $label');
//               }
//             } catch (e) {
//               print('❌ Dashboard: Error in quick access navigation: $e');
//             }
//           },
//       borderRadius: BorderRadius.circular(16.r),
//       child: SizedBox(
//         width: 80.w,
//         child: Column(
//           children: [
//             Container(
//               width: 56.w,
//               height: 56.h,
//               decoration: BoxDecoration(
//                 color: backgroundColor,
//                 borderRadius: BorderRadius.circular(16.r),
//               ),
//               child: Icon(icon, color: iconColor, size: 28.w),
//             ),
//             SizedBox(height: 8.h),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Color(0xFF64748B),
//                 fontSize: 12.sp,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Recent Activity section with real data from Firestore
//   Widget _buildRecentActivitySection() {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
//       child: Column(
//         children: [
//           // Section header with "View All" button
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'recent_activity'.tr(),
//                 style: TextStyle(
//                   color: Color(0xFF1E293B),
//                   fontSize: 18.sp,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               TextButton(
//                 onPressed: () {},
//                 style: TextButton.styleFrom(
//                   padding: EdgeInsets.zero,
//                   minimumSize: const Size(0, 0),
//                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                 ),
//                 child: Text(
//                   'view_details'.tr(),
//                   style: TextStyle(
//                     color: Color(0xFF0E4778),
//                     fontSize: 14.sp,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           SizedBox(height: 16.h),

//           // Fetch real activities from Firestore
//           FutureBuilder(
//             future: _fetchRecentActivities(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Padding(
//                   padding: EdgeInsets.all(16.0.w),
//                   child: CircularProgressIndicator(),
//                 );
//               }

//               if (snapshot.hasError) {
//                 print('❌ Error fetching activities: ${snapshot.error}');
//                 return Padding(
//                   padding: EdgeInsets.all(16.0.w),
//                   child: Text('Error loading activities: ${snapshot.error}'),
//                 );
//               }

//               final activities = snapshot.data ?? [];

//               if (activities.isEmpty) {
//                 return Padding(
//                   padding: EdgeInsets.all(16.0.w),
//                   child: Text('No recent activities'),
//                 );
//               }

//               return Column(
//                 children: List.generate(activities.length, (index) {
//                   final activity = activities[index];
//                   return Column(
//                     children: [
//                       _buildActivityItemFromData(activity),
//                       if (index < activities.length - 1) SizedBox(height: 12.h),
//                     ],
//                   );
//                 }),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   /// Fetch recent activities from Firestore
//   Future<List<dynamic>> _fetchRecentActivities() async {
//     print('🔵 Fetching recent activities from Firestore...');
//     try {
//       final result = await RecentActivityFlowFunction.instance
//           .fetchRecentActivities(limit: 5);

//       if (result.success) {
//         print('✅ Fetched ${result.activities.length} activities');
//         return result.activities;
//       } else {
//         print('❌ Error: ${result.message}');
//         return [];
//       }
//     } catch (e) {
//       print('❌ Error fetching activities: $e');
//       return [];
//     }
//   }

//   /// Build activity item from real data
//   Widget _buildActivityItemFromData(dynamic activity) {
//     // Get icon and colors based on activity type
//     IconData icon;
//     Color iconColor;
//     Color iconBackground;

//     if (activity.activityType == 'booking') {
//       icon = Icons.calendar_today;
//       iconColor = const Color(0xFF8B5CF6);
//       iconBackground = const Color(0xFFEDE9FF);
//     } else if (activity.activityType == 'visitor') {
//       icon = Icons.shield_outlined;
//       iconColor = const Color(0xFFF97316);
//       iconBackground = const Color(0xFFFFF3E8);
//     } else if (activity.activityType == 'complaint') {
//       icon = Icons.warning_outlined;
//       iconColor = const Color(0xFFEF4444);
//       iconBackground = const Color(0xFFFEE2E2);
//     } else {
//       icon = Icons.info_outlined;
//       iconColor = const Color(0xFF3B82F6);
//       iconBackground = const Color(0xFFEAF1FF);
//     }

//     // Get status color
//     Color statusColor;
//     Color statusBackground;

//     final status = activity.statusText.toLowerCase();
//     if (status.contains('confirmed') ||
//         status.contains('approved') ||
//         status.contains('received')) {
//       statusColor = const Color(0xFF10B981);
//       statusBackground = const Color(0xFFD1FAE5);
//     } else if (status.contains('pending')) {
//       statusColor = const Color(0xFFF59E0B);
//       statusBackground = const Color(0xFFFEF3C7);
//     } else if (status.contains('rejected') || status.contains('cancelled')) {
//       statusColor = const Color(0xFFEF4444);
//       statusBackground = const Color(0xFFFEE2E2);
//     } else {
//       statusColor = const Color(0xFF3B82F6);
//       statusBackground = const Color(0xFFDBEAFE);
//     }

//     return _buildActivityItem(
//       icon: icon,
//       iconColor: iconColor,
//       iconBackground: iconBackground,
//       title: activity.title,
//       subtitle: activity.subtitle,
//       statusText: activity.statusText,
//       statusColor: statusColor,
//       statusBackground: statusBackground,
//     );
//   }

//   /// Individual activity item widget
//   Widget _buildActivityItem({
//     required IconData icon,
//     required Color iconColor,
//     required Color iconBackground,
//     required String title,
//     required String subtitle,
//     required String statusText,
//     required Color statusColor,
//     required Color statusBackground,
//   }) {
//     return Container(
//       padding: EdgeInsets.all(16.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Icon container
//           Container(
//             padding: EdgeInsets.all(12.w),
//             decoration: BoxDecoration(
//               color: iconBackground,
//               borderRadius: BorderRadius.circular(12.r),
//             ),
//             child: Icon(icon, color: iconColor, size: 24.w),
//           ),

//           SizedBox(width: 12.w),

//           // Title and subtitle
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(
//                     color: Color(0xFF1E293B),
//                     fontSize: 15.sp,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 SizedBox(height: 4.h),
//                 Text(
//                   subtitle,
//                   style: TextStyle(
//                     color: Color(0xFF94A3B8),
//                     fontSize: 13.sp,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Status badge
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
//             decoration: BoxDecoration(
//               color: statusBackground,
//               borderRadius: BorderRadius.circular(8.r),
//             ),
//             child: Text(
//               statusText,
//               style: TextStyle(
//                 color: statusColor,
//                 fontSize: 12.sp,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Emergency SOS button
//   Widget _buildEmergencyButton() {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
//       child: Container(
//         width: double.infinity,
//         height: 56.h,
//         decoration: BoxDecoration(
//           color: const Color(0xFFEF4444),
//           borderRadius: BorderRadius.circular(16.r),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFFEF4444).withOpacity(0.3),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Material(
//           color: Colors.transparent,
//           child: InkWell(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const EmergencySosScreen(),
//                 ),
//               );
//             },
//             borderRadius: BorderRadius.circular(16.r),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.warning_amber_rounded,
//                   color: Colors.white,
//                   size: 24.w,
//                 ),
//                 SizedBox(width: 8.w),
//                 Text(
//                   'Emergency SOS',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 16.sp,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'community_wall_screen.dart';
import 'complaints_screen.dart';
import 'src/screens/amenities_booking_screen.dart';
import 'src/screens/emergency_sos_screen.dart';
import 'src/screens/marketplace_screen.dart';
import 'src/screens/messages_screen.dart';
import 'src/screens/notifications_screen.dart';
import 'src/services/apartment_images_service.dart';
import 'src/services/bill_firestore_service.dart';
import 'src/services/complaint_firestore_service.dart';
import 'src/services/recent_activity_flow_function.dart';
import 'src/services/tenant_resolution_service.dart';
import 'src/services/visitor_firestore_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const DashboardScreen({super.key, this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _navy = Color(0xFF082F73);
  static const Color _blue = Color(0xFF1558D6);
  static const Color _cyan = Color(0xFF2B95C8);
  static const Color _ink = Color(0xFF0E2247);
  static const Color _muted = Color(0xFF667792);
  static const Color _pageBg = Color(0xFFF7F9FD);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  late Future<List<dynamic>> _recentActivityFuture;

  final _billService = BillFirestoreService();
  final _visitorService = VisitorFirestoreService();
  final _complaintService = ComplaintFirestoreService();
  final _apartmentImagesService = ApartmentImagesService();

  String _userName = 'User';
  String _userFlat = 'Not Set';
  String _organizationName = 'Your Apartment';
  bool _isLoading = true;

  double _pendingBillAmount = 0;
  int _visitorTodayCount = 0;
  int _openComplaintCount = 0;
  List<String> _bannerImages = [];

  @override
  void initState() {
    super.initState();
    _recentActivityFuture = _fetchRecentActivities();
    _loadDashboardData();
    _loadApartmentImages();
    Future.delayed(const Duration(seconds: 5), _autoScroll);
  }

  Future<void> _loadDashboardData() async {
    if (mounted) setState(() => _isLoading = true);
    final tenantName = context.read<TenantResolutionService>().current?.name;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? 'User';
      final userFlat = userData['flatLabel'] ?? userData['flatId'] ?? 'Not Set';
      final userOrganization = (userData['organization'] as String?)?.trim();
      var organizationName = tenantName?.isNotEmpty == true
          ? tenantName!
          : userOrganization?.isNotEmpty == true
          ? userOrganization!
          : 'Your Apartment';

      final communityId = (userData['communityId'] as String?)?.trim();
      if (communityId?.isNotEmpty == true) {
        try {
          final communityDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .get();
          final communityName = (communityDoc.data()?['name'] as String?)
              ?.trim();
          if (communityDoc.exists && communityName?.isNotEmpty == true) {
            organizationName = communityName!;
          }
        } catch (error) {
          debugPrint(
            'Dashboard community lookup failed for $communityId: $error',
          );
        }
      }

      final currentBill = await _billService.getCurrentBill();
      final billAmount = currentBill != null
          ? (currentBill['amount'] as num?)?.toDouble() ?? 0.0
          : 0.0;

      final results = await Future.wait<dynamic>([
        _visitorService.getMyVisitors(),
        _complaintService.getMyComplaints(),
      ]);

      final visitors = results[0] as List<Map<String, dynamic>>;
      final complaints = results[1] as List;

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

      final openComplaints = complaints.where((complaint) {
        if (complaint is Map) {
          final status = complaint['status'] as String?;
          return status == 'pending' ||
              status == 'in-progress' ||
              status == 'inProgress';
        }
        final status = (complaint as dynamic).status?.toString() ?? '';
        return status == 'pending' ||
            status == 'in-progress' ||
            status == 'inProgress';
      }).length;

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
      }
    } catch (e, stackTrace) {
      debugPrint('Dashboard load error: $e');
      debugPrint('$stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApartmentImages() async {
    try {
      final result = await _apartmentImagesService.getApartmentImages();
      if (!result.success) {
        if (mounted) setState(() => _bannerImages = []);
        return;
      }
      if (mounted) {
        setState(() => _bannerImages = result.imageUrls ?? []);
      }
    } catch (e) {
      debugPrint('Apartment image load error: $e');
      if (mounted) setState(() => _bannerImages = []);
    }
  }

  void _autoScroll() {
    if (!mounted) return;
    if (_bannerImages.length < 2) {
      Future.delayed(const Duration(seconds: 5), _autoScroll);
      return;
    }

    final nextPage = (_currentPage + 1) % _bannerImages.length;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    }
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
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadDashboardData(), _loadApartmentImages()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroAndBanner(),
                SizedBox(height: 12.h),
                _buildSummaryCards(),
                SizedBox(height: 20.h),
                _buildQuickAccessSection(),
                SizedBox(height: 18.h),
                _buildRecentActivitySection(),
                SizedBox(height: 18.h),
                _buildEmergencyButton(),
                SizedBox(height: 110.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroAndBanner() {
  final topInset = MediaQuery.of(context).padding.top;

  // Keep header + banner to roughly 45-48% of an iPhone-height screen.
  // The Stack itself reserves the banner's full height, so following widgets
  // can never overlap it.
  final heroHeight = 230.h + topInset;
  final bannerHeight = 150.h;
  final bannerTop = heroHeight - 24.h;
  final indicatorSpace = 22.h;
  final totalHeight = bannerTop + bannerHeight + indicatorSpace;

  return SizedBox(
    height: totalHeight,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: heroHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B376C),
                Color(0xFF103F78),
                Color(0xFF2CA4C7),
              ],
              stops: [0.05, 0.60, 1.0],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.r),
              bottomRight: Radius.circular(30.r),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -45.w,
                top: topInset + 8.h,
                child: Container(
                  width: 220.w,
                  height: 125.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20.w,
                  topInset + 10.h,
                  20.w,
                  18.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _notificationButton(),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'good_morning'.tr(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Hi, $_userName!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          '👋',
                          style: TextStyle(fontSize: 21.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Welcome back to your community',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12.5.sp,
                      ),
                    ),
                    SizedBox(height: 9.h),
                    _apartmentCard(),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          left: 16.w,
          right: 16.w,
          top: bannerTop,
          child: _bannerCard(height: bannerHeight),
        ),
      ],
    ),
  );
}
  Widget _notificationButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(13.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: _blue,
              size: 23.w,
            ),
          ),
          Positioned(
            right: 7.w,
            top: 7.h,
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B3B),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _apartmentCard() {
    return Container(
      width: 245.w,
      constraints: BoxConstraints(minHeight: 62.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(color: Colors.white.withOpacity(0.40), width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: const Color(0xFF0D4EA8).withOpacity(0.86),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 23.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _organizationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _userFlat,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white, size: 25.w),
        ],
      ),
    );
  }

  Widget _bannerCard({required double height}) {
    return Column(
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E2247).withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.r),
            child: _bannerImages.isEmpty
                ? _bannerEmptyState()
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _bannerImages.length,
                    onPageChanged: (index) {
                      if (mounted) setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        _bannerImages[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color(0xFFEFF3F8),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _bannerEmptyState(
                            title: 'failed_to_load_image'.tr(),
                            icon: Icons.broken_image_outlined,
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
        SizedBox(height: 10.h),
        if (_bannerImages.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _bannerImages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: _currentPage == index ? 8.w : 7.w,
                height: _currentPage == index ? 8.w : 7.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? _blue
                      : const Color(0xFFD6DAE2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bannerEmptyState({
    String? title,
    IconData icon = Icons.apartment_rounded,
  }) {
    return Container(
      color: const Color(0xFFF0F4F9),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF9BA8BA), size: 44.w),
          SizedBox(height: 8.h),
          Text(
            title ?? 'no_images_available'.tr(),
            style: TextStyle(
              color: const Color(0xFF75849A),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF08A760),
              iconBg: const Color(0xFFE2F8EA),
              value: _pendingBillAmount > 0
                  ? '₹${_pendingBillAmount.toStringAsFixed(0)}'
                  : '₹0',
              label: 'billing'.tr(),
              onTap: () => widget.onTabChange?.call(2),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _summaryCard(
              icon: Icons.groups_2_outlined,
              iconColor: const Color(0xFF7848F5),
              iconBg: const Color(0xFFEDE5FF),
              value: '$_visitorTodayCount',
              label: 'visitors'.tr(),
              onTap: () => widget.onTabChange?.call(1),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _summaryCard(
              icon: Icons.support_agent_rounded,
              iconColor: const Color(0xFF1568E9),
              iconBg: const Color(0xFFE7F0FF),
              value: '$_openComplaintCount',
              label: 'complaints'.tr(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 108.h),
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 10.w, 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A3A64).withOpacity(0.075),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24.w),
              ),
              SizedBox(height: 10.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF34445D),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 29.w,
                    height: 29.w,
                    decoration: BoxDecoration(
                      color: iconBg.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: iconColor,
                      size: 21.w,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    final items = <_QuickAccessItemData>[
      _QuickAccessItemData(
        icon: Icons.groups_2_outlined,
        label: 'visitors'.tr(),
        iconColor: const Color(0xFF1568E9),
        backgroundColor: const Color(0xFFE7F0FF),
        onTap: () => widget.onTabChange?.call(1),
      ),
      _QuickAccessItemData(
        icon: Icons.receipt_long_outlined,
        label: 'billing'.tr(),
        iconColor: const Color(0xFF08A760),
        backgroundColor: const Color(0xFFE2F8EA),
        onTap: () => widget.onTabChange?.call(2),
      ),
      _QuickAccessItemData(
        icon: Icons.calendar_month_rounded,
        label: 'events'.tr(),
        iconColor: const Color(0xFF7848F5),
        backgroundColor: const Color(0xFFEDE5FF),
        onTap: () => widget.onTabChange?.call(3),
      ),
      _QuickAccessItemData(
        icon: Icons.support_agent_rounded,
        label: 'complaints'.tr(),
        iconColor: const Color(0xFFF26A21),
        backgroundColor: const Color(0xFFFFEFE4),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
          );
        },
      ),
      _QuickAccessItemData(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'messages'.tr(),
        iconColor: const Color(0xFFF26A21),
        backgroundColor: const Color(0xFFFFEFE4),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessagesScreenEnhanced()),
          );
        },
      ),
      _QuickAccessItemData(
        icon: Icons.groups_rounded,
        label: 'community_wall'.tr(),
        iconColor: const Color(0xFF7848F5),
        backgroundColor: const Color(0xFFEDE5FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunityWallScreen()),
          );
        },
      ),
      _QuickAccessItemData(
        icon: Icons.fitness_center_rounded,
        label: 'amenities'.tr(),
        iconColor: const Color(0xFF08A760),
        backgroundColor: const Color(0xFFE2F8EA),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AmenitiesBookingScreen()),
          );
        },
      ),
      _QuickAccessItemData(
        icon: Icons.shopping_bag_outlined,
        label: 'marketplace'.tr(),
        iconColor: const Color(0xFF1568E9),
        backgroundColor: const Color(0xFFE7F0FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
          );
        },
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'quick_access'.tr(),
                style: TextStyle(
                  color: _ink,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Text(
              //   'View All',
              //   style: TextStyle(
              //     color: _blue,
              //     fontSize: 13.sp,
              //     fontWeight: FontWeight.w700,
              //   ),
              // ),
            ],
          ),
          SizedBox(height: 12.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 0.87,
            ),
            itemBuilder: (context, index) => _quickAccessCard(items[index]),
          ),
        ],
      ),
    );
  }

  Widget _quickAccessCard(_QuickAccessItemData item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 11.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF193A65).withOpacity(0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 45.w,
                height: 45.w,
                decoration: BoxDecoration(
                  color: item.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.iconColor, size: 24.w),
              ),
              SizedBox(height: 8.h),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 11.5.sp,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(15.w, 14.h, 15.w, 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF193A65).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'recent_activity'.tr(),
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // const Spacer(),
                // TextButton(
                //   onPressed: () {},
                //   style: TextButton.styleFrom(
                //     padding: EdgeInsets.zero,
                //     minimumSize: Size(52.w, 30.h),
                //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                //   ),
                //   child: Text(
                //     'View All',
                //     style: TextStyle(
                //       color: _blue,
                //       fontSize: 13.sp,
                //       fontWeight: FontWeight.w700,
                //     ),
                //   ),
                // ),
              ],
            ),
            FutureBuilder<List<dynamic>>(
              future: _recentActivityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final activities = snapshot.data ?? [];
                if (activities.isEmpty) return _emptyRecentActivity();

                return Column(
                  children: List.generate(
                    activities.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 6.h : 10.h),
                      child: _activityItemFromData(activities[index]),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyRecentActivity() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 2.h),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 58.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.assignment_outlined,
              color: const Color(0xFF75A2F4),
              size: 34.w,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No recent activities',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "You're all caught up!",
                  style: TextStyle(color: _muted, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _fetchRecentActivities() async {
    try {
      final result = await RecentActivityFlowFunction.instance
          .fetchRecentActivities(limit: 5);
      return result.success ? result.activities : [];
    } catch (e) {
      debugPrint('Recent activity error: $e');
      return [];
    }
  }

  Widget _activityItemFromData(dynamic activity) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    if (activity.activityType == 'booking') {
      icon = Icons.calendar_today;
      iconColor = const Color(0xFF7848F5);
      iconBg = const Color(0xFFEDE5FF);
    } else if (activity.activityType == 'visitor') {
      icon = Icons.shield_outlined;
      iconColor = const Color(0xFFF26A21);
      iconBg = const Color(0xFFFFEFE4);
    } else if (activity.activityType == 'complaint') {
      icon = Icons.warning_amber_rounded;
      iconColor = const Color(0xFFE54848);
      iconBg = const Color(0xFFFFE8E8);
    } else {
      icon = Icons.info_outline_rounded;
      iconColor = const Color(0xFF1568E9);
      iconBg = const Color(0xFFE7F0FF);
    }

    final status = activity.statusText.toLowerCase();
    late Color statusColor;
    late Color statusBg;

    if (status.contains('confirmed') ||
        status.contains('approved') ||
        status.contains('received')) {
      statusColor = const Color(0xFF08A760);
      statusBg = const Color(0xFFE2F8EA);
    } else if (status.contains('pending')) {
      statusColor = const Color(0xFFE39513);
      statusBg = const Color(0xFFFFF2D6);
    } else if (status.contains('rejected') || status.contains('cancelled')) {
      statusColor = const Color(0xFFE54848);
      statusBg = const Color(0xFFFFE8E8);
    } else {
      statusColor = const Color(0xFF1568E9);
      statusBg = const Color(0xFFE7F0FF);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Icon(icon, color: iconColor, size: 22.w),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                activity.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 11.5.sp,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(9.r),
          ),
          child: Text(
            activity.statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        height: 54.h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3C43), Color(0xFFF01F25)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF52D34).withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmergencySosScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 21.w,
                ),
                SizedBox(width: 9.w),
                Text(
                  'Emergency SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
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

class _QuickAccessItemData {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _QuickAccessItemData({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });
}
