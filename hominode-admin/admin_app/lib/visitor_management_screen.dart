import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'desktop/admin_desktop_page_frame.dart';
import 'qr_gate_scanner_screen.dart';
import 'services/visitor_service.dart';
import 'widgets/standard_header.dart';

/// Visitor Management Screen - Exact Flow UI Compliance with Firestore Integration
///
/// Features:
/// - Real-time data from Firestore
/// - Exact spacing and sizing matching other Flow UI screens
/// - Professional layout with proper auto-layout
/// - Consistent component sizing and positioning
/// - Perfect alignment with app design system

class VisitorManagementScreen extends StatefulWidget {
  final int initialTab;
  final VisitorWorkflowService? visitorService;

  const VisitorManagementScreen({
    super.key,
    this.initialTab = 0,
    this.visitorService,
  });

  @override
  State<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen>
    with TickerProviderStateMixin {
  // Tab management
  int _currentTab = 0;
  late PageController _pageController;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Firestore service
  late final VisitorWorkflowService _visitorService;

  // Real-time counts from Firestore
  int _pendingCount = 0;
  int _activeCount = 0;
  int _historyCount = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _visitorService = widget.visitorService ?? VisitorService();
    _pageController = PageController(initialPage: _currentTab);

    // Initialize animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    print('VisitorManagementScreen: Initialized with Firestore integration');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Tab change handler
  void _onTabChanged(int index) async {
    if (index == _currentTab) return;

    HapticFeedback.selectionClick();

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() => _currentTab = index);
  }

