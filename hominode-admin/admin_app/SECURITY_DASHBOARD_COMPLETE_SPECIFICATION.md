# Security Dashboard - Complete Specification

## Overview
The Security Dashboard is the main screen for security guards, displaying real-time statistics, quick actions, and assigned work details. It fetches security staff data from Firestore including shift timing, gate assignment, and current status.

---

## Screen Purpose
- Display today's visitor statistics
- Show security guard's assigned shift and gate
- Quick access to main features
- View recent activity
- Display current work status
- Real-time updates from Firestore

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│ StandardHeader: "Security Dashboard"                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ [👤] Welcome, Rajesh Kumar                          │   │
│ │                                                     │   │
│ │ [🚪] Gate A - Main Entrance                        │   │
│ │ [⏰] Shift: 6:00 AM - 2:00 PM (Morning)            │   │
│ │ [✓] Status: On Duty                                │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
│ Today's Overview                                            │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│ │   [👥]  │ │   [⏳]   │ │   [✓]   │ │   [🚪]  │          │
│ │   12    │ │    5    │ │   22    │ │    4    │          │
│ │ Total   │ │ Pending │ │ Active  │ │ Exited  │          │
│ │Visitors │ │Requests │ │Visitors │ │ Today   │          │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│                                                             │
│ Quick Actions                                               │
│ ┌──────────────────┐ ┌──────────────────┐                 │
│ │  [📷]            │ │  [👥]            │                 │
│ │  Scan QR Code    │ │  View Visitors   │                 │
│ │  Check In/Out    │ │  Manage Entries  │                 │
│ └──────────────────┘ └──────────────────┘                 │
│                                                             │
│ ┌──────────────────┐ ┌──────────────────┐                 │
│ │  [⏰]            │ │  [📋]            │                 │
│ │  Mark Attendance │ │  View Complaints │                 │
│ │  Staff Check-in  │ │  Assigned Tasks  │                 │
│ └──────────────────┘ └──────────────────┘                 │
│                                                             │
│ Recent Activity                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ [✓] John Doe checked in                            │   │
│ │     Flat A-101 • 10:30 AM                          │   │
│ ├─────────────────────────────────────────────────────┤   │
│ │ [✓] Staff attendance marked                        │   │
│ │     22 present, 2 absent • 9:00 AM                 │   │
│ ├─────────────────────────────────────────────────────┤   │
│ │ [🚪] Visitor exited                                │   │
│ │     Jane Smith • Duration: 2h 15m                  │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Firestore Data Structure

### Collection: `security_staff`

**Purpose**: Store security guard details, shift assignments, and gate assignments  
**Document ID**: Firebase Auth UID

**Fields**:
```dart
{
  // Personal Info
  name: String,                    // Security guard name
  phone: String,                   // Contact number
  email: String,                   // Login email
  employeeId: String,              // Employee ID
  
  // Assignment Details
  gateAssignment: String,          // "Gate A", "Gate B", "Main Entrance"
  gateLocation: String,            // Detailed location
  shiftTiming: String,             // "6:00 AM - 2:00 PM"
  shiftType: String,               // "morning", "afternoon", "night"
  
  // Status
  status: String,                  // "on-duty", "off-duty", "on-leave"
  currentShiftStart: Timestamp?,   // Current shift start time
  currentShiftEnd: Timestamp?,     // Current shift end time
  lastCheckIn: Timestamp?,         // Last check-in time
  lastCheckOut: Timestamp?,        // Last check-out time
  
  // Work Assignment
  assignedTasks: Array<String>,    // List of assigned task IDs
  responsibilities: Array<String>, // ["visitor-management", "attendance", "complaints"]
  
  // Property Assignment
  adminId: String,                 // Property admin ID
  buildingId: String,              // Assigned building
  buildingName: String,            // Building name
  
  // Metadata
  joiningDate: Timestamp,          // Date of joining
  isActive: Boolean,               // Account active status
  createdAt: Timestamp,
  updatedAt: Timestamp,
  createdBy: String,               // Admin who created
}
```

### Collection: `security_shifts`

**Purpose**: Store shift schedules and rotations  
**Document ID**: Auto-generated

