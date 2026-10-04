import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/standard_header.dart';
import 'services/reports_service.dart';
import 'widgets/reports_charts.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key, ReportsService? reportsService})
    : _reportsService = reportsService;

  final ReportsService? _reportsService;

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  late final ReportsService _reportsService;

  DateTime selectedDate = DateTime.now();
  int selectedTabIndex = 0; // 0: Financial, 1: Occupancy, 2: Complaints

  // Data holders
  FinancialSummary? _financialSummary;
  OccupancySummary? _occupancySummary;
  List<BuildingOccupancy> _buildingOccupancies = [];
  ComplaintsSummary? _complaintsSummary;
  List<MonthlyComplaints> _complaintsTrends = [];
  int? _deliveriesCount;
  String? _financialLoadError;
  bool _occupancyLoading = true;
  String? _occupancyLoadError;
  bool _complaintsLoading = true;
  String? _complaintsLoadError;

  bool _isLoading = true;

  final List<String> tabs = ['Financial', 'Occupancy', 'Complaints'];

  @override
  void initState() {
    super.initState();
    _reportsService = widget._reportsService ?? ReportsService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all data in parallel
      await Future.wait([
        _loadFinancialData(),
        _loadOccupancyData(),
        _loadComplaintsData(),
        _loadDeliveriesData(),
      ]);
    } catch (e) {
      print('Error loading reports data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFinancialData() async {
    try {
      final summary = await _reportsService.getFinancialSummary(
        year: selectedDate.year,
        month: selectedDate.month,
      );

      if (mounted) {
        setState(() {
          _financialSummary = summary;
          _financialLoadError = null;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _financialSummary = null;
          _financialLoadError = error.userMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _financialSummary = null;
          _financialLoadError =
              'Financial report is unavailable right now. Please try again shortly.';
        });
      }
      print('ReportsAnalyticsScreen: Financial load error: $error');
    }
  }

  Future<void> _loadOccupancyData() async {
    if (mounted) {
      setState(() {
        _occupancyLoading = true;
        _occupancyLoadError = null;
      });
    }

    try {
      final summary = await _reportsService.getOccupancySummary();
      final buildings = await _reportsService.getBuildingOccupancy();

      if (mounted) {
        setState(() {
          _occupancySummary = summary;
          _buildingOccupancies = buildings;
          _occupancyLoading = false;
          _occupancyLoadError = null;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _occupancySummary = null;
          _buildingOccupancies = [];
          _occupancyLoading = false;
          _occupancyLoadError = error.userMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _occupancySummary = null;
          _buildingOccupancies = [];
          _occupancyLoading = false;
          _occupancyLoadError =
              'Occupancy report is unavailable right now. Please try again shortly.';
        });
      }
      print('ReportsAnalyticsScreen: Occupancy load error: $error');
    }
  }

  Future<void> _loadComplaintsData() async {
    if (mounted) {
      setState(() {
        _complaintsLoading = true;
        _complaintsLoadError = null;
      });
    }

    try {
      final summary = await _reportsService.getComplaintsSummary(
        year: selectedDate.year,
        month: selectedDate.month,
      );
      final trends = await _reportsService.getMonthlyComplaintsTrends();

      if (mounted) {
        setState(() {
          _complaintsSummary = summary;
          _complaintsTrends = trends;
          _complaintsLoading = false;
          _complaintsLoadError = null;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _complaintsSummary = null;
          _complaintsTrends = [];
          _complaintsLoading = false;
          _complaintsLoadError = error.userMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _complaintsSummary = null;
          _complaintsTrends = [];
          _complaintsLoading = false;
          _complaintsLoadError =
              'Complaints report is unavailable right now. Please try again shortly.';
        });
      }
      print('ReportsAnalyticsScreen: Complaints load error: $error');
    }
  }

  Future<void> _loadDeliveriesData() async {
    try {
      final count = await _reportsService.getDeliveriesCount(
        year: selectedDate.year,
        month: selectedDate.month,
      );

      if (mounted) {
        setState(() {
          _deliveriesCount = count;
        });
      }
    } on ReportsServiceException catch (_) {
      if (mounted) {
        setState(() {
          _deliveriesCount = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _deliveriesCount = null;
        });
      }
      print('ReportsAnalyticsScreen: Deliveries load error: $error');
    }
  }

  String get selectedMonth {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[selectedDate.month - 1]} ${selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Reports & Analytics'),
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      _buildFilterRow(),
                      _buildKpiCards(),
                      _buildTabSwitcher(),
                      _buildCharts(),
                      SizedBox(height: 80.h),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Text(
            'Loading reports data...',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Color(0xFF0E4778),
                  size: 24.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Dashboard',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Track billing, collections & key metrics for $selectedMonth',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null && picked != selectedDate) {
                  setState(() {
                    selectedDate = picked;
                  });
                  _loadData();
                }
              },
              child: Container(
                height: 52.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    Icon(
                      Icons.calendar_month,
                      size: 18.w,
                      color: Color(0xFF0E4778),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        selectedMonth,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Container(
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E4778).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () async {
                if (selectedTabIndex == 0) {
                  await _showDesktopOnlyReportDialog('Financial report export');
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Export is not available yet for this report.',
                    ),
                    backgroundColor: const Color(0xFF0E4778),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_download, color: Colors.white, size: 20.w),
                  SizedBox(width: 8.w),
                  Text(
                    'Export',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    if (selectedTabIndex != 0) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnalyticsKpiCard(
                  key: const ValueKey('kpi-collections'),
                  title: 'Collections Received',
                  value: _financialSummary?.formattedCollectionsReceived ?? '—',
                  isUnavailable: _financialSummary == null,
                  growth: '+0%',
                  isPositive: true,
                  showGrowth: false,
                  color: const Color(0xFF0E4778),
                  icon: Icons.account_balance_wallet,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AnalyticsKpiCard(
                  key: const ValueKey('kpi-occupancy'),
                  title: 'Occupancy Rate',
                  value: _occupancySummary?.formattedOccupancyRate ?? '—',
                  isUnavailable: _occupancySummary == null,
                  growth: '+0%',
                  isPositive: true,
                  color: const Color(0xFF10B981),
                  icon: Icons.home,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: AnalyticsKpiCard(
                  key: const ValueKey('kpi-resolved-issues'),
                  title: 'Resolved Issues',
                  value: _complaintsSummary == null
                      ? '—'
                      : '${_complaintsSummary!.resolvedComplaints}',
                  isUnavailable: _complaintsSummary == null,
                  growth: _complaintsSummary?.formattedResolutionRate ?? '',
                  isPositive: true,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AnalyticsKpiCard(
                  key: const ValueKey('kpi-deliveries'),
                  title: 'Deliveries',
                  value: _deliveriesCount == null ? '—' : '$_deliveriesCount',
                  isUnavailable: _deliveriesCount == null,
                  growth: _deliveriesCount == null ? '' : '+0%',
                  isPositive: true,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.local_shipping,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SegmentedTabBar(
        tabs: tabs,
        selectedIndex: selectedTabIndex,
        onTabSelected: (index) {
          setState(() {
            selectedTabIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildCharts() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          if (selectedTabIndex == 0) ...[
            // Financial Tab
            if (_financialLoadError != null)
              _buildFinancialErrorBanner(_financialLoadError!),
            if (_financialLoadError != null) SizedBox(height: 12.h),
            _buildFinancialSummaryCard(),
            SizedBox(height: 20.h),
            _buildDesktopOnlyFinancialReportsCard(),
          ] else if (selectedTabIndex == 1) ...[
            // Occupancy Tab
            if (_occupancyLoading)
              _buildReportLoadingState('Loading occupancy data...')
            else if (_occupancyLoadError != null)
              _buildReportErrorCard(
                title: 'Occupancy data unavailable',
                message: _occupancyLoadError!,
              )
            else if (_occupancySummary != null) ...[
              OccupancyChart(occupancySummary: _occupancySummary!),
              SizedBox(height: 20.h),
              BuildingOccupancyChart(buildingOccupancies: _buildingOccupancies),
            ],
          ] else if (selectedTabIndex == 2) ...[
            // Complaints Tab
            if (_complaintsLoading)
              _buildReportLoadingState('Loading complaints data...')
            else if (_complaintsLoadError != null)
              _buildReportErrorCard(
                title: 'Complaints data unavailable',
                message: _complaintsLoadError!,
              )
            else if (_complaintsSummary != null) ...[
              ComplaintsChart(
                complaintsSummary: _complaintsSummary!,
                complaintsTrends: _complaintsTrends,
              ),
              SizedBox(height: 20.h),
              ComplaintCategoryChart(complaintsSummary: _complaintsSummary!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReportLoadingState(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 12.h),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildReportErrorCard({
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0D7D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8D3340),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF784E54)),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB91C1C)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    final summary = _financialSummary;
    String formatValue(String Function(FinancialSummary s) select) {
      return summary == null ? 'Unavailable' : select(summary);
    }

    String formatCount(int? value) => value == null ? 'Unavailable' : '$value';

    Widget row(String label, String value) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing V2 Summary',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 10.h),
          row('Total billed', formatValue((s) => s.formattedTotalBilled)),
          row(
            'Collections received',
            formatValue((s) => s.formattedCollectionsReceived),
          ),
          row('Outstanding', formatValue((s) => s.formattedOutstanding)),
          row(
            'Overdue outstanding',
            formatValue((s) => s.formattedOverdueOutstanding),
          ),
          row(
            'Available resident credit',
            formatValue((s) => s.formattedAvailableCredit),
          ),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          SizedBox(height: 8.h),
          row('Bills - Pending', formatCount(summary?.pendingBills)),
          row(
            'Bills - Partially paid',
            formatCount(summary?.partiallyPaidBills),
          ),
          row('Bills - Paid', formatCount(summary?.paidBills)),
          row('Bills - Overdue', formatCount(summary?.overdueBills)),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          SizedBox(height: 8.h),
          row(
            'UPI collections',
            summary == null
                ? 'Unavailable'
                : '${summary.upiCollection.formattedTotal} (${summary.upiCollection.count})',
          ),
          row(
            'Cash collections',
            summary == null
                ? 'Unavailable'
                : '${summary.cashCollection.formattedTotal} (${summary.cashCollection.count})',
          ),
          row(
            'Bank transfer collections',
            summary == null
                ? 'Unavailable'
                : '${summary.bankTransferCollection.formattedTotal} (${summary.bankTransferCollection.count})',
          ),
          row(
            'Cheque collections',
            summary == null
                ? 'Unavailable'
                : '${summary.chequeCollection.formattedTotal} (${summary.chequeCollection.count})',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOnlyFinancialReportsCard() {
    final items = <String>[
      'Detailed collections report',
      'Outstanding / overdue report',
      'Payment-method report',
      'Resident credit report',
      'Resident statement',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Desktop-only financial reports',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8.h),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                item,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Open in Hominode Admin Web/Desktop'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showDesktopOnlyReportDialog(item),
            ),
        ],
      ),
    );
  }

  Future<void> _showDesktopOnlyReportDialog(String reportName) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reportName),
        content: const Text(
          'This detailed financial report is currently available in Hominode Admin Web/Desktop. '
          'Please open Admin Web/Desktop to view or export this report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Reusable KPI Card Widget
class AnalyticsKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String growth;
  final bool isPositive;
  final bool showGrowth;
  final bool isUnavailable;
  final Color color;
  final IconData icon;

  const AnalyticsKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.growth,
    required this.isPositive,
    this.showGrowth = true,
    this.isUnavailable = false,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40.h,
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Icon(icon, color: color, size: 21.w),
                ),
                const Spacer(),
                if (showGrowth && !isUnavailable && growth.isNotEmpty)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFDC2626).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 12.w,
                              color: isPositive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFDC2626),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              growth,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFDC2626),
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
          SizedBox(height: 8.h),
          SizedBox(
            height: 30.h,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            height: 34.h,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  height: 1.1,
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            height: 14.h,
            child: isUnavailable
                ? Text(
                    'Unavailable',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A94A3),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// Segmented Tab Bar Widget
class SegmentedTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;

  const SegmentedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
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
        }).toList(),
      ),
    );
  }
}
