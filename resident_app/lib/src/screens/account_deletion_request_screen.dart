import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/account_deletion_request_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/tenant_resolution_service.dart';
import '../services/user_data_service.dart';

class AccountDeletionRequestScreen extends StatefulWidget {
  const AccountDeletionRequestScreen({super.key, this.service, this.onLogout});
  final AccountDeletionRequests? service;
  final Future<void> Function()? onLogout;
  @override
  State<AccountDeletionRequestScreen> createState() =>
      _AccountDeletionRequestScreenState();
}

class _AccountDeletionRequestScreenState
    extends State<AccountDeletionRequestScreen>
    with WidgetsBindingObserver {
  late final AccountDeletionRequests _service =
      widget.service ?? AccountDeletionRequestService();
  final _code = TextEditingController();
  Map<String, dynamic>? _request;
  String? _verificationId;
  String? _error;
  bool _busy = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _confirmed = false;
  bool _needsVerification = false;
  bool _retryProcessing = false;
  bool _submissionUncertain = false;
  bool _statusInFlight = false;
  bool _leaving = false;
  bool _navigated = false;
  Timer? _refreshTimer;
  Timer? _logoutRetry;
  String _activity = 'deletion_activity_processing';

  String? get _status => _request?['status'] as String?;
  bool get _completed => _status == 'completed';
  bool get _review => _status == 'pending_review';
  bool get _queued =>
      [
        'queued',
        'processing',
        'retry_scheduled',
        'deletion_processing',
        'deletion_in_progress',
      ].contains(_status) ||
      (_status == 'pending_verification' &&
          _request?['verificationCompletedAt'] != null);
  bool get _verificationFinished =>
      _review ||
      _completed ||
      _queued ||
      (_status == 'pending_verification' &&
          _request?['verificationCompletedAt'] != null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _applySavedProfileLanguage(),
    );
    _load();
  }

  Future<void> _applySavedProfileLanguage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final language = await UserDataService().getUserLanguagePreference(uid);
      const supported = {'en', 'ta', 'hi', 'es', 'ar', 'ml', 'te', 'kn'};
      if (!mounted ||
          language == null ||
          !supported.contains(language) ||
          context.locale.languageCode == language) {
        return;
      }
      await context.setLocale(Locale(language));
    } catch (_) {
      // Keep the active locale if the saved profile preference is unavailable.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _logoutRetry?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _acceptRequest(Map<String, dynamic>? value) {
    if (value == null) return;
    if (value['requestId'] is! String ||
        (value['requestId'] as String).trim().isEmpty) {
      throw StateError('The backend did not return a request reference.');
    }
    if (_request != null && value['requestId'] != _request!['requestId']) {
      throw StateError(
        'The request reference changed. Please reopen this screen.',
      );
    }
    if (_completed && value['status'] != 'completed') return;
    _request = value;
    if (_verificationFinished) {
      _error = null;
      _submissionUncertain = false;
      _verificationId = null;
      _needsVerification = false;
      _retryProcessing = false;
      _confirmed = true;
      _code.clear();
    } else if (['failed', 'reconciliation_required'].contains(_status)) {
      _submissionUncertain = false;
      _retryProcessing = true;
      _error = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_completed) {
        unawaited(_logout());
      } else {
        unawaited(_load(background: true));
      }
    } else {
      _refreshTimer?.cancel();
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!mounted ||
        (_request == null && !_submissionUncertain) ||
        _completed ||
        _leaving) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _refreshTimer = Timer(const Duration(seconds: 10), () {
      if (_busy || _statusInFlight) {
        _scheduleRefresh();
      } else {
        unawaited(_load(background: true));
      }
    });
  }

  Future<void> _load({bool background = false}) async {
    if (_busy || _statusInFlight || _leaving) return;
    _statusInFlight = true;
    setState(() {
      if (!background) _loading = true;
      if (!background) _error = null;
    });
    try {
      final value = await _service.status();
      if (mounted) {
        setState(() {
          _acceptRequest(value);
          _loadFailed = false;
        });
        if (_completed) await _logout();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error = 'deletion_error_load'.tr();
        });
      }
    } finally {
      _statusInFlight = false;
      if (mounted) setState(() => _loading = false);
      _scheduleRefresh();
    }
  }

  Future<void> _start() async {
    if (_busy || _loading || _verificationFinished) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_confirmed) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('deletion_confirm_title'.tr()),
            content: Text('deletion_intro'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('deletion_cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('deletion_confirm_button'.tr()),
              ),
            ],
          ),
        );
        if (yes != true || !mounted) return;
        _confirmed = true;
      }
      if (_needsVerification || await _service.requiresReauthentication()) {
        if (!mounted) return;
        setState(() => _activity = 'deletion_activity_sending_otp');
        final sent = Completer<void>();
        await _service.beginReauthentication(
          (id) {
            if (mounted && !_verificationFinished) {
              setState(() => _verificationId = id);
            }
            if (!sent.isCompleted) sent.complete();
          },
          (_) {
            if (mounted && !_verificationFinished) {
              setState(() => _error = 'deletion_error_verify'.tr());
            }
            if (!sent.isCompleted) sent.complete();
          },
        );
        await sent.future;
      } else {
        await _process();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'deletion_error_processing'.tr());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _verificationId == null || _verificationFinished) return;
    setState(() {
      _busy = true;
      _error = null;
      _activity = 'deletion_activity_verifying_otp';
    });
    try {
      await _service.completeReauthentication(
        _verificationId!,
        _code.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _verificationId = null;
        _needsVerification = false;
        _code.clear();
      });
      await _process();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'deletion_error_verify'.tr());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _process() async {
    setState(() {
      _activity = 'deletion_activity_processing';
      _retryProcessing = false;
    });
    try {
      final result = await _service.submit();
      if (!mounted) return;
      setState(() => _acceptRequest(result));
    } catch (e) {
      if (!mounted) return;
      // A lost/expired HTTP response does not roll back a persisted request.
      // Recover only from a trusted status response, never from an auth error.
      try {
        final current = await _service.status();
        if (!mounted) return;
        setState(() => _acceptRequest(current));
      } catch (_) {
        /* Final status is unknown; do not claim completion. */
      }
      if (!mounted) return;
      if (_completed) {
        await _logout();
        return;
      }
      final transient =
          e is FirebaseFunctionsException &&
          [
            'deadline-exceeded',
            'unavailable',
            'aborted',
            'internal',
            'unknown',
          ].contains(e.code);
      final failed = ['failed', 'reconciliation_required'].contains(_status);
      setState(() {
        if (transient && !failed) {
          _submissionUncertain = !_verificationFinished;
          _retryProcessing = false;
          _error = _submissionUncertain
              ? 'deletion_error_unconfirmed'.tr()
              : null;
        } else {
          _retryProcessing = true;
          _needsVerification =
              e is FirebaseFunctionsException &&
              (e.code == 'unauthenticated' ||
                  e.code == 'failed-precondition' &&
                      (e.message ?? '').toLowerCase().contains(
                        'reauthenticate',
                      ));
          _error = _needsVerification
              ? 'deletion_error_reauth'.tr()
              : 'deletion_error_processing'.tr();
        }
      });
      _scheduleRefresh();
      return;
    }
    if (_completed) {
      await _logout();
      return;
    }
    try {
      final value = await _service.status();
      if (mounted) {
        setState(() => _acceptRequest(value));
        if (_completed) await _logout();
      }
    } catch (_) {
      // Auth-last deletion may invalidate the session before this status read.
      // The completed submission response is already a trusted server result.
      if (mounted && !_completed) {
        setState(() => _error = 'deletion_error_refresh'.tr());
      }
    }
    _scheduleRefresh();
  }

  Future<void> _logout() async {
    if (!mounted || _leaving || _navigated) return;
    setState(() => _leaving = true);
    _refreshTimer?.cancel();
    _logoutRetry?.cancel();
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    if (_completed) {
      // Dispose covered Home/settings routes and their Firestore subscriptions
      // immediately; retain this screen while local sign-out finishes/retries.
      final route = ModalRoute.of(context);
      if (route != null && route.navigator == navigator) {
        while (!route.isFirst) {
          navigator.removeRouteBelow(route);
        }
      }
    }
    try {
      if (widget.onLogout != null) {
        await widget.onLogout!();
      } else {
        final result = await FirebaseAuthService.instance.signOut(
          context.read<TenantResolutionService?>(),
        );
        if (!result.success) throw StateError('Local sign-out failed.');
      }
      if (!mounted || _navigated) return;
      _navigated = true;
      if (_completed) {
        messenger.showSnackBar(
          SnackBar(content: Text('deletion_success'.tr())),
        );
      }
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _leaving = false;
        _error = _completed
            ? 'deletion_error_deleted_signout'.tr()
            : 'deletion_error_signout'.tr();
      });
      if (_completed) {
        _logoutRetry = Timer(const Duration(seconds: 5), () {
          unawaited(_logout());
        });
      }
    }
  }

  String get _statusLabel {
    if (_completed) return 'deletion_status_completed'.tr();
    if (_busy && _activity == 'deletion_activity_processing') {
      return 'deletion_status_processing'.tr();
    }
    if (_submissionUncertain || _queued) {
      return 'deletion_status_processing'.tr();
    }
    if (_retryProcessing) return 'deletion_status_failed'.tr();
    if (_review) {
      final financial = _request?['financialStatus'];
      if (financial == 'awaiting_settlement' ||
          financial == 'unknown_requires_reconciliation') {
        return 'deletion_status_pending_admin'.tr();
      }
      return _request?['reviewType'] == 'community_admin'
          ? 'deletion_status_pending_admin'.tr()
          : 'deletion_status_pending_processing'.tr();
    }
    if (_status == 'deletion_in_progress') {
      return 'deletion_status_processing'.tr();
    }
    if (['failed', 'reconciliation_required'].contains(_status)) {
      return 'deletion_status_failed'.tr();
    }
    return 'deletion_status_verification'.tr();
  }

  String get _primaryLabel {
    if (_loading) return 'deletion_loading'.tr();
    if (_busy) return _activity.tr();
    if (_loadFailed) return 'deletion_retry_status_button'.tr();
    if (_submissionUncertain) return 'deletion_refresh_button'.tr();
    if (_completed || _leaving) return 'deletion_signing_out'.tr();
    if (_verificationFinished) return 'deletion_refresh_button'.tr();
    if (_verificationId != null) return 'deletion_verify_otp_button'.tr();
    if (_needsVerification) return 'deletion_verify_identity_button'.tr();
    if (_retryProcessing ||
        ['failed', 'reconciliation_required'].contains(_status)) {
      return 'deletion_retry_processing_button'.tr();
    }
    if (_request == null) return 'deletion_request_button'.tr();
    if (_status == 'pending_verification') {
      return 'deletion_continue_button'.tr();
    }
    return 'deletion_refresh_button'.tr();
  }

  List<Widget> get _financialReviewNotices {
    if (_request?['reviewType'] != 'community_admin') {
      return [
        const SizedBox(height: 12),
        Text(
          'deletion_account_active'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'deletion_next_steps_processing'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ];
    }
    final financial = _request?['financialStatus'];
    final messageKey = switch (financial) {
      'awaiting_settlement' => 'deletion_pending_dues',
      'eligible_for_verification' => 'deletion_zero_finances',
      _ => 'deletion_unknown_finances',
    };
    return [
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                messageKey.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'deletion_account_active'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'deletion_next_steps'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _primaryAction() {
    if (_loadFailed || _submissionUncertain) {
      _load();
    } else if (_completed) {
      _logout();
    } else if (_verificationFinished) {
      _load();
    } else if (_verificationId != null) {
      _verify();
    } else if (_request == null ||
        _status == 'pending_verification' ||
        _needsVerification ||
        _retryProcessing ||
        ['failed', 'reconciliation_required'].contains(_status)) {
      _start();
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_completed && !_leaving,
    child: Scaffold(
      appBar: AppBar(
        title: Text('deletion_title'.tr()),
        actions: [
          TextButton(
            onPressed: _busy || _leaving || _completed ? null : _logout,
            child: Text('deletion_sign_out_button'.tr()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('deletion_intro'.tr()),
          const SizedBox(height: 12),
          Text('deletion_records_notice'.tr()),
          if (_submissionUncertain && _request == null)
            Card(
              child: ListTile(title: Text('deletion_status_processing'.tr())),
            ),
          if (_request != null)
            Card(
              child: ListTile(
                title: Text(_statusLabel),
                subtitle: Text(
                  'deletion_reference'.tr(
                    namedArgs: {'reference': '${_request!['requestId']}'},
                  ),
                ),
              ),
            ),
          if (_review) ..._financialReviewNotices,
          if (_verificationId != null && !_verificationFinished) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'deletion_otp_label'.tr()),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('deletion-primary'),
            onPressed: _busy || _loading || _leaving || _completed
                ? null
                : _primaryAction,
            child: Text(_primaryLabel),
          ),
        ],
      ),
    ),
  );
}
