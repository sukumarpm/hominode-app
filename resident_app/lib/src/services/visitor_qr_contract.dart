import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Resident-side display contract for the Security visitor QR gate.
/// Security remains authoritative; this only avoids presenting a pass the
/// callable is guaranteed to reject based on its state or visit time.
class VisitorQrContract {
  static const Duration validityWindow = Duration(hours: 24);

  /// Human-readable physical state for pass details and share text.
  /// This is presentation only; it never changes the stored visitor state.
  static String statusLabel(Map<String, dynamic> visitor) {
    final status = visitor['status'];
    if (visitor['departure'] != null ||
        visitor['checkOutTime'] != null ||
        const {
          'departed',
          'exited',
          'completed',
          'checked_out',
          'checked-out',
        }.contains(status)) {
      return 'Checked Out';
    }
    if (visitor['actualArrival'] != null ||
        const {'arrived', 'inside', 'checked_in'}.contains(status)) {
      return 'Checked In';
    }
    if (visitor['gateAccessStatus'] == 'denied' ||
        visitor['gateEntryDeniedAt'] != null ||
        status == 'denied') {
      return 'Entry Denied';
    }
    if (status == 'rejected') return 'Rejected by Admin';
    if (status == 'cancelled' || status == 'canceled') return 'Cancelled';
    if (status == 'approved' || status == 'expected' || status == 'pending') {
      return 'Expected';
    }
    return 'Unknown';
  }

  static String shareTextFor(
    Map<String, dynamic> visitor, {
    required String visitorId,
  }) {
    final visitorName = visitor['visitorName'] ?? 'Visitor';
    final flatLabel = visitor['flatLabel'] ?? visitor['flatId'] ?? '';
    final passId = visitorId
        .substring(0, visitorId.length < 12 ? visitorId.length : 12)
        .toUpperCase();

    return '''
Visitor Pass - ${statusLabel(visitor)}

Name: $visitorName
Visiting: Flat $flatLabel
Pass ID: $passId

Please show this QR code at the security gate.
''';
  }

  static bool canDisplay(Map<String, dynamic> visitor, {DateTime? now}) =>
      payloadFor(visitor, visitorId: 'display-check', now: now) != null;

  static String safeLoadDiagnostic(Map<String, dynamic> visitor) {
    final token = visitor['qrToken'];
    return 'Resident visitor QR loaded '
        '(status=${visitor['status']}, hasToken=${token is String && token.isNotEmpty}).';
  }

  /// Returns the existing-token payload, or the supported legacy document-ID
  /// payload when the document genuinely has no qrToken field/value.
  /// Invalid tokens and ineligible visitor states return null.
  static String? payloadFor(
    Map<String, dynamic> visitor, {
    required String visitorId,
    DateTime? now,
  }) {
    final status = visitor['status'];
    final isPending =
        (status == 'expected' || status == 'pending') &&
        visitor['isApproved'] == false;
    final isApproved = status == 'approved' && visitor['isApproved'] == true;

    if ((!isPending && !isApproved) ||
        visitor['actualArrival'] != null ||
        visitor['departure'] != null) {
      return null;
    }

    final expectedValue = visitor['expectedArrival'] ?? visitor['expectedTime'];
    final expectedArrival = switch (expectedValue) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };
    if (expectedArrival == null ||
        (now ?? DateTime.now())
                .difference(expectedArrival)
                .inMilliseconds
                .abs() >
            validityWindow.inMilliseconds) {
      return null;
    }

    final rawToken = visitor['qrToken'];
    if (rawToken == null) {
      final id = visitorId.trim();
      if (id.isEmpty) return null;
      return jsonEncode({'visitorId': id, 'legacy': true});
    }

    if (rawToken is! String) return null;
    final token = rawToken.trim();
    if (token.isEmpty || token.length > 512 || RegExp(r'\s').hasMatch(token)) {
      return null;
    }

    return jsonEncode({
      'type': 'hominode_visitor',
      'version': 1,
      'token': token,
    });
  }
}
