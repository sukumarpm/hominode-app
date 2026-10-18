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
  bool _loading = true, _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      await widget.initialize().timeout(widget.timeout);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Do not display SDK exception bodies, attestation tokens or account data.
      if (mounted) setState(() => _loading = false);
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
