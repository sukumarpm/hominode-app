import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/services/resident_service.dart';

void main() {
  test(
    'display prefers canonical phoneNumber while preserving old phone-only records',
    () {
      expect(
        ResidentModel.fromFirestore('r', {
          'phoneNumber': '+639170000000',
          'phone': 'old',
        }).phone,
        '+639170000000',
      );
      expect(
        ResidentModel.fromFirestore('r', {'phone': 'legacy'}).phone,
        'legacy',
      );
      expect(ResidentModel.fromFirestore('r', {}).phone, '');
    },
  );
}
