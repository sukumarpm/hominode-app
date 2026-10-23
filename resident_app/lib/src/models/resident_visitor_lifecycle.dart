import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/visitor_qr_contract.dart';

enum ResidentVisitorTab { expected, checkedIn, history }

/// Presentation-only classification of a visitor's physical lifecycle.
/// Admin approval remains independent metadata and never determines whether a
/// visitor is expected or checked in.
class ResidentVisitorLifecycle {
  static const _checkedOutStates = {
    'checked-out',
    'checked_out',
    'checkedout',
    'departed',
    'exited',
    'completed',
  };
  static const _expectedStates = {'expected', 'pending', 'approved'};
  static const _checkedInStates = {'inside', 'active', 'arrived', 'checked_in'};
  static const _cancelledStates = {'cancelled', 'canceled'};

  static bool _hasValue(dynamic value) =>
      value != null && value.toString().isNotEmpty;

  static bool _isDenied(Map<String, dynamic> visitor) =>
      visitor['gateAccessStatus'] == 'denied' ||
      const {
        'denied',
        'entry_denied',
        'denied-entry',
      }.contains(visitor['status']?.toString().toLowerCase()) ||
      _hasValue(visitor['gateEntryDeniedAt']) ||
      _hasValue(visitor['deniedAt']);

  static bool _hasDeparture(Map<String, dynamic> visitor) =>
      _hasValue(visitor['departure']) || _hasValue(visitor['checkOutTime']);

  static bool _hasArrival(Map<String, dynamic> visitor) =>
      _hasValue(visitor['actualArrival']) || _hasValue(visitor['checkInTime']);

  // Align the resident's expected/history tabs with the existing QR pass
  // expiration rule. This is a display-only classification: Firestore status
  // and gate authorization are never changed by this code.
  static DateTime? _expectedArrival(Map<String, dynamic> visitor) {
    final value = visitor['expectedArrival'] ?? visitor['expectedTime'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int && value >= 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool _isExpired(Map<String, dynamic> visitor, {DateTime? now}) {
    final expectedArrival = _expectedArrival(visitor);
    // Unknown dates must not be advertised as still-valid invitations.
    if (expectedArrival == null) return true;
    return (now ?? DateTime.now()).isAfter(
      expectedArrival.add(VisitorQrContract.validityWindow),
    );
  }

  static ResidentVisitorTab tabFor(
    Map<String, dynamic> visitor, {
    DateTime? now,
  }) {
    final status = visitor['status']?.toString().toLowerCase();
    if (_hasDeparture(visitor) || _checkedOutStates.contains(status)) {
      return ResidentVisitorTab.history;
    }
    if (_isDenied(visitor) ||
        _cancelledStates.contains(status) ||
        status == 'rejected') {
      return ResidentVisitorTab.history;
    }
    if (_hasArrival(visitor) || _checkedInStates.contains(status)) {
      return ResidentVisitorTab.checkedIn;
    }
    if (_expectedStates.contains(status)) {
      return _isExpired(visitor, now: now)
          ? ResidentVisitorTab.history
          : ResidentVisitorTab.expected;
    }

    // Keep legacy/unknown states visible instead of dropping a host's record.
    return ResidentVisitorTab.history;
  }

  static String statusKeyFor(Map<String, dynamic> visitor, {DateTime? now}) {
    final status = visitor['status']?.toString().toLowerCase();
    if (_hasDeparture(visitor) || _checkedOutStates.contains(status)) {
      return 'visitor_status_checked_out';
    }
    if (_isDenied(visitor)) return 'visitor_status_entry_denied';
    if (_cancelledStates.contains(status)) return 'visitor_status_cancelled';
    if (status == 'rejected') return 'visitor_status_rejected';
    if (_hasArrival(visitor) || _checkedInStates.contains(status)) {
      return 'visitor_status_checked_in';
    }
    if (_expectedStates.contains(status)) {
      return _isExpired(visitor, now: now)
          ? 'visitor_status_expired'
          : 'visitor_status_expected';
    }
    return 'visitor_status_unknown';
  }

  /// Optional Admin decision, shown separately from the physical status.
  static String? adminDecisionKeyFor(Map<String, dynamic> visitor) {
    final status = visitor['status']?.toString().toLowerCase();
    if (status == 'rejected') return 'visitor_admin_rejected';
    if (visitor['isApproved'] == true &&
        tabFor(visitor) != ResidentVisitorTab.history) {
      return 'visitor_admin_approved';
    }
    return null;
  }

  static bool isExpected(Map<String, dynamic> visitor, {DateTime? now}) =>
      tabFor(visitor, now: now) == ResidentVisitorTab.expected;

  static bool isCheckedIn(Map<String, dynamic> visitor) =>
      tabFor(visitor) == ResidentVisitorTab.checkedIn;

  static bool isHistory(Map<String, dynamic> visitor, {DateTime? now}) =>
      tabFor(visitor, now: now) == ResidentVisitorTab.history;
}
