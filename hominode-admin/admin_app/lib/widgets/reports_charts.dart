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
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: const Text('Occupancy Chart'),
    );
  }
}

class BuildingOccupancyChart extends StatelessWidget {
  final List<BuildingOccupancy> buildingOccupancies;
  const BuildingOccupancyChart({super.key, required this.buildingOccupancies});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: const Text('Building Occupancy Chart'),
    );
  }
}

class ComplaintsChart extends StatelessWidget {
  final List<MonthlyComplaints> complaintsTrends;
  const ComplaintsChart({super.key, required this.complaintsTrends});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: const Text('Complaints Chart'),
    );
  }
}

class ComplaintCategoryChart extends StatelessWidget {
  final ComplaintsSummary? complaintsSummary;
  const ComplaintCategoryChart({super.key, required this.complaintsSummary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: const Text('Complaint Category Chart'),
    );
  }
}

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
