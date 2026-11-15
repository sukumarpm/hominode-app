import 'package:admin_app/utils/phone_input_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected PH country canonicalizes 940 input before validation', () {
    for (final phone in ['9400000000', '09400000000', '+63 9400000000']) {
      expect(
        normalizeResidentPhoneInput(phone, countryCode: 'PH'),
        '+639400000000',
      );
      expect(validateResidentPhoneInput(phone, countryCode: 'PH'), isNull);
    }
    expect(
      normalizeResidentPhoneInput('9400000000', countryCode: 'IN'),
      '9400000000',
    );
    expect(validateResidentPhoneInput('9400000000'), isNotNull);
  });

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

  test('normalizes PH and IN international mobile formatting to E.164', () {
    expect(normalizeResidentPhoneInput('+63 (917) 123-4567'), '+639171234567');
    expect(normalizeResidentPhoneInput('+91 98765 43210'), '+919876543210');
    expect(
      normalizeResidentPhoneInput('+63 917 123 4567', countryCode: 'IN'),
      '+639171234567',
    );
  });

  test(
    'retains national digits and explicit country for server normalization',
    () {
      for (final sample in [
        ('PH', '0917 123 4567', '09171234567'),
        ('IN', '09876543210', '09876543210'),
        ('US', '(415) 555-2671', '4155552671'),
        ('GB', '020 7946 0958', '02079460958'),
        ('IT', '02 3661 8300', '0236618300'),
      ]) {
        expect(
          normalizeResidentPhoneInput(sample.$2, countryCode: sample.$1),
          sample.$3,
        );
      }
      expect(
        validateResidentPhoneInput('09171234567'),
        contains('Select a country'),
      );
      expect(
        validateResidentPhoneInput('9876543210'),
        contains('Select a country'),
      );
    },
  );

  test(
    'format validation does not substitute for backend numbering metadata',
    () {
      expect(validateResidentPhoneInput('+639400000000'), isNull);
      expect(
        validateResidentPhoneInput('09400000000', countryCode: 'PH'),
        isNull,
      );
      expect(validateResidentPhoneInput('+639421234567'), isNull);
    },
  );

  test('does not truncate, guess or repair malformed mobile numbers', () {
    for (final phone in [
      '+63+9171234567',
      '+63 917 123 4567 ext 2',
      '+0639171234567',
      '+1234567890123456',
    ]) {
      expect(validateResidentPhoneInput(phone), isNotNull, reason: phone);
    }
    expect(validateResidentPhoneInput('639171234567'), isNotNull);
    expect(validateResidentPhoneInput('00919876543210'), isNotNull);
  });
}
