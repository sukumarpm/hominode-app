# Security App - Staff Attendance Complete Guide

## Overview
Complete implementation guide for the Staff Attendance screen in the Security Guard App. This screen allows security personnel to mark staff attendance, view attendance statistics, and track attendance history.

---

## Screen Structure

### File: `lib/security_staff_attendance_screen.dart`

### Purpose
- View today's attendance statistics
- Mark staff as present/absent/on leave
- View attendance history (last 30 days)
- Quick broadcast to all staff
- Real-time attendance tracking

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│ StandardHeader: "Staff Attendance"                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ [⏰] Staff Attendance                                       │
│      Track and manage attendance                            │
│                                                             │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│ │   [👥]  │ │   [✓]   │ │   [✗]   │ │   [📅]  │          │
│ │   25    │ │   22    │ │    2    │ │    1    │          │
│ │  Total  │ │ Present │ │ Absent  │ │ On Leave│          │
│ │  Staff  │ │  Today  │ │         │ │         │          │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│                                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ Quick Broadcast                                     │   │
│ │ Send instant notification to all staff              │   │
│ │                                      22 / 25  88%   │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ 🔍 Search attendance by date...              [X]    │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
│ Attendance History                                          │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ [📅] 6 Mar, 2026                    22/25 ✓        │   │
│ │                                                     │   │
│ │ ┌─────────┐ ┌─────────┐ ┌─────────┐              │   │
│ │ │   22    │ │    2    │ │    1    │              │   │
│ │ │ Present │ │ Absent  │ │On Leave │              │   │
│ │ └─────────┘ └─────────┘ └─────────┘              │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
              [Mark Attendance] FAB
```

---

## Complete Implementation

### 1. Main Screen Widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/standard_header.dart';
import 'security_attendance_marking_screen.dart';
import 'security_attendance_details_screen.dart';
import 'services/attendance_service.dart';

class SecurityStaffAttendanceScreen extends StatefulWidget {
  const SecurityStaffAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<SecurityStaffAttendanceScreen> createState() => 
      _SecurityStaffAttendanceScreenState();
}

class _SecurityStaffAttendanceScreenState 
    extends State<SecurityStaffAttendanceScreen> {
  
  final TextEditingController _searchController = TextEditingController();
  final AttendanceService _attendanceService = AttendanceService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(
            title: 'Staff Attendance',
            showBackButton: true,
          ),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Header Section
                _buildPageHeader(),
                
                const SizedBox(height: 20),
                
                // Summary Metrics Cards
                _buildSummaryMetrics(),
                
                const SizedBox(height: 20),
                  
                // Quick Broadcast Card
                _buildQuickBroadcastCard(),
                
                const SizedBox(height: 16),
                
                // Search Bar
                _buildSearchBar(),
                
                const SizedBox(height: 20),
                
                // Attendance History List
                _buildAttendanceHistory(),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onMarkAttendance,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Mark Attendance'),
      ),
    );
  }

  // Page Header
  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff Attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track and manage attendance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Summary Metrics Cards
  Widget _buildSummaryMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<AttendanceStats>(
        future: _attendanceService.getTodayStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 80,
                    margin: EdgeInsets.only(left: index > 0 ? 12 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final stats = snapshot.data ?? AttendanceStats(
            totalStaff: 0,
            present: 0,
            absent: 0,
            onLeave: 0,
            pending: 0,
          );

          return Row(
            children: [
              Expanded(
                child: TopMetricCard(
                  title: 'Total Staff',
                  value: stats.totalStaff.toString(),
                  valueColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TopMetricCard(
                  title: 'Present Today',
                  value: stats.present.toString(),
                  valueColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TopMetricCard(
                  title: 'Absent',
                  value: stats.absent.toString(),
                  valueColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TopMetricCard(
                  title: 'On Leave',
                  value: stats.onLeave.toString(),
                  valueColor: const Color(0xFF9333EA),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Quick Broadcast Card
  Widget _buildQuickBroadcastCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<AttendanceStats>(
        future: _attendanceService.getTodayStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? AttendanceStats(
            totalStaff: 0,
            present: 0,
            absent: 0,
            onLeave: 0,
            pending: 0,
          );
          
          final percentage = stats.totalStaff > 0 
              ? ((stats.present / stats.totalStaff) * 100).round()
              : 0;

          return GestureDetector(
            onTap: _showQuickBroadcast,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Broadcast',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send instant notification to all staff',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stats.present} / ${stats.totalStaff}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
            hintText: 'Search attendance by date...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey[500],
              size: 20,
            ),
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

  // Attendance History List
  Widget _buildAttendanceHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<DailyAttendanceSummary>>(
        stream: _attendanceService.getAttendanceHistory(days: 30),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final summaries = snapshot.data ?? [];
          
          final filteredSummaries = _searchQuery.isEmpty
              ? summaries
              : summaries.where((summary) {
                  return summary.date.toLowerCase().contains(_searchQuery);
                }).toList();

          if (filteredSummaries.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: filteredSummaries.asMap().entries.map((entry) {
              final index = entry.key;
              final summary = entry.value;
              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 16),
                  DateAttendanceSection(
                    date: summary.date,
                    present: summary.present,
                    absent: summary.absent,
                    onLeave: summary.onLeave,
                    total: summary.totalStaff,
                    percentage: summary.attendancePercentage,
                    onTap: () => _showAttendanceDetails(summary.date),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.calendar_today : Icons.search_off,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No attendance records yet'
                  : 'No attendance records found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Start marking attendance to see history'
                  : 'Try adjusting your search',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Error State
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading attendance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Action Handlers
  void _onMarkAttendance() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityAttendanceMarkingScreen(),
      ),
    );
  }

  void _showAttendanceDetails(String date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecurityAttendanceDetailsScreen(date: date),
      ),
    );
  }

  void _showQuickBroadcast() {
    // Show broadcast dialog
    showDialog(
      context: context,
      builder: (context) => const QuickBroadcastDialog(),
    );
  }
}
```

---

## Supporting Widgets

### Top Metric Card

```dart
class TopMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const TopMetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
```

### Date Attendance Section

```dart
class DateAttendanceSection extends StatelessWidget {
  final String date;
  final int present;
  final int absent;
  final int onLeave;
  final int total;
  final double percentage;
  final VoidCallback? onTap;

  const DateAttendanceSection({
    Key? key,
    required this.date,
    required this.present,
    required this.absent,
    required this.onLeave,
    required this.total,
    required this.percentage,
    this.onTap,
  }) : super(key: key);

  Color _getBadgeColor() {
    if (percentage == 100) {
      return const Color(0xFF22C55E);
    } else if (percentage >= 80) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Date Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getBadgeColor(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$present / $total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Attendance Summary Cards
            Row(
              children: [
                Expanded(
                  child: AttendanceSummaryCard(
                    value: present.toString(),
                    label: 'Present',
                    valueColor: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AttendanceSummaryCard(
                    value: absent.toString(),
                    label: 'Absent',
                    valueColor: const Color(0xFFEF4444),
                    icon: Icons.cancel_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AttendanceSummaryCard(
                    value: onLeave.toString(),
                    label: 'On Leave',
                    valueColor: const Color(0xFF9333EA),
                    icon: Icons.event_busy_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
```

### Attendance Summary Card

```dart
class AttendanceSummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final IconData? icon;

  const AttendanceSummaryCard({
    Key? key,
    required this.value,
    required this.label,
    required this.valueColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: valueColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valueColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: valueColor),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Continued in next section...
