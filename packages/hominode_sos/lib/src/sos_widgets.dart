import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sos_client.dart';

const _red = Color(0xFFB91C1C);
typedef SosLocationCapture = Future<Map<String, dynamic>?> Function();

class SosEntryButton extends StatelessWidget {
  const SosEntryButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.sos),
        label: const Text(
          'SOS — Emergency assistance',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}

class ResidentSosPage extends StatefulWidget {
  const ResidentSosPage({super.key, this.client, this.captureLocation});
  final SosClient? client;
  final SosLocationCapture? captureLocation;
  @override
  State<ResidentSosPage> createState() => _ResidentSosPageState();
}

class _ResidentSosPageState extends State<ResidentSosPage> {
  late final SosClient _client = widget.client ?? FirebaseSosClient();
  SosContext? _context;
  String? _error;
  String? _alertId;
  String? _requestId;
  bool _loading = true;
  bool _sending = false;
  int _activationTaps = 0;
  String? _locationInfo;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.context();
      if (mounted)
        setState(() {
          _context = result;
          _alertId = result.activeAlertId;
        });
    } catch (error) {
      if (mounted) setState(() => _error = sosErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _activate() {
    if (_sending || _alertId != null || _context == null) return;
    setState(() => _activationTaps++);
    if (_activationTaps == 3) unawaited(_send());
  }

  Future<void> _send() async {
    if (_sending || _alertId != null || _context == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _requestId ??= newSosRequestId(); // The same ID survives network retries.
    try {
      Map<String, dynamic>? location;
      if (widget.captureLocation != null) {
        try {
          location = await widget.captureLocation!().timeout(
            const Duration(seconds: 2),
          );
        } catch (_) {
          location = null;
        }
      }
      _locationInfo = location == null
          ? 'Location unavailable. SOS can still be sent.'
          : 'One-time location snapshot attached.';
      final id = await _client.trigger(_requestId!, location);
      if (mounted) setState(() => _alertId = id);
    } catch (error) {
      if (mounted) setState(() => _error = sosErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alertId != null && _context != null)
      return SosDetailPage(
        client: _client,
        communityId: _context!.communityId,
        alertId: _alertId!,
        responder: false,
        securityPhone: _context!.securityPhone,
        emergencyPhone: _context!.emergencyPhone,
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.sos, color: _red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Request emergency assistance',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Security and authorized community management can respond. For immediate danger, also use your local emergency services.',
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) _ErrorBox(message: _error!),
          if (_context != null) ...[
            const Text('Tap SOS 3 times to request emergency assistance.'),
            if (_locationInfo != null) Text(_locationInfo!),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _sending
                    ? null
                    : _requestId != null
                    ? _send
                    : _activate,
                style: FilledButton.styleFrom(backgroundColor: _red),
                icon: const Icon(Icons.sos),
                label: Semantics(
                  liveRegion: true,
                  child: Text(
                    _sending
                        ? 'Sending — awaiting server confirmation…'
                        : _requestId != null
                        ? 'Retry SOS'
                        : _activationTaps == 0
                        ? 'Request SOS'
                        : 'Request SOS — $_activationTaps/3',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SosCallButtons(
              securityPhone: _context!.securityPhone,
              emergencyPhone: _context!.emergencyPhone,
            ),
            TextButton(
              onPressed: _sending
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SosListPage(
                          client: _client,
                          communityId: _context!.communityId,
                          responder: false,
                          residentUid: _context!.residentUid,
                        ),
                      ),
                    ),
              child: const Text('My SOS history'),
            ),
          ] else if (!_loading)
            FilledButton(
              onPressed: _load,
              child: const Text('Retry connection'),
            ),
        ],
      ),
    );
  }
}

class SosCallButtons extends StatelessWidget {
  const SosCallButtons({super.key, this.securityPhone, this.emergencyPhone});
  final String? securityPhone;
  final String? emergencyPhone;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    children: [
      if (securityPhone?.isNotEmpty == true)
        OutlinedButton.icon(
          icon: const Icon(Icons.phone),
          label: const Text('Call Security'),
          onPressed: () =>
              _openUri(context, Uri(scheme: 'tel', path: securityPhone)),
        ),
      if (emergencyPhone?.isNotEmpty == true)
        OutlinedButton.icon(
          icon: const Icon(Icons.phone),
          label: const Text('Call Emergency Contact'),
          onPressed: () =>
              _openUri(context, Uri(scheme: 'tel', path: emergencyPhone)),
        ),
    ],
  );
}