**Fields**:
```dart
{
  securityId: String,              // Reference to security_staff
  securityName: String,            // Guard name
  date: String,                    // Date in YYYY-MM-DD format
  
  // Shift Details
  shiftType: String,               // "morning", "afternoon", "night"
  startTime: Timestamp,            // Shift start time
  endTime: Timestamp,              // Shift end time
  duration: Number,                // Duration in hours
  
  // Gate Assignment
  gateAssignment: String,          // Assigned gate
  gateLocation: String,            // Gate location
  
  // Status
  status: String,                  // "scheduled", "active", "completed", "missed"
  checkInTime: Timestamp?,         // Actual check-in time
  checkOutTime: Timestamp?,        // Actual check-out time
  
  // Metadata
  adminId: String,
  buildingId: String,
  createdAt: Timestamp,
  updatedAt: Timestamp,
}
```

### Collection: `security_tasks`

**Purpose**: Store assigned tasks and work orders  
**Document ID**: Auto-generated

**Fields**:
```dart
{
  taskTitle: String,               // Task title
  taskDescription: String,         // Detailed description
  taskType: String,                // "visitor-check", "patrol", "maintenance", "emergency"
  priority: String,                // "high", "medium", "low"
  
  // Assignment
  assignedTo: String,              // Security staff ID
  assignedToName: String,          // Security guard name
  assignedBy: String,              // Admin who assigned
  assignedAt: Timestamp,           // Assignment time
  
  // Status
  status: String,                  // "pending", "in-progress", "completed"
  startedAt: Timestamp?,           // Task start time
  completedAt: Timestamp?,         // Task completion time
  
  // Details
  location: String?,               // Task location
  notes: String?,                  // Additional notes
  
  // Metadata
  adminId: String,
  buildingId: String,
  createdAt: Timestamp,
  updatedAt: Timestamp,
}
```

---

## Complete Implementation

