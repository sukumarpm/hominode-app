import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../utils/app_colors.dart';
import '../widgets/standard_header.dart';
import 'qr_scanner_screen.dart';

class VisitorManagementScreen extends StatefulWidget {
  final int initialTab;
  final VisitorWorkflow? visitorWorkflow;

  const VisitorManagementScreen({
    super.key,
    this.initialTab = 0,
    this.visitorWorkflow,
  });

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

  late final VisitorWorkflow _visitorService =
      widget.visitorWorkflow ?? VisitorService();

  // ---------------------------------------------------------------------------
  // Cached visitor lists.
  //
  // Each VisitorService stream is listened to exactly ONCE.
  // Metrics and tab content both read from these cached lists.
  // ---------------------------------------------------------------------------
  List<VisitorModel> _activeVisitors = [];
  List<VisitorModel> _historyVisitors = [];
  List<VisitorModel> _expectedVisitors = [];

  bool _activeLoading = true;
  bool _historyLoading = true;
  bool _expectedLoading = true;
  bool _isRefreshing = false;
  bool _selectionMode = false;
  bool _isCheckoutDialogOpen = false;
  bool _isCheckoutSubmitting = false;
  String? _checkoutError;
  final Set<String> _selectedActiveVisitorIds = {};
  String? _pendingCheckoutOperationId;
  List<String>? _pendingCheckoutIds;

  Object? _activeError;
  Object? _historyError;
  Object? _expectedError;

  bool _isChangingTab = false;

  bool get _isCheckoutBusy => _isCheckoutDialogOpen || _isCheckoutSubmitting;