  // Visitor action handlers
  void _onApproveVisitor(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      // Approve in Firestore and check-in
      await _visitorService.approveVisitor(visitorId);
      await _visitorService.checkInVisitor(visitorId);

      if (mounted) {
        _showSnackBar(
          '$visitorName approved and checked in',
          const Color(0xFF16A34A),
          Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to approve visitor: $e',
          const Color(0xFFEF4444),
          Icons.error,
        );
      }
    }
  }

  void _onRejectVisitor(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      await _visitorService.rejectVisitor(visitorId);

      if (mounted) {
        _showSnackBar(
          '$visitorName request rejected',
          const Color(0xFFEF4444),
          Icons.cancel,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to reject visitor: $e',
          const Color(0xFFEF4444),
          Icons.error,
        );
      }
    }
  }

  void _onMarkExit(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      await _visitorService.checkOutVisitor(visitorId);

      if (mounted) {
        _showSnackBar(
          '$visitorName marked as exited',
          const Color(0xFF16A34A),
          Icons.logout,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to mark exit: $e',
          const Color(0xFFEF4444),
          Icons.error,
        );
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20.w),
            SizedBox(width: 8.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  void _onQRScannerTap() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrGateScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Visitors',
        subtitle: 'Review visitor requests, active visits, and history.',
        actions: [
          AdminDesktopPrimaryAction(
            label: 'Scan QR',
            icon: Icons.qr_code_scanner,
            onPressed: _onQRScannerTap,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryMetrics(),
            SizedBox(height: 16.h),
            _buildSearchBar(),
            SizedBox(height: 16.h),
            _buildTabSwitcher(),
            SizedBox(height: 14.h),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentTab = index),
                children: [
                  _buildPendingTab(),
                  _buildActiveTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Visitor Management'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),

                // Page Header - matching other screens
                _buildPageHeader(),

                SizedBox(height: 16.h),

                // Summary Metrics - exact spacing from other screens
                _buildSummaryMetrics(),

                SizedBox(height: 20.h),

                // Search Bar - matching parcel screen
                _buildSearchBar(),

                SizedBox(height: 20.h),

                // Tab Switcher - matching complaint screen
                _buildTabSwitcher(),

                SizedBox(height: 16.h),

                // Content Area
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentTab = index);
                      HapticFeedback.lightImpact();
                    },
                    children: [
                      _buildPendingTab(),
                      _buildActiveTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),

                SizedBox(height: 100.h), // Bottom padding for FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onQRScannerTap,
        backgroundColor: const Color(0xFF0E4778),
        elevation: 4,
        icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 20.w),
        label: Text(
          'Scan QR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  // Page Header - matching reports screen pattern exactly
  Widget _buildPageHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.people, color: Color(0xFF0E4778), size: 24.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visitor Management',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _getSubtitleForTab(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _onQRScannerTap,
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: const Color(0xFF0E4778).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF0E4778),
                size: 20.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitleForTab() {
    switch (_currentTab) {
      case 0:
        return 'Approve pending visitor requests';
      case 1:
        return 'Track active visitors inside';
      case 2:
        return 'View completed visitor records';
      default:
        return 'Manage visitor entries';
    }
  }

  // Summary Metrics - matching complaint screen pattern exactly
  Widget _buildSummaryMetrics() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: _getStatIcon(0),
              iconColor: _getStatColor(0),
              iconBg: _getStatColor(0).withOpacity(0.1),
              value: _getStatValue(0),
              label: _getStatTitle(0),
              subtitle: _getStatSubtitle(0),
              subtitleColor: _getStatColor(0),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              icon: _getStatIcon(1),
              iconColor: _getStatColor(1),
              iconBg: _getStatColor(1).withOpacity(0.1),
              value: _getStatValue(1),
              label: _getStatTitle(1),
              subtitle: _getStatSubtitle(1),
              subtitleColor: _getStatColor(1),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              icon: _getStatIcon(2),
              iconColor: _getStatColor(2),
              iconBg: _getStatColor(2).withOpacity(0.1),
              value: _getStatValue(2),
              label: _getStatTitle(2),
              subtitle: _getStatSubtitle(2),
              subtitleColor: _getStatColor(2),
            ),
          ),
        ],
      ),
    );
  }

  // Stat Card - exact pattern from complaint screen
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20.w),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Dynamic stat data based on current tab
  String _getStatTitle(int index) {
    switch (_currentTab) {
      case 0: // Pending
        return ['Pending', 'Today\'s Total', 'Avg. Response'][index];
      case 1: // Active
        return ['Active', 'Today\'s Total', 'Avg. Duration'][index];
      case 2: // History
        return ['Today\'s Visits', 'Weekly Total', 'Avg. Duration'][index];
      default:
        return '';
    }
  }

  String _getStatValue(int index) {
    switch (_currentTab) {
      case 0: // Pending
        return [_pendingCount.toString(), _pendingCount.toString(), '-'][index];
      case 1: // Active
        return [_activeCount.toString(), _activeCount.toString(), '-'][index];
      case 2: // History
        return [_historyCount.toString(), _historyCount.toString(), '-'][index];
      default:
        return '0';
    }
  }

  String _getStatSubtitle(int index) {
    switch (_currentTab) {
      case 0: // Pending
        return [
          'Awaiting approval',
          'Requests received',
          'Response time',
        ][index];
      case 1: // Active
        return ['Currently inside', 'Visitors today', 'Stay duration'][index];
      case 2: // History
        return ['Completed visits', 'This week', 'Visit duration'][index];
      default:
        return '';
    }
  }

  IconData _getStatIcon(int index) {
    switch (_currentTab) {
      case 0: // Pending
        return [Icons.pending_actions, Icons.today, Icons.timer][index];
      case 1: // Active
        return [Icons.people, Icons.today, Icons.schedule][index];
      case 2: // History
        return [Icons.history, Icons.date_range, Icons.schedule][index];
      default:
        return Icons.info;
    }
  }

  Color _getStatColor(int index) {
    switch (_currentTab) {
      case 0: // Pending
        return [
          const Color(0xFFF59E0B),
          const Color(0xFF0E4778),
          const Color(0xFF8B5CF6),
        ][index];
      case 1: // Active
        return [
          const Color(0xFF16A34A),
          const Color(0xFF0E4778),
          const Color(0xFF8B5CF6),
        ][index];
      case 2: // History
        return [
          const Color(0xFF8B5CF6),
          const Color(0xFF0E4778),
          const Color(0xFF16A34A),
        ][index];
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Search Bar - matching parcel screen pattern exactly
  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search visitors...',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.sp),
            prefixIcon: Icon(
              Icons.search,
              color: Color(0xFF9CA3AF),
              size: 20.w,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 20.w,
                      color: Color(0xFF9CA3AF),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
    );
  }

  // Tab Switcher - matching complaint screen pattern exactly
  Widget _buildTabSwitcher() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Expanded(child: _buildTabButton('Pending', 0)),
            Expanded(child: _buildTabButton('Active', 1)),
            Expanded(child: _buildTabButton('History', 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: Container(
        margin: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF111827)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  // Tab content builders
  Widget _buildPendingTab() {
    return StreamBuilder<List<VisitorModel>>(
      stream: _visitorService.getPendingVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading visitors: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        final visitors = snapshot.data ?? [];

        // Update count
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pendingCount != visitors.length) {
            setState(() {
              _pendingCount = visitors.length;
            });
          }
        });

        final filteredVisitors = _getFilteredVisitors(visitors);

        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions,
            title: _searchQuery.isNotEmpty
                ? 'No visitors found'
                : 'No Pending Requests',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'All requests have been processed',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: filteredVisitors.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _buildPendingVisitorCard(filteredVisitors[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveTab() {
    return StreamBuilder<List<VisitorModel>>(
      stream: _visitorService.getActiveVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading visitors: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        final visitors = snapshot.data ?? [];

        // Update count
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _activeCount != visitors.length) {
            setState(() {
              _activeCount = visitors.length;
            });
          }
        });

        final filteredVisitors = _getFilteredVisitors(visitors);

        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people,
            title: _searchQuery.isNotEmpty
                ? 'No visitors found'
                : 'No Active Visitors',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'No visitors are currently inside',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: filteredVisitors.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _buildActiveVisitorCard(filteredVisitors[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<VisitorModel>>(
      stream: _visitorService.getHistoryVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading visitors: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        final visitors = snapshot.data ?? [];

        // Update count
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _historyCount != visitors.length) {
            setState(() {
              _historyCount = visitors.length;
            });
          }
        });

        final filteredVisitors = _getFilteredVisitors(visitors);

        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: _searchQuery.isNotEmpty
                ? 'No visitors found'
                : 'No History Records',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Completed visitor records will appear here',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: filteredVisitors.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _buildHistoryVisitorCard(filteredVisitors[index]),
            );
          },
        );
      },
    );
  }

  // Unified filter method for all visitor types
  List<VisitorModel> _getFilteredVisitors(List<VisitorModel> visitors) {
    if (_searchQuery.isEmpty) return visitors;
    return visitors.where((visitor) {
      return visitor.visitorName.toLowerCase().contains(_searchQuery) ||
          visitor.residentName.toLowerCase().contains(_searchQuery) ||
          visitor.flatLabel.toLowerCase().contains(_searchQuery) ||
          visitor.purpose.toLowerCase().contains(_searchQuery) ||
          visitor.phone.contains(_searchQuery);
    }).toList();
  }

  // Empty state widget
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64.w, color: const Color(0xFFE5E7EB)),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Pending visitor card - matching exact Flow UI patterns
  Widget _buildPendingVisitorCard(VisitorModel visitor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Profile Icon
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFFF59E0B),
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),

                // Name and Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        visitor.phone,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Request Time
            Text(
              'Requested: ${visitor.createdAt != null ? _formatTime(visitor.createdAt!) : "N/A"}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),

            SizedBox(height: 12.h),

            // Details Section
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Visiting', visitor.residentName),
                  SizedBox(height: 8.h),
                  _buildDetailRow('Unit', visitor.flatLabel),
                  SizedBox(height: 8.h),
                  _buildDetailRow('Purpose', visitor.purpose),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _onRejectVisitor(visitor.id, visitor.visitorName),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _onApproveVisitor(visitor.id, visitor.visitorName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Active visitor card - matching exact Flow UI patterns
  Widget _buildActiveVisitorCard(VisitorModel visitor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Profile Icon
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF16A34A),
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),

                // Name and Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        visitor.phone,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Inside',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Entry Time
            Text(
              'Entered: ${visitor.checkInTime != null ? _formatTime(visitor.checkInTime!) : "N/A"}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Color(0xFF16A34A),
              ),
            ),

            SizedBox(height: 12.h),

            // Details Section
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Visiting', visitor.residentName),
                  SizedBox(height: 8.h),
                  _buildDetailRow('Unit', visitor.flatLabel),
                  SizedBox(height: 8.h),
                  _buildDetailRow('Purpose', visitor.purpose),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Mark Exit Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onMarkExit(visitor.id, visitor.visitorName),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                icon: Icon(Icons.logout, color: Color(0xFF111827), size: 16.w),
                label: Text(
                  'Mark Exit',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // History visitor card - matching exact Flow UI patterns
  Widget _buildHistoryVisitorCard(VisitorModel visitor) {
    final entryTime =
        visitor.checkInTime ?? visitor.createdAt ?? DateTime.now();
    final exitTime = visitor.checkOutTime ?? DateTime.now();
    final duration = exitTime.difference(entryTime);
    final durationText = _formatDuration(duration);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Profile Icon
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF8B5CF6),
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),

                // Name and Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${visitor.flatLabel} • ${visitor.purpose}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    durationText,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Entry and Exit Times
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  // Entry Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entry',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _formatTime(entryTime),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1.w,
                    height: 32.h,
                    color: const Color(0xFFE5E7EB),
                  ),

                  // Exit Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _formatTime(exitTime),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDB2777),
                          ),
                        ),
                      ],
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

  // Detail row helper - exact typography matching
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Time formatting helper
  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Duration formatting helper
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
