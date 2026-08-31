// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'quick_access_page.dart';
// import 'manage_buildings_page.dart';
// import 'visitor_management_screen.dart';
// import 'complaint_management_screen.dart';
// import 'events_announcements_screen.dart';
// import 'billing_screen.dart';
// import 'admin_residents_page_firestore.dart';
// import 'parking_management_screen.dart';
// import 'notifications_screen.dart';
// import 'amenities_management_screen.dart';
// import 'widgets/standard_bottom_nav.dart';
// import 'widgets/notification_badge.dart';
// import 'services/notification_service.dart';
// import 'services/dashboard_service.dart';
// import 'services/admin_tenant_context.dart';
// import 'security_management_screen.dart';

// class AdminDashboardPage extends StatefulWidget {
//   const AdminDashboardPage({super.key});

//   @override
//   State<AdminDashboardPage> createState() => _AdminDashboardPageState();
// }

// class _AdminDashboardPageState extends State<AdminDashboardPage> {
//   final NotificationService _notificationService = NotificationService();
//   final DashboardService _dashboardService = DashboardService();

//   String _adminName = 'Admin';
//   String _adminRole = 'Administrator';
//   String _buildingName = 'Loading...';
//   bool _isLoadingUserData = true;

//   // Get current admin ID
//   String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? '';
//   String get _communityId => AdminTenantContext.instance.requireCommunityId();

//   @override
//   void initState() {
//     super.initState();
//     _notificationService.initializeNotifications();
//     _notificationService.addListener(_onNotificationUpdate);
//     _loadAdminData();
//   }

//   Future<void> _loadAdminData() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         print('DEBUG Dashboard: No user logged in');
//         return;
//       }

//       print('=== DEBUG: Dashboard Data Fetch ===');
//       print('Auth UID: ${user.uid}');
//       print('Auth Email: ${user.email}');
//       print('Fetching from: admins/${user.uid}');

//       final userDoc = await FirebaseFirestore.instance
//           .collection('admins')
//           .doc(user.uid)
//           .get();

//       print('Document exists: ${userDoc.exists}');

//       if (userDoc.exists && mounted) {
//         final data = userDoc.data()!;
//         print('Fetched data: $data');

//         setState(() {
//           _adminName = data['name'] ?? 'Admin';
//           _adminRole = _formatRole(data['role'] ?? 'admin');
//           _buildingName =
//               data['organization'] ?? 'HOMINODE Property Management';
//           _isLoadingUserData = false;
//         });

//         print('Admin Name: $_adminName');
//         print('Admin Role: $_adminRole');
//         print('Building Name: $_buildingName');
//       } else if (mounted) {
//         print('WARNING: Admin document does not exist');
//         setState(() {
//           _buildingName = 'HOMINODE Property Management';
//           _isLoadingUserData = false;
//         });
//       }
//       print('===================================');
//     } catch (e) {
//       print('ERROR loading admin data: $e');
//       if (mounted) {
//         setState(() {
//           _buildingName = 'HOMINODE Property Management';
//           _isLoadingUserData = false;
//         });
//       }
//     }
//   }

//   String _formatRole(String role) {
//     switch (role.toLowerCase()) {
//       case 'super_admin':
//       case 'superadmin':
//         return 'Super Administrator';
//       case 'admin':
//         return 'Administrator';
//       case 'manager':
//         return 'Manager';
//       case 'staff':
//         return 'Staff Member';
//       default:
//         return 'Administrator';
//     }
//   }

//   @override
//   void dispose() {
//     _notificationService.removeListener(_onNotificationUpdate);
//     super.dispose();
//   }

//   void _onNotificationUpdate() {
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF9FAFB),
//       body: CustomScrollView(
//         physics: const BouncingScrollPhysics(),
//         slivers: [
//           _buildModernHeader(),
//           SliverToBoxAdapter(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: 20.h),
//                 _buildStatisticCards(),
//                 SizedBox(height: 12.h),
//                 _buildAlertCards(),
//                 SizedBox(height: 16.h),
//                 _buildQuickAccess(),
//                 SizedBox(height: 16.h),
//                 _buildRealTimeAlerts(),
//                 SizedBox(height: 80.h),
//               ],
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: const StandardBottomNav(selectedIndex: 0),
//     );
//   }