  @override
  void initState() {
    super.initState();

    _currentTab = widget.initialTab;
    _pageController = PageController(initialPage: _currentTab);

    _refreshVisitors();

    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _refreshVisitors() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _expectedLoading = _expectedVisitors.isEmpty;
      _activeLoading = _activeVisitors.isEmpty;
      _historyLoading = _historyVisitors.isEmpty;
    });

    final results = await Future.wait([
      _loadVisitorCategory('expected'),
      _loadVisitorCategory('inside'),
      _loadVisitorCategory('completed'),
    ]);
    if (!mounted) return;
    setState(() {
      _expectedVisitors = results[0].visitors;
      _expectedError = results[0].error;
      _expectedLoading = false;
      _activeVisitors = results[1].visitors;
      _activeError = results[1].error;
      _activeLoading = false;
      _historyVisitors = results[2].visitors;
      _historyError = results[2].error;
      _historyLoading = false;
      _isRefreshing = false;
      _selectedActiveVisitorIds.removeWhere(
        (id) => !_activeVisitors.any((visitor) => visitor.id == id),
      );
      if (_selectedActiveVisitorIds.isEmpty) _selectionMode = false;
    });
  }

  Future<({List<VisitorModel> visitors, Object? error})> _loadVisitorCategory(
    String category,
  ) async {
    try {
      return (
        visitors: await _visitorService.getVisitors(category),
        error: null,
      );
    } catch (error) {
      return (visitors: <VisitorModel>[], error: error);
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _pageController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // TAB NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _onTabChanged(int index) async {
    if (index == _currentTab || _isChangingTab || _isCheckoutBusy) {
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

  Future<void> _onMarkExit(String visitorId, String visitorName) async {
    if (_isCheckoutBusy) return;
    final matches = _activeVisitors.where((item) => item.id == visitorId);
    if (matches.isEmpty) return;
    final visitor = matches.first;
    await _confirmCheckout(
      [visitor],
      title: 'Mark Visitor Out?',
      description: 'Confirm that $visitorName has left the property.',
    );
  }

  Future<void> _confirmCheckout(
    List<VisitorModel> visitors, {
    String? title,
    String? description,
  }) async {
    if (visitors.isEmpty || _isCheckoutBusy || !mounted) return;
    HapticFeedback.mediumImpact();
    final names = visitors.map((visitor) => visitor.visitorName).join(', ');
    final ids = visitors.map((visitor) => visitor.id).toList();
    setState(() {
      _isCheckoutDialogOpen = true;
      _checkoutError = null;
    });

    Map<String, dynamic>? response;
    try {
      response = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !_isCheckoutSubmitting,
            child: AlertDialog(
              title: Text(title ?? 'Mark ${visitors.length} Visitors Out?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description ?? 'Confirm these visitors have left: $names',
                  ),
                  if (_checkoutError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _checkoutError!,
                      style: const TextStyle(color: AppColors.errorRed),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isCheckoutSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _isCheckoutSubmitting
                      ? null
                      : () async {
                          setState(() {
                            _isCheckoutSubmitting = true;
                            _checkoutError = null;
                          });
                          setDialogState(() {});
                          final operationId = _checkoutOperationFor(ids);
                          final result = await _submitCheckout(
                            ids,
                            operationId,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          setDialogState(() {});
                          if (result != null) {
                            Navigator.of(dialogContext).pop(result);
                          }
                        },
                  child: _isCheckoutSubmitting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Checking Out…'),
                          ],
                        )
                      : Text(
                          _checkoutError == null
                              ? 'Mark Out'
                              : 'Retry Checkout',
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckoutDialogOpen = false;
          _isCheckoutSubmitting = false;
          _checkoutError = null;
        });
      }
    }
    if (response == null || !mounted) return;

    final succeeded = (response['succeeded'] as num?)?.toInt() ?? 0;
    final failed =
        (response['failed'] as num?)?.toInt() ?? ids.length - succeeded;
    await _showCheckoutResults(response, succeeded, failed);
    if (mounted) await _refreshVisitors();
  }

  bool _sameIds(List<String> left, List<String> right) =>
      left.length == right.length && left.toSet().containsAll(right);

  String _checkoutOperationFor(List<String> ids) {
    if (_pendingCheckoutIds == null || !_sameIds(_pendingCheckoutIds!, ids)) {
      _pendingCheckoutIds = List<String>.from(ids);
      _pendingCheckoutOperationId = _visitorService.newOperationId();
    }
    return _pendingCheckoutOperationId!;
  }

  Future<Map<String, dynamic>?> _submitCheckout(
    List<String> visitorIds,
    String operationId,
  ) async {
    try {
      final response = await _visitorService.checkoutVisitors(
        visitorIds: visitorIds,
        operationId: operationId,
      );
      if (!mounted) return null;
      _pendingCheckoutIds = null;
      _pendingCheckoutOperationId = null;
      setState(() {
        _isCheckoutSubmitting = false;
        _selectedActiveVisitorIds.clear();
        _selectionMode = false;
      });
      return response;
    } catch (error) {
      debugPrint('Visitor checkout failed (${error.runtimeType}).');
      if (!mounted) return null;
      setState(() {
        _isCheckoutSubmitting = false;
        _checkoutError = 'Checkout could not be confirmed. Please retry.';
      });
      return null;
    }
  }

  Future<void> _showCheckoutResults(
    Map<String, dynamic> response,
    int succeeded,
    int failed,
  ) async {
    final rawResults = response['results'];
    final results = rawResults is List
        ? rawResults.whereType<Map>().toList()
        : const <Map>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(failed == 0 ? 'Checkout Complete' : 'Checkout Results'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$succeeded marked out; $failed failed.'),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: results.map((result) {
                    final id = result['visitorId']?.toString() ?? '';
                    final matches = _activeVisitors.where(
                      (item) => item.id == id,
                    );
                    final name = matches.isEmpty
                        ? id
                        : matches.first.visitorName;
                    final success = result['success'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        success ? Icons.check_circle : Icons.error_outline,
                        color: success
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                      title: Text(name),
                      subtitle: success
                          ? const Text('Marked out')
                          : Text(
                              result['message']?.toString() ??
                                  'Checkout failed',
                            ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _onDenyEntry(VisitorModel visitor) async {
    var denialReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deny Visitor Entry'),
        content: TextField(
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Operational reason',
            hintText: 'Enter the reason for denying entry',
          ),
          onChanged: (value) => denialReason = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = denialReason.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || reason == null || reason.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Denial'),
        content: Text(
          'Deny entry for ${visitor.visitorName}? This invitation cannot be used to enter afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deny Entry'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _visitorService.denyVisitorEntry(
        visitorId: visitor.id,
        reason: reason,
        operationId: _visitorService.newOperationId(),
      );
      if (!mounted) return;
      _showSnackBar(
        'Entry denied for ${visitor.visitorName}',
        AppColors.warningOrange,
        Icons.block,
      );
      await _refreshVisitors();
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Visitor entry denial failed: ${error.code}');
      if (!mounted) return;
      _showSnackBar(
        'Unable to deny entry. Refresh and retry.',
        AppColors.errorRed,
        Icons.error,
      );
      await _refreshVisitors();
    } catch (error) {
      debugPrint('Visitor entry denial failed (${error.runtimeType}).');
      if (!mounted) return;
      _showSnackBar(
        'Unable to deny entry. Refresh and retry.',
        AppColors.errorRed,
        Icons.error,
      );
    }
  }

  Future<void> _showManualCodeDialog() async {
    var manualCode = '';
    var operationId = '';
    var isSubmitting = false;
    String? errorMessage;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            final code = manualCode.trim();
            if (code.isEmpty || isSubmitting) return;
            operationId = operationId.isEmpty
                ? _visitorService.newOperationId()
                : operationId;
            setDialogState(() {
              isSubmitting = true;
              errorMessage = null;
            });
            try {
              final verified = await _visitorService.verifyVisitorCredential(
                manualCode: code,
                operationId: operationId,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, verified);
            } on FirebaseFunctionsException catch (error) {
              debugPrint('Manual visitor verification failed: ${error.code}');
              if (dialogContext.mounted) {
                setDialogState(() {
                  isSubmitting = false;
                  errorMessage =
                      'Code could not be verified. Check it and retry.';
                });
              }
            } catch (error) {
              debugPrint(
                'Manual visitor verification failed (${error.runtimeType}).',
              );
              if (dialogContext.mounted) {
                setDialogState(() {
                  isSubmitting = false;
                  errorMessage =
                      'Verification could not be confirmed. Retry safely.';
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Verify Manual Visitor Code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Visitor code'),
                  onChanged: (value) {
                    setDialogState(() {
                      manualCode = value;
                      operationId = '';
                      errorMessage = null;
                    });
                  },
                  onSubmitted: (_) {
                    if (!isSubmitting && manualCode.trim().isNotEmpty) {
                      submit();
                    }
                  },
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: AppColors.errorRed),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(errorMessage == null ? 'Verify' : 'Retry'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || result == null) return;
    _showSnackBar(
      'Entry verified for ${result['visitorName'] ?? 'visitor'}',
      AppColors.successGreen,
      Icons.check_circle,
    );
    await _refreshVisitors();
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

    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    ).then((_) => _refreshVisitors());
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
        return 'Verify a visitor QR or manual code to record gate entry';

      case 1:
        return 'View visitors checked in at the gate';

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
        onPressed: _isCheckoutBusy ? null : _onQRScannerTap,
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
          IconButton(
            tooltip: 'Refresh visitor lists',
            onPressed: _isRefreshing || _isCheckoutBusy
                ? null
                : _refreshVisitors,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: AppColors.primaryTeal),
          ),
          IconButton(
            tooltip: 'Scan visitor pass',
            onPressed: _isCheckoutBusy ? null : _onQRScannerTap,
            icon: const Icon(
              Icons.qr_code_scanner,
              color: AppColors.primaryTeal,
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
            value: 'QR',
            label: 'Expected',
            subtitle: 'Credential verification',
          ),
          second: _MetricCard(
            icon: Icons.today,
            iconColor: AppColors.primaryTeal,
            iconBgColor: const Color(0xFFE6F5F2),
            value: '—',
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
            label: 'Checked In',
            subtitle: 'Currently checked in',
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
                label: 'Expected',
                isSelected: _currentTab == 0,
                onTap: () => _onTabChanged(0),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'Checked In',
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
    if (_expectedLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }
    if (_expectedError != null) {
      return _buildRetryState('Unable to load expected visitors');
    }
    final visitors = _filterVisitors(_expectedVisitors);
    if (visitors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty
                    ? 'No expected visitors'
                    : 'No visitors found',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGray, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan a visitor pass or enter its manual code to verify entry.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGray, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isCheckoutBusy ? null : _onQRScannerTap,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isCheckoutBusy ? null : _showManualCodeDialog,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter Code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visitors.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _showManualCodeDialog,
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter Manual Code'),
              ),
            ),
          );
        }
        final visitor = visitors[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ExpectedVisitorCard(
            visitor: visitor,
            onDeny: visitor.gateAccessStatus == 'denied'
                ? null
                : () => _onDenyEntry(visitor),
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
      return _buildRetryState('Unable to load active visitors');
    }

    final visitors = _filterVisitors(_activeVisitors);

    if (visitors.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isEmpty ? 'No checked-in visitors' : 'No visitors found',
        _searchQuery.isEmpty
            ? 'No visitors are currently checked in'
            : 'Try adjusting your search',
        Icons.person_pin_circle,
      );
    }

    final selectedVisitors = visitors
        .where((visitor) => _selectedActiveVisitorIds.contains(visitor.id))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              TextButton(
                onPressed: _isCheckoutBusy
                    ? null
                    : () {
                        setState(() {
                          if (_selectionMode &&
                              selectedVisitors.length == visitors.length) {
                            _selectedActiveVisitorIds.clear();
                          } else {
                            _selectionMode = true;
                            _selectedActiveVisitorIds
                              ..clear()
                              ..addAll(visitors.map((visitor) => visitor.id));
                          }
                          if (_selectedActiveVisitorIds.isEmpty) {
                            _selectionMode = false;
                          }
                        });
                      },
                child: Text(
                  selectedVisitors.length == visitors.length
                      ? 'Clear Selection'
                      : 'Select All',
                ),
              ),
              const Spacer(),
              if (_selectionMode) ...[
                Text('${selectedVisitors.length} selected'),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: selectedVisitors.isEmpty || _isCheckoutBusy
                      ? null
                      : () => _confirmCheckout(selectedVisitors),
                  child: const Text('Mark Out'),
                ),
              ] else
                TextButton(
                  onPressed: _isCheckoutBusy
                      ? null
                      : () => setState(() => _selectionMode = true),
                  child: const Text('Select'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
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
                  selectionMode: _selectionMode,
                  checkoutInProgress: _isCheckoutBusy,
                  selected: _selectedActiveVisitorIds.contains(visitor.id),
                  onSelected: (selected) {
                    if (_isCheckoutBusy) return;
                    setState(() {
                      if (selected) {
                        _selectedActiveVisitorIds.add(visitor.id);
                        _selectionMode = true;
                      } else {
                        _selectedActiveVisitorIds.remove(visitor.id);
                        if (_selectedActiveVisitorIds.isEmpty) {
                          _selectionMode = false;
                        }
                      }
                    });
                  },
                  onMarkExit: () =>
                      _onMarkExit(visitor.id, visitor.visitorName),
                ),
              );
            },
          ),
        ),
      ],
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
      return _buildRetryState('Unable to load visit history');
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

  Widget _buildRetryState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGray, fontSize: 15),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isRefreshing ? null : _refreshVisitors,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
              fontSize: 16,
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
              fontSize: 10,
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
              fontSize: 8,
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

class _ExpectedVisitorCard extends StatelessWidget {
  const _ExpectedVisitorCard({required this.visitor, required this.onDeny});

  final VisitorModel visitor;
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    final denied = visitor.gateAccessStatus == 'denied';
    final arrival = visitor.expectedTime == null
        ? '—'
        : DateFormat('MMM d, h:mm a').format(visitor.expectedTime!);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.primaryTeal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    visitor.visitorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    denied
                        ? 'Entry Denied'
                        : visitor.isApproved
                        ? 'Admin Approved'
                        : 'Expected',
                  ),
                  backgroundColor: denied
                      ? Colors.red.shade50
                      : Colors.teal.shade50,
                  labelStyle: TextStyle(
                    color: denied ? AppColors.errorRed : AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DetailRow(label: 'Unit:', value: visitor.flatLabel),
            const SizedBox(height: 6),
            _DetailRow(label: 'Host:', value: visitor.residentName),
            const SizedBox(height: 6),
            _DetailRow(label: 'Purpose:', value: visitor.purpose),
            const SizedBox(height: 6),
            _DetailRow(label: 'Expected:', value: arrival),
            if (denied &&
                (visitor.gateEntryDenialReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${visitor.gateEntryDenialReason}',
                style: const TextStyle(color: AppColors.errorRed),
              ),
            ],
            if (!denied) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDeny,
                  icon: const Icon(Icons.block),
                  label: const Text('Deny Entry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveVisitorCard extends StatelessWidget {
  final VisitorModel visitor;
  final VoidCallback onMarkExit;
  final bool selectionMode;
  final bool checkoutInProgress;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _ActiveVisitorCard({
    required this.visitor,
    required this.onMarkExit,
    required this.selectionMode,
    required this.checkoutInProgress,
    required this.selected,
    required this.onSelected,
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
              if (selectionMode)
                Checkbox(
                  value: selected,
                  onChanged: checkoutInProgress
                      ? null
                      : (value) => onSelected(value == true),
                )
              else
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
                    'Checked In',
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
            'Checked in: ${_formatTime(visitor.actualArrival)}',
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
          // Mark Out Button
          if (!selectionMode)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: checkoutInProgress ? null : onMarkExit,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Mark Out',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(
                    color: AppColors.borderGray,
                    width: 1.5,
                  ),
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

  String _formatDenialTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('MMM d, h:mm a').format(dateTime);
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
                  visitor.gateAccessStatus == 'denied'
                      ? 'Entry Denied'
                      : 'Checked Out',
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
          // Denials have no physical entry/exit times. Show their own
          // server-recorded event timestamp; completed visits retain times.
          if (visitor.gateAccessStatus == 'denied')
            _DetailRow(
              label: 'Denied:',
              value: _formatDenialTime(visitor.gateEntryDeniedAt),
            )
          else
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
          if (visitor.gateAccessStatus == 'denied' &&
              (visitor.gateEntryDenialReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            _DetailRow(label: 'Reason:', value: visitor.gateEntryDenialReason!),
          ],
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
