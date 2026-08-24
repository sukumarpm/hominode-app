# Attendance & Staff Details - Firestore Integration Guide

## Overview

This guide provides the exact code changes needed to:
1. Remove demo data from attendance screens
2. Integrate with Firestore attendance service
3. Fix staff details navigation to work with Firestore model

---

## PART 1: Update Attendance Marking Screen

**File:** `lib/attendance_marking_screen.dart`

### Changes Required:

1. **Update Imports**
```dart
// REMOVE
import 'models/staff_models.dart';

// ADD
import 'services/staff_vendor_service.dart';
import 'services/attendance_service.dart';
```

2. **Update State Variables**
```dart
// REMOVE
late List<StaffMember> staffMembers;
late List<StaffMember> filteredStaff;

// ADD
final StaffVendorService _staffService = StaffVendorService();
final AttendanceService _attendanceService = AttendanceService();
```

3. **Remove initState Demo Data**
```dart
// REMOVE entire initState method
@override
void initState() {
  super.initState();
  staffMembers = StaffMember.getSampleStaff();
  filteredStaff = staffMembers;
  _searchController.addListener(_filterStaff);
}

// REPLACE WITH
@override
void initState() {
  super.initState();
  _searchController.addListener(() {
    setState(() {}); // Trigger rebuild for search
  });
}
```

