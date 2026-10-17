import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/resident_visitor_lifecycle.dart';

void main() {
  group('ResidentVisitorLifecycle', () {
    test(
      'expected visitors remain Expected with or without Admin approval',
      () {
        for (final approved in [false, true]) {
          final visitor = {'status': 'expected', 'isApproved': approved};
          expect(
            ResidentVisitorLifecycle.tabFor(visitor),
            ResidentVisitorTab.expected,
          );
          expect(
            ResidentVisitorLifecycle.statusKeyFor(visitor),
            'visitor_status_expected',
          );
          expect(
            ResidentVisitorLifecycle.adminDecisionKeyFor(visitor),
            approved ? 'visitor_admin_approved' : isNull,
          );
        }
      },
    );

    test(
      'inside visitors remain Checked In with or without Admin approval',
      () {
        for (final approved in [false, true]) {
          final visitor = {'status': 'inside', 'isApproved': approved};
          expect(
            ResidentVisitorLifecycle.tabFor(visitor),
            ResidentVisitorTab.checkedIn,
          );
          expect(
            ResidentVisitorLifecycle.statusKeyFor(visitor),
            'visitor_status_checked_in',
          );
          expect(
            ResidentVisitorLifecycle.adminDecisionKeyFor(visitor),
            approved ? 'visitor_admin_approved' : isNull,
          );
        }
      },
    );

    test('checkout, denial, cancellation and rejection appear in History', () {
      final cases = <Map<String, dynamic>, String>{
        {'status': 'completed'}: 'visitor_status_checked_out',
        {'status': 'inside', 'departure': DateTime(2026)}:
            'visitor_status_checked_out',
        {'status': 'expected', 'gateAccessStatus': 'denied'}:
            'visitor_status_entry_denied',
        {'status': 'denied'}: 'visitor_status_entry_denied',
        {'status': 'cancelled'}: 'visitor_status_cancelled',
        {'status': 'rejected'}: 'visitor_status_rejected',
      };
      for (final entry in cases.entries) {
        expect(
          ResidentVisitorLifecycle.tabFor(entry.key),
          ResidentVisitorTab.history,
        );
        expect(ResidentVisitorLifecycle.statusKeyFor(entry.key), entry.value);
      }
      expect(
        ResidentVisitorLifecycle.adminDecisionKeyFor({'status': 'rejected'}),
        'visitor_admin_rejected',
      );
    });

    test('each visitor state belongs to exactly one lifecycle tab', () {
      final records = [
        {'status': 'expected', 'isApproved': false},
        {'status': 'expected', 'isApproved': true},
        {'status': 'inside', 'isApproved': false},
        {'status': 'inside', 'isApproved': true},
        {'status': 'completed'},
        {'status': 'expected', 'gateAccessStatus': 'denied'},
      ];
      for (final visitor in records) {
        final membership = [
          ResidentVisitorLifecycle.isExpected(visitor),
          ResidentVisitorLifecycle.isCheckedIn(visitor),
          ResidentVisitorLifecycle.isHistory(visitor),
        ].where((value) => value).length;
        expect(membership, 1);
      }
    });
  });
}
