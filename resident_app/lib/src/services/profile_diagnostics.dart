import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Log only the operation and error category. Never log exception messages,
/// profile fields, local paths, tokens, private references or image contents.
void logProfileFailure(String stage, Object error) {
  final code = error is FirebaseException
      ? error.code
      : error.runtimeType.toString();
  final safeCode = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(code)
      ? code
      : 'unknown';
  String? reason;
  if (stage == 'app-check' && error is FirebaseException) {
    // Classify known SDK failures without printing their messages or tokens.
    final message = error.message?.toLowerCase() ?? '';
    if (message.contains('too many attempts')) {
      reason = 'throttled';
    } else if (message.contains('app attestation failed') ||
        message.contains('403')) {
      reason = 'attestation-rejected';
    }
  }
  debugPrint(
    'Resident profile: stage=$stage code=$safeCode'
    '${reason == null ? '' : ' reason=$reason'}',
  );
}
