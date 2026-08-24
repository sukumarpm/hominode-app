import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/attendance_model.dart';
import '../models/security_user_model.dart';
import 'location_service.dart';

class AttendanceService {
  AttendanceService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final LocationService _locationService = LocationService();

  Future<Map<String, dynamic>> recordCheckIn(SecurityUserModel user) async {
    try {
      final position = await _locationService.getFreshCheckInLocation();
      await _functions.httpsCallable('securityCheckIn').call({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracyMeters': position.accuracy,
      });
      return {'success': true, 'message': 'Checked in successfully'};
    } on FirebaseFunctionsException catch (error) {
      return {'success': false, 'message': error.message ?? 'Check-in failed.'};
    } on LocationAcquisitionException catch (error) {
      return {'success': false, 'message': error.message};
    } catch (_) {
      return {
        'success': false,
        'message': 'Check-in failed. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> recordCheckOut(
    SecurityUserModel user,
    String attendanceId,
  ) async {
    try {
      final position = await _locationService.tryGetCheckoutLocation();
      await _functions.httpsCallable('securityCheckOut').call({
        if (position != null) ...{
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
        },
      });
      return {'success': true, 'message': 'Checked out successfully'};
    } on FirebaseFunctionsException catch (error) {
      return {
        'success': false,
        'message': error.message ?? 'Check-out failed.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Check-out failed. Please try again.',
      };
    }
  }

  Query<Map<String, dynamic>> _openAttendanceQuery(SecurityUserModel user) =>
      _firestore
          .collection('staffAttendance')
          .where('communityId', isEqualTo: user.communityId)
          .where('staffId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'checked_in')
          .orderBy('checkInTime', descending: true)
          .limit(1);

  Future<AttendanceModel?> getTodayAttendance(SecurityUserModel user) async {
    final records = await _openAttendanceQuery(user).get();
    return records.docs.isEmpty
        ? null
        : AttendanceModel.fromFirestore(records.docs.first);
  }

  Stream<AttendanceModel?> getTodayAttendanceStream(SecurityUserModel user) =>
      _openAttendanceQuery(user).snapshots().map(
        (snapshot) => snapshot.docs.isEmpty
            ? null
            : AttendanceModel.fromFirestore(snapshot.docs.first),
      );

  Query<Map<String, dynamic>> _todayQuery() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('staffAttendance')
        .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('checkInTime', descending: true);
  }

  Future<List<AttendanceModel>> getAllStaffAttendanceToday() async =>
      (await _todayQuery().get()).docs
          .map(AttendanceModel.fromFirestore)
          .toList();

  Stream<List<AttendanceModel>> getAllStaffAttendanceTodayStream() =>
      _todayQuery().snapshots().map(
        (snapshot) => snapshot.docs.map(AttendanceModel.fromFirestore).toList(),
      );

  Future<List<AttendanceModel>> getAttendanceHistory(
    String staffId, {
    int days = 30,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _firestore
        .collection('staffAttendance')
        .where('staffId', isEqualTo: staffId)
        .where(
          'checkInTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .orderBy('checkInTime', descending: true)
        .get();
    return snapshot.docs.map(AttendanceModel.fromFirestore).toList();
  }

  Future<bool> updateAttendanceStatus(
    String attendanceId,
    String status,
  ) async {
    await _firestore.collection('staffAttendance').doc(attendanceId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
