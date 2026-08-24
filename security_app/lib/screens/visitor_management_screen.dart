import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../utils/app_colors.dart';
import '../widgets/standard_header.dart';
import 'qr_scanner_screen.dart';

class VisitorManagementScreen extends StatefulWidget {
  final int initialTab;

  const VisitorManagementScreen({super.key, this.initialTab = 0});

  @override
  State<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen>
    with TickerProviderStateMixin {
  int _currentTab = 0;
  late final PageController _pageController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final VisitorService _visitorService = VisitorService();

  // ---------------------------------------------------------------------------
  // Cached visitor lists.
  //
  // Each VisitorService stream is listened to exactly ONCE.
  // Metrics and tab content both read from these cached lists.
  // ---------------------------------------------------------------------------
  List<VisitorModel> _pendingVisitors = [];
  List<VisitorModel> _activeVisitors = [];
  List<VisitorModel> _historyVisitors = [];

  bool _pendingLoading = true;
  bool _activeLoading = true;
  bool _historyLoading = true;

  Object? _pendingError;
  Object? _activeError;
  Object? _historyError;

  StreamSubscription<List<VisitorModel>>? _pendingSubscription;
  StreamSubscription<List<VisitorModel>>? _activeSubscription;
  StreamSubscription<List<VisitorModel>>? _historySubscription;

  bool _isChangingTab = false;

  @override
  void initState() {
    super.initState();

    _currentTab = widget.initialTab;
    _pageController = PageController(initialPage: _currentTab);

    _startVisitorSubscriptions();

    _searchController.addListener(_onSearchChanged);
  }

  void _startVisitorSubscriptions() {
    _pendingSubscription = _visitorService.getPendingVisitors().listen(
      (visitors) {
        if (!mounted) return;

        setState(() {
          _pendingVisitors = visitors;
          _pendingLoading = false;
          _pendingError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Pending visitor stream error: $error');

        if (!mounted) return;

        setState(() {
          _pendingLoading = false;
          _pendingError = error;
        });
      },
    );

    _activeSubscription = _visitorService.getActiveVisitors().listen(
      (visitors) {
        if (!mounted) return;

        setState(() {
          _activeVisitors = visitors;
          _activeLoading = false;
          _activeError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Active visitor stream error: $error');

        if (!mounted) return;

        setState(() {
          _activeLoading = false;
          _activeError = error;
        });
      },
    );

    _historySubscription = _visitorService.getHistoryVisitors().listen(
      (visitors) {
        if (!mounted) return;

        setState(() {
          _historyVisitors = visitors;
          _historyLoading = false;
          _historyError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('History visitor stream error: $error');

        if (!mounted) return;

        setState(() {
          _historyLoading = false;
          _historyError = error;
        });
      },
    );
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    _activeSubscription?.cancel();
    _historySubscription?.cancel();

    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _pageController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // TAB NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _onTabChanged(int index) async {
    if (index == _currentTab || _isChangingTab) {
      return;
    }

    HapticFeedback.selectionClick();

    _isChangingTab = true;

    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } finally {
      _isChangingTab = false;
    }
  }

  // ---------------------------------------------------------------------------
  // VISITOR ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _onApproveVisitor(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      await _visitorService.approveVisitor(visitorId);
      await _visitorService.checkInVisitor(visitorId);

      if (!mounted) return;

      _showSnackBar(
        '$visitorName approved and checked in',
        AppColors.successGreen,
        Icons.check_circle,
      );
    } catch (e) {
      debugPrint('Approve visitor error: $e');

      if (!mounted) return;

      _showSnackBar(
        'Failed to approve visitor',
        AppColors.errorRed,
        Icons.error,
      );
    }
  }

  Future<void> _onRejectVisitor(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      await _visitorService.rejectVisitor(visitorId);

      if (!mounted) return;

      _showSnackBar(
        '$visitorName request rejected',
        AppColors.errorRed,
        Icons.cancel,
      );
    } catch (e) {
      debugPrint('Reject visitor error: $e');

      if (!mounted) return;

      _showSnackBar(
        'Failed to reject visitor',
        AppColors.errorRed,
        Icons.error,
      );
    }
  }

  Future<void> _onMarkExit(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      await _visitorService.checkOutVisitor(visitorId);

      if (!mounted) return;

      _showSnackBar(
        '$visitorName marked as exited',
        AppColors.successGreen,
        Icons.logout,
      );
    } catch (e) {
      debugPrint('Mark visitor exit error: $e');

      if (!mounted) return;

      _showSnackBar('Failed to mark exit', AppColors.errorRed, Icons.error);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onQRScannerTap() {
    HapticFeedback.mediumImpact();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  List<VisitorModel> _filterVisitors(List<VisitorModel> visitors) {
    if (_searchQuery.isEmpty) {
      return visitors;
    }

    return visitors.where((visitor) {
      return visitor.visitorName.toLowerCase().contains(_searchQuery) ||
          visitor.phone.toLowerCase().contains(_searchQuery) ||
          visitor.residentName.toLowerCase().contains(_searchQuery) ||
          visitor.flatLabel.toLowerCase().contains(_searchQuery) ||
          visitor.purpose.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // DATE / METRIC HELPERS
  // ---------------------------------------------------------------------------

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int get _todayPendingRequests {
    final now = DateTime.now();

    return _pendingVisitors.where((visitor) {
      final createdAt = visitor.createdAt;

      if (createdAt == null) {
        return false;
      }

      return _isSameDay(createdAt, now);
    }).length;
  }

  int get _todayEnteredVisitors {
    final now = DateTime.now();

    final activeToday = _activeVisitors.where((visitor) {
      final arrival = visitor.actualArrival;

      return arrival != null && _isSameDay(arrival, now);
    }).length;

    final completedToday = _historyVisitors.where((visitor) {
      final arrival = visitor.actualArrival;

      return arrival != null && _isSameDay(arrival, now);
    }).length;

    return activeToday + completedToday;
  }

  int get _todayCompletedVisits {
    final now = DateTime.now();

    return _historyVisitors.where((visitor) {
      final departure = visitor.departure;

      return departure != null && _isSameDay(departure, now);
    }).length;
  }

  int get _weeklyCompletedVisits {
    final now = DateTime.now();

    final startOfToday = DateTime(now.year, now.month, now.day);

    final startOfWeek = startOfToday.subtract(
      Duration(days: startOfToday.weekday - 1),
    );

    final startOfTomorrow = startOfToday.add(const Duration(days: 1));

    return _historyVisitors.where((visitor) {
      final departure = visitor.departure;

      if (departure == null) {
        return false;
      }

      return !departure.isBefore(startOfWeek) &&
          departure.isBefore(startOfTomorrow);
    }).length;
  }

  String get _activeAverageDuration {
    if (_activeVisitors.isEmpty) {
      return '-';
    }

    final now = DateTime.now();

    final durations = _activeVisitors
        .where((visitor) => visitor.actualArrival != null)
        .map((visitor) => now.difference(visitor.actualArrival!))
        .where((duration) => !duration.isNegative)
        .toList();

    if (durations.isEmpty) {
      return '-';
    }

    final totalMinutes = durations.fold<int>(
      0,
      (total, duration) => total + duration.inMinutes,
    );

    return _formatDurationMinutes(totalMinutes ~/ durations.length);
  }

  String get _historyAverageDuration {
    final durations = _historyVisitors
        .where(
          (visitor) =>
              visitor.actualArrival != null && visitor.departure != null,
        )
        .map((visitor) => visitor.departure!.difference(visitor.actualArrival!))
        .where((duration) => !duration.isNegative)
        .toList();

    if (durations.isEmpty) {
      return '-';
    }

    final totalMinutes = durations.fold<int>(
      0,
      (total, duration) => total + duration.inMinutes,
    );

    return _formatDurationMinutes(totalMinutes ~/ durations.length);
  }

  String _formatDurationMinutes(int totalMinutes) {
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  // ---------------------------------------------------------------------------
  // PAGE TEXT
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const StandardHeader(
        title: 'Visitor Management',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            _buildPageHeader(),

            const SizedBox(height: 20),

            _buildSummaryMetrics(),

            const SizedBox(height: 20),

            _buildSearchBar(),

            const SizedBox(height: 20),

            _buildTabSwitcher(),

            const SizedBox(height: 16),

            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  if (_currentTab != index) {
                    setState(() {
                      _currentTab = index;
                    });

                    HapticFeedback.lightImpact();
                  }
                },
                children: [
                  _buildPendingTab(),
                  _buildActiveTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onQRScannerTap,
        backgroundColor: AppColors.primaryTeal,
        elevation: 4,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
        label: const Text(
          'Scan QR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people,
              color: AppColors.primaryTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visitor Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSubtitleForTab(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textGray,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _onQRScannerTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: AppColors.primaryTeal,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY METRICS
  // ---------------------------------------------------------------------------

  Widget _buildSummaryMetrics() {
    switch (_currentTab) {
      case 0:
        return _buildMetricRow(
          first: _MetricCard(
            icon: Icons.pending_actions,
            iconColor: AppColors.warningOrange,
            iconBgColor: AppColors.softGoldBackground,
            value: _pendingVisitors.length.toString(),
            label: 'Pending',
            subtitle: 'Awaiting approval',
          ),
          second: _MetricCard(
            icon: Icons.today,
            iconColor: AppColors.primaryTeal,
            iconBgColor: const Color(0xFFE6F5F2),
            value: _todayPendingRequests.toString(),
            label: 'Today\'s Total',
            subtitle: 'Requests received',
          ),
          third: const _MetricCard(
            icon: Icons.timer,
            iconColor: AppColors.goldAccent,
            iconBgColor: AppColors.softGoldBackground,
            value: '-',
            label: 'Avg. Response',
            subtitle: 'Response time',
          ),
        );

      case 1:
        return _buildMetricRow(
          first: _MetricCard(
            icon: Icons.person_pin_circle,
            iconColor: AppColors.successGreen,
            iconBgColor: const Color(0xFFD1FAE5),
            value: _activeVisitors.length.toString(),
            label: 'Active',
            subtitle: 'Currently inside',
          ),
          second: _MetricCard(
            icon: Icons.today,
            iconColor: AppColors.primaryTeal,
            iconBgColor: const Color(0xFFE6F5F2),
            value: _todayEnteredVisitors.toString(),
            label: 'Today\'s Total',
            subtitle: 'Visitors today',
          ),
          third: _MetricCard(
            icon: Icons.access_time,
            iconColor: AppColors.goldAccent,
            iconBgColor: AppColors.softGoldBackground,
            value: _activeAverageDuration,
            label: 'Avg. Duration',
            subtitle: 'Stay duration',
          ),
        );

      case 2:
        return _buildMetricRow(
          first: _MetricCard(
            icon: Icons.history,
            iconColor: AppColors.goldAccent,
            iconBgColor: AppColors.softGoldBackground,
            value: _todayCompletedVisits.toString(),
            label: 'Today\'s Visits',
            subtitle: 'Completed visits',
          ),
          second: _MetricCard(
            icon: Icons.calendar_today,
            iconColor: AppColors.primaryTeal,
            iconBgColor: const Color(0xFFE6F5F2),
            value: _weeklyCompletedVisits.toString(),
            label: 'Weekly Total',
            subtitle: 'This week',
          ),
          third: _MetricCard(
            icon: Icons.timelapse,
            iconColor: AppColors.successGreen,
            iconBgColor: const Color(0xFFD1FAE5),
            value: _historyAverageDuration,
            label: 'Avg. Duration',
            subtitle: 'Visit duration',
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMetricRow({
    required Widget first,
    required Widget second,
    required Widget third,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
          const SizedBox(width: 12),
          Expanded(child: third),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search visitors...',
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABS
  // ---------------------------------------------------------------------------

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                label: 'Pending',
                isSelected: _currentTab == 0,
                onTap: () => _onTabChanged(0),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'Active',
                isSelected: _currentTab == 1,
                onTap: () => _onTabChanged(1),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'History',
                isSelected: _currentTab == 2,
                onTap: () => _onTabChanged(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PENDING TAB
  // ---------------------------------------------------------------------------

  Widget _buildPendingTab() {
    if (_pendingLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }

    if (_pendingError != null) {
      return _buildErrorState('Unable to load pending visitors');
    }

    final visitors = _filterVisitors(_pendingVisitors);

    if (visitors.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isEmpty ? 'No pending visitors' : 'No visitors found',
        _searchQuery.isEmpty
            ? 'Pending requests will appear here'
            : 'Try adjusting your search',
        Icons.pending_actions,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visitors.length,
      itemBuilder: (context, index) {
        final visitor = visitors[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < visitors.length - 1 ? 12 : 0,
          ),
          child: _PendingVisitorCard(
            visitor: visitor,
            onApprove: () => _onApproveVisitor(visitor.id, visitor.visitorName),
            onReject: () => _onRejectVisitor(visitor.id, visitor.visitorName),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVE TAB
  // ---------------------------------------------------------------------------

  Widget _buildActiveTab() {
    if (_activeLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }

    if (_activeError != null) {
      return _buildErrorState('Unable to load active visitors');
    }

    final visitors = _filterVisitors(_activeVisitors);

    if (visitors.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isEmpty ? 'No active visitors' : 'No visitors found',
        _searchQuery.isEmpty
            ? 'No visitors are currently inside'
            : 'Try adjusting your search',
        Icons.person_pin_circle,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visitors.length,
      itemBuilder: (context, index) {
        final visitor = visitors[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < visitors.length - 1 ? 12 : 0,
          ),
          child: _ActiveVisitorCard(
            visitor: visitor,
            onMarkExit: () => _onMarkExit(visitor.id, visitor.visitorName),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORY TAB
  // ---------------------------------------------------------------------------

  Widget _buildHistoryTab() {
    if (_historyLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }

    if (_historyError != null) {
      return _buildErrorState('Unable to load visit history');
    }

    final visitors = _filterVisitors(_historyVisitors);

    if (visitors.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isEmpty ? 'No visit history' : 'No visitors found',
        _searchQuery.isEmpty
            ? 'Completed visits will appear here'
            : 'Try adjusting your search',
        Icons.history,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visitors.length,
      itemBuilder: (context, index) {
        final visitor = visitors[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < visitors.length - 1 ? 12 : 0,
          ),
          child: _HistoryVisitorCard(visitor: visitor),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY / ERROR
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Helper Widgets

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;
  final String subtitle;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: AppColors.textGray,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textGray,
          ),
        ),
      ),
    );
  }
}

// Visitor Card Widgets

class _PendingVisitorCard extends StatelessWidget {
  final VisitorModel visitor;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingVisitorCard({
    required this.visitor,
    required this.onApprove,
    required this.onReject,
  });

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softGoldBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.warningOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.visitorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      visitor.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGoldBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warningOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Requested time
          Text(
            'Requested: ${_formatTime(visitor.createdAt)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: 12),
          // Details
          _DetailRow(label: 'Visiting:', value: visitor.residentName),
          const SizedBox(height: 8),
          _DetailRow(label: 'Unit:', value: visitor.flatLabel),
          const SizedBox(height: 8),
          _DetailRow(label: 'Purpose:', value: visitor.purpose),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(
                      color: AppColors.errorRed,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveVisitorCard extends StatelessWidget {
  final VisitorModel visitor;
  final VoidCallback onMarkExit;

  const _ActiveVisitorCard({required this.visitor, required this.onMarkExit});

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.successGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.visitorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      visitor.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Inside',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Entered time
          Text(
            'Entered: ${_formatTime(visitor.actualArrival)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(height: 12),
          // Details
          _DetailRow(label: 'Visiting:', value: visitor.residentName),
          const SizedBox(height: 8),
          _DetailRow(label: 'Unit:', value: visitor.flatLabel),
          const SizedBox(height: 8),
          _DetailRow(label: 'Purpose:', value: visitor.purpose),
          const SizedBox(height: 16),
          // Mark Exit Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onMarkExit,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'Mark Exit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                side: const BorderSide(color: AppColors.borderGray, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryVisitorCard extends StatelessWidget {
  final VisitorModel visitor;

  const _HistoryVisitorCard({required this.visitor});

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('h:mm a').format(dateTime);
  }

  String _calculateDuration() {
    if (visitor.actualArrival == null || visitor.departure == null) {
      return '-';
    }

    final duration = visitor.departure!.difference(visitor.actualArrival!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softGoldBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.goldAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.visitorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      visitor.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGoldBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _calculateDuration(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Entry and Exit times
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(visitor.actualArrival),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(visitor.departure),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details
          _DetailRow(label: 'Visiting:', value: visitor.residentName),
          const SizedBox(height: 8),
          _DetailRow(label: 'Unit:', value: visitor.flatLabel),
          const SizedBox(height: 8),
          _DetailRow(label: 'Purpose:', value: visitor.purpose),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textGray,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
