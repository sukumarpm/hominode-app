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
  debugPrint('Resident profile: stage=$stage code=$safeCode');
}
