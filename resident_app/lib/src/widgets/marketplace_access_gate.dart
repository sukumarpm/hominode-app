import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';

import '../components/primary_header.dart';
import '../services/subscription_entitlement_service.dart';

typedef MarketplaceAccessLoader = Future<HominodeEntitlement?> Function();

/// Mounts Marketplace content only after fresh server authorization. Subscription
/// snapshots invalidate access; they never grant it from a cached plan field.
class MarketplaceAccessGate extends StatefulWidget {
  const MarketplaceAccessGate({
    super.key,
    required this.builder,
    this.loader,
    this.invalidations,
    this.preserveContentOnLifecycleChange = false,
  });

  final WidgetBuilder builder;
  final MarketplaceAccessLoader? loader;
  final Stream<void>? invalidations;
  // Native image pickers pause/resume the app. Keep the form mounted but hidden
  // during lifecycle verification; identity/subscription changes still dispose it.
  final bool preserveContentOnLifecycleChange;

  @override
  State<MarketplaceAccessGate> createState() => _MarketplaceAccessGateState();
}

class _MarketplaceAccessGateState extends State<MarketplaceAccessGate>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _auth, _profile, _subscription, _invalidations;
  Timer? _expiry;
  int _generation = 0;
  bool _loading = true, _allowed = false, _failed = false;
  bool _hasContent = false;
  String? _communityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _invalidations = widget.invalidations?.listen((_) => _verify());
    if (widget.loader != null) {
      _verify();
      return;
    }
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      _invalidate();
      _profile?.cancel();
      _subscription?.cancel();
      _communityId = null;
      if (!mounted) return;
      if (user == null) {
        _deny();
        return;
      }
      _profile = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((profile) {
            _invalidate();
            _subscription?.cancel();
            if (!mounted) return;
            final community = profile.data()?['communityId'];
            if (community is! String || community.trim().isEmpty) {
              _deny();
              return;
            }
            _communityId = community;
            _subscription = FirebaseFirestore.instance
                .collection('subscriptions')
                .doc(community)
                .snapshots()
                .listen((_) => _verify(), onError: (_) => _deny());
          }, onError: (_) => _deny());
    }, onError: (_) => _deny());
  }

  void _invalidate({bool preserveContent = false}) {
    _generation++;
    _expiry?.cancel();
    if (mounted) {
      setState(() {
        _allowed = false;
        _loading = true;
        _failed = false;
        if (!preserveContent) _hasContent = false;
      });
    }
  }

  void _deny() {
    _invalidate();
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _verify({bool preserveContent = false}) async {
    if (!mounted) return;
    _invalidate(preserveContent: preserveContent);
    final generation = _generation;
    try {
      final entitlement =
          await (widget.loader?.call() ??
                  ResidentSubscriptionEntitlementService().getEntitlement(
                    _communityId ?? '',
                  ))
              .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      final allowed =
          entitlement != null &&
          (widget.loader != null || entitlement.communityId == _communityId) &&
          ['plus', 'pro'].contains(entitlement.planId) &&
          entitlement.canUseFeature('marketplace');
      setState(() {
        _loading = false;
        _allowed = allowed;
        _hasContent = allowed;
      });
      if (allowed && entitlement.endsAtMs != null) {
        final remaining =
            entitlement.endsAtMs! - DateTime.now().millisecondsSinceEpoch;
        _expiry = Timer(
          Duration(milliseconds: remaining > 0 ? remaining : 0),
          _verify,
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) _deny();
    }
  }

  @override
  void didUpdateWidget(covariant MarketplaceAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader ||
        oldWidget.invalidations != widget.invalidations) {
      _auth?.cancel();
      _profile?.cancel();
      _subscription?.cancel();
      _invalidations?.cancel();
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verify(preserveContent: widget.preserveContentOnLifecycleChange);
    }
    if (state == AppLifecycleState.paused) {
      _invalidate(preserveContent: widget.preserveContentOnLifecycleChange);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _profile?.cancel();
    _subscription?.cancel();
    _invalidations?.cancel();
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preserveContentOnLifecycleChange) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: !_allowed,
            child: TickerMode(
              enabled: _allowed,
              child: _hasContent ? widget.builder(context) : const SizedBox(),
            ),
          ),
          if (!_allowed) _buildAccessStatus(context),
        ],
      );
    }
    return _allowed ? widget.builder(context) : _buildAccessStatus(context);
  }

  Widget _buildAccessStatus(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PrimaryHeader(title: 'Marketplace'),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_outlined, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _failed
                                ? 'Marketplace access could not be verified.'
                                : 'Marketplace requires Plus or Pro.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _failed
                                ? 'Please try again when you are connected.'
                                : 'Contact your community administrator to upgrade.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _verify,
                            child: const Text('Check access again'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
