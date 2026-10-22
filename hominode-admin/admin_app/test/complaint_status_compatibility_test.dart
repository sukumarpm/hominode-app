import 'package:admin_app/models/complaint_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin accepts canonical and legacy complaint status values', () {
    for (final value in ['pending', 'open', 'new']) {
      expect(complaintStatusFromFirestore(value), ComplaintStatus.pending);
    }
    for (final value in [
      'inprogress',
      'inProgress',
      'in-progress',
      'in_progress',
      'in progress',
      'assigned',
    ]) {
      expect(complaintStatusFromFirestore(value), ComplaintStatus.inProgress);
    }
    for (final value in ['completed', 'resolved', 'closed']) {
      expect(complaintStatusFromFirestore(value), ComplaintStatus.resolved);
    }
  });
}
