import 'package:admin_app/utils/phone_input_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'accepts explicit international phone formats without dropping plus',
    () {
      for (final phone in [
        '+91 98765 43210',
        '+63 917 123 4567',
        '+1 415 555 2671',
        '+44 20 7946 0958',
      ]) {
        expect(validateResidentPhoneInput(phone), isNull);
      }
    },
  );

  test('rejects malformed phone input with clear validation', () {
    expect(validateResidentPhoneInput(''), 'Phone number is required');
    expect(
      validateResidentPhoneInput('call me +91 9876543210'),
      contains('valid phone number'),
    );
    expect(
      validateResidentPhoneInput('++919876543210'),
      contains('valid phone number'),
    );
    expect(validateResidentPhoneInput('+123'), contains('7 to 15 digits'));
  });
}