//   // Modern Flow UI Header
//   Widget _buildModernHeader() {
//     return SliverAppBar(
//       expandedHeight: 180,
//       floating: false,
//       pinned: true,
//       elevation: 0,
//       backgroundColor: Colors.white,
//       flexibleSpace: FlexibleSpaceBar(
//         background: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
//             ),
//           ),
//           child: SafeArea(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   // Top Row - Profile & Notifications
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       // Profile Section
//                       Row(
//                         children: [
//                           Container(
//                             width: 48.w,
//                             height: 48.h,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.2),
//                               borderRadius: BorderRadius.circular(14.r),
//                               border: Border.all(
//                                 color: Colors.white.withOpacity(0.3),
//                                 width: 2,
//                               ),
//                             ),
//                             child: Icon(
//                               Icons.person,
//                               color: Colors.white,
//                               size: 24.w,
//                             ),
//                           ),
//                           SizedBox(width: 12.w),
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Welcome back,',
//                                 style: TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 13.sp,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                               ),
//                               SizedBox(height: 2.h),
//                               Text(
//                                 _adminName,
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 18.sp,
//                                   fontWeight: FontWeight.w700,
//                                   shadows: [
//                                     Shadow(
//                                       color: Colors.black.withOpacity(0.1),
//                                       offset: const Offset(0, 1),
//                                       blurRadius: 2,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                       // Notification Bell
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => const NotificationsScreen(),
//                             ),
//                           );
//                         },
//                         child: NotificationBadge(
//                           showBadge: _notificationService.unreadCount > 0,
//                           count: _notificationService.unreadCount,
//                           top: -2,
//                           right: -2,
//                           child: Container(
//                             width: 44.w,
//                             height: 44.h,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.15),
//                               borderRadius: BorderRadius.circular(12.r),
//                             ),
//                             child: Center(
//                               child: Icon(
//                                 Icons.notifications_outlined,
//                                 color: Colors.white,
//                                 size: 24.w,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),

//                   SizedBox(height: 20.h),

//                   // Society Name & Info
//                   Row(
//                     children: [
//                       Container(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 10.w,
//                           vertical: 6.h,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(8.r),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(
//                               Icons.apartment,
//                               color: Colors.white,
//                               size: 16.w,
//                             ),
//                             SizedBox(width: 6.w),
//                             Text(
//                               _buildingName,
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 12.sp,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       SizedBox(width: 8.w),
//                       Container(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 8.w,
//                           vertical: 6.h,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF10B981).withOpacity(0.9),
//                           borderRadius: BorderRadius.circular(8.r),
//                         ),
//                         child: Row(
//                           children: [
//                             Container(
//                               width: 6.w,
//                               height: 6.h,
//                               decoration: const BoxDecoration(
//                                 color: Colors.white,
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                             SizedBox(width: 6.w),
//                             Text(
//                               'Active',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 12.sp,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),

//                   SizedBox(height: 12.h),

