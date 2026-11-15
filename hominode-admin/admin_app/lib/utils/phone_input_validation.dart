import 'resident_phone_countries.dart';

/// Compacts international or national input for the existing creation payload.
/// Most national input retains its explicit country for backend normalization.
/// The existing PH 0940 exception is canonicalized before final format validation;
/// backend metadata validation remains authoritative for other numbering plans.
String normalizeResidentPhoneInput(String? value, {String? countryCode}) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) throw const FormatException('Phone number is required');

  if (!RegExp(r'^\+?[0-9().\s-]+$').hasMatch(input)) {
    throw const FormatException(
      'Enter a valid phone number. Use digits and standard phone formatting.',
    );
  }

  final digits = input.replaceAll(RegExp(r'[\s().+-]'), '');
  if (digits.length < 7 || digits.length > 15) {
    throw const FormatException(
      'Enter a valid phone number with 7 to 15 digits.',
    );
  }

  if (!input.startsWith('+')) {
    final country = countryCode?.trim().toUpperCase();
    if (!residentPhoneCountries.containsKey(country)) {
      throw const FormatException(
        'Select a country for a local number, or include the +country code.',
      );
    }
    // Match the backend's narrowly scoped PH 0940 handling, including national
    // input without a trunk zero. This never establishes assignment or ownership.
    if (country == 'PH' && RegExp(r'^0?940[0-9]{7}$').hasMatch(digits)) {
      final national = digits.startsWith('0') ? digits.substring(1) : digits;
      return normalizeResidentPhoneInput('+63$national');
    }
    return digits;
  }

  final normalized = '+$digits';
  if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(normalized)) {
    throw const FormatException('Enter a valid international phone number.');
  }
  return normalized;
}

String? validateResidentPhoneInput(String? value, {String? countryCode}) {
  try {
    normalizeResidentPhoneInput(value, countryCode: countryCode);
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}
