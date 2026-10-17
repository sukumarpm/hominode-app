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

  static ResidentVisitorTab tabFor(Map<String, dynamic> visitor) {
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
    if (_expectedStates.contains(status)) return ResidentVisitorTab.expected;

    // Keep legacy/unknown states visible instead of dropping a host's record.
    return ResidentVisitorTab.history;
  }

  static String statusKeyFor(Map<String, dynamic> visitor) {
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
    if (_expectedStates.contains(status)) return 'visitor_status_expected';
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

  static bool isExpected(Map<String, dynamic> visitor) =>
      tabFor(visitor) == ResidentVisitorTab.expected;

  static bool isCheckedIn(Map<String, dynamic> visitor) =>
      tabFor(visitor) == ResidentVisitorTab.checkedIn;

  static bool isHistory(Map<String, dynamic> visitor) =>
      tabFor(visitor) == ResidentVisitorTab.history;
}
