import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();

  static const String _attendanceCollection = 'staffAttendance';
  static const String _staffCollection = 'securityStaff';

  // Admin attendance is reporting-only. Physical check-in and check-out are
  // performed by the trusted securityCheckIn/securityCheckOut Cloud Functions.

  Stream<List<AttendanceRecord>> getTodayAttendance() {
    final communityId = _adminService.requireCurrentCommunityId();
    final range = _localDayRange(DateTime.now());

    return _attendanceQuery(
      communityId,
      range,
    ).snapshots().map(_recordsFromSnapshot);
  }

  Stream<List<DailyAttendanceSummary>> getAttendanceHistory({int days = 30}) {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Must be greater than zero.');
    }

    final communityId = _adminService.requireCurrentCommunityId();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final range = _DateRange(start, DateTime(now.year, now.month, now.day + 1));

    return _attendanceQuery(communityId, range).snapshots().asyncMap((
      snapshot,
    ) async {
      final records = _recordsFromSnapshot(snapshot);
      final staffSnapshot = await _firestore
          .collection(_staffCollection)
          .where('communityId', isEqualTo: communityId)
          .get();
      final totalStaff = staffSnapshot.docs.length;

      final groupedByDate = <String, List<AttendanceRecord>>{};
      for (final record in records) {
        groupedByDate.putIfAbsent(record.date, () => []).add(record);
      }

      final summaries = groupedByDate.entries.map((entry) {
        final attendedStaffIds = entry.value
            .map((record) => record.staffId)
            .toSet();
        final onDutyStaffIds = entry.value
            .where((record) => record.isCurrentlyOnDuty)
            .map((record) => record.staffId)
            .toSet();
        final completedStaffIds = entry.value
            .where((record) => record.isCompleted)
            .map((record) => record.staffId)
            .toSet();

        return DailyAttendanceSummary(
          date: entry.key,
          totalStaff: totalStaff,
          present: attendedStaffIds.length,
          absent: 0,
          onLeave: 0,
          currentlyOnDuty: onDutyStaffIds.length,
          completed: completedStaffIds.length,
        );
      }).toList()..sort((a, b) => b.date.compareTo(a.date));

      return summaries;
    });
  }

  Future<List<AttendanceRecord>> getAttendanceByDate(String date) async {
    final communityId = _adminService.requireCurrentCommunityId();
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      throw FormatException('Attendance date must use YYYY-MM-DD.', date);
    }

    final snapshot = await _attendanceQuery(
      communityId,
      _localDayRange(parsedDate),
    ).get();
    return _recordsFromSnapshot(snapshot);
  }

  Future<AttendanceStats> getTodayStats() async {
    final communityId = _adminService.requireCurrentCommunityId();
    final range = _localDayRange(DateTime.now());

    final results = await Future.wait([
      _firestore
          .collection(_staffCollection)
          .where('communityId', isEqualTo: communityId)
          .get(),
      _attendanceQuery(communityId, range).get(),
    ]);

    final totalStaff = results[0].docs.length;
    final attendanceRecords = _recordsFromSnapshot(results[1]);
    final attendedStaffIds = attendanceRecords
        .map((record) => record.staffId)
        .toSet();
    final onDutyStaffIds = attendanceRecords
        .where((record) => record.isCurrentlyOnDuty)
        .map((record) => record.staffId)
        .toSet();
    final completedStaffIds = attendanceRecords
        .where((record) => record.isCompleted)
        .map((record) => record.staffId)
        .toSet();

    return AttendanceStats(
      totalStaff: totalStaff,
      present: attendedStaffIds.length,
      absent: 0,
      onLeave: 0,
      pending: (totalStaff - attendedStaffIds.length).clamp(0, totalStaff),
      currentlyOnDuty: onDutyStaffIds.length,
      completed: completedStaffIds.length,
    );
  }

  Future<StaffAttendanceStats> getStaffAttendanceStats(
    String staffId, {
    int days = 30,
  }) async {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Must be greater than zero.');
    }

    final communityId = _adminService.requireCurrentCommunityId();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final snapshot = await _firestore
        .collection(_attendanceCollection)
        .where('communityId', isEqualTo: communityId)
        .where('staffId', isEqualTo: staffId)
        .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();
    final records = _recordsFromSnapshot(snapshot);
    final attendedDates = records.map((record) => record.date).toSet();

    return StaffAttendanceStats(
      totalDays: days,
      present: attendedDates.length,
      absent: 0,
      onLeave: 0,
      currentlyOnDuty: records.any((record) => record.isCurrentlyOnDuty),
      completed: records.where((record) => record.isCompleted).length,
    );
  }

  Query<Map<String, dynamic>> _attendanceQuery(
    String communityId,
    _DateRange range,
  ) {
    return _firestore
        .collection(_attendanceCollection)
        .where('communityId', isEqualTo: communityId)
        .where(
          'checkInTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('checkInTime', isLessThan: Timestamp.fromDate(range.end));
  }

  List<AttendanceRecord> _recordsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  _DateRange _localDayRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return _DateRange(start, DateTime(date.year, date.month, date.day + 1));
  }
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.communityId,
    required this.staffId,
    required this.staffName,
    required this.gateName,
    required this.checkInTime,
    required this.status,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String communityId;
  final String staffId;
  final String staffName;
  final String gateName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String status;
  final Map<String, dynamic>? checkInLocation;
  final Map<String, dynamic>? checkOutLocation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get date => _formatDate(checkInTime);

  bool get isCurrentlyOnDuty => checkOutTime == null && status == 'checked_in';

  bool get isCompleted => checkOutTime != null && status == 'completed';

  factory AttendanceRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final checkInTimestamp = data['checkInTime'];
    if (checkInTimestamp is! Timestamp) {
      throw StateError('Attendance $id has no canonical checkInTime.');
    }

    return AttendanceRecord(
      id: id,
      communityId: data['communityId'] as String? ?? '',
      staffId: data['staffId'] as String? ?? '',
      staffName: data['staffName'] as String? ?? '',
      gateName: data['gateName'] as String? ?? '',
      checkInTime: checkInTimestamp.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? '',
      checkInLocation: _mapValue(data['checkInLocation']),
      checkOutLocation: _mapValue(data['checkOutLocation']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class DailyAttendanceSummary {
  const DailyAttendanceSummary({
    required this.date,
    required this.totalStaff,
    required this.present,
    required this.absent,
    required this.onLeave,
    this.currentlyOnDuty = 0,
    this.completed = 0,
  });

  final String date;
  final int totalStaff;
  final int present;
  final int absent;
  final int onLeave;
  final int currentlyOnDuty;
  final int completed;

  int get pending => (totalStaff - present).clamp(0, totalStaff);

  double get attendancePercentage {
    if (totalStaff == 0) return 0;
    return (present / totalStaff) * 100;
  }
}

class AttendanceStats {
  const AttendanceStats({
    required this.totalStaff,
    required this.present,
    required this.absent,
    required this.onLeave,
    required this.pending,
    this.currentlyOnDuty = 0,
    this.completed = 0,
  });

  final int totalStaff;
  final int present;
  final int absent;
  final int onLeave;
  final int pending;
  final int currentlyOnDuty;
  final int completed;

  double get attendancePercentage {
    if (totalStaff == 0) return 0;
    return (present / totalStaff) * 100;
  }
}

class StaffAttendanceStats {
  const StaffAttendanceStats({
    required this.totalDays,
    required this.present,
    required this.absent,
    required this.onLeave,
    this.currentlyOnDuty = false,
    this.completed = 0,
  });

  final int totalDays;
  final int present;
  final int absent;
  final int onLeave;
  final bool currentlyOnDuty;
  final int completed;

  double get attendancePercentage {
    if (totalDays == 0) return 0;
    return (present / totalDays) * 100;
  }
}
