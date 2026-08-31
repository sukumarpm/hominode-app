abstract final class HominodeLegalAcceptance {
  static const termsVersion = '2026-08-28.v1';
  static const privacyVersion = '2026-08-28.v1';

  static bool isCurrent(Object? value) {
    if (value is! Map) return false;
    return value['termsVersion'] == termsVersion &&
        value['privacyVersion'] == privacyVersion &&
        value['acceptedAt'] != null;
  }
}