### File: `lib/security_dashboard_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/standard_header.dart';
import 'security_visitor_management_screen.dart';
import 'security_qr_scanner_screen.dart';
import 'security_staff_attendance_screen.dart';
import 'security_complaints_screen.dart';
import 'services/security_service.dart';
import 'services/visitor_service.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SecurityDashboardScreen> createState() => 
      _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  final SecurityService _securityService = SecurityService();
  final VisitorService _visitorService = VisitorService();
  
  SecurityStaffModel? _securityData;
  bool _isLoading = true;
  
  // Visitor statistics
  int _totalVisitors = 0;
  int _pendingVisitors = 0;
  int _activeVisitors = 0;
  int _exitedVisitors = 0;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
    _loadVisitorStats();
  }

  Future<void> _loadSecurityData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final data = await _securityService.getSecurityStaffData(
          currentUser.uid,
        );
        
        if (mounted) {
          setState(() {
            _securityData = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading security data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVisitorStats() async {
    try {
      final stats = await _visitorService.getTodayVisitorStats();
      
      if (mounted) {
        setState(() {
          _totalVisitors = stats.total;
          _pendingVisitors = stats.pending;
          _activeVisitors = stats.active;
          _exitedVisitors = stats.exited;
        });
      }
    } catch (e) {
      print('Error loading visitor stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Security Dashboard'),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Security Info Card
                _buildSecurityInfoCard(),
                
                const SizedBox(height: 20),
                
                // Today's Overview Section
                _buildSectionHeader('Today\'s Overview'),
                const SizedBox(height: 12),
                _buildVisitorStatistics(),
                
                const SizedBox(height: 24),
                
                // Quick Actions Section
                _buildSectionHeader('Quick Actions'),
                const SizedBox(height: 12),
                _buildQuickActions(),
                
                const SizedBox(height: 24),
                
                // Recent Activity Section
                _buildSectionHeader('Recent Activity'),
                const SizedBox(height: 12),
                _buildRecentActivity(),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Security Info Card
  Widget _buildSecurityInfoCard() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_securityData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Unable to load security data',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and Status
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${_securityData!.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Employee ID: ${_securityData!.employeeId}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(_securityData!.status),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),
            
            // Gate Assignment
            Row(
              children: [
                Icon(
                  Icons.door_front_door_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gate Assignment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_securityData!.gateAssignment} - ${_securityData!.gateLocation}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Shift Timing
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Shift',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_securityData!.shiftTiming} (${_getShiftLabel(_securityData!.shiftType)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Status Badge
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    
    switch (status) {
      case 'on-duty':
        bgColor = const Color(0xFF16A34A);
        textColor = Colors.white;
        label = 'On Duty';
        break;
      case 'off-duty':
        bgColor = const Color(0xFF6B7280);
        textColor = Colors.white;
        label = 'Off Duty';
        break;
      case 'on-leave':
        bgColor = const Color(0xFFF59E0B);
        textColor = Colors.white;
        label = 'On Leave';
        break;
      default:
        bgColor = const Color(0xFF6B7280);
        textColor = Colors.white;
        label = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _getShiftLabel(String shiftType) {
    switch (shiftType) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'night':
        return 'Night';
      default:
        return shiftType;
    }
  }

  // Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  // Visitor Statistics
  Widget _buildVisitorStatistics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.people,
              iconColor: const Color(0xFF2563EB),
              value: _totalVisitors.toString(),
              label: 'Total\nVisitors',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.pending_actions,
              iconColor: const Color(0xFFF59E0B),
              value: _pendingVisitors.toString(),
              label: 'Pending\nRequests',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle,
              iconColor: const Color(0xFF16A34A),
              value: _activeVisitors.toString(),
              label: 'Active\nVisitors',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFF9333EA),
              value: _exitedVisitors.toString(),
              label: 'Exited\nToday',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.qr_code_scanner,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Scan QR Code',
                  subtitle: 'Check In/Out',
                  onTap: _onScanQR,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.people,
                  iconColor: const Color(0xFF16A34A),
                  title: 'View Visitors',
                  subtitle: 'Manage Entries',
                  onTap: _onViewVisitors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.access_time,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Mark Attendance',
                  subtitle: 'Staff Check-in',
                  onTap: _onMarkAttendance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.assignment,
                  iconColor: const Color(0xFF9333EA),
                  title: 'View Complaints',
                  subtitle: 'Assigned Tasks',
                  onTap: _onViewComplaints,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Recent Activity
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<ActivityModel>>(
        stream: _securityService.getRecentActivity(limit: 5),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data ?? [];
          
          if (activities.isEmpty) {
            return _buildEmptyActivity();
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFE5E7EB),
              ),
              itemBuilder: (context, index) {
                return _buildActivityItem(activities[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(ActivityModel activity) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: activity.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              activity.icon,
              color: activity.iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'No recent activity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Action Handlers
  void _onScanQR() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityQrScannerScreen(),
      ),
    );
  }

  void _onViewVisitors() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityVisitorManagementScreen(),
      ),
    );
  }

  void _onMarkAttendance() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityStaffAttendanceScreen(),
      ),
    );
  }

  void _onViewComplaints() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityComplaintsScreen(),
      ),
    );
  }
}
```

---

## Continued in next section...

## Security Service Implementation

### File: `lib/services/security_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get security staff data for current user
  Future<SecurityStaffModel?> getSecurityStaffData(String userId) async {
    try {
      print('SecurityService: Fetching data for user $userId');
      
      final doc = await _firestore
          .collection('security_staff')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data() != null) {
        print('SecurityService: Data found');
        return SecurityStaffModel.fromFirestore(doc.id, doc.data()!);
      }
      
      print('SecurityService: No data found');
      return null;
    } catch (e) {
      print('SecurityService ERROR: $e');
      return null;
    }
  }

  /// Get current shift details
  Future<SecurityShiftModel?> getCurrentShift(String securityId) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final querySnapshot = await _firestore
          .collection('security_shifts')
          .where('securityId', isEqualTo: securityId)
          .where('date', isEqualTo: dateStr)
          .where('status', whereIn: ['scheduled', 'active'])
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return SecurityShiftModel.fromFirestore(doc.id, doc.data());
      }
      
      return null;
    } catch (e) {
      print('SecurityService ERROR: Failed to get current shift: $e');
      return null;
    }
  }

  /// Get assigned tasks
  Stream<List<SecurityTaskModel>> getAssignedTasks(String securityId) {
    return _firestore
        .collection('security_tasks')
        .where('assignedTo', isEqualTo: securityId)
        .where('status', whereIn: ['pending', 'in-progress'])
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SecurityTaskModel.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get recent activity
  Stream<List<ActivityModel>> getRecentActivity({int limit = 10}) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);
    
    // This would combine multiple streams (visitors, attendance, tasks)
    // For now, returning visitor activity as example
    return _firestore
        .collection('visitors')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ActivityModel.fromVisitorData(doc.id, data);
      }).toList();
    });
  }

  /// Update security status
  Future<void> updateStatus(String securityId, String status) async {
    try {
      await _firestore
          .collection('security_staff')
          .doc(securityId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('SecurityService: Status updated to $status');
    } catch (e) {
      print('SecurityService ERROR: Failed to update status: $e');
      throw Exception('Failed to update status');
    }
  }

  /// Check in for shift
  Future<void> checkInShift(String securityId, String shiftId) async {
    try {
      final batch = _firestore.batch();
      
      // Update shift
      batch.update(
        _firestore.collection('security_shifts').doc(shiftId),
        {
          'status': 'active',
          'checkInTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      
      // Update security staff
      batch.update(
        _firestore.collection('security_staff').doc(securityId),
        {
          'status': 'on-duty',
          'lastCheckIn': FieldValue.serverTimestamp(),
          'currentShiftStart': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      
      await batch.commit();
      print('SecurityService: Shift check-in successful');
    } catch (e) {
      print('SecurityService ERROR: Failed to check in: $e');
      throw Exception('Failed to check in for shift');
    }
  }

  /// Check out from shift
  Future<void> checkOutShift(String securityId, String shiftId) async {
    try {
      final batch = _firestore.batch();
      
      // Update shift
      batch.update(
        _firestore.collection('security_shifts').doc(shiftId),
        {
          'status': 'completed',
          'checkOutTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      
      // Update security staff
      batch.update(
        _firestore.collection('security_staff').doc(securityId),
        {
          'status': 'off-duty',
          'lastCheckOut': FieldValue.serverTimestamp(),
          'currentShiftEnd': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      
      await batch.commit();
      print('SecurityService: Shift check-out successful');
    } catch (e) {
      print('SecurityService ERROR: Failed to check out: $e');
      throw Exception('Failed to check out from shift');
    }
  }

  /// Update task status
  Future<void> updateTaskStatus(
    String taskId,
    String status,
  ) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (status == 'in-progress') {
        updateData['startedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }
      
      await _firestore
          .collection('security_tasks')
          .doc(taskId)
          .update(updateData);
      
      print('SecurityService: Task status updated to $status');
    } catch (e) {
      print('SecurityService ERROR: Failed to update task: $e');
      throw Exception('Failed to update task status');
    }
  }
}

// ============================================================================
// MODELS
// ============================================================================

class SecurityStaffModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String employeeId;
  final String gateAssignment;
  final String gateLocation;
  final String shiftTiming;
  final String shiftType;
  final String status;
  final DateTime? currentShiftStart;
  final DateTime? currentShiftEnd;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final List<String> assignedTasks;
  final List<String> responsibilities;
  final String adminId;
  final String buildingId;
  final String buildingName;
  final DateTime? joiningDate;
  final bool isActive;

  SecurityStaffModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.employeeId,
    required this.gateAssignment,
    required this.gateLocation,
    required this.shiftTiming,
    required this.shiftType,
    required this.status,
    this.currentShiftStart,
    this.currentShiftEnd,
    this.lastCheckIn,
    this.lastCheckOut,
    required this.assignedTasks,
    required this.responsibilities,
    required this.adminId,
    required this.buildingId,
    required this.buildingName,
    this.joiningDate,
    required this.isActive,
  });

  factory SecurityStaffModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SecurityStaffModel(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      employeeId: data['employeeId'] ?? '',
      gateAssignment: data['gateAssignment'] ?? '',
      gateLocation: data['gateLocation'] ?? '',
      shiftTiming: data['shiftTiming'] ?? '',
      shiftType: data['shiftType'] ?? '',
      status: data['status'] ?? 'off-duty',
      currentShiftStart: (data['currentShiftStart'] as Timestamp?)?.toDate(),
      currentShiftEnd: (data['currentShiftEnd'] as Timestamp?)?.toDate(),
      lastCheckIn: (data['lastCheckIn'] as Timestamp?)?.toDate(),
      lastCheckOut: (data['lastCheckOut'] as Timestamp?)?.toDate(),
      assignedTasks: List<String>.from(data['assignedTasks'] ?? []),
      responsibilities: List<String>.from(data['responsibilities'] ?? []),
      adminId: data['adminId'] ?? '',
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      joiningDate: (data['joiningDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class SecurityShiftModel {
  final String id;
  final String securityId;
  final String securityName;
  final String date;
  final String shiftType;
  final DateTime startTime;
  final DateTime endTime;
  final int duration;
  final String gateAssignment;
  final String gateLocation;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  SecurityShiftModel({
    required this.id,
    required this.securityId,
    required this.securityName,
    required this.date,
    required this.shiftType,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.gateAssignment,
    required this.gateLocation,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
  });

  factory SecurityShiftModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SecurityShiftModel(
      id: id,
      securityId: data['securityId'] ?? '',
      securityName: data['securityName'] ?? '',
      date: data['date'] ?? '',
      shiftType: data['shiftType'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      duration: data['duration'] ?? 0,
      gateAssignment: data['gateAssignment'] ?? '',
      gateLocation: data['gateLocation'] ?? '',
      status: data['status'] ?? '',
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
    );
  }
}

class SecurityTaskModel {
  final String id;
  final String taskTitle;
  final String taskDescription;
  final String taskType;
  final String priority;
  final String assignedTo;
  final String assignedToName;
  final String assignedBy;
  final DateTime assignedAt;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? location;
  final String? notes;

  SecurityTaskModel({
    required this.id,
    required this.taskTitle,
    required this.taskDescription,
    required this.taskType,
    required this.priority,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedBy,
    required this.assignedAt,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.location,
    this.notes,
  });

  factory SecurityTaskModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SecurityTaskModel(
      id: id,
      taskTitle: data['taskTitle'] ?? '',
      taskDescription: data['taskDescription'] ?? '',
      taskType: data['taskType'] ?? '',
      priority: data['priority'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      assignedToName: data['assignedToName'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      assignedAt: (data['assignedAt'] as Timestamp).toDate(),
      status: data['status'] ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      location: data['location'],
      notes: data['notes'],
    );
  }
}

class ActivityModel {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color iconColor;

  ActivityModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.iconColor,
  });

  factory ActivityModel.fromVisitorData(
    String id,
    Map<String, dynamic> data,
  ) {
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    final timeStr = updatedAt != null ? _formatTime(updatedAt) : '';
    
    String title;
    IconData icon;
    Color iconColor;
    
    if (data['actualArrival'] != null && data['departure'] == null) {
      title = '${data['visitorName']} checked in';
      icon = Icons.check_circle;
      iconColor = const Color(0xFF16A34A);
    } else if (data['departure'] != null) {
      title = '${data['visitorName']} exited';
      icon = Icons.logout_rounded;
      iconColor = const Color(0xFF9333EA);
    } else {
      title = 'New visitor request';
      icon = Icons.pending_actions;
      iconColor = const Color(0xFFF59E0B);
    }
    
    return ActivityModel(
      id: id,
      title: title,
      subtitle: '${data['flatLabel']} • $timeStr',
      time: timeStr,
      icon: icon,
      iconColor: iconColor,
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
```

---

## Admin App Integration

### Admin Creates Security Staff

**File**: `lib/widgets/add_security_staff_modal.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSecurityStaffModal extends StatefulWidget {
  const AddSecurityStaffModal({Key? key}) : super(key: key);

  @override
  State<AddSecurityStaffModal> createState() => _AddSecurityStaffModalState();
}

class _AddSecurityStaffModalState extends State<AddSecurityStaffModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  
  String _selectedGate = 'Gate A';
  String _gateLocation = 'Main Entrance';
  String _shiftType = 'morning';
  String _shiftTiming = '6:00 AM - 2:00 PM';
  
  final List<String> _gates = ['Gate A', 'Gate B', 'Gate C', 'Main Entrance'];
  final List<String> _shiftTypes = ['morning', 'afternoon', 'night'];
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Add Security Staff',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Employee ID
                TextFormField(
                  controller: _employeeIdController,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter employee ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Gate Assignment
                DropdownButtonFormField<String>(
                  value: _selectedGate,
                  decoration: const InputDecoration(
                    labelText: 'Gate Assignment',
                    border: OutlineInputBorder(),
                  ),
                  items: _gates.map((gate) {
                    return DropdownMenuItem(
                      value: gate,
                      child: Text(gate),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedGate = value!);
                  },
                ),
                const SizedBox(height: 16),
                
                // Shift Type
                DropdownButtonFormField<String>(
                  value: _shiftType,
                  decoration: const InputDecoration(
                    labelText: 'Shift Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _shiftTypes.map((shift) {
                    return DropdownMenuItem(
                      value: shift,
                      child: Text(_getShiftLabel(shift)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _shiftType = value!;
                      _shiftTiming = _getShiftTiming(value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Shift Timing (Display)
                TextFormField(
                  initialValue: _shiftTiming,
                  decoration: const InputDecoration(
                    labelText: 'Shift Timing',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Add Staff'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getShiftLabel(String shiftType) {
    switch (shiftType) {
      case 'morning':
        return 'Morning Shift';
      case 'afternoon':
        return 'Afternoon Shift';
      case 'night':
        return 'Night Shift';
      default:
        return shiftType;
    }
  }

  String _getShiftTiming(String shiftType) {
    switch (shiftType) {
      case 'morning':
        return '6:00 AM - 2:00 PM';
      case 'afternoon':
        return '2:00 PM - 10:00 PM';
      case 'night':
        return '10:00 PM - 6:00 AM';
      default:
        return '';
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: 'Security@123', // Default password
      );
      
      final userId = userCredential.user!.uid;
      
      // Get current admin data
      final currentUser = FirebaseAuth.instance.currentUser!;
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final adminData = adminDoc.data()!;
      
      // Create security_staff document
      await FirebaseFirestore.instance
          .collection('security_staff')
          .doc(userId)
          .set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'employeeId': _employeeIdController.text.trim(),
        'gateAssignment': _selectedGate,
        'gateLocation': _gateLocation,
        'shiftTiming': _shiftTiming,
        'shiftType': _shiftType,
        'status': 'off-duty',
        'assignedTasks': [],
        'responsibilities': [
          'visitor-management',
          'attendance',
          'complaints'
        ],
        'adminId': adminData['adminId'],
        'buildingId': adminData['buildingId'],
        'buildingName': adminData['buildingName'],
        'joiningDate': FieldValue.serverTimestamp(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
      });
      
      // Create users document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'security',
        'adminId': adminData['adminId'],
        'buildingId': adminData['buildingId'],
        'buildingName': adminData['buildingName'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security staff added successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }
}
```

---

## Data Flow

### 1. Admin Creates Security Staff

```
Admin App
    ↓
Opens "Add Security Staff" modal
    ↓
Fills in details:
  - Name, Phone, Email, Employee ID
  - Gate Assignment
  - Shift Type & Timing
    ↓
Submits form
    ↓
Creates Firebase Auth user
    ↓
Creates security_staff/{userId} document
Creates users/{userId} document with role='security'
    ↓
Security guard can now login
```

### 2. Security Guard Logs In

```
Security App Login
    ↓
Firebase Auth sign in
    ↓
Fetch security_staff/{userId} data
    ↓
Display on Dashboard:
  - Name, Employee ID
  - Gate Assignment
  - Shift Timing
  - Current Status
```

### 3. Real-Time Updates

```
Admin updates shift/gate assignment
    ↓
Firestore security_staff document updated
    ↓
Security App Dashboard auto-updates
(via StreamBuilder or periodic refresh)
```

---

## Testing Checklist

- [ ] Admin can create security staff
- [ ] Security staff data saved to Firestore
- [ ] Security guard can login
- [ ] Dashboard displays correct data
- [ ] Gate assignment shows correctly
- [ ] Shift timing displays correctly
- [ ] Status badge shows correct color
- [ ] Visitor statistics update in real-time
- [ ] Quick actions navigate correctly
- [ ] Recent activity displays
- [ ] Real-time updates work

---

**Status**: Complete & Ready for Implementation  
**Last Updated**: March 6, 2026
