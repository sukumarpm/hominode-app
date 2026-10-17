import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/utils/visitor_qr_payload.dart';

void main() {
  test('parses the current opaque-token payload used by Resident', () {
    final parsed = VisitorQrPayload.tryParse(
      '{"type":"hominode_visitor","version":1,"token":"opaque-token"}',
    );

    expect(parsed?.qrToken, 'opaque-token');
    expect(parsed?.legacyVisitorId, isNull);
  });

  test('retains legacy visitor ID QR compatibility', () {
    expect(
      VisitorQrPayload.tryParse(
        '{"visitorId":"legacy-123","legacy":true}',
      )?.legacyVisitorId,
      'legacy-123',
    );
    expect(
      VisitorQrPayload.tryParse('legacy-123')?.legacyVisitorId,
      'legacy-123',
    );
  });

  test('rejects empty QR data', () {
    expect(VisitorQrPayload.tryParse('  '), isNull);
  });
}
