import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/hominode_theme.dart';

/// Attestation is required before any authenticated application widget is built.
class AdminStartupGate extends StatefulWidget {
  const AdminStartupGate({
    super.key,
    required this.initialize,
    required this.child,
    this.timeout = const Duration(seconds: 75),
  });

  final Future<void> Function() initialize;
  final Widget child;
  final Duration timeout;

  @override
  State<AdminStartupGate> createState() => _AdminStartupGateState();
}

class _AdminStartupGateState extends State<AdminStartupGate> {
  bool _loading = true;
  bool _ready = false;
  int _generation = 0;
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    _start();
  }

  // Reuse an ongoing native Firebase initialization after a gate timeout,
  // rather than launching an overlapping second initialization.
  Future<void> _initializeOnce() {
    final existing = _inFlight;
    if (existing != null) return existing;
    late final Future<void> attempt;
    attempt = Future<void>.sync(widget.initialize).whenComplete(() {
      if (identical(_inFlight, attempt)) _inFlight = null;
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<void> _initializeWithRetries() async {
    const delays = [Duration(milliseconds: 400), Duration(milliseconds: 900)];
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        await _initializeOnce();
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'Admin secure startup attempt ${attempt + 1}/${delays.length + 1} '
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
    } catch (_) {
      // Do not display SDK exception bodies, attestation tokens or account data.
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: HominodeTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'HOMINODE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_loading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Verifying secure access…'),
                    ] else ...[
                      const Text(
                        'Secure access could not be verified.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Check your connection and try again. If this continues, contact support.',
                        textAlign: TextAlign.center,
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Emulator: register the generated debug token in Firebase App Check, then retry.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _start,
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
