import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/reports_service.dart';

class RevenueBarChart extends StatelessWidget {
  final List<MonthlyRevenue> revenueTrends;
  const RevenueBarChart({super.key, required this.revenueTrends});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: const Text('Revenue Chart'),
    );
  }
}

class ExpenseDonutChart extends StatelessWidget {
  final FinancialSummary? financialSummary;
  const ExpenseDonutChart({super.key, required this.financialSummary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: const Text('Expense Chart'),
    );
  }
}

class OccupancyChart extends StatelessWidget {
  final OccupancySummary? occupancySummary;
  const OccupancyChart({super.key, required this.occupancySummary});

  @override
  Widget build(BuildContext context) {
    final summary = occupancySummary;
    if (summary == null) {
      return const _AnalyticsCard(
        title: 'Occupancy overview',
        child: Text('Occupancy data is unavailable.'),
      );
    }

    final occupancyValue = _safeRatio(
      summary.occupiedFlats.toDouble(),
      summary.totalFlats.toDouble(),
    );
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('Occupancy overview', 'Current community units'),
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FE),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Occupancy rate',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF516680),
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  summary.formattedOccupancyRate,
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0E4778),
                  ),
                ),
                SizedBox(height: 10.h),
                LinearProgressIndicator(
                  value: occupancyValue,
                  minHeight: 8.h,
                  borderRadius: BorderRadius.circular(99.r),
                  backgroundColor: const Color(0xFFDDE8F5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2877C7),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 13.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
                childAspectRatio: columns == 4 ? 1.3 : 1.55,
                children: [
                  _occupancyMetric(
                    'Total units',
                    summary.totalFlats,
                    const Color(0xFF2877C7),
                  ),
                  _occupancyMetric(
                    'Occupied',
                    summary.occupiedFlats,
                    const Color(0xFF258363),
                  ),
                  _occupancyMetric(
                    'Vacant',
                    summary.vacantFlats,
                    const Color(0xFFD28A28),
                  ),
                  _occupancyMetric(
                    'Maintenance',
                    summary.maintenanceFlats,
                    const Color(0xFF7865B1),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class BuildingOccupancyChart extends StatelessWidget {
  final List<BuildingOccupancy> buildingOccupancies;
  const BuildingOccupancyChart({super.key, required this.buildingOccupancies});

  @override
  Widget build(BuildContext context) {
    if (buildingOccupancies.isEmpty) {
      return const _AnalyticsCard(
        title: 'Building-wise occupancy',
        child: Text('No building occupancy data available.'),
      );
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('Building-wise occupancy', 'Occupied units by building'),
          SizedBox(height: 6.h),
          ...buildingOccupancies.map((building) {
            final progress = _safeRatio(
              building.occupiedFlats.toDouble(),
              building.totalFlats.toDouble(),
            );
            return Padding(
              padding: EdgeInsets.only(top: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          building.buildingName,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF203653),
                          ),
                        ),
                      ),
                      Text(
                        '${_safePercent(building.occupancyRate)}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0E4778),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    'Occupied ${building.occupiedFlats} of ${building.totalFlats}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF667991),
                    ),
                  ),
                  SizedBox(height: 7.h),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 7.h,
                    borderRadius: BorderRadius.circular(99.r),
                    backgroundColor: const Color(0xFFE8EEF5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2877C7),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ComplaintsChart extends StatelessWidget {
  final ComplaintsSummary? complaintsSummary;
  final List<MonthlyComplaints> complaintsTrends;
  const ComplaintsChart({
    super.key,
    required this.complaintsSummary,
    required this.complaintsTrends,
  });

  @override
  Widget build(BuildContext context) {
    final summary = complaintsSummary;
    if (summary == null) {
      return const _AnalyticsCard(
        title: 'Complaints overview',
        child: Text('Complaints data is unavailable.'),
      );
    }

    final maximumTotal = complaintsTrends.fold<int>(
      0,
      (maximum, item) =>
          item.totalComplaints > maximum ? item.totalComplaints : maximum,
    );
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('Complaints overview', 'Selected month'),
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FE),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resolution rate',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF516680),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        summary.formattedResolutionRate,
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0E4778),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.support_agent,
                  color: Color(0xFF2877C7),
                  size: 30,
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
                childAspectRatio: columns == 4 ? 1.3 : 1.55,
                children: [
                  _complaintMetric(
                    'Total complaints',
                    summary.totalComplaints,
                    const Color(0xFF2877C7),
                  ),
                  _complaintMetric(
                    'Resolved',
                    summary.resolvedComplaints,
                    const Color(0xFF258363),
                  ),
                  _complaintMetric(
                    'In progress',
                    summary.inProgressComplaints,
                    const Color(0xFFD28A28),
                  ),
                  _complaintMetric(
                    'Pending',
                    summary.pendingComplaints,
                    const Color(0xFF7865B1),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 18.h),
          _cardHeading('Six-month complaint trend', 'Reported / resolved'),
          SizedBox(height: 7.h),
          if (complaintsTrends.isEmpty)
            const Text('No complaint trend data available.')
          else
            ...complaintsTrends.map(
              (item) => _monthlyComplaintRow(item, maximumTotal),
            ),
        ],
      ),
    );
  }
}

