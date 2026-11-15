import 'package:cloud_firestore/cloud_firestore.dart';

/// Presentation only. Credential retrieval and gate entry remain server-owned.
class ResidentVisitorAuthorization {
  static const window = Duration(hours: 24);
  static DateTime? arrival(Map<String, dynamic> row) {
    final value = row['expectedArrival'] ?? row['expectedTime'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String label(Map<String, dynamic> row) {
    switch (row['authorizationState']) {
      case 'auto_authorized':
        return 'Resident authorized';
      case 'admin_authorized':
        return 'Admin authorized';
      case 'pending_admin':
        return 'Pending Admin approval';
      case 'rejected':
        return 'Rejected';
      case 'revoked':
        return 'Revoked';
    }
    if (row['authorizationManaged'] == true) return 'Authorization unavailable';
    if ((row['visitorPolicySnapshot'] as Map?)?['enforced'] == false) {
      return 'Resident authorized';
    }
    return 'Legacy invitation — authorization checked when opening the pass';
  }

  static bool permitsPassRequest(Map<String, dynamic> row) {
    final state = row['authorizationState'];
    // Historical pending/automatic states cannot decide current availability.
    // Only a successful backend credential response permits display.
    return !const {'rejected', 'revoked'}.contains(state);
  }

  static bool canChange(Map<String, dynamic> row) =>
      const {'expected', 'pending', 'approved'}.contains(row['status']) &&
      row['actualArrival'] == null &&
      row['checkInTime'] == null &&
      row['departure'] == null &&
      row['gateAccessStatus'] != 'denied' &&
      row['gateEntryDeniedAt'] == null &&
      !const {'rejected', 'revoked'}.contains(row['authorizationState']);
  static String passMessage(Map<String, dynamic> row) {
    if (row['actualArrival'] != null ||
        row['departure'] != null ||
        const {
          'inside',
          'arrived',
          'completed',
          'departed',
          'cancelled',
          'canceled',
        }.contains(row['status'])) {
      return 'This visitor pass is unavailable: the visit is checked in, completed, or cancelled.';
    }
    final expected = arrival(row);
    if (expected != null && DateTime.now().isAfter(expected.add(window))) {
      return 'This visitor pass has expired.';
    }
    switch (row['authorizationState']) {
      case 'pending_admin':
        return 'Waiting for your Community Admin. The pass will be available after authorization.';
      case 'rejected':
        return 'This visitor pass is unavailable: rejected.';
      case 'revoked':
        return 'This visitor pass is unavailable: revoked.';
    }
    return 'This visitor pass is unavailable, outside its arrival window, or no longer authorized. Reload to check its current status.';
  }
}
