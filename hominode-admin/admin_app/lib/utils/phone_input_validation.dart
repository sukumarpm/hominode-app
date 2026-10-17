/// Validates phone input syntax before the server applies the community's
/// country context and canonical libphonenumber validation.
String? validateResidentPhoneInput(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Phone number is required';

  if (!RegExp(r'^\+?[0-9().\s-]+$').hasMatch(input)) {
    return 'Enter a valid phone number. Use digits and standard phone formatting.';
  }

  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) {
    return 'Enter a valid phone number with 7 to 15 digits.';
  }

  return null;
}