class ComplaintCategoryChart extends StatelessWidget {
  final ComplaintsSummary? complaintsSummary;
  const ComplaintCategoryChart({super.key, required this.complaintsSummary});

  @override
  Widget build(BuildContext context) {
    final summary = complaintsSummary;
    if (summary == null) {
      return const _AnalyticsCard(
        title: 'Complaint categories',
        child: Text('Complaints data is unavailable.'),
      );
    }
    final categories = summary.categoryBreakdown.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('Complaint categories', 'Selected month'),
          SizedBox(height: 13.h),
          if (categories.isEmpty)
            const Text('No complaint categories for this period.')
          else
            ...categories.map((category) {
              final share = _safeRatio(
                category.value.toDouble(),
                summary.totalComplaints.toDouble(),
              );
              return Padding(
                padding: EdgeInsets.only(bottom: 13.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.key,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF304665),
                            ),
                          ),
                        ),
                        Text(
                          '${category.value}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF203653),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    LinearProgressIndicator(
                      value: share,
                      minHeight: 6.h,
                      borderRadius: BorderRadius.circular(99.r),
                      backgroundColor: const Color(0xFFE8EEF5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2877C7),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _AnalyticsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading(title, null),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

Widget _cardHeading(String title, String? subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF172D50),
        ),
      ),
      if (subtitle != null) ...[
        SizedBox(height: 3.h),
        Text(
          subtitle,
          style: TextStyle(fontSize: 10.sp, color: const Color(0xFF72839A)),
        ),
      ],
    ],
  );
}

Widget _occupancyMetric(String label, int value, Color color) {
  return Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFCFF),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: const Color(0xFFE7EDF5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: const Color(0xFF6A7C94)),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _complaintMetric(String label, int value, Color color) =>
    _occupancyMetric(label, value, color);

Widget _monthlyComplaintRow(MonthlyComplaints item, int maximumTotal) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 7.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62.w,
          child: Text(
            '${item.month}\n${item.year}',
            style: TextStyle(
              fontSize: 10.sp,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF526780),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _trendBar(
                'Total',
                item.totalComplaints,
                maximumTotal,
                const Color(0xFF2877C7),
              ),
              SizedBox(height: 5.h),
              _trendBar(
                'Resolved',
                item.resolvedComplaints,
                maximumTotal,
                const Color(0xFF258363),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _trendBar(String label, int count, int maximum, Color color) {
  final value = _safeRatio(count.toDouble(), maximum.toDouble());
  return Row(
    children: [
      SizedBox(
        width: 49.w,
        child: Text(
          '$label $count',
          style: TextStyle(fontSize: 9.sp, color: const Color(0xFF647892)),
        ),
      ),
      Expanded(
        child: LinearProgressIndicator(
          value: value,
          minHeight: 5.h,
          borderRadius: BorderRadius.circular(99.r),
          backgroundColor: const Color(0xFFE8EEF5),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ],
  );
}

double _safeRatio(double value, double total) {
  if (!value.isFinite || !total.isFinite || total <= 0) return 0;
  return (value / total).clamp(0.0, 1.0).toDouble();
}

String _safePercent(double value) =>
    value.isFinite ? value.toStringAsFixed(1) : 'Unavailable';

class AnalyticsKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const AnalyticsKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(title),
    );
  }
}

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
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF111111)
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
