import 'dart:convert';

/// Parses current opaque-token QR payloads and the supported legacy ID format.
class VisitorQrPayload {
  final String? qrToken;
  final String? legacyVisitorId;

  const VisitorQrPayload({this.qrToken, this.legacyVisitorId});

  static VisitorQrPayload? tryParse(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue.trim());
      if (decoded is Map<String, dynamic> &&
          decoded['type'] == 'hominode_visitor') {
        final token = decoded['token']?.toString().trim() ?? '';
        if (token.isNotEmpty) return VisitorQrPayload(qrToken: token);
        final visitorId = decoded['visitorId']?.toString().trim() ?? '';
        if (visitorId.isNotEmpty) {
          return VisitorQrPayload(legacyVisitorId: visitorId);
        }
      } else if (decoded is Map<String, dynamic>) {
        final visitorId = decoded['visitorId']?.toString().trim() ?? '';
        if (visitorId.isNotEmpty) {
          return VisitorQrPayload(legacyVisitorId: visitorId);
        }
      }
    } catch (_) {
      // Older visitor QR versions may contain only the Firestore document ID.
      final value = rawValue.trim();
      if (value.isNotEmpty) return VisitorQrPayload(legacyVisitorId: value);
    }
    return null;
  }
}