4. **Update build() Method to Use StreamBuilder**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    body: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ... header code ...
        
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<List<StaffMember>>(
              stream: _staffService.getStaffMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final staffMembers = snapshot.data ?? [];
                
                // Filter staff based on search and status
                final filteredStaff = staffMembers.where((staff) {
                  final matchesSearch = _searchController.text.isEmpty ||
                      staff.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                      staff.role.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                      staff.phone.contains(_searchController.text);
                  
                  final matchesFilter = selectedFilter == 'All' ||
                      (selectedFilter == 'Present' && staff.status == 'present') ||
                      (selectedFilter == 'Absent' && staff.status == 'absent') ||
                      (selectedFilter == 'Pending' && staff.status == 'pending');
                  
                  return matchesSearch && matchesFilter;
                }).toList();
                
                // Calculate stats
                final presentCount = staffMembers.where((s) => s.status == 'present').length;
                final absentCount = staffMembers.where((s) => s.status == 'absent').length;
                final pendingCount = staffMembers.where((s) => s.status == 'pending').length;
                
                return Column(
                  children: [
                    // Quick Stats
                    Row(
                      children: [
                        Expanded(child: _buildQuickStatCard('Present', presentCount.toString(), const Color(0xFF10B981), Icons.check_circle)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildQuickStatCard('Absent', absentCount.toString(), const Color(0xFFEF4444), Icons.cancel)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildQuickStatCard('Pending', pendingCount.toString(), const Color(0xFFF59E0B), Icons.schedule)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions, Filter Chips, Search Bar...
                    // (keep existing UI code)
                    
                    // Staff List
                    if (filteredStaff.isEmpty)
                      const Center(child: Text('No staff found'))
                    else
                      ...filteredStaff.map((staff) {
                        return Column(
                          children: [
                            StaffMarkingCard(
                              staff: staff,
                              onStatusChanged: (newStatus) => _updateStaffStatus(staff.id, newStatus),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }).toList(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
```

5. **Update _updateStaffStatus Method**
```dart
Future<void> _updateStaffStatus(String staffId, String newStatus) async {
  try {
    if (newStatus == 'present') {
      await _attendanceService.markPresent(staffId);
    } else if (newStatus == 'absent') {
      await _attendanceService.markAbsent(staffId);
    } else if (newStatus == 'onLeave') {
      await _attendanceService.markOnLeave(staffId);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance marked successfully'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }
}
```

6. **Update _markAllPresent Method**
```dart
Future<void> _markAllPresent() async {
  try {
    await _attendanceService.markAllPresent();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All staff marked as present'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }
}
```

7. **Update StaffMarkingCard Widget**
```dart
class StaffMarkingCard extends StatelessWidget {
  final StaffMember staff;
  final Function(String) onStatusChanged;

  const StaffMarkingCard({
    Key? key,
    required this.staff,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Staff Info Row
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(staff.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: _getStatusColor(staff.status),
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Staff Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.role,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (staff.getCheckInTimeDisplay() != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Checked in: ${staff.getCheckInTimeDisplay()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Current Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(staff.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  staff.getStatusDisplay(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(staff.status),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: staff.status == 'present' 
                      ? null 
                      : () => onStatusChanged('present'),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Present'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: staff.status == 'present' 
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: staff.status == 'absent' 
                      ? null 
                      : () => onStatusChanged('absent'),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Absent'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: staff.status == 'absent' 
                        ? const Color(0xFFEF4444).withOpacity(0.5)
                        : const Color(0xFFEF4444),
                    side: BorderSide(
                      color: staff.status == 'absent' 
                          ? const Color(0xFFEF4444).withOpacity(0.5)
                          : const Color(0xFFEF4444),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: staff.status == 'onLeave' 
                      ? null 
                      : () => onStatusChanged('onLeave'),
                  icon: const Icon(Icons.event_busy, size: 16),
                  label: const Text('Leave'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: staff.status == 'onLeave' 
                        ? const Color(0xFFF59E0B).withOpacity(0.5)
                        : const Color(0xFFF59E0B),
                    side: BorderSide(
                      color: staff.status == 'onLeave' 
                          ? const Color(0xFFF59E0B).withOpacity(0.5)
                          : const Color(0xFFF59E0B),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'onLeave':
        return const Color(0xFFF59E0B);
      case 'offDuty':
        return const Color(0xFF6B7280);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }
}
```

---

## PART 2: Update Staff Attendance Screen (History)

**File:** `lib/staff_attendance_screen.dart`

### Changes Required:

1. **Update Imports**
```dart
// REMOVE
import 'models/staff_models.dart';

// ADD
import 'services/staff_vendor_service.dart';
import 'services/attendance_service.dart';
```

2. **Update State Variables**
```dart
// REMOVE
late List<StaffMember> staffMembers;
late List<AttendanceRecord> attendanceHistory;
late List<AttendanceRecord> filteredAttendance;

// ADD
final StaffVendorService _staffService = StaffVendorService();
final AttendanceService _attendanceService = AttendanceService();
```

3. **Remove Demo Data from initState**
```dart
// REMOVE
staffMembers = StaffMember.getSampleStaff();
attendanceHistory = AttendanceRecord.getSampleAttendanceHistory();
filteredAttendance = attendanceHistory;
```

4. **Update Stats Section**
```dart
// Replace _getAttendanceStats() method with FutureBuilder
FutureBuilder<AttendanceStats>(
  future: _attendanceService.getTodayStats(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final stats = snapshot.data!;
      return Row(
        children: [
          Expanded(child: TopMetricCard(title: 'Total Staff', value: stats.totalStaff.toString(), valueColor: const Color(0xFF2563EB))),
          const SizedBox(width: 12),
          Expanded(child: TopMetricCard(title: 'Present Today', value: stats.present.toString(), valueColor: const Color(0xFF10B981))),
          const SizedBox(width: 12),
          Expanded(child: TopMetricCard(title: 'Absent', value: stats.absent.toString(), valueColor: const Color(0xFFF59E0B))),
          const SizedBox(width: 12),
          Expanded(child: TopMetricCard(title: 'On Leave', value: stats.onLeave.toString(), valueColor: const Color(0xFF9333EA))),
        ],
      );
    }
    return const CircularProgressIndicator();
  },
)
```

5. **Update Attendance History List**
```dart
// Replace attendance history list with StreamBuilder
StreamBuilder<List<DailyAttendanceSummary>>(
  stream: _attendanceService.getAttendanceHistory(days: 30),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    
    final history = snapshot.data ?? [];
    
    // Filter based on search
    final filteredHistory = _searchController.text.isEmpty
        ? history
        : history.where((summary) {
            return summary.date.contains(_searchController.text.toLowerCase()) ||
                   summary.present.toString().contains(_searchController.text) ||
                   summary.absent.toString().contains(_searchController.text);
          }).toList();
    
    if (filteredHistory.isEmpty) {
      return const Center(child: Text('No attendance records found'));
    }
    
    return Column(
      children: filteredHistory.map((summary) {
        return Column(
          children: [
            DateAttendanceSection(
              date: summary.date,
              present: summary.present,
              absent: summary.absent,
              total: summary.totalStaff,
              badgeColor: _getBadgeColor(summary.attendancePercentage),
              onTap: () => _showAttendanceDetails(summary.date),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  },
)
```

6. **Add Helper Method**
```dart
Color _getBadgeColor(double percentage) {
  if (percentage == 100) return const Color(0xFF22C55E);
  if (percentage >= 80) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}
```

---

## PART 3: Fix Staff Details Navigation

**Option A: Simple Fix - Keep Old Model (Recommended for now)**

In `staff_vendor_management_screen.dart`, convert Firestore model to old model:

```dart
void _navigateToStaffDetails(StaffMember firestoreStaff) {
  // Convert Firestore model to old model for details screen
  final oldModelStaff = models.StaffMember(
    id: firestoreStaff.id,
    name: firestoreStaff.name,
    role: firestoreStaff.role,
    phone: firestoreStaff.phone,
    email: firestoreStaff.email ?? '',
    shift: 'Not Set', // Default value
    checkedIn: firestoreStaff.getCheckInTimeDisplay(),
    checkedOut: firestoreStaff.getCheckOutTimeDisplay(),
    salary: firestoreStaff.salary != null ? '₹${firestoreStaff.salary!.toStringAsFixed(0)}/month' : 'Not Set',
    status: _convertStatus(firestoreStaff.status),
    joinDate: firestoreStaff.joiningDate ?? DateTime.now(),
    address: firestoreStaff.address ?? '',
    emergencyContact: 'Not Set',
    emergencyContactPhone: 'Not Set',
    skills: [],
    rating: 0.0,
    totalTasks: 0,
    completedTasks: 0,
  );
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StaffDetailsScreen(staffMember: oldModelStaff),
    ),
  );
}

models.StaffStatus _convertStatus(String status) {
  switch (status) {
    case 'present':
      return models.StaffStatus.present;
    case 'absent':
      return models.StaffStatus.absent;
    case 'onLeave':
      return models.StaffStatus.onLeave;
    case 'offDuty':
      return models.StaffStatus.offDuty;
    default:
      return models.StaffStatus.offDuty;
  }
}
```

Add import:
```dart
import 'models/staff_models.dart' as models;
```

---

## Summary of Changes

### Files to Update:
1. ✅ `lib/attendance_marking_screen.dart` - Remove demo data, add Firestore
2. ✅ `lib/staff_attendance_screen.dart` - Remove demo data, add Firestore
3. ✅ `lib/staff_vendor_management_screen.dart` - Fix staff details navigation

### Demo Data Removed:
- ❌ `StaffMember.getSampleStaff()`
- ❌ `AttendanceRecord.getSampleAttendanceHistory()`
- ❌ Hardcoded attendance stats

### Firestore Integration Added:
- ✅ Real-time staff list
- ✅ Real-time attendance stats
- ✅ Real-time attendance history
- ✅ Mark attendance (Present/Absent/Leave)
- ✅ Mark all present
- ✅ Search and filter functionality

---

**Status:** Ready for Implementation  
**Estimated Time:** 30-45 minutes  
**Priority:** HIGH