Future<void> _openUri(BuildContext context, Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
      throw StateError('Unavailable');
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this action on your device.'),
        ),
      );
  }
}

class SosDetailPage extends StatefulWidget {
  const SosDetailPage({
    super.key,
    required this.communityId,
    required this.alertId,
    required this.responder,
    this.client,
    this.securityPhone,
    this.emergencyPhone,
  });
  final String communityId;
  final String alertId;
  final bool responder;
  final SosClient? client;
  final String? securityPhone;
  final String? emergencyPhone;
  @override
  State<SosDetailPage> createState() => _SosDetailPageState();
}

class _SosDetailPageState extends State<SosDetailPage> {
  late final SosClient _client = widget.client ?? FirebaseSosClient();
  late Stream<SosAlert?> _stream = _client.watchAlert(
    widget.communityId,
    widget.alertId,
  );
  bool _busy = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SosDetailPage old) {
    super.didUpdateWidget(old);
    if (old.communityId != widget.communityId ||
        old.alertId != widget.alertId) {
      _stream = _client.watchAlert(widget.communityId, widget.alertId);
      _error = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    String? note;
    if (action == 'resolve') {
      var draft = '';
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resolve emergency'),
          content: TextField(
            onChanged: (value) => draft = value,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resolution note (optional)',
              hintText: 'Briefly describe the assistance provided',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('Confirm resolution'),
            ),
          ],
        ),
      );
      if (note == null || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.transition(
        widget.communityId,
        widget.alertId,
        action,
        note: note,
      );
    } catch (error) {
      if (mounted) setState(() => _error = sosErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Emergency status')),
    body: StreamBuilder<SosAlert?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Padding(
            padding: EdgeInsets.all(20),
            child: _ErrorBox(
              message:
                  'Live emergency status is unavailable. Check your connection or call Security.',
            ),
          );
        if (!snapshot.hasData)
          return Center(
            child: snapshot.connectionState == ConnectionState.waiting
                ? const CircularProgressIndicator()
                : const Text('Emergency is unavailable.'),
          );
        final alert = snapshot.data!;
        final triggered = alert.time('triggeredAt');
        final location = alert.data['location'];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                alert.statusLabel,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: alert.active ? _red : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.responder && alert.active)
              const Text(
                'Emergency alert received by the server. Security and management have live access; push delivery may depend on their connection.',
              ),
            if (widget.responder)
              Text(
                alert.residentName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(alert.data['communityName'] as String? ?? alert.communityId),
            Text(
              alert.unitDescription.isEmpty
                  ? 'No assigned unit — check the location or contact the resident.'
                  : alert.unitDescription,
              style: const TextStyle(fontSize: 18),
            ),
            if (triggered != null)
              Text(
                'Triggered ${triggered.toLocal()}${alert.active ? ' • ${DateTime.now().difference(triggered).inMinutes.clamp(0, 999999)} min ago' : ''}',
              ),
            for (final status in [
              'acknowledged',
              'responding',
              'resolved',
              'cancelled',
            ])
              if (alert.time('${status}At') != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${status[0].toUpperCase()}${status.substring(1)}: ${alert.time('${status}At')!.toLocal()}${alert.data['${status}ByName'] != null ? ' — ${alert.data['${status}ByName']}' : ''}',
                  ),
                ),
            if ((alert.data['resolutionNote'] as String?)?.isNotEmpty == true)
              Text('Resolution: ${alert.data['resolutionNote']}'),
            const SizedBox(height: 16),
            if (location is Map &&
                location['latitude'] is num &&
                location['longitude'] is num) ...[
              Text(
                'Trigger-time location • accuracy ${location['accuracy']} m',
              ),
              OutlinedButton.icon(
                onPressed: () => _openUri(
                  context,
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': '${location['latitude']},${location['longitude']}',
                  }),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open location map'),
              ),
            ] else
              const Text(
                'Device location unavailable. Use the building/unit shown above.',
              ),
            SosCallButtons(
              securityPhone: widget.securityPhone,
              emergencyPhone: widget.emergencyPhone,
            ),
            if (_error != null) _ErrorBox(message: _error!),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Updating — awaiting server confirmation…'),
              ),
            if (widget.responder) ...[
              if (alert.status == 'triggered')
                _actionButton('Acknowledge SOS', 'acknowledge'),
              if (alert.status == 'acknowledged')
                _actionButton('Mark responding', 'respond'),
              if (['acknowledged', 'responding'].contains(alert.status))
                _actionButton('Resolve SOS', 'resolve'),
            ] else if (alert.status == 'triggered')
              _actionButton('CANCEL SOS', 'cancel'),
          ],
        );
      },
    ),
  );
  Widget _actionButton(String label, String action) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _busy ? null : () => _act(action),
        style: FilledButton.styleFrom(backgroundColor: _red),
        child: Text(label),
      ),
    ),
  );
}