//                   // Date & Time
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.calendar_today,
//                         color: Colors.white70,
//                         size: 14.w,
//                       ),
//                       SizedBox(width: 6.w),
//                       Text(
//                         _getCurrentDate(),
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 13.sp,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       SizedBox(width: 16.w),
//                       Icon(
//                         Icons.access_time,
//                         color: Colors.white70,
//                         size: 14.w,
//                       ),
//                       SizedBox(width: 6.w),
//                       Text(
//                         _getCurrentTime(),
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 13.sp,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   String _getCurrentDate() {
//     final now = DateTime.now();
//     final months = [
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return '${now.day} ${months[now.month - 1]}, ${now.year}';
//   }

//   String _getCurrentTime() {
//     final now = DateTime.now();
//     final hour = now.hour > 12
//         ? now.hour - 12
//         : (now.hour == 0 ? 12 : now.hour);
//     final minute = now.minute.toString().padLeft(2, '0');
//     final period = now.hour >= 12 ? 'PM' : 'AM';
//     return '$hour:$minute $period';
//   }

//   // 3️⃣ Statistic Cards Row with Real-time Data
//   Widget _buildStatisticCards() {
//     return StreamBuilder<DashboardStats>(
//       stream: _dashboardService.getDashboardStats(_communityId),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16.w),
//             child: Row(
//               children: [
//                 Expanded(child: _buildLoadingCard()),
//                 SizedBox(width: 12.w),
//                 Expanded(child: _buildLoadingCard()),
//                 SizedBox(width: 12.w),
//                 Expanded(child: _buildLoadingCard()),
//               ],
//             ),
//           );
//         }

//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }

//         final stats = snapshot.data!;

//         return Padding(
//           padding: EdgeInsets.symmetric(horizontal: 16.w),
//           child: Row(
//             children: [
//               Expanded(
//                 child: _buildStatCard(
//                   icon: Icons.people,
//                   iconColor: const Color(0xFF0E4778),
//                   iconBg: const Color(0xFFE0EDFF),
//                   value: '${stats.totalResidents}',
//                   label: 'Total Residents',
//                   subtitle: 'Active users',
//                   subtitleColor: const Color(0xFF0E4778),
//                 ),
//               ),
//               SizedBox(width: 12.w),
//               Expanded(
//                 child: _buildStatCard(
//                   icon: Icons.apartment,
//                   iconColor: const Color(0xFF10B981),
//                   iconBg: const Color(0xFFD1FAE5),
//                   value: '${stats.totalFlats}',
//                   label: 'Total Flats',
//                   subtitle: 'All units',
//                   subtitleColor: const Color(0xFF10B981),
//                 ),
//               ),
//               SizedBox(width: 12.w),
//               Expanded(
//                 child: _buildStatCard(
//                   icon: Icons.person_outline,
//                   iconColor: const Color(0xFF8B5CF6),
//                   iconBg: const Color(0xFFEDE9FE),
//                   value: '${stats.pendingVisitors}',
//                   label: 'Pending Visitors',
//                   subtitle: 'Awaiting approval',
//                   subtitleColor: const Color(0xFF8B5CF6),
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const VisitorManagementScreen(),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLoadingCard() {
//     return Container(
//       padding: EdgeInsets.all(10.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: 40.w,
//             height: 40.h,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               shape: BoxShape.circle,
//             ),
//           ),
//           SizedBox(height: 6.h),
//           Container(
//             width: 40.w,
//             height: 18.h,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(4.r),
//             ),
//           ),
//           SizedBox(height: 4.h),
//           Container(
//             width: 60.w,
//             height: 11.h,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(4.r),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatCard({
//     required IconData icon,
//     required Color iconColor,
//     required Color iconBg,
//     required String value,
//     required String label,
//     required String subtitle,
//     required Color subtitleColor,
//     VoidCallback? onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap ?? () {},
//       child: Container(
//         padding: EdgeInsets.all(10.w),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12.r),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.06),
//               blurRadius: 10,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 40.w,
//               height: 40.h,
//               decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
//               child: Icon(icon, color: iconColor, size: 20.w),
//             ),
//             SizedBox(height: 6.h),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 18.sp,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF111111),
//               ),
//             ),
//             SizedBox(height: 2.h),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 11.sp,
//                 fontWeight: FontWeight.w400,
//                 color: Color(0xFF6A6A6A),
//               ),
//             ),
//             SizedBox(height: 3.h),
//             Text(
//               subtitle,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 10.sp,
//                 fontWeight: FontWeight.w500,
//                 color: subtitleColor,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // 4️⃣ Alert Highlight Cards Row with Real-time Data
//   Widget _buildAlertCards() {
//     return StreamBuilder<DashboardStats>(
//       stream: _dashboardService.getDashboardStats(_communityId),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16.w),
//             child: Row(
//               children: [
//                 Expanded(child: _buildLoadingAlertCard()),
//                 SizedBox(width: 12.w),
//                 Expanded(child: _buildLoadingAlertCard()),
//               ],
//             ),
//           );
//         }

//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }

//         final stats = snapshot.data!;

//         return Padding(
//           padding: EdgeInsets.symmetric(horizontal: 16.w),
//           child: Row(
//             children: [
//               Expanded(
//                 child: GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const ComplaintManagementScreen(),
//                       ),
//                     );
//                   },
//                   child: _buildAlertCard(
//                     icon: Icons.warning_rounded,
//                     iconColor: const Color(0xFFFF4747),
//                     iconBg: const Color(0xFFFFE5E5),
//                     value: '${stats.pendingComplaints}',
//                     label: 'Pending Complaints',
//                     subtitle: 'Needs attention',
//                   ),
//                 ),
//               ),
//               SizedBox(width: 12.w),
//               Expanded(
//                 child: GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const BillingScreen(),
//                       ),
//                     );
//                   },
//                   child: _buildAlertCard(
//                     icon: Icons.account_balance_wallet,
//                     iconColor: const Color(0xFF10B981),
//                     iconBg: const Color(0xFFD1FAE5),
//                     value: stats.formattedCollection,
//                     label: 'This Month Collection',
//                     subtitle: 'Paid bills',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLoadingAlertCard() {
//     return Container(
//       padding: EdgeInsets.all(14.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 50.w,
//             height: 50.h,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               shape: BoxShape.circle,
//             ),
//           ),
//           SizedBox(width: 14.w),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   width: 40.w,
//                   height: 22.h,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(4.r),
//                   ),
//                 ),
//                 SizedBox(height: 6.h),
//                 Container(
//                   width: 80.w,
//                   height: 13.h,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(4.r),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAlertCard({
//     required IconData icon,
//     required Color iconColor,
//     required Color iconBg,
//     required String value,
//     required String label,
//     required String subtitle,
//   }) {
//     return Container(
//       padding: EdgeInsets.all(14.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 50.w,
//             height: 50.h,
//             decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
//             child: Icon(icon, color: iconColor, size: 26.w),
//           ),
//           SizedBox(width: 14.w),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 22.sp,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF111111),
//                   ),
//                 ),
//                 SizedBox(height: 4.h),
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontSize: 13.sp,
//                     fontWeight: FontWeight.w500,
//                     color: Color(0xFF6A6A6A),
//                   ),
//                 ),
//                 SizedBox(height: 2.h),
//                 Text(
//                   subtitle,
//                   style: TextStyle(
//                     fontSize: 11.sp,
//                     fontWeight: FontWeight.w400,
//                     color: iconColor,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // 5️⃣ Quick Access Section
//   Widget _buildQuickAccess() {
//     return Column(
//       children: [
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 16.w),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Quick Actions',
//                 style: TextStyle(
//                   fontSize: 16.sp,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF111111),
//                 ),
//               ),
//               GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const QuickAccessPage(),
//                     ),
//                   );
//                 },
//                 child: Text(
//                   'View All',
//                   style: TextStyle(
//                     fontSize: 14.sp,
//                     fontWeight: FontWeight.w500,
//                     color: Color(0xFF0E4778),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 12.h),
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 16.w),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _buildQuickAccessButton(
//                 icon: Icons.apartment,
//                 label: 'Add Building',
//                 color: const Color(0xFF0E4778),
//                 bgColor: const Color(0xFFE0EDFF),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const ManageBuildingsPage(),
//                     ),
//                   );
//                 },
//               ),
//               _buildQuickAccessButton(
//                 icon: Icons.receipt_long,
//                 label: 'Add Bill',
//                 color: const Color(0xFF10B981),
//                 bgColor: const Color(0xFFD1FAE5),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const BillingScreen(),
//                     ),
//                   );
//                 },
//               ),
//               _buildQuickAccessButton(
//                 icon: Icons.how_to_reg,
//                 label: 'Approve Visitor',
//                 color: const Color(0xFFF4A100),
//                 bgColor: const Color(0xFFFFF4E5),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const VisitorManagementScreen(),
//                     ),
//                   );
//                 },
//               ),
//               _buildQuickAccessButton(
//                 icon: Icons.security,
//                 label: 'Security',
//                 color: const Color(0xFF8B5CF6),
//                 bgColor: const Color(0xFFEDE9FE),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const SecurityManagementScreen(),
//                     ),
//                   );
//                 },
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 16.h),
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 16.w),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _buildQuickAccessButton(
//                 icon: Icons.people,
//                 label: 'Residents',
//                 color: const Color(0xFF059669),
//                 bgColor: const Color(0xFFECFDF5),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const AdminResidentsPageFirestore(),
//                     ),
//                   );
//                 },
//               ),
//               _buildQuickAccessButton(
//                 icon: Icons.event,
//                 label: 'Events',
//                 color: const Color(0xFF8B5CF6),
//                 bgColor: const Color(0xFFEDE9FE),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const EventsAnnouncementsScreen(),
//                     ),
//                   );
//                 },
//               ),
//               _buildQuickAccessButton(
//                 icon: Icons.local_parking,
//                 label: 'Parking',
//                 color: const Color(0xFF6366F1),
//                 bgColor: const Color(0xFFEEF2FF),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) =>
//                           const ParkingManagementScreenEnhanced(),
//                     ),
//                   );
//                 },
//               ),
//               _buildQuickAccessButton(
//                 icon: Icons.apartment,
//                 label: 'Amenities',
//                 color: const Color(0xFF8B5CF6),
//                 bgColor: const Color(0xFFF3E8FF),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const AmenitiesManagementScreen(),
//                     ),
//                   );
//                 },
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildQuickAccessButton({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required Color bgColor,
//     VoidCallback? onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap ?? () {},
//       child: Column(
//         children: [
//           Container(
//             width: 60.w,
//             height: 60.h,
//             decoration: BoxDecoration(
//               color: bgColor,
//               borderRadius: BorderRadius.circular(14.r),
//             ),
//             child: Icon(icon, color: color, size: 28.w),
//           ),
//           SizedBox(height: 6.h),
//           SizedBox(
//             width: 75.w,
//             child: Text(
//               label,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 11.sp,
//                 fontWeight: FontWeight.w500,
//                 color: Color(0xFF111111),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // 7️⃣ Real-time Alerts Section - Real Data Only
//   Widget _buildRealTimeAlerts() {
//     return Column(
//       children: [
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 16.w),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Real-time Alerts',
//                 style: TextStyle(
//                   fontSize: 16.sp,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF111111),
//                 ),
//               ),
//               GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const NotificationsScreen(),
//                     ),
//                   );
//                 },
//                 child: Text(
//                   'View All',
//                   style: TextStyle(
//                     fontSize: 14.sp,
//                     fontWeight: FontWeight.w500,
//                     color: Color(0xFF0E4778),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 10.h),
//         _buildRealNotificationsStream(),
//       ],
//     );
//   }

//   Widget _buildRealNotificationsStream() {
//     return StreamBuilder<List<Map<String, dynamic>>>(
//       stream: _getAdminNotifications(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Column(
//             children: [
//               _buildLoadingAlertItem(),
//               _buildLoadingAlertItem(),
//               _buildLoadingAlertItem(),
//             ],
//           );
//         }

//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
//             child: Center(
//               child: Text(
//                 'No alerts at the moment',
//                 style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
//               ),
//             ),
//           );
//         }

//         final notifications = snapshot.data!;
//         return Column(
//           children: notifications
//               .take(4) // Show only last 4 notifications
//               .map((notification) => _buildRealAlertItem(notification))
//               .toList(),
//         );
//       },
//     );
//   }

//   Stream<List<Map<String, dynamic>>> _getAdminNotifications() {
//     try {
//       print('🔵 NOTIFICATIONS LOAD: Starting...');

//       // STEP 1: Validate Admin Authentication
//       print('🔐 STEP 1: Validating admin authentication...');
//       final adminId = _adminId;
//       if (adminId.isEmpty) {
//         throw Exception('Admin not authenticated');
//       }
//       print('✅ STEP 1 PASSED: Admin authenticated');

//       // STEP 2: Fetch Real Notifications from Firestore
//       print('📋 STEP 2: Fetching real notifications...');
//       return FirebaseFirestore.instance
//           .collection('notifications')
//           .where('communityId', isEqualTo: _communityId)
//           .orderBy('timestamp', descending: true)
//           .limit(10)
//           .snapshots()
//           .map((snapshot) {
//             print('✅ STEP 2 PASSED: Notifications fetched');

//             // STEP 3: Transform Firestore Data
//             print('📝 STEP 3: Transforming notification data...');
//             final notifications = snapshot.docs.map((doc) {
//               final data = doc.data();
//               return {
//                 'id': doc.id,
//                 'title': data['title'] ?? 'Notification',
//                 'message': data['message'] ?? '',
//                 'type': data['type'] ?? 'general',
//                 'priority': data['priority'] ?? 'medium',
//                 'timestamp': data['timestamp'] as Timestamp?,
//                 'isRead': data['isRead'] ?? false,
//                 'metadata': data['metadata'] ?? {},
//               };
//             }).toList();
//             print('✅ STEP 3 PASSED: Data transformed');

//             // STEP 4: Return Real Data
//             print('🔔 STEP 4: Returning real notifications...');
//             print('✅ NOTIFICATIONS LOAD: COMPLETE');
//             return notifications;
//           });
//     } catch (e) {
//       print('❌ ERROR: $e');
//       return Stream.value([]);
//     }
//   }

//   Widget _buildLoadingAlertItem() {
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
//       padding: EdgeInsets.all(12.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40.w,
//             height: 40.h,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(10.r),
//             ),
//           ),
//           SizedBox(width: 10.w),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: 150.w,
//                   height: 13.h,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(4.r),
//                   ),
//                 ),
//                 SizedBox(height: 6.h),
//                 Container(
//                   width: 80.w,
//                   height: 11.h,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(4.r),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRealAlertItem(Map<String, dynamic> notification) {
//     final type = notification['type'] as String;
//     final timestamp = notification['timestamp'] as Timestamp?;
//     final timeAgo = _getTimeAgo(timestamp?.toDate());

//     // Determine icon and color based on notification type
//     IconData icon = Icons.notifications;
//     Color iconColor = const Color(0xFF6A6A6A);
//     Color iconBg = const Color(0xFFF1F1F1);

//     switch (type.toLowerCase()) {
//       case 'visitor':
//         icon = Icons.person_add;
//         iconColor = const Color(0xFF10B981);
//         iconBg = const Color(0xFFD1FAE5);
//         break;
//       case 'complaint':
//         icon = Icons.warning_rounded;
//         iconColor = const Color(0xFFF4A100);
//         iconBg = const Color(0xFFFFF4E5);
//         break;
//       case 'payment':
//         icon = Icons.payment;
//         iconColor = const Color(0xFF0E4778);
//         iconBg = const Color(0xFFE0EDFF);
//         break;
//       case 'security':
//         icon = Icons.security;
//         iconColor = const Color(0xFFEF4444);
//         iconBg = const Color(0xFFFFE5E5);
//         break;
//       case 'maintenance':
//         icon = Icons.build;
//         iconColor = const Color(0xFF8B5CF6);
//         iconBg = const Color(0xFFEDE9FE);
//         break;
//       case 'event':
//         icon = Icons.event;
//         iconColor = const Color(0xFF06B6D4);
//         iconBg = const Color(0xFFCFFAFE);
//         break;
//       default:
//         icon = Icons.check_circle;
//         iconColor = const Color(0xFF6A6A6A);
//         iconBg = const Color(0xFFF1F1F1);
//     }

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
//       padding: EdgeInsets.all(12.w),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40.w,
//             height: 40.h,
//             decoration: BoxDecoration(
//               color: iconBg,
//               borderRadius: BorderRadius.circular(10.r),
//             ),
//             child: Icon(icon, color: iconColor, size: 20.w),
//           ),
//           SizedBox(width: 10.w),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   notification['title'] ?? 'Notification',
//                   style: TextStyle(
//                     fontSize: 13.sp,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF111111),
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 SizedBox(height: 3.h),
//                 Text(
//                   timeAgo,
//                   style: TextStyle(
//                     fontSize: 11.sp,
//                     fontWeight: FontWeight.w400,
//                     color: Color(0xFF6A6A6A),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getTimeAgo(DateTime? dateTime) {
//     if (dateTime == null) return 'Just now';

//     final now = DateTime.now();
//     final difference = now.difference(dateTime);

//     if (difference.inSeconds < 60) {
//       return 'Just now';
//     } else if (difference.inMinutes < 60) {
//       return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
//     } else if (difference.inHours < 24) {
//       return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
//     } else if (difference.inDays < 7) {
//       return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
//     } else {
//       return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
//     }
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'admin_residents_page_firestore.dart';
import 'amenities_management_screen.dart';
import 'billing_screen.dart';
import 'complaint_management_screen.dart';
import 'events_announcements_screen.dart';
import 'manage_buildings_page.dart';
import 'notifications_screen.dart';
import 'parking_management_screen.dart';
import 'quick_access_page.dart';
import 'security_management_screen.dart';
import 'dart:async';

import 'package:hominode_notifications/hominode_notifications.dart';

import 'services/admin_tenant_context.dart';
import 'services/dashboard_service.dart';
import 'services/notification_service.dart';
import 'theme/hominode_theme.dart';
import 'visitor_management_screen.dart';
import 'widgets/notification_badge.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/community_switcher_dialog.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final NotificationService _notificationService = NotificationService();
  final DashboardService _dashboardService = DashboardService();

  String _adminName = 'Admin';
  String _adminRole = 'Administrator';
  String _buildingName = 'Loading...';
  bool _isLoadingUserData = true;

  String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _communityId => AdminTenantContext.instance.requireCommunityId();

  @override
  void initState() {
    super.initState();
    _notificationService.initializeNotifications();
    _notificationService.addListener(_onNotificationUpdate);
    _loadAdminData();
    unawaited(
      HominodePushNotifications.instance.activate(
        selectedCommunityId: _communityId,
      ),
    );
  }

  Future<void> _loadAdminData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG Dashboard: No user logged in');
        return;
      }

      print('=== DEBUG: Dashboard Data Fetch ===');
      print('Auth UID: ${user.uid}');
      print('Auth Email: ${user.email}');
      print('Fetching from: admins/${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      print('Document exists: ${userDoc.exists}');

      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        print('Fetched data: $data');

        setState(() {
          _adminName = data['name'] ?? 'Admin';
          _adminRole = _formatRole(data['role'] ?? 'admin');
          _buildingName =
              data['organization'] ?? 'HOMINODE Property Management';
          _isLoadingUserData = false;
        });

        print('Admin Name: $_adminName');
        print('Admin Role: $_adminRole');
        print('Building Name: $_buildingName');
      } else if (mounted) {
        print('WARNING: Admin document does not exist');
        setState(() {
          _buildingName = 'HOMINODE Property Management';
          _isLoadingUserData = false;
        });
      }

      print('===================================');
    } catch (e) {
      print('ERROR loading admin data: $e');
      if (mounted) {
        setState(() {
          _buildingName = 'HOMINODE Property Management';
          _isLoadingUserData = false;
        });
      }
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return 'Super Administrator';
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'staff':
        return 'Staff Member';
      default:
        return 'Administrator';
    }
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationUpdate);
    super.dispose();
  }

  void _onNotificationUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroHeader()),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: Offset(0, -8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDashboardStats(),
                    SizedBox(height: 22.h),
                    _buildQuickActions(),
                    SizedBox(height: 22.h),
                    _buildPromoBanner(),
                    SizedBox(height: 22.h),
                    _buildRealTimeAlerts(),
                    SizedBox(height: 26.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 0),
    );
  }

  Widget _buildHeroHeader() {
    return ClipPath(
      clipper: _DashboardHeaderClipper(),
      child: Container(
        height: 260.h,
        decoration: const BoxDecoration(
          gradient: HominodeTheme.primaryGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16.w,
              bottom: -8.h,
              child: Opacity(
                opacity: 0.10,
                child: Icon(
                  Icons.apartment_rounded,
                  size: 148.w,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              right: 44.w,
              bottom: 34.h,
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  Icons.location_city_rounded,
                  size: 94.w,
                  color: Colors.white,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 6.h),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeaderCircleButton(
                          icon: Icons.menu_rounded,
                          onTap:
                              AdminTenantContext
                                      .instance
                                      .authorizedTenants
                                      .length >
                                  1
                              ? () async {
                                  if (await CommunitySwitcherDialog.show(
                                        context,
                                      ) &&
                                      mounted) {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/dashboard',
                                      (route) => false,
                                    );
                                  }
                                }
                              : null,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsScreen(),
                              ),
                            );
                          },
                          child: NotificationBadge(
                            showBadge: _notificationService.unreadCount > 0,
                            count: _notificationService.unreadCount,
                            top: -3,
                            right: -3,
                            child: _buildHeaderCircleButton(
                              icon: Icons.notifications_none_rounded,
                              onTap: null,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 2.h),

                    _buildBrandMark(),

                    SizedBox(height: 1.h),

                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    SizedBox(height: 1.h),

                    Text(
                      _adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color.fromARGB(255, 244, 181, 22),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        Expanded(flex: 5, child: _buildCommunityPill()),
                        SizedBox(width: 6.w),
                        Flexible(flex: 2, child: _buildActivePill()),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCircleButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24.r),
        child: Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: Colors.white, size: 25.w),
        ),
      ),
    );
  }

  Widget _buildBrandMark() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Geometric Node Icon
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC66D).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: const Color(0xFFFFC66D), width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC66D),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          'HOMINODE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0.w,
          ),
        ),
      ],
    );
  }

  // Widget _buildBrandMark() {
  //   return Container(
  //     height: 38.h,
  //     padding: EdgeInsets.symmetric(horizontal: 16.w),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.06),
  //       borderRadius: BorderRadius.circular(20.r),
  //       border: Border.all(
  //         color: const Color(0xFFFFD58A).withOpacity(0.22),
  //         width: 1,
  //       ),
  //       boxShadow: [
  //         BoxShadow(
  //           color: const Color(0xFFFFD58A).withOpacity(0.10),
  //           blurRadius: 14,
  //           spreadRadius: 1,
  //         ),
  //       ],
  //     ),
  //     child: Center(
  //       child: Text(
  //         'HOMINODE',
  //         style: TextStyle(
  //           color: const Color(0xFFFFD58A),
  //           fontSize: 18.sp,
  //           fontWeight: FontWeight.w700,
  //           letterSpacing: 4.w,
  //           height: 1,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildCommunityPill() {
    return Container(
      height: 46.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.apartment_rounded, color: Colors.white, size: 21.w),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              _buildingName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 23.w,
          ),
        ],
      ),
    );
  }

  Widget _buildActivePill() {
    return Container(
      height: 46.h,
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9.w,
            height: 9.w,
            decoration: const BoxDecoration(
              color: Color(0xFF55E1B8),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 7.w),
          Text(
            'Active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStats() {
    return StreamBuilder<DashboardStats>(
      stream: _dashboardService.getDashboardStats(_communityId),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final stats = snapshot.data;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: SizedBox(
            height: 150.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF2F61D7),
                    iconBg: const Color(0xFFEAF0FF),
                    value: loading ? '—' : '${stats?.totalResidents ?? 0}',
                    label: 'Total\nResidents',
                    subtitle: 'Active users',
                    subtitleColor: const Color(0xFF2F61D7),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.apartment_rounded,
                    iconColor: const Color(0xFF19956F),
                    iconBg: const Color(0xFFE3F8EF),
                    value: loading ? '—' : '${stats?.totalFlats ?? 0}',
                    label: 'Total Flats',
                    subtitle: 'All units',
                    subtitleColor: const Color(0xFF19956F),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF8054D7),
                    iconBg: const Color(0xFFF0E9FF),
                    value: loading ? '—' : '${stats?.pendingVisitors ?? 0}',
                    label: 'Pending\nVisitors',
                    subtitle: 'Awaiting\napproval',
                    subtitleColor: const Color(0xFF8054D7),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VisitorManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.warning_rounded,
                    iconColor: const Color(0xFFEB3535),
                    iconBg: const Color(0xFFFFE8E4),
                    value: loading ? '—' : '${stats?.pendingComplaints ?? 0}',
                    label: 'Pending\nComplaints',
                    subtitle: 'Needs\nattention',
                    subtitleColor: const Color(0xFFEB3535),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ComplaintManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF14966F),
                    iconBg: const Color(0xFFE4F8EF),
                    value: loading ? '—' : (stats?.formattedCollection ?? '₹0'),
                    label: 'This Month\nCollection',
                    subtitle: 'Paid bills',
                    subtitleColor: const Color(0xFF14966F),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BillingScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
    required Color subtitleColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Ink(
          padding: EdgeInsets.fromLTRB(4.w, 12.h, 4.w, 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21.w),
              ),
              SizedBox(height: 8.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111418),
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF42464D),
                  fontSize: 9.5.sp,
                  height: 1.12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 8.8.sp,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: const Color(0xFF111418),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuickAccessPage(),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: const Color(0xFF2657D9),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19.w,
                      color: const Color(0xFF2657D9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding:
                EdgeInsets.zero, // important: removes unwanted vertical gap
            crossAxisCount: 4,
            crossAxisSpacing: 9.w,
            mainAxisSpacing: 10.h,
            mainAxisExtent: 125.h, // enough height for icon + label + arrow

            children: [
              _buildQuickActionCard(
                icon: Icons.apartment_rounded,
                label: 'Add Building',
                color: const Color(0xFF2F61D7),
                bgColor: const Color(0xFFEAF0FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageBuildingsPage(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'Add Bill',
                color: const Color(0xFF12966F),
                bgColor: const Color(0xFFE4F8EF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BillingScreen(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.how_to_reg_rounded,
                label: 'Approve Visitor',
                color: const Color(0xFFF0A11C),
                bgColor: const Color(0xFFFFF2DD),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VisitorManagementScreen(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.shield_rounded,
                label: 'Security',
                color: const Color(0xFF7447D8),
                bgColor: const Color(0xFFF1EAFF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecurityManagementScreen(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.groups_rounded,
                label: 'Residents',
                color: const Color(0xFF117A83),
                bgColor: const Color(0xFFE7F7F8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminResidentsPageFirestore(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.event_rounded,
                label: 'Events',
                color: const Color(0xFFD6348B),
                bgColor: const Color(0xFFFFEAF5),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsAnnouncementsScreen(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.local_parking_rounded,
                label: 'Parking',
                color: const Color(0xFF3565D9),
                bgColor: const Color(0xFFEAF0FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ParkingManagementScreenEnhanced(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                icon: Icons.apartment_outlined,
                label: 'Amenities',
                color: const Color(0xFF3EA853),
                bgColor: const Color(0xFFE9F8EB),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AmenitiesManagementScreen(),
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 13,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(7.w, 12.h, 7.w, 9.h),
            child: Column(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 23.w),
                ),
                SizedBox(height: 10.h),
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF15171B),
                        fontSize: 10.5.sp,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17.w,
                  color: const Color(0xFF9AA0A8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      child: Container(
        height: 104.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFDCE7FF), Color(0xFFCFEFFF), Color(0xFFD9FBF7)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Stack(
            children: [
              Positioned(
                left: 10.w,
                bottom: -8.h,
                child: Opacity(
                  opacity: 0.22,
                  child: Icon(
                    Icons.phone_iphone_rounded,
                    size: 82.w,
                    color: const Color(0xFF17489B),
                  ),
                ),
              ),
              Positioned(
                left: 58.w,
                top: 18.h,
                child: _buildPromoBubble(Icons.person_outline_rounded),
              ),
              Positioned(
                left: 47.w,
                bottom: 16.h,
                child: _buildPromoBubble(Icons.receipt_long_rounded),
              ),
              Positioned.fill(
                left: 108.w,
                right: 56.w,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Community,\nBetter Living',
                        maxLines: 2,
                        style: TextStyle(
                          color: const Color(0xFF0B2D6A),
                          fontSize: 15.sp,
                          height: 1.10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 7.h),
                      Text(
                        'Manage your society, connect with residents and simplify everyday tasks.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF18375F),
                          fontSize: 8.8.sp,
                          height: 1.22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 14.w,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF103A8D),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 21.w,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBubble(IconData icon) {
    return Container(
      width: 27.w,
      height: 20.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Icon(icon, size: 12.w, color: const Color(0xFF1E64C8)),
    );
  }

  Widget _buildRealTimeAlerts() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Real-time Alerts',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111418),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2657D9),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19.w,
                      color: const Color(0xFF2657D9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        _buildRealNotificationsStream(),
      ],
    );
  }

  Widget _buildRealNotificationsStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getAdminNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              _buildLoadingAlertItem(),
              _buildLoadingAlertItem(),
              _buildLoadingAlertItem(),
            ],
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: Center(
              child: Text(
                'No alerts at the moment',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
          );
        }

        final notifications = snapshot.data!;
        return Column(
          children: notifications
              .take(4)
              .map((notification) => _buildRealAlertItem(notification))
              .toList(),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getAdminNotifications() {
    try {
      print('🔵 NOTIFICATIONS LOAD: Starting...');

      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminId;
      if (adminId.isEmpty) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      print('📋 STEP 2: Fetching real notifications...');
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('communityId', isEqualTo: _communityId)
          .where('recipientId', isEqualTo: adminId)
          .where('audience', isEqualTo: 'admin')
          .where('role', isEqualTo: 'admin')
          .where('appId', isEqualTo: 'admin')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .map((snapshot) {
            print('✅ STEP 2 PASSED: Notifications fetched');

            print('📝 STEP 3: Transforming notification data...');
            final notifications = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'title': data['title'] ?? 'Notification',
                'message': data['message'] ?? '',
                'type': data['type'] ?? 'general',
                'priority': data['priority'] ?? 'medium',
                'timestamp': data['createdAt'] as Timestamp?,
                'isRead': data['isRead'] ?? false,
                'metadata': data['metadata'] ?? {},
              };
            }).toList();
            print('✅ STEP 3 PASSED: Data transformed');

            print('🔔 STEP 4: Returning real notifications...');
            print('✅ NOTIFICATIONS LOAD: COMPLETE');
            return notifications;
          });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  Widget _buildLoadingAlertItem() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150.w,
                  height: 13.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 80.w,
                  height: 11.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealAlertItem(Map<String, dynamic> notification) {
    final type = notification['type'] as String;
    final timestamp = notification['timestamp'] as Timestamp?;
    final timeAgo = _getTimeAgo(timestamp?.toDate());

    IconData icon = Icons.notifications;
    Color iconColor = const Color(0xFF6A6A6A);
    Color iconBg = const Color(0xFFF1F1F1);

    switch (type.toLowerCase()) {
      case 'visitor':
        icon = Icons.person_add;
        iconColor = const Color(0xFF10B981);
        iconBg = const Color(0xFFD1FAE5);
        break;
      case 'complaint':
        icon = Icons.warning_rounded;
        iconColor = const Color(0xFFF4A100);
        iconBg = const Color(0xFFFFF4E5);
        break;
      case 'payment':
        icon = Icons.payment;
        iconColor = HominodeTheme.blue;
        iconBg = const Color(0xFFE0EDFF);
        break;
      case 'security':
        icon = Icons.security;
        iconColor = const Color(0xFFEF4444);
        iconBg = const Color(0xFFFFE5E5);
        break;
      case 'maintenance':
        icon = Icons.build;
        iconColor = const Color(0xFF8B5CF6);
        iconBg = const Color(0xFFEDE9FE);
        break;
      case 'event':
        icon = Icons.event;
        iconColor = const Color(0xFF06B6D4);
        iconBg = const Color(0xFFCFFAFE);
        break;
      default:
        icon = Icons.check_circle;
        iconColor = const Color(0xFF6A6A6A);
        iconBg = const Color(0xFFF1F1F1);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'] ?? 'Notification',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6A6A6A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _DashboardHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 18)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height + 10,
        size.width,
        size.height - 18,
      )
      ..lineTo(size.width, 0)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
