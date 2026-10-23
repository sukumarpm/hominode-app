import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/resident_visitor_lifecycle.dart';
import 'package:resident_app/src/services/visitor_qr_contract.dart';

void main() {
  final planned = DateTime.utc(2026, 10, 13, 10, 1);
  final withinWindow = planned.add(const Duration(hours: 23));
  final exactEnd = planned.add(const Duration(hours: 24));
  final afterWindow = planned.add(const Duration(hours: 24, seconds: 1));

  Map<String, dynamic> invite({Object? date, String status = 'expected'}) => {
    'status': status,
    'isApproved': false,
    'expectedArrival': date ?? Timestamp.fromDate(planned),
  };

  test('October 13 unarrived visitor appears in History on October 23', () {
    final visitor = invite();
    final onOctober23 = DateTime.utc(2026, 10, 23);
    expect(
      ResidentVisitorLifecycle.tabFor(visitor, now: onOctober23),
      ResidentVisitorTab.history,
    );
    expect(
      ResidentVisitorLifecycle.statusKeyFor(visitor, now: onOctober23),
      'visitor_status_expired',
    );
    expect(
      ResidentVisitorLifecycle.isExpected(visitor, now: onOctober23),
      isFalse,
    );
    expect(
      ResidentVisitorLifecycle.isHistory(visitor, now: onOctober23),
      isTrue,
    );
    expect(VisitorQrContract.canDisplay(visitor, now: onOctober23), isFalse);
  });

  test(
    'invitation remains Expected throughout the existing 24-hour grace window',
    () {
      final visitor = invite();
      for (final now in [withinWindow, exactEnd]) {
        expect(
          ResidentVisitorLifecycle.tabFor(visitor, now: now),
          ResidentVisitorTab.expected,
        );
        expect(
          ResidentVisitorLifecycle.statusKeyFor(visitor, now: now),
          'visitor_status_expected',
        );
      }
      expect(
        ResidentVisitorLifecycle.tabFor(visitor, now: afterWindow),
        ResidentVisitorTab.history,
      );
    },
  );

  test('checked-in and terminal states take precedence over expiry', () {
    expect(
      ResidentVisitorLifecycle.tabFor({
        ...invite(),
        'actualArrival': Timestamp.fromDate(planned),
      }, now: afterWindow),
      ResidentVisitorTab.checkedIn,
    );
    expect(
      ResidentVisitorLifecycle.tabFor(
        invite(status: 'cancelled'),
        now: afterWindow,
      ),
      ResidentVisitorTab.history,
    );
    expect(
      ResidentVisitorLifecycle.statusKeyFor(
        invite(status: 'cancelled'),
        now: afterWindow,
      ),
      'visitor_status_cancelled',
    );
  });

  test(
    'Timestamp, DateTime, and millisecond integer represent same instant',
    () {
      for (final date in [
        Timestamp.fromDate(planned),
        planned,
        planned.millisecondsSinceEpoch,
      ]) {
        final visitor = invite(date: date);
        expect(
          ResidentVisitorLifecycle.tabFor(visitor, now: afterWindow),
          ResidentVisitorTab.history,
        );
      }
    },
  );

  test(
    'missing or unusable visit date is not treated as an active invitation',
    () {
      final visitor = invite(date: 'not-a-date');
      expect(
        ResidentVisitorLifecycle.tabFor(visitor, now: afterWindow),
        ResidentVisitorTab.history,
      );
    },
  );
}
