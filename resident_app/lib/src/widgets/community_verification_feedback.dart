import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Owns retryable community-verification feedback for one screen/operation.
/// It drops stale async results and closes only the SnackBar it created.
class CommunityVerificationFeedback {
  int _generation = 0;
  bool _isRunning = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notice;

  Future<void> run({
    required BuildContext context,
    required String operation,
    required Future<void> Function() verify,
    required void Function(Object error) onFailure,
    required VoidCallback onSuccess,
  }) async {
    if (_isRunning) return;

    final generation = ++_generation;
    _isRunning = true;
    _dismissNotice();

    try {
      await verify();
      if (generation != _generation || !context.mounted) return;
      _dismissNotice();
      onSuccess();
    } catch (error) {
      if (generation != _generation || !context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      if (kDebugMode) {
        debugPrint(
          '[$operation] verification failed (${_safeErrorCode(error)}).',
        );
      }
      onFailure(error);
    } finally {
      if (generation == _generation) _isRunning = false;
    }
  }

  void showRetryableNotice({
    required BuildContext context,
    required String message,
    required String retryLabel,
    required VoidCallback onRetry,
  }) {
    _dismissNotice();
    _notice = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: retryLabel, onPressed: onRetry),
      ),
    );
  }

  void showNotice({required BuildContext context, required String message}) {
    _dismissNotice();
    _notice = ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Call when the owning operation/screen is left, invalidating late results.
  void cancel() {
    _generation++;
    _isRunning = false;
    _dismissNotice();
  }

  void _dismissNotice() {
    final notice = _notice;
    _notice = null;
    notice?.close();
  }

  String _safeErrorCode(Object error) {
    if (error is FirebaseFunctionsException) return error.code;
    if (error is FirebaseException) return error.code;
    return error.runtimeType.toString();
  }
}
