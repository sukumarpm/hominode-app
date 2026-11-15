import 'package:hominode_time/community_time.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'desktop/admin_desktop_page_frame.dart';
import 'qr_gate_scanner_screen.dart';
import 'services/visitor_service.dart';
import 'services/admin_tenant_context.dart';
import 'services/visitor_policy_service.dart';
import 'widgets/standard_header.dart';
import 'widgets/standard_bottom_nav.dart';

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
  final VisitorPolicyService? policyService;

  const VisitorManagementScreen({
    super.key,
    this.initialTab = 0,
    this.visitorService,
    this.policyService,
  });

  @override
  State<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  int _approvalCount = 0;
  final Set<String> _deciding = {};
  int _requestEpoch = 0;
  String? _community;
  late Stream<List<VisitorModel>> _expectedStream,
      _insideStream,
      _historyStream;

  late final VisitorPolicyService _policyService =
      widget.policyService ?? VisitorPolicyService();
  VisitorPolicyConfig? _actionPolicy;
  StreamSubscription<int>? _policySubscription;
  Timer? _policyBoundary;
  int _policyRequest = 0;
  final Map<String, String?> _residentTypes = {};
  final Map<String, StreamSubscription<String?>> _hostSubscriptions = {};

  void _clearHostSubscriptions() {
    for (final subscription in _hostSubscriptions.values) {
      subscription.cancel();
    }
    _hostSubscriptions.clear();
    _residentTypes.clear();
  }

  void _watchPolicy() {
    _policySubscription?.cancel();
    try {
      _policySubscription = _policyService.watch().listen(
        (_) => _loadPolicy(),
        onError: (_) => _loadPolicy(),
      );
    } catch (_) {
      /* Loading below reports unavailable policy context. */
    }
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final ticket = ++_policyRequest;
    _policyBoundary?.cancel();
    try {
      final config = await _policyService.load();
      if (!mounted || ticket != _policyRequest) return;
      setState(() {
        _actionPolicy = config;
        _clearHostSubscriptions();
      });
      final now = config.currentServerTime;
      final emergency = config.policy['emergency'] as Map?;
      final boundaries = [
        config.pendingSchedule?.effectiveAt,
        (emergency?['startAt'] as num?)?.toInt(),
        (emergency?['endAt'] as num?)?.toInt(),
      ].whereType<int>().where((time) => time > now).toList()..sort();
      if (boundaries.isNotEmpty) {
        _policyBoundary = Timer(
          Duration(milliseconds: boundaries.first - now + 1),
          _loadPolicy,
        );
      }
    } catch (_) {
      if (mounted && ticket == _policyRequest)
        setState(() => _actionPolicy = null);
    }
  }

  void _watchHostType(VisitorModel visitor) {
    if (_actionPolicy?.policy['enabled'] != true ||
        _actionPolicy?.policy['approvalMode'] != 'tenant_approval_required' ||
        !visitorBelongsInExpectedQueue(visitor.lifecycleData) ||
        _hostSubscriptions.containsKey(visitor.residentId))
      return;
    final ticket = _policyRequest;
    try {
      _hostSubscriptions[visitor.residentId] = _visitorService
          .watchVisitorHostResidentType(visitor)
          .listen(
            (type) {
              if (mounted && ticket == _policyRequest)
                setState(() => _residentTypes[visitor.residentId] = type);
            },
            onError: (_) {
              if (mounted && ticket == _policyRequest)
                setState(() => _residentTypes.remove(visitor.residentId));
            },
          );
    } catch (_) {
      /* The server still checks the host before any mutation. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPolicy();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTab = widget.initialTab;
    _visitorService = widget.visitorService ?? VisitorService();
    _community = AdminTenantContext.instance.communityId;
    _setStreams();
    _watchPolicy();
    AdminTenantContext.instance.addListener(_communityChanged);
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
    AdminTenantContext.instance.removeListener(_communityChanged);
    _pageController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    _policyRequest++;
    _policyBoundary?.cancel();
    _policySubscription?.cancel();
    _clearHostSubscriptions();
    WidgetsBinding.instance.removeObserver(this);
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

  void _setStreams() {
    Stream<List<VisitorModel>> relisten(
      Stream<List<VisitorModel>> Function() source,
    ) => Stream.multi((controller) {
      try {
        final subscription = source().listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      } catch (error, stack) {
        controller.addError(error, stack);
        controller.close();
      }
    }, isBroadcast: true);
    _expectedStream = relisten(_visitorService.getPendingVisitors);
    _insideStream = relisten(_visitorService.getActiveVisitors);
    _historyStream = relisten(_visitorService.getHistoryVisitors);
  }

  void _communityChanged() {
    final next = AdminTenantContext.instance.communityId;
    if (next == _community) {
      setState(() {});
      return;
    }
    _requestEpoch++;
    _policyRequest++;
    _actionPolicy = null;
    _clearHostSubscriptions();
    _watchPolicy();
    setState(() {
      _community = next;
      _deciding.clear();
      _searchQuery = '';
      _searchController.clear();
      _pendingCount = 0;
      _activeCount = 0;
      _historyCount = 0;
      _approvalCount = 0;
      _setStreams();
    });
  }

  Future<void> _decision(
    VisitorModel visitor,
    AdminVisitorAction action,
  ) async {
    if (_deciding.contains(visitor.id)) return;
    final epoch = _requestEpoch;
    final verb = action.name;
    setState(() => _deciding.add(visitor.id));
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${verb[0].toUpperCase()}${verb.substring(1)} visitor?'),
          content: Text(
            '${visitor.visitorName} · ${visitor.flatLabel}\nThis records authorization only. Security still verifies entry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel decision'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirm $verb'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || epoch != _requestEpoch) return;
      if (action == AdminVisitorAction.approve ||
          action == AdminVisitorAction.reapprove) {
        await _visitorService.approveVisitor(
          visitor.id,
          expectedRevision: visitor.authorizationRevision,
        );
      } else if (action == AdminVisitorAction.revoke) {
        await _visitorService.revokeVisitor(
          visitor.id,
          expectedRevision: visitor.authorizationRevision,
        );
      } else {
        await _visitorService.rejectVisitor(
          visitor.id,
          expectedRevision: visitor.authorizationRevision,
        );
      }
      if (mounted && epoch == _requestEpoch) {
        _showSnackBar(
          'Decision confirmed by the server. Security still verifies entry.',
          const Color(0xFF16A34A),
          Icons.check_circle,
        );
        setState(_setStreams);
      }
    } catch (error) {
      if (mounted && epoch == _requestEpoch) {
        _showSnackBar(
          visitorPolicyError(error),
          const Color(0xFFEF4444),
          Icons.error,
        );
        setState(_setStreams);
      }
    } finally {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _deciding.remove(visitor.id));
      }
    }
  }

  void _onMarkExit(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();

    try {
      await _visitorService.checkOutVisitor(visitorId);

      if (mounted) {
        _showSnackBar(
          'visitor_checked_out_message'.tr(namedArgs: {'name': visitorName}),
          const Color(0xFF16A34A),
          Icons.logout,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'visitor_checkout_failed'.tr(namedArgs: {'error': '$e'}),
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
        title: 'visitors_title'.tr(),
        subtitle: 'visitors_subtitle'.tr(),
        actions: [
          AdminDesktopPrimaryAction(
            label: 'visitor_scan_qr'.tr(),
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
                  _buildPendingTab(approvalOnly: true),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 5),
      body: LayoutBuilder(
        builder: (context, viewport) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            StandardHeader(title: 'visitor_management_title'.tr()),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // Page Header - matching other screens
                  _buildPageHeader(),

                  SizedBox(height: 16),

                  // Summary Metrics - exact spacing from other screens
                  _buildSummaryMetrics(),

                  SizedBox(height: 20),

                  // Search Bar - matching parcel screen
                  _buildSearchBar(),

                  SizedBox(height: 20),

                  // Tab Switcher - matching complaint screen
                  _buildTabSwitcher(),

                  SizedBox(height: 16),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: viewport.maxHeight * 0.45,
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
                    _buildPendingTab(approvalOnly: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onQRScannerTap,
        backgroundColor: const Color(0xFF0E4778),
        elevation: 4,
        icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
        label: Text(
          'visitor_scan_qr'.tr(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Page Header - matching reports screen pattern exactly
  Widget _buildPageHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.people, color: Color(0xFF0E4778), size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'visitor_management_title'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _getSubtitleForTab(),
                  style: TextStyle(
                    fontSize: 14,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0E4778).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF0E4778),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitleForTab() {
    switch (_currentTab) {
      case 3:
        return 'Invitations awaiting a Community Admin decision';
      case 0:
        return 'visitor_expected_subtitle'.tr();
      case 1:
        return 'visitor_active_subtitle'.tr();
      case 2:
        return 'visitor_history_all_subtitle'.tr();
      default:
        return 'visitor_default_subtitle'.tr();
    }
  }

  // Summary Metrics - matching complaint screen pattern exactly
  Widget _buildSummaryMetrics() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
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
          SizedBox(width: 12),
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
          SizedBox(width: 12),
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
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
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
      case 3:
      case 0: // Pending
        return [
          _currentTab == 3 ? 'Pending approval' : 'visitor_tab_expected'.tr(),
          'visitor_today_total'.tr(),
          'visitor_average_response'.tr(),
        ][index];
      case 1: // Active
        return [
          'visitor_status_active'.tr(),
          'visitor_today_total'.tr(),
          'visitor_average_duration'.tr(),
        ][index];
      case 2: // History
        return [
          'visitor_tab_history'.tr(),
          'visitor_weekly_total'.tr(),
          'visitor_average_duration'.tr(),
        ][index];
      default:
        return '';
    }
  }

  String _getStatValue(int index) {
    switch (_currentTab) {
      case 3:
        return [
          _approvalCount.toString(),
          _approvalCount.toString(),
          '-',
        ][index];
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
      case 3:
      case 0: // Pending
        return [
          'visitor_waiting_arrival'.tr(),
          'visitor_requests_received'.tr(),
          'visitor_response_time'.tr(),
        ][index];
      case 1: // Active
        return [
          'visitor_currently_inside'.tr(),
          'visitor_today_visitors'.tr(),
          'visitor_stay_duration'.tr(),
        ][index];
      case 2: // History
        return [
          'visitor_records'.tr(),
          'visitor_this_week'.tr(),
          'visitor_visit_duration'.tr(),
        ][index];
      default:
        return '';
    }
  }

  IconData _getStatIcon(int index) {
    switch (_currentTab) {
      case 3:
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
      case 3:
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
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            hintText: 'visitor_search_hint'.tr(),
            hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: Color(0xFF9CA3AF)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : IconButton(
                    tooltip: 'Refresh visitors',
                    onPressed: () => setState(_setStreams),
                    icon: const Icon(Icons.refresh),
                  ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          children: [
            _buildTabButton('visitor_tab_expected'.tr(), 0),
            _buildTabButton('visitor_status_inside'.tr(), 1),
            _buildTabButton('visitor_tab_history'.tr(), 2),
            _buildTabButton('Pending approval', 3),
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
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
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
  Widget _buildPendingTab({bool approvalOnly = false}) {
    return StreamBuilder<List<VisitorModel>>(
      stream: _expectedStream,
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
                    'visitor_load_failed'.tr(
                      namedArgs: {'error': '${snapshot.error}'},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        final visitors = (snapshot.data ?? <VisitorModel>[])
            .where(
              (row) =>
                  visitorRequiresAdminApproval(row.lifecycleData) ==
                  approvalOnly,
            )
            .toList();

        // Update count
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              (approvalOnly ? _approvalCount : _pendingCount) !=
                  visitors.length) {
            setState(() {
              if (approvalOnly) {
                _approvalCount = visitors.length;
              } else {
                _pendingCount = visitors.length;
              }
            });
          }
        });

        final filteredVisitors = _getFilteredVisitors(visitors);

        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions,
            title: _searchQuery.isNotEmpty
                ? 'visitor_no_search_results'.tr()
                : approvalOnly
                ? 'No invitations awaiting Admin approval'
                : 'visitor_no_expected_visitors'.tr(),
            subtitle: _searchQuery.isNotEmpty
                ? 'visitor_adjust_search'.tr()
                : 'visitor_all_requests_processed'.tr(),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
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
      stream: _insideStream,
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
                    'visitor_load_failed'.tr(
                      namedArgs: {'error': '${snapshot.error}'},
                    ),
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
                ? 'visitor_no_search_results'.tr()
                : 'visitor_no_active_visitors'.tr(),
            subtitle: _searchQuery.isNotEmpty
                ? 'visitor_adjust_search'.tr()
                : 'visitor_none_inside'.tr(),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
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
      stream: _historyStream,
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
                    'visitor_load_failed'.tr(
                      namedArgs: {'error': '${snapshot.error}'},
                    ),
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
                ? 'visitor_no_search_results'.tr()
                : 'visitor_no_history_records'.tr(),
            subtitle: _searchQuery.isNotEmpty
                ? 'visitor_adjust_search'.tr()
                : 'visitor_history_all_subtitle'.tr(),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
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
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  // Pending visitor card - matching exact Flow UI patterns
  Widget _buildPendingVisitorCard(VisitorModel visitor) {
    _watchHostType(visitor);
    final policy = _actionPolicy;
    final actions = visitorDecisionActions(
      visitor.lifecycleData,
      policy: policy?.policy,
      now: policy == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              policy.currentServerTime,
              isUtc: true,
            ),
      residentType: _residentTypes[visitor.residentId],
    );

    return Container(
      key: ValueKey('visitor-${visitor.id}'),
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
                    (visitor.isApproved
                            ? 'visitor_status_approved'
                            : 'visitor_status_pending')
                        .tr(),
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
              'visitor_requested_at'.tr(
                namedArgs: {
                  'time': visitor.createdAt != null
                      ? _formatTime(visitor.createdAt!)
                      : 'not_available'.tr(),
                },
              ),
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
                  _buildDetailRow(
                    'visitor_visiting_label'.tr(),
                    visitor.residentName,
                  ),
                  SizedBox(height: 8.h),
                  _buildDetailRow('visitor_unit_label'.tr(), visitor.flatLabel),
                  SizedBox(height: 8.h),
                  _buildDetailRow(
                    'visitor_purpose_label'.tr(),
                    visitor.purpose,
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              'Authorization: ${visitorAuthorizationLabel(visitor.lifecycleData)}',
            ),
            const Text('Physical visit: Expected — not checked in'),
            if (visitor.expectedTime != null)
              Text('Expected: ${_formatDateTime(visitor.expectedTime!)}'),
            if (visitor.bringingPet) const Text('Bringing a pet'),
            // Action visibility is advisory; every callback is server/revision checked.
            if (actions.isNotEmpty)
              Row(
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) SizedBox(width: 12.w),
                    Expanded(child: _authorizationButton(visitor, actions[i])),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _authorizationButton(VisitorModel visitor, AdminVisitorAction action) {
    final label = switch (action) {
      AdminVisitorAction.approve => 'visitor_approve_action'.tr(),
      AdminVisitorAction.reject => 'visitor_reject_action'.tr(),
      AdminVisitorAction.reapprove => 'Reapprove',
      AdminVisitorAction.revoke => 'Revoke',
    };
    final onPressed = _deciding.contains(visitor.id)
        ? null
        : () => _decision(visitor, action);
    if (action == AdminVisitorAction.reject ||
        action == AdminVisitorAction.revoke) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          side: const BorderSide(color: Color(0xFFEF4444)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFEF4444),
          ),
        ),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // Active visitor card - matching exact Flow UI patterns
  Widget _buildActiveVisitorCard(VisitorModel visitor) {
    return Container(
      key: ValueKey('visitor-${visitor.id}'),
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
            Text(
              visitor.authorizationState != null || visitor.compatibilityIssued
                  ? 'Authorization: ${visitorAuthorizationLabel(visitor.lifecycleData)}'
                  : visitor.isApproved
                  ? 'Legacy approval recorded'
                  : 'visitor_admin_not_recorded'.tr(),
            ),
            SizedBox(height: 8.h),
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
                    'visitor_status_inside'.tr(),
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
              'visitor_entered_at'.tr(
                namedArgs: {
                  'time': visitor.checkInTime != null
                      ? _formatTime(visitor.checkInTime!)
                      : 'not_available'.tr(),
                },
              ),
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
                  _buildDetailRow(
                    'visitor_visiting_label'.tr(),
                    visitor.residentName,
                  ),
                  SizedBox(height: 8.h),
                  _buildDetailRow('visitor_unit_label'.tr(), visitor.flatLabel),
                  SizedBox(height: 8.h),
                  _buildDetailRow(
                    'visitor_purpose_label'.tr(),
                    visitor.purpose,
                  ),
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
                  'visitor_mark_exit_action'.tr(),
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
    final entryTime = visitor.checkInTime;
    final exitTime = visitor.checkOutTime;
    final spansMultipleDays =
        entryTime != null &&
        exitTime != null &&
        !_isSameCalendarDay(entryTime, exitTime);
    final historyLabel = 'visitor_status_${visitor.status}'.tr();

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
                    historyLabel,
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
                          'visitor_entry_label'.tr(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          entryTime == null
                              ? '—'
                              : spansMultipleDays
                              ? _formatDateTime(entryTime)
                              : _formatTime(entryTime),
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
                          'visitor_exit_label'.tr(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          exitTime == null
                              ? '—'
                              : spansMultipleDays
                              ? _formatDateTime(exitTime)
                              : _formatTime(exitTime),
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
            if (entryTime != null && exitTime != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(_formatDuration(exitTime.difference(entryTime))),
              ),
            if (visitor.gateEntryDenialReason?.isNotEmpty == true)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(visitor.gateEntryDenialReason!),
              ),
          ],
        ),
      ),
    );
  }

  // Detail row helper - exact typography matching
  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            'visitor_detail_label_format'.tr(namedArgs: {'label': label}),
            softWrap: true,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          flex: 6,
          child: Text(
            value,
            softWrap: true,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String? get _timeZone => AdminTenantContext.instance.activeTenant?.timeZone;

  String _formatTime(DateTime time) => CommunityTime.format(
    time,
    _timeZone,
    dateFormat: DateFormat('d MMM y, h:mm a', context.locale.toString()).format,
  );

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    try {
      return CommunityTime.dayDifference(first, second, _timeZone) == 0;
    } on FormatException {
      return false;
    }
  }

  String _formatDateTime(DateTime time) => CommunityTime.format(
    time,
    _timeZone,
    dateFormat: DateFormat('d MMM y, h:mm a', context.locale.toString()).format,
  );

  // Duration formatting helper
  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    if (days > 0) {
      final parts = <String>[
        'visitor_duration_days'.tr(namedArgs: {'count': '$days'}),
      ];

      if (hours > 0) {
        parts.add('visitor_duration_hours'.tr(namedArgs: {'count': '$hours'}));
      }

      if (minutes > 0 || hours == 0) {
        parts.add(
          'visitor_duration_minutes'.tr(namedArgs: {'count': '$minutes'}),
        );
      }

      return parts.join(' ');
    }

    if (hours > 0) {
      return 'visitor_duration_hours_minutes'.tr(
        namedArgs: {'hours': '$hours', 'minutes': '$minutes'},
      );
    }

    return 'visitor_duration_minutes'.tr(namedArgs: {'count': '$minutes'});
  }
}
