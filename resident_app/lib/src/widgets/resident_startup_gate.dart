import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Denies access to authenticated widgets until Firebase and App Check succeed.
/// A transient startup failure is retried automatically; persistent failures
/// remain fail-closed and provide an explicit manual retry button.
class ResidentStartupGate extends StatefulWidget {
  const ResidentStartupGate({
    super.key,
    required this.initialize,
    required this.child,
    this.onReady,
    this.timeout = const Duration(seconds: 75),
  });

  final Future<void> Function() initialize;
  final Widget child;
  final Future<void> Function()? onReady;
  final Duration timeout;

  @override
  State<ResidentStartupGate> createState() => _ResidentStartupGateState();
}

class _ResidentStartupGateState extends State<ResidentStartupGate> {
  bool _loading = true;
  bool _ready = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _initializeWithRetries() async {
    const delays = [Duration(milliseconds: 400), Duration(milliseconds: 900)];
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        await widget.initialize();
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'Resident secure startup attempt ${attempt + 1}/${delays.length + 1} '
          'failed (${error.runtimeType}).',
        );
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        if (attempt == delays.length) rethrow;
        await Future<void>.delayed(delays[attempt]);
      }
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      await _initializeWithRetries().timeout(widget.timeout);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _ready = true;
      });
      if (widget.onReady != null) unawaited(widget.onReady!());
    } catch (_) {
      if (!mounted || generation != _generation) return;
      // No authenticated UI is built after failed attestation.
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Verifying secure access…'),
                ] else ...[
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Secure startup could not complete',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check your connection and retry. Access stays locked until verification succeeds.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _start, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
