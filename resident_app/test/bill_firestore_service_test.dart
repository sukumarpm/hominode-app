import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/bill_firestore_service.dart';

void main() {
  test('only schemaVersion 2 selects the V2 billing contract', () {
    for (final schemaVersion in [null, 1, '2', 3]) {
      expect(
        BillFirestoreService.isV2Bill({'schemaVersion': schemaVersion}),
        isFalse,
      );
    }
    expect(BillFirestoreService.isV2Bill({'schemaVersion': 2}), isTrue);
  });

  test('formats V2 integer paise without rounding through doubles', () {
    expect(BillFirestoreService.formatInrMinorUnits(1), '₹0.01');
    expect(BillFirestoreService.formatInrMinorUnits(29), '₹0.29');
    expect(BillFirestoreService.formatInrMinorUnits(250000), '₹2500.00');
    expect(
      BillFirestoreService.formatInrMinorUnits(9007199254740991),
      '₹90071992547409.91',
    );
    expect(BillFirestoreService.formatInrMinorUnits(1.5), '—');
    expect(BillFirestoreService.formatInrMinorUnits(-1), '—');
    final v2Bill = {'schemaVersion': 2, 'currency': 'INR'};
    expect(
      BillFirestoreService.formatV2BillMinorUnits(v2Bill, 250000),
      '₹2500.00',
    );
    expect(
      BillFirestoreService.formatV2BillMinorUnits({
        ...v2Bill,
        'currency': 'USD',
      }, 250000),
      '—',
    );
  });

  test('V2 charge lines use integer minor units and labels', () {
    final lines = BillFirestoreService.getV2ChargeLines({
      'schemaVersion': 2,
      'currency': 'INR',
      'chargeLines': [
        {
          'lineId': 'maintenance',
          'code': 'maintenance',
          'label': 'Maintenance',
          'amountMinor': 225000,
        },
        {
          'lineId': 'custom',
          'code': 'custom',
          'label': 'Lift',
          'amountMinor': 25000,
        },
      ],
    });

    expect(lines.map((line) => line.label), ['Maintenance', 'Lift']);
    expect(lines.map((line) => line.amountMinor), [225000, 25000]);
    expect(
      BillFirestoreService.getV2ChargeLines({
        'schemaVersion': 1,
        'chargeLines': [
          {'label': 'Ignored', 'amountMinor': 100},
        ],
      }),
      isEmpty,
    );
  });

  test('V1 chargeBreakdown handling is preserved', () {
    final service = BillFirestoreService();
    expect(
      service.getBillBreakdown({
        'chargeBreakdown': {'Water': 125.5, 'Maintenance': 500},
      }),
      {
        'Electricity': 0,
        'Maintenance': 500.0,
        'Parking': 0,
        'Security': 0,
        'Service': 0,
        'Water': 125.5,
      },
    );
    expect(
      service.getBillBreakdown({
        'schemaVersion': 2,
        'chargeLines': [
          {'label': 'Maintenance', 'amountMinor': 50000},
        ],
      }),
      isEmpty,
    );
  });
}
