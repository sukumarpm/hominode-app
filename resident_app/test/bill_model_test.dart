import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/bill_model.dart';

void main() {
  test('BillModel parses legacy V1 bill shape', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final updatedAt = DateTime.utc(2026, 1, 2);
    final dueDate = DateTime.utc(2026, 1, 20);
    final periodStart = DateTime.utc(2026, 1, 1);
    final periodEnd = DateTime.utc(2026, 1, 31);

    final bill = BillModel.fromMap({
      'communityId': 'C',
      'flatId': 'f1',
      'type': 'maintenance',
      'amount': 1200.5,
      'dueDate': Timestamp.fromDate(dueDate),
      'billingPeriodStart': Timestamp.fromDate(periodStart),
      'billingPeriodEnd': Timestamp.fromDate(periodEnd),
      'status': 'pending',
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    }, 'bill-v1');

    expect(bill.id, 'bill-v1');
    expect(bill.schemaVersion, 1);
    expect(bill.communityId, 'C');
    expect(bill.flatId, 'f1');
    expect(bill.type, 'maintenance');
    expect(bill.amount, 1200.5);
    expect(bill.amountMinor, isNull);
    expect(bill.outstandingAmountMinor, isNull);
    expect(bill.chargeLines, isEmpty);
    expect(bill.dueDate.toUtc(), dueDate);
    expect(bill.billingPeriodStart.toUtc(), periodStart);
    expect(bill.billingPeriodEnd.toUtc(), periodEnd);
    expect(bill.createdAt.toUtc(), createdAt);
    expect(bill.updatedAt.toUtc(), updatedAt);
  });

  test('BillModel parses V2 bill shape with missing legacy-only fields', () {
    final createdAt = DateTime.utc(2026, 2, 1);
    final updatedAt = DateTime.utc(2026, 2, 2);
    final dueDate = DateTime.utc(2026, 2, 20);

    final bill = BillModel.fromMap({
      'schemaVersion': 2,
      'communityId': 'C',
      'residentId': 'r1',
      'flatId': 'f1',
      'billingPeriod': '2026-02',
      'amountMinor': 250000,
      'outstandingAmountMinor': 125000,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': 'partially_paid',
      'chargeLines': [
        {
          'lineId': 'maintenance',
          'code': 'maintenance',
          'label': 'Maintenance',
          'amountMinor': 200000,
        },
        {
          'lineId': 'water',
          'code': 'water',
          'label': 'Water',
          'amountMinor': 50000,
        },
      ],
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    }, 'bill-v2');

    expect(bill.id, 'bill-v2');
    expect(bill.schemaVersion, 2);
    expect(bill.communityId, 'C');
    expect(bill.residentId, 'r1');
    expect(bill.flatId, 'f1');
    expect(bill.billingPeriod, '2026-02');
    expect(bill.amountMinor, 250000);
    expect(bill.outstandingAmountMinor, 125000);
    expect(bill.amount, 2500.0);
    expect(bill.type, 'combined');
    expect(bill.status, 'partially_paid');
    expect(bill.dueDate.toUtc(), dueDate);
    expect(bill.billingPeriodStart.year, 2026);
    expect(bill.billingPeriodStart.month, 2);
    expect(bill.billingPeriodStart.day, 1);
    expect(bill.billingPeriodEnd.year, 2026);
    expect(bill.billingPeriodEnd.month, 2);
    expect(bill.billingPeriodEnd.day, 28);
    expect(bill.chargeLines.length, 2);
    expect(bill.chargeLines.first.label, 'Maintenance');
    expect(bill.chargeLines.first.amountMinor, 200000);
    expect(bill.createdAt.toUtc(), createdAt);
    expect(bill.updatedAt.toUtc(), updatedAt);
  });

  test('BillModel does not treat schemaVersion 2.0 or 2.5 as V2', () {
    final dueDate = DateTime.utc(2026, 3, 20);

    for (final value in [2.0, 2.5]) {
      final bill = BillModel.fromMap({
        'schemaVersion': value,
        'communityId': 'C',
        'flatId': 'f1',
        'amountMinor': 123456,
        'billingPeriod': '2026-03',
        'dueDate': Timestamp.fromDate(dueDate),
      }, 'bill-non-v2');

      expect(bill.schemaVersion, 1);
      expect(bill.amountMinor, isNull);
      expect(bill.billingPeriod, isNull);
      expect(bill.type, '');
      expect(bill.status, 'pending');
    }
  });

  test('BillModel keeps malformed V2 minor units malformed (no truncation)', () {
    final bill = BillModel.fromMap({
      'schemaVersion': 2,
      'communityId': 'C',
      'flatId': 'f1',
      'billingPeriod': '2026-04',
      'amountMinor': 100.5,
      'outstandingAmountMinor': 90.25,
      'chargeLines': [
        {
          'lineId': 'm',
          'code': 'maintenance',
          'label': 'Maintenance',
          'amountMinor': 10.75,
        },
      ],
    }, 'bill-v2-fractional');

    expect(bill.amountMinor, isNull);
    expect(bill.outstandingAmountMinor, isNull);
    expect(bill.chargeLines.single.amountMinor, isNull);
    expect(bill.amount, 0);
  });

  test('BillModel does not synthesize pending status for V2 when status missing', () {
    final bill = BillModel.fromMap({
      'schemaVersion': 2,
      'communityId': 'C',
      'flatId': 'f1',
      'billingPeriod': '2026-05',
      'amountMinor': 10000,
    }, 'bill-v2-no-status');

    expect(bill.status, '');
  });

  test('BillModel toMap/toJson preserves legacy write shape', () {
    final now = DateTime.utc(2026, 1, 1);
    final bill = BillModel(
      id: 'legacy',
      schemaVersion: 2,
      communityId: 'C',
      residentId: 'r1',
      flatId: 'f1',
      billingPeriod: '2026-01',
      amountMinor: 10000,
      outstandingAmountMinor: 5000,
      chargeLines: const [
        BillChargeLineModel(
          lineId: 'm',
          code: 'maintenance',
          label: 'Maintenance',
          amountMinor: 10000,
        ),
      ],
      type: 'maintenance',
      amount: 100,
      dueDate: now,
      billingPeriodStart: now,
      billingPeriodEnd: now,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    final serialized = bill.toMap();
    expect(serialized.keys.toSet(), {
      'id',
      'communityId',
      'flatId',
      'type',
      'amount',
      'dueDate',
      'billingPeriodStart',
      'billingPeriodEnd',
      'status',
      'description',
      'createdAt',
      'updatedAt',
    });
    expect(serialized.containsKey('schemaVersion'), isFalse);
    expect(serialized.containsKey('residentId'), isFalse);
    expect(serialized.containsKey('billingPeriod'), isFalse);
    expect(serialized.containsKey('amountMinor'), isFalse);
    expect(serialized.containsKey('outstandingAmountMinor'), isFalse);
    expect(serialized.containsKey('chargeLines'), isFalse);
    expect(bill.toJson().keys.toSet(), serialized.keys.toSet());
  });
}
