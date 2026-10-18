import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/utils/resident_phone.dart';

void main() {
  test(
    'new canonical-only users retain their phone in profile, chat and Marketplace projections',
    () {
      expect(
        residentDisplayPhone({'phoneNumber': '+639170000000'}),
        '+639170000000',
      );
      expect(
        residentDisplayPhone({
          'phoneNumber': '+639170000000',
          'phone': 'old alias',
        }),
        '+639170000000',
      );
    },
  );
  test('display keeps legacy phone-only data readable without changing it', () {
    final legacy = {'phone': 'historical contact'};
    expect(residentDisplayPhone(legacy), 'historical contact');
    expect(legacy, {'phone': 'historical contact'});
    expect(residentDisplayPhone(null), '');
    expect(
      residentDisplayPhone({'phoneNumber': 1, 'phone': 'legacy'}),
      'legacy',
    );
  });
}
