import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/standard_header.dart';
import 'services/pdf_export_service.dart';
import 'services/reports_service.dart';
import 'widgets/reports_charts.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  final ReportsService _reportsService = ReportsService();

  DateTime selectedDate = DateTime.now();
  int selectedTabIndex = 0; // 0: Financial, 1: Occupancy, 2: Complaints

  // Data holders
  FinancialSummary? _financialSummary;
  List<MonthlyRevenue> _revenueTrends = [];
  OccupancySummary? _occupancySummary;
  List<BuildingOccupancy> _buildingOccupancies = [];
  ComplaintsSummary? _complaintsSummary;
  List<MonthlyComplaints> _complaintsTrends = [];
  int _deliveriesCount = 0;

  bool _isLoading = true;

  final List<String> tabs = ['Financial', 'Occupancy', 'Complaints'];

  @override
  void initState() {
    super.initState();
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
    final summary = await _reportsService.getFinancialSummary(
      year: selectedDate.year,
      month: selectedDate.month,
    );
    final trends = await _reportsService.getMonthlyRevenueTrends();

    if (mounted) {
      setState(() {
        _financialSummary = summary;
        _revenueTrends = trends;
      });
    }
  }

  Future<void> _loadOccupancyData() async {
    final summary = await _reportsService.getOccupancySummary();
    final buildings = await _reportsService.getBuildingOccupancy();

    if (mounted) {
      setState(() {
        _occupancySummary = summary;
        _buildingOccupancies = buildings;
      });
    }
  }

  Future<void> _loadComplaintsData() async {
    final summary = await _reportsService.getComplaintsSummary(
      year: selectedDate.year,
      month: selectedDate.month,
    );
    final trends = await _reportsService.getMonthlyComplaintsTrends();

    if (mounted) {
      setState(() {
        _complaintsSummary = summary;
        _complaintsTrends = trends;
      });
    }
  }

  Future<void> _loadDeliveriesData() async {
    final count = await _reportsService.getDeliveriesCount(
      year: selectedDate.year,
      month: selectedDate.month,
    );

    if (mounted) {
      setState(() {
        _deliveriesCount = count;
      });
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
                      'Track revenue, expenses & key metrics for $selectedMonth',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text('Generating PDF report for $selectedMonth...'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF0E4778),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );

                await PdfExportService.exportReportsAnalytics(
                  selectedMonth: selectedMonth,
                  selectedTabIndex: selectedTabIndex,
                  context: context,
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
    // Calculate growth (comparing to previous month - simplified for now)
    final revenueGrowth = _revenueTrends.length >= 2
        ? ((_revenueTrends.last.revenue -
                      _revenueTrends[_revenueTrends.length - 2].revenue) /
                  _revenueTrends[_revenueTrends.length - 2].revenue *
                  100)
              .toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnalyticsKpiCard(
                  title: 'Total Revenue',
                  value: _financialSummary?.formattedRevenue ?? '₹0',
                  growth: '$revenueGrowth%',
                  isPositive:
                      double.tryParse(revenueGrowth) != null &&
                      double.parse(revenueGrowth) >= 0,
                  color: const Color(0xFF0E4778),
                  icon: Icons.account_balance_wallet,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AnalyticsKpiCard(
                  title: 'Occupancy Rate',
                  value: _occupancySummary?.formattedOccupancyRate ?? '0%',
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
                  title: 'Resolved Issues',
                  value: '${_complaintsSummary?.resolvedComplaints ?? 0}',
                  growth: _complaintsSummary?.formattedResolutionRate ?? '0%',
                  isPositive: true,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AnalyticsKpiCard(
                  title: 'Deliveries',
                  value: '$_deliveriesCount',
                  growth: '+0%',
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
            RevenueBarChart(revenueTrends: _revenueTrends),
            SizedBox(height: 20.h),
            ExpenseDonutChart(financialSummary: _financialSummary),
          ] else if (selectedTabIndex == 1) ...[
            // Occupancy Tab
            OccupancyChart(occupancySummary: _occupancySummary),
            SizedBox(height: 20.h),
            BuildingOccupancyChart(buildingOccupancies: _buildingOccupancies),
          ] else if (selectedTabIndex == 2) ...[
            // Complaints Tab
            ComplaintsChart(complaintsTrends: _complaintsTrends),
            SizedBox(height: 20.h),
            ComplaintCategoryChart(complaintsSummary: _complaintsSummary),
          ],
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
  final Color color;
  final IconData icon;

  const AnalyticsKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.growth,
    required this.isPositive,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
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
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 22.w),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14.w,
                      color: isPositive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      growth,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.1,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
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
