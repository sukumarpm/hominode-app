/// A successful historical operation is a receipt, never new entry permission.
class VisitorVerificationReceipt {
  VisitorVerificationReceipt(this.data);
  final Map<String, dynamic> data;
  bool get isFreshEntry =>
      data['idempotent'] == false &&
      (data['currentStatus'] ?? data['status']) == 'inside';
  String get title => data['idempotent'] == true
      ? 'Previously processed verification'
      : 'Verification receipt';
  String get currentState => switch (data['currentStatus']) {
    'inside' => 'Inside',
    'completed' || 'departed' || 'checked_out' => 'Checked out',
    'expected' || 'pending' || 'approved' => 'Expected',
    'cancelled' || 'canceled' => 'Cancelled',
    'rejected' => 'Rejected',
    _ => 'Unavailable — refresh the visitor list',
  };
  String get processedTime {
    final value = data['processedAt'];
    if (value is! int) return 'Unavailable';
    return DateTime.fromMillisecondsSinceEpoch(
      value,
      isUtc: true,
    ).toIso8601String();
  }

  String get message =>
      'No new entry was granted.\n\n'
      'Current visit state: $currentState\n'
      'Original processing time (UTC): $processedTime';
}
