import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_auth_service.dart';
import '../services/resident_auth_routing.dart';
import '../services/tenant_resolution_service.dart';

class AwaitingApprovalScreen extends StatefulWidget {
  const AwaitingApprovalScreen({super.key});

  @override
  State<AwaitingApprovalScreen> createState() => _AwaitingApprovalScreenState();
}

class _AwaitingApprovalScreenState extends State<AwaitingApprovalScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final result = await FirebaseAuthService().restoreResidentSession(
      context.read<TenantResolutionService>(),
    );
    if (!mounted) return;
    setState(() => _checking = false);
    final route = ResidentAuthRouting.routeFor(result);
    if (route == '/awaiting-approval') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approval is still pending.')),
      );
    } else {
      ResidentAuthRouting.navigateToResult(context, result);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuthService().signOut(
      context.read<TenantResolutionService>(),
    );
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 88,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(height: 24),
              const Text(
                'Awaiting Admin Approval',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your registration was submitted. Your community administrator must verify your building and unit before access is enabled.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : _checkStatus,
                  child: Text(_checking ? 'Checking…' : 'Check Status'),
                ),
              ),
              TextButton(onPressed: _signOut, child: const Text('Sign Out')),
            ],
          ),
        ),
      ),
    );
  }
}
