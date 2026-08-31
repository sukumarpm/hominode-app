import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'legal_acceptance.dart';
import 'legal_document_viewer.dart';

class HominodeLegalAcceptanceGate extends StatefulWidget {
  const HominodeLegalAcceptanceGate({
    required this.profileCollection,
    required this.child,
    super.key,
  });

  final String profileCollection;
  final Widget child;

  @override
  State<HominodeLegalAcceptanceGate> createState() =>
      _HominodeLegalAcceptanceGateState();
}

class _HominodeLegalAcceptanceGateState
    extends State<HominodeLegalAcceptanceGate> {
  late Future<bool> _status = _loadStatus();
  bool _acceptedInSession = false;

  Future<bool> _loadStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    final profile = await FirebaseFirestore.instance
        .collection(widget.profileCollection)
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    if (!profile.exists)
      throw StateError('The authenticated profile is missing.');
    return HominodeLegalAcceptance.isCurrent(
      profile.data()?['legalAcceptance'],
    );
  }

  Future<void> _accept() async {
    final result =
        await FirebaseFunctions.instanceFor(
          region: 'asia-southeast1',
        ).httpsCallable('acceptCurrentLegalTerms').call(<String, dynamic>{
          'termsVersion': HominodeLegalAcceptance.termsVersion,
          'privacyVersion': HominodeLegalAcceptance.privacyVersion,
        });
    final data = result.data;
    if (data is! Map ||
        data['accepted'] != true ||
        data['termsVersion'] != HominodeLegalAcceptance.termsVersion ||
        data['privacyVersion'] != HominodeLegalAcceptance.privacyVersion) {
      throw StateError('Legal acceptance could not be verified.');
    }
    if (mounted) setState(() => _acceptedInSession = true);
  }

  void _retry() {
    setState(() {
      _status = _loadStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_acceptedInSession) return widget.child;
    return FutureBuilder<bool>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LegalLoadingScreen();
        }
        if (snapshot.hasError) {
          return _LegalLoadError(onRetry: _retry);
        }
        if (snapshot.data == true) return widget.child;
        return LegalAcceptanceScreen(onAccept: _accept);
      },
    );
  }
}

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({required this.onAccept, super.key});

  final Future<void> Function() onAccept;

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error =
              'Acceptance could not be saved. Check your connection and try again.';
        });
      }
    }
  }

  void _openDocument(String title, String assetPath) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HominodeLegalDocumentViewer(title: title, assetPath: assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.gavel_outlined, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    'Terms & Privacy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Review and accept the current Terms & Conditions and Privacy Policy to continue using Hominode.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _openDocument(
                      'Terms & Conditions',
                      HominodeLegalDocuments.termsAndConditionsAsset,
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Read Terms & Conditions'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openDocument(
                      'Privacy Policy',
                      HominodeLegalDocuments.privacyPolicyAsset,
                    ),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Read Privacy Policy'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept and continue'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Terms ${HominodeLegalAcceptance.termsVersion} · Privacy ${HominodeLegalAcceptance.privacyVersion}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLoadingScreen extends StatelessWidget {
  const _LegalLoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _LegalLoadError extends StatelessWidget {
  const _LegalLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Terms and Privacy acceptance could not be verified.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}
