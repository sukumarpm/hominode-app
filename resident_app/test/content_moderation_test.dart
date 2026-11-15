import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/content_moderation_service.dart';

void main() {
  test('whole words are filtered without blocking harmless substrings', () {
    expect(
      ContentModerationService.isTextSafe('The white Essex sign is bright'),
      isTrue,
    );
    expect(ContentModerationService.isTextSafe('I have a gun'), isFalse);
    expect(ContentModerationService.isTextSafe('Please avoid fraud'), isFalse);
  });
}