class SosListPage extends StatefulWidget {
  const SosListPage({
    super.key,
    required this.communityId,
    this.responder = true,
    this.residentUid,
    this.client,
  });
  final String communityId;
  final bool responder;
  final String? residentUid;
  final SosClient? client;
  @override
  State<SosListPage> createState() => _SosListPageState();
}

class _SosListPageState extends State<SosListPage> {
  late final SosClient _client = widget.client ?? FirebaseSosClient();
  late Stream<List<SosAlert>> _active;
  late Stream<List<SosAlert>> _history;

  @override
  void initState() {
    super.initState();
    _configureStreams();
  }

  void _configureStreams() {
    _active = _client.watchAlerts(
      widget.communityId,
      residentUid: widget.residentUid,
    );

    _history = _client.watchAlerts(
      widget.communityId,
      active: false,
      residentUid: widget.residentUid,
    );
  }

  @override
  void didUpdateWidget(covariant SosListPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.communityId != widget.communityId ||
        oldWidget.residentUid != widget.residentUid) {
      _configureStreams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SOS Alerts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAlertList(_active, active: true),
            _buildAlertList(_history, active: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertList(
    Stream<List<SosAlert>> stream, {
    required bool active,
  }) {
    return StreamBuilder<List<SosAlert>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ErrorBox(message: 'SOS alerts could not be loaded.');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final alerts = snapshot.data!;

        if (alerts.isEmpty) {
          return Center(
            child: Text(
              active ? 'No active SOS alerts' : 'No SOS history available',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            final triggeredAt = alert.time('triggeredAt');

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: Icon(
                  alert.active ? Icons.sos : Icons.history,
                  color: alert.active ? _red : Colors.black54,
                ),
                title: Text(
                  alert.residentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(alert.statusLabel),
                    if (alert.unitDescription.isNotEmpty)
                      Text(alert.unitDescription),
                    if (triggeredAt != null)
                      Text('Triggered ${triggeredAt.toLocal()}'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SosDetailPage(
                        communityId: widget.communityId,
                        alertId: alert.id,
                        responder: widget.responder,
                        client: _client,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class SosActiveBanner extends StatefulWidget {
  const SosActiveBanner({super.key, required this.communityId, this.client});
  final String communityId;
  final SosClient? client;
  @override
  State<SosActiveBanner> createState() => _SosActiveBannerState();
}

class _SosActiveBannerState extends State<SosActiveBanner> {
  late final SosClient _client = widget.client ?? FirebaseSosClient();
  late Stream<List<SosAlert>> _stream = _client.watchAlerts(widget.communityId);
  @override
  void didUpdateWidget(covariant SosActiveBanner old) {
    super.didUpdateWidget(old);
    if (old.communityId != widget.communityId)
      _stream = _client.watchAlerts(widget.communityId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<SosAlert>>(
    stream: _stream,
    builder: (context, snapshot) => Card(
      margin: const EdgeInsets.all(16),
      color: const Color(0xFFFFF1F2),
      child: ListTile(
        minVerticalPadding: 16,
        leading: const Icon(Icons.sos, color: _red, size: 36),
        title: Semantics(
          liveRegion: true,
          child: Text(
            snapshot.hasError
                ? 'SOS connection unavailable'
                : !snapshot.hasData
                ? 'Checking active SOS…'
                : '${snapshot.data!.length} active SOS alerts',
            style: const TextStyle(color: _red, fontWeight: FontWeight.bold),
          ),
        ),
        subtitle: const Text(
          'Emergency assistance • open active alerts and history',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                SosListPage(client: _client, communityId: widget.communityId),
          ),
        ),
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: const TextStyle(
          color: _red,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
