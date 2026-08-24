import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _attendanceCollection = 'attendance';
  final String _staffCollection = 'security_staff';

  // ============================================================================
  // MARK ATTENDANCE
  // ============================================================================

  /// Mark staff member as present
  Future<void> markPresent(String staffId) async {
    try {
      print('AttendanceService: Marking staff as present - $staffId');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final today = _getTodayDateString();
      final now = DateTime.now();

      // Create attendance record
      await _firestore
          .collection(_attendanceCollection)
          .doc('${staffId}_$today')
          .set({
            'staffId': staffId,
            'adminId': adminId,
            'communityId': _adminService.requireCurrentCommunityId(),
            'date': today,
            'status': 'present',
            'checkInTime': Timestamp.fromDate(now),
            'checkOutTime': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Check if staff has work assignment (security staff)
      final staffDoc = await _firestore
          .collection(_staffCollection)
          .doc(staffId)
          .get();
      final staffData = staffDoc.data();
      final hasWorkAssignment = staffData?['gateAssignment'] != null;

      // Update staff status - if they have work assignment, set to on-duty, otherwise present
      await _firestore.collection(_staffCollection).doc(staffId).update({
        'status': hasWorkAssignment ? 'on-duty' : 'present',
        'lastCheckIn': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('AttendanceService: Staff marked as present successfully');
    } catch (e) {
      print('AttendanceService ERROR: Failed to mark present: $e');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Mark staff member as absent
  Future<void> markAbsent(String staffId) async {
    try {
      print('AttendanceService: Marking staff as absent - $staffId');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final today = _getTodayDateString();
      final now = DateTime.now();

      // Create attendance record
      await _firestore
          .collection(_attendanceCollection)
          .doc('${staffId}_$today')
          .set({
            'staffId': staffId,
            'adminId': adminId,
            'communityId': _adminService.requireCurrentCommunityId(),
            'date': today,
            'status': 'absent',
            'checkInTime': null,
            'checkOutTime': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update staff status
      await _firestore.collection(_staffCollection).doc(staffId).update({
        'status': 'absent',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('AttendanceService: Staff marked as absent successfully');
    } catch (e) {
      print('AttendanceService ERROR: Failed to mark absent: $e');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Mark staff member as on leave
  Future<void> markOnLeave(String staffId) async {
    try {
      print('AttendanceService: Marking staff as on leave - $staffId');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final today = _getTodayDateString();

      // Create attendance record
      await _firestore
          .collection(_attendanceCollection)
          .doc('${staffId}_$today')
          .set({
            'staffId': staffId,
            'adminId': adminId,
            'communityId': _adminService.requireCurrentCommunityId(),
            'date': today,
            'status': 'onLeave',
            'checkInTime': null,
            'checkOutTime': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update staff status
      await _firestore.collection(_staffCollection).doc(staffId).update({
        'status': 'onLeave',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('AttendanceService: Staff marked as on leave successfully');
    } catch (e) {
      print('AttendanceService ERROR: Failed to mark on leave: $e');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Mark check-out time for staff member
  Future<void> markCheckOut(String staffId) async {
    try {
      print('AttendanceService: Marking check-out - $staffId');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final today = _getTodayDateString();
      final now = DateTime.now();

      // Update attendance record with check-out time
      await _firestore
          .collection(_attendanceCollection)
          .doc('${staffId}_$today')
          .update({
            'checkOutTime': Timestamp.fromDate(now),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update staff status to off duty
      await _firestore.collection(_staffCollection).doc(staffId).update({
        'status': 'offDuty',
        'lastCheckOut': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('AttendanceService: Check-out marked successfully');
    } catch (e) {
      print('AttendanceService ERROR: Failed to mark check-out: $e');
      throw Exception('Failed to mark check-out: $e');
    }
  }

  // ============================================================================
  // GET ATTENDANCE DATA
  // ============================================================================

  /// Get today's attendance for all staff filtered by adminId
  Stream<List<AttendanceRecord>> getTodayAttendance() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print(
      'AttendanceService: Fetching today\'s attendance for admin: $adminId',
    );
    final today = _getTodayDateString();

    return _firestore
        .collection(_attendanceCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('date', isEqualTo: today)
        .snapshots()
        .map((snapshot) {
          print(
            'AttendanceService: Received ${snapshot.docs.length} attendance records for today',
          );
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return AttendanceRecord.fromFirestore(doc.id, data);
          }).toList();
        })
        .handleError((error) {
          print('AttendanceService ERROR: $error');
          throw Exception('Failed to fetch today\'s attendance: $error');
        });
  }

  /// Get attendance history (last 30 days) filtered by adminId
  Stream<List<DailyAttendanceSummary>> getAttendanceHistory({int days = 30}) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print(
      'AttendanceService: Fetching attendance history for admin: $adminId, last $days days',
    );

    final startDate = DateTime.now().subtract(Duration(days: days));
    final startDateString = _getDateString(startDate);

    return _firestore
        .collection(_attendanceCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .asyncMap((snapshot) async {
          print(
            'AttendanceService: Processing ${snapshot.docs.length} attendance records',
          );

          // Filter by date in memory instead of using where clause to avoid composite index
          final filteredDocs = snapshot.docs.where((doc) {
            final date = doc.data()['date'] as String?;
            return date != null && date.compareTo(startDateString) >= 0;
          }).toList();

          // Group by date
          final Map<String, List<AttendanceRecord>> groupedByDate = {};
          for (var doc in filteredDocs) {
            final data = doc.data();
            final record = AttendanceRecord.fromFirestore(doc.id, data);
            if (!groupedByDate.containsKey(record.date)) {
              groupedByDate[record.date] = [];
            }
            groupedByDate[record.date]!.add(record);
          }

          // Get total staff count for this admin
          final staffSnapshot = await _firestore
              .collection(_staffCollection)
              .where(
                'communityId',
                isEqualTo: _adminService.requireCurrentCommunityId(),
              )
              .get();
          final totalStaff = staffSnapshot.docs.length;

          // Create daily summaries
          final summaries = groupedByDate.entries.map((entry) {
            final date = entry.key;
            final records = entry.value;

            final present = records.where((r) => r.status == 'present').length;
            final absent = records.where((r) => r.status == 'absent').length;
            final onLeave = records.where((r) => r.status == 'onLeave').length;

            return DailyAttendanceSummary(
              date: date,
              totalStaff: totalStaff,
              present: present,
              absent: absent,
              onLeave: onLeave,
            );
          }).toList();

          // Sort by date descending in memory
          summaries.sort((a, b) => b.date.compareTo(a.date));

          print(
            'AttendanceService: Created ${summaries.length} daily summaries',
          );
          return summaries;
        })
        .handleError((error) {
          print('AttendanceService ERROR: $error');
          throw Exception('Failed to fetch attendance history: $error');
        });
  }

  /// Get attendance for specific date filtered by adminId
  Future<List<AttendanceRecord>> getAttendanceByDate(String date) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print(
        'AttendanceService: Fetching attendance for admin: $adminId, date - $date',
      );

      final snapshot = await _firestore
          .collection(_attendanceCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      // Filter by date in memory instead of using where clause to avoid composite index
      final records = snapshot.docs
          .where((doc) => doc.data()['date'] == date)
          .map((doc) {
            final data = doc.data();
            return AttendanceRecord.fromFirestore(doc.id, data);
          })
          .toList();

      print('AttendanceService: Found ${records.length} records for $date');

      return records;
    } catch (e) {
      print('AttendanceService ERROR: Failed to fetch attendance by date: $e');
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  /// Get attendance statistics for today filtered by adminId
  Future<AttendanceStats> getTodayStats() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('AttendanceService: Fetching today\'s stats for admin: $adminId');

      final today = _getTodayDateString();

      // Get all staff for this admin
      final staffSnapshot = await _firestore
          .collection(_staffCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();
      final totalStaff = staffSnapshot.docs.length;

      // Get today's attendance for this admin - fetch all and filter in memory
      final attendanceSnapshot = await _firestore
          .collection(_attendanceCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      // Filter by today's date in memory instead of using where clause
      final todayRecords = attendanceSnapshot.docs
          .where((doc) => doc.data()['date'] == today)
          .toList();

      int present = 0;
      int absent = 0;
      int onLeave = 0;

      for (var doc in todayRecords) {
        final status = doc.data()['status'] as String?;
        if (status == 'present') {
          present++;
        } else if (status == 'absent')
          absent++;
        else if (status == 'onLeave')
          onLeave++;
      }

      final pending = totalStaff - (present + absent + onLeave);

      print(
        'AttendanceService: Stats - Total: $totalStaff, Present: $present, Absent: $absent, Leave: $onLeave, Pending: $pending',
      );

      return AttendanceStats(
        totalStaff: totalStaff,
        present: present,
        absent: absent,
        onLeave: onLeave,
        pending: pending,
      );
    } catch (e) {
      print('AttendanceService ERROR: Failed to fetch stats: $e');
      throw Exception('Failed to fetch attendance stats: $e');
    }
  }

  /// Mark all staff as present for admin
  Future<void> markAllPresent() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print(
        'AttendanceService: Marking all staff as present for admin: $adminId',
      );

      final staffSnapshot = await _firestore
          .collection(_staffCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();
      final batch = _firestore.batch();
      final today = _getTodayDateString();
      final now = DateTime.now();

      for (var staffDoc in staffSnapshot.docs) {
        final staffId = staffDoc.id;

        // Create attendance record
        final attendanceRef = _firestore
            .collection(_attendanceCollection)
            .doc('${staffId}_$today');

        batch.set(attendanceRef, {
          'staffId': staffId,
          'adminId': adminId,
          'communityId': _adminService.requireCurrentCommunityId(),
          'date': today,
          'status': 'present',
          'checkInTime': Timestamp.fromDate(now),
          'checkOutTime': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update staff status
        batch.update(staffDoc.reference, {
          'status': 'present',
          'lastCheckIn': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('AttendanceService: All staff marked as present successfully');
    } catch (e) {
      print('AttendanceService ERROR: Failed to mark all present: $e');
      throw Exception('Failed to mark all present: $e');
    }
  }

  /// Get attendance statistics for a specific staff member
  Future<StaffAttendanceStats> getStaffAttendanceStats(
    String staffId, {
    int days = 30,
  }) async {
    try {
      print(
        'AttendanceService: Fetching attendance stats for staff - $staffId',
      );

      final startDate = DateTime.now().subtract(Duration(days: days));
      final startDateString = _getDateString(startDate);

      final snapshot = await _firestore
          .collection(_attendanceCollection)
          .where('staffId', isEqualTo: staffId)
          .where('date', isGreaterThanOrEqualTo: startDateString)
          .get();

      int present = 0;
      int absent = 0;
      int onLeave = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'present') {
          present++;
        } else if (status == 'absent')
          absent++;
        else if (status == 'onLeave')
          onLeave++;
      }

      print(
        'AttendanceService: Staff stats - Present: $present, Absent: $absent, Leave: $onLeave',
      );

      return StaffAttendanceStats(
        totalDays: days,
        present: present,
        absent: absent,
        onLeave: onLeave,
      );
    } catch (e) {
      print('AttendanceService ERROR: Failed to fetch staff stats: $e');
      // Return empty stats instead of throwing
      return StaffAttendanceStats(
        totalDays: days,
        present: 0,
        absent: 0,
        onLeave: 0,
      );
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  String _getTodayDateString() {
    final now = DateTime.now();
    return _getDateString(now);
  }

  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// ATTENDANCE MODELS
// ============================================================================

class AttendanceRecord {
  final String id;
  final String staffId;
  final String adminId;
  final String date;
  final String status; // 'present', 'absent', 'onLeave'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.adminId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceRecord.fromFirestore(String id, Map<String, dynamic> data) {
    return AttendanceRecord(
      id: id,
      staffId: data['staffId'] ?? '',
      adminId: data['adminId'] ?? '',
      date: data['date'] ?? '',
      status: data['status'] ?? 'pending',
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'adminId': adminId,
      'date': date,
      'status': status,
      'checkInTime': checkInTime != null
          ? Timestamp.fromDate(checkInTime!)
          : null,
      'checkOutTime': checkOutTime != null
          ? Timestamp.fromDate(checkOutTime!)
          : null,
    };
  }
}

class DailyAttendanceSummary {
  final String date;
  final int totalStaff;
  final int present;
  final int absent;
  final int onLeave;

  DailyAttendanceSummary({
    required this.date,
    required this.totalStaff,
    required this.present,
    required this.absent,
    required this.onLeave,
  });

  int get pending => totalStaff - (present + absent + onLeave);

  double get attendancePercentage {
    if (totalStaff == 0) return 0.0;
    return (present / totalStaff) * 100;
  }
}

class AttendanceStats {
  final int totalStaff;
  final int present;
  final int absent;
  final int onLeave;
  final int pending;

  AttendanceStats({
    required this.totalStaff,
    required this.present,
    required this.absent,
    required this.onLeave,
    required this.pending,
  });

  double get attendancePercentage {
    if (totalStaff == 0) return 0.0;
    return (present / totalStaff) * 100;
  }
}

class StaffAttendanceStats {
  final int totalDays;
  final int present;
  final int absent;
  final int onLeave;

  StaffAttendanceStats({
    required this.totalDays,
    required this.present,
    required this.absent,
    required this.onLeave,
  });

  double get attendancePercentage {
    final totalMarked = present + absent + onLeave;
    if (totalMarked == 0) return 0.0;
    return (present / totalMarked) * 100;
  }
}
