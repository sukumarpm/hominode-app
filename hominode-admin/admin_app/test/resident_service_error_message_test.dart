import 'package:admin_app/services/resident_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bare callable not-found errors display a helpful message', () {
    for (final message in ['', 'NOT_FOUND', 'not-found']) {
      final displayed = ResidentService.errorMessage(
        FirebaseFunctionsException(code: 'not-found', message: message),
      );
      expect(displayed, contains('service or record could not be found'));
      expect(displayed, contains('contact support'));
      expect(displayed, isNot(contains('NOT_FOUND')));
    }
  });

  test('application-level not-found descriptions are preserved', () {
    const message =
        'The selected unit could not be found. Select another unit.';
    expect(
      ResidentService.errorMessage(
        FirebaseFunctionsException(code: 'not-found', message: message),
      ),
      message,
    );
  });

  test(
    'authorization, community and phone error descriptions remain unchanged',
    () {
      for (final sample in [
        ('permission-denied', 'An authorized active Admin is required.'),
        ('failed-precondition', 'Community is inactive or unavailable.'),
        ('invalid-argument', 'Enter a valid resident phone number.'),
      ]) {
        expect(
          ResidentService.errorMessage(
            FirebaseFunctionsException(code: sample.$1, message: sample.$2),
          ),
          sample.$2,
        );
      }
    },
  );
}
