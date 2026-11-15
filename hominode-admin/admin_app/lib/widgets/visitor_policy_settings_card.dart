import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/admin_tenant_context.dart';
import '../services/visitor_policy_service.dart';

class VisitorPolicySettingsCard extends StatefulWidget {
  const VisitorPolicySettingsCard({super.key, this.service});
  final VisitorPolicyService? service;
  @override
  State<VisitorPolicySettingsCard> createState() =>
      _VisitorPolicySettingsCardState();
}

class _VisitorPolicySettingsCardState extends State<VisitorPolicySettingsCard>
    with WidgetsBindingObserver {
  late final VisitorPolicyService _service =
      widget.service ?? VisitorPolicyService();
  VisitorPolicyConfig? _config;
  Map<String, dynamic>? _draft;
  StreamSubscription<int>? _subscription;
  Timer? _activationTimer;
  final _emStart = TextEditingController(), _emEnd = TextEditingController();
  final _petStart = TextEditingController(), _petEnd = TextEditingController();
  final _effectiveAt = TextEditingController();
  bool _loading = true,
      _saving = false,
      _dirty = false,
      _conflict = false,
      _emergency = false,
      _scheduled = false,
      _refreshQueued = false;
  int _generation = 0;
  String _scope = '', _message = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdminTenantContext.instance.addListener(_communityChanged);
    _start();
  }

  void _start() {
    try {
      _scope = _service.communityId;
      final scope = _scope;
      _subscription?.cancel();
      _subscription = _service.watch().listen(
        (_) {
          if (!mounted || scope != _scope) return;
          if (_config != null) _refresh();
        },
        onError: (Object error) {
          if (mounted && scope == _scope) {
            setState(
              () => _message =
                  'Live updates unavailable. Reload to refresh. ${visitorPolicyError(error)}',
            );
          }
        },
      );
      _load();
    } catch (error) {
      _loading = false;
      _message = visitorPolicyError(error);
    }
  }

  void _communityChanged() {
    String next;
    try {
      next = _service.communityId;
    } catch (_) {
      next = '';
    }
    if (next == _scope) return;
    _generation++;
    _subscription?.cancel();
    _activationTimer?.cancel();
    setState(() {
      _scope = next;
      _config = null;
      _draft = null;
      _dirty = false;
      _conflict = false;
      _saving = false;
      _refreshQueued = false;
      _message = '';
    });
    _start();
  }

  void _refresh() {
    if (_saving || _loading) {
      _refreshQueued = true;
      return;
    }
    if (_dirty) {
      _checkRevision();
    } else {
      _load();
    }
  }

  Future<void> _checkRevision() async {
    final ticket = ++_generation;
    try {
      final latest = await _service.load();
      if (!mounted || ticket != _generation) return;
      setState(() {
        if (latest.writeRevision != _config?.writeRevision ||
            latest.revision != _config?.revision ||
            latest.timeZone != _config?.timeZone ||
            latest.pendingSchedule?.effectiveAt !=
                _config?.pendingSchedule?.effectiveAt) {
          _conflict = true;
          _message = 'Policy changed on another device. Reload before saving.';
        }
        _config = latest;
        _armActivation(latest);
      });
    } catch (error) {
      if (mounted && ticket == _generation) {
        setState(() {
          _conflict = true;
          _message = visitorPolicyError(error);
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _apply(VisitorPolicyConfig config) {
    _config = config;
    _draft = visitorPolicyInput(
      config.pendingSchedule?.policy ?? config.policy,
    );
    _draft!['timeZone'] = config.timeZone;
    _scheduled = config.pendingSchedule != null;
    _effectiveAt.text = config.timeZoneError == null
        ? VisitorSchedule.local(
            config.pendingSchedule?.effectiveAt,
            config.timeZone,
          )
        : '';
    final emergency = _draft!['emergency'] as Map?,
        pets = _draft!['pets'] as Map;
    final restriction = pets['restriction'] as Map?;
    _emergency = emergency != null;
    _emStart.text = _local((emergency?['startAt'] as num?)?.toInt(), config);
    _emEnd.text = _local((emergency?['endAt'] as num?)?.toInt(), config);
    _petStart.text = _local((restriction?['startAt'] as num?)?.toInt(), config);
    _petEnd.text = _local((restriction?['endAt'] as num?)?.toInt(), config);
    _dirty = false;
    _conflict = false;
    _armActivation(config);
  }

  void _armActivation(VisitorPolicyConfig config) {
    _activationTimer?.cancel();
    final effectiveAt = config.pendingSchedule?.effectiveAt;
    if (effectiveAt == null) return;
    final delay = effectiveAt - config.currentServerTime;
    _activationTimer = Timer(Duration(milliseconds: delay > 0 ? delay : 0), () {
      if (mounted) _refresh();
    });
  }

  String _local(int? instant, VisitorPolicyConfig config) =>
      config.timeZoneError == null
      ? VisitorSchedule.local(instant, config.timeZone)
      : '';

  List<Widget> _policySummary(
    Map<String, dynamic> policy,
    bool enabled,
    VisitorPolicyConfig config,
    Widget Function(String, String) row, {
    bool pending = false,
  }) {
    final pets = policy['pets'] as Map;
    String period(Map? value) {
      if (!enabled || value == null) return 'Off';
      if (config.timeZoneError != null) {
        return 'Community time zone unavailable';
      }
      final from = _local(
        (value['startAt'] as num).toInt(),
        config,
      ).replaceFirst('T', ' ');
      final until = _local(
        (value['endAt'] as num).toInt(),
        config,
      ).replaceFirst('T', ' ');
      return '$from – $until (${VisitorSchedule.status(value, config.currentServerTime)})';
    }

    return [
      row('Enforcement', enabled ? (pending ? 'Scheduled' : 'Active') : 'Off'),
      row(
        'Approval',
        visitorApprovalOptions[enabled
            ? policy['approvalMode']
            : 'resident_authorized']!,
      ),
      row('Emergency period', period(policy['emergency'] as Map?)),
      row(
        'Pets',
        !enabled
            ? 'Pets allowed'
            : const {
                'allowed': 'Pets allowed',
                'not_allowed': 'Pets not allowed',
                'temporarily_restricted': 'Temporarily restricted',
              }[pets['mode']]!,
      ),
      if (enabled && pets['mode'] == 'temporarily_restricted') ...[
        row('Pet restriction', period(pets['restriction'] as Map?)),
        row(
          'Outside restriction',
          pets['normalMode'] == 'allowed' ? 'Pets allowed' : 'Pets not allowed',
        ),
      ],
    ];
  }

  Future<void> _load() async {
    final ticket = ++_generation;
    setState(() => _loading = true);
    try {
      final config = await _service.load();
      if (mounted && ticket == _generation) {
        setState(() {
          _apply(config);
          _message = '';
        });
      }
    } catch (error) {
      if (mounted && ticket == _generation) {
        setState(() => _message = visitorPolicyError(error));
      }
    } finally {
      if (mounted && ticket == _generation) {
        setState(() => _loading = false);
        _flushRefresh();
      }
    }
  }

  void _flushRefresh() {
    if (!_refreshQueued) return;
    _refreshQueued = false;
    _refresh();
  }

  bool get _enablingBlocked =>
      _draft?['enabled'] == true && _config?.rolloutReady != true;

  Future<void> _save() async {
    if (_saving ||
        _conflict ||
        _config == null ||
        _draft == null ||
        _enablingBlocked) {
      return;
    }
    final ticket = ++_generation;
    try {
      final effectiveAt = _scheduled
          ? VisitorSchedule.futureInstant(
              _effectiveAt.text,
              _config!.timeZone,
              _config!.currentServerTime,
              originalInstant: _config!.pendingSchedule?.effectiveAt,
            )
          : null;
      final input = visitorPolicyInput(_draft!);
      input['emergency'] = _emergency
          ? VisitorSchedule.period(
              _emStart.text,
              _emEnd.text,
              _config!.timeZone,
            )
          : null;
      final pets = input['pets'] as Map<String, dynamic>;
      pets['restriction'] = pets['mode'] == 'temporarily_restricted'
          ? VisitorSchedule.period(
              _petStart.text,
              _petEnd.text,
              _config!.timeZone,
            )
          : null;
      setState(() {
        _saving = true;
        _message = '';
      });
      final result = await _service.save(
        input,
        _config!.writeRevision,
        effectiveAt: effectiveAt,
      );
      if (mounted && ticket == _generation) {
        setState(() {
          _apply(result);
          _message = result.pendingSchedule != null
              ? 'Visitor settings saved and reloaded. ${result.pendingSchedule!.policy['enabled'] == true ? 'Enforcement' : 'Enforcement deactivation'} scheduled for ${VisitorSchedule.local(result.pendingSchedule!.effectiveAt, result.timeZone).replaceFirst('T', ' ')} (${result.timeZone}).'
              : 'Visitor settings saved and reloaded. Enforcement is ${result.enabled ? 'active' : 'off'}.';
        });
      }
    } catch (error) {
      if (mounted && ticket == _generation) {
        setState(() {
          _message = visitorPolicyError(error);
          if (error is FirebaseFunctionsException && error.code == 'aborted') {
            _conflict = true;
          }
        });
      }
    } finally {
      if (mounted && ticket == _generation) {
        setState(() => _saving = false);
        if (_config != null) _armActivation(_config!);
        _flushRefresh();
      }
    }
  }

  Future<void> _pick(TextEditingController controller) async {
    final current =
        DateTime.tryParse('${controller.text}:00Z') ??
        DateTime.tryParse(
          '${VisitorSchedule.local(_config!.serverTime, _config!.timeZone)}:00Z',
        ) ??
        DateTime.utc(2026);
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      controller.text = DateTime.utc(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ).toIso8601String().substring(0, 16);
      _dirty = true;
    });
  }

  Widget _date(String label, TextEditingController controller) => TextField(
    controller: controller,
    enabled: !_saving && !_enablingBlocked && _config?.timeZoneError == null,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'YYYY-MM-DDTHH:mm',
      suffixIcon: IconButton(
        tooltip: 'Choose $label',
        onPressed: _saving || _enablingBlocked || _config?.timeZoneError != null
            ? null
            : () => _pick(controller),
        icon: const Icon(Icons.calendar_month),
      ),
    ),
    onChanged: (_) => setState(() => _dirty = true),
  );
  Widget _dates(
    String prefix,
    TextEditingController start,
    TextEditingController end,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final fields = [_date('$prefix start', start), _date('$prefix end', end)];
      return constraints.maxWidth >= 560
          ? Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 16),
                Expanded(child: fields[1]),
              ],
            )
          : Column(
              children: [fields[0], const SizedBox(height: 12), fields[1]],
            );
    },
  );
  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    key: ValueKey('$label:$value'),
    isExpanded: true,
    isDense: false,
    itemHeight: null,
    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(),
    onChanged: _saving || _enablingBlocked || _config!.timeZoneError != null
        ? null
        : (value) {
            if (value != null) {
              setState(() {
                changed(value);
                _dirty = true;
                _message = '';
              });
            }
          },
  );

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final config = _config;

    Widget section({
      required IconData icon,
      required String title,
      required List<Widget> children,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF0E4778)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172B45),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );
    }

    Widget policyRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.right,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF172B45),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget note(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: Color(0xFF64748B),
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: const Color(0xFFF2F5FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visitor Policies',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172B45),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFF385674),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config == null
                          ? 'Visitor policy settings'
                          : _enablingBlocked
                          ? 'Enabling is blocked until visitor policy rollout is ready for this community. Disabling is allowed.'
                          : 'Save applies the selected ON/OFF state immediately or at the scheduled community time.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF385674),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dirty ? 'Unsaved changes' : 'Community policy',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dirty
                          ? const Color(0xFF9A6700)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading || _saving ? null : _load,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('Reload'),
                ),
              ],
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _message,
                  key: const ValueKey('visitor-policy-feedback'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (draft != null && config != null) ...[
              Text(
                'Time zone: ${config.timeZone ?? 'Not configured'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              if (config.timeZoneError != null) note(config.timeZoneError!),
              SwitchListTile(
                key: const ValueKey('visitor-enforcement-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Visitor-policy enforcement'),
                subtitle: Text(
                  draft['enabled'] == true
                      ? 'ON · Apply visitor restrictions'
                      : 'OFF · Use baseline authorization',
                ),
                value: draft['enabled'] == true,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _draft!['enabled'] = value;
                        _dirty = true;
                        _message = '';
                      }),
              ),
              const SizedBox(height: 12),

              section(
                icon: Icons.verified_user_outlined,
                title: 'Current Effective Policy',
                children: _policySummary(
                  config.policy,
                  config.enabled,
                  config,
                  policyRow,
                ),
              ),
              if (config.pendingSchedule != null) ...[
                const SizedBox(height: 12),
                section(
                  icon: Icons.event_outlined,
                  title: 'Scheduled Policy',
                  children: [
                    policyRow(
                      'Effective from',
                      '${_local(config.pendingSchedule!.effectiveAt, config).replaceFirst('T', ' ')} (${config.timeZone})',
                    ),
                    ..._policySummary(
                      config.pendingSchedule!.policy,
                      config.pendingSchedule!.policy['enabled'] == true,
                      config,
                      policyRow,
                      pending: true,
                    ),
                    note(
                      'Saving replaces this pending schedule. Choose Immediately to apply the edited policy now.',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              section(
                icon: Icons.schedule_outlined,
                title: 'Apply Changes',
                children: [
                  _select(
                    'Apply policy',
                    _scheduled ? 'scheduled' : 'immediate',
                    const {
                      'immediate': 'Immediately',
                      'scheduled': 'At a scheduled time',
                    },
                    (value) => _scheduled = value == 'scheduled',
                  ),
                  if (_scheduled) ...[
                    const SizedBox(height: 12),
                    _date('Policy effective time', _effectiveAt),
                    note(
                      'Choose a future date and time in ${config.timeZone}. Skipped or repeated daylight-saving times cannot be used.',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              section(
                icon: Icons.how_to_reg_outlined,
                title: 'Visitor Approval',
                children: [
                  policyRow(
                    'Owners',
                    draft['approvalMode'] == 'all_approval_required'
                        ? 'Admin approval required'
                        : 'Direct invitation',
                  ),
                  policyRow(
                    'Tenants',
                    draft['approvalMode'] == 'resident_authorized'
                        ? 'Direct invitation'
                        : 'Admin approval required',
                  ),
                  const SizedBox(height: 12),
                  _select(
                    'Approval mode',
                    draft['approvalMode'] as String,
                    visitorApprovalOptions,
                    (value) => draft['approvalMode'] = value,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              section(
                icon: Icons.schedule_outlined,
                title: 'Emergency Approval',
                children: [
                  policyRow(
                    'Saved period',
                    VisitorSchedule.status(
                      config.policy['emergency'] as Map?,
                      config.serverTime,
                    ),
                  ),
                  policyRow(
                    'Entry approval',
                    _emergency
                        ? 'Admin approval required'
                        : 'Normal approval policy',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Set temporary approval period',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _emergency,
                    onChanged:
                        _saving ||
                            _enablingBlocked ||
                            config.timeZoneError != null
                        ? null
                        : (value) => setState(() {
                            _emergency = value!;
                            _dirty = true;
                          }),
                  ),
                  if (_emergency) ...[
                    _dates('Emergency', _emStart, _emEnd),
                    note(
                      'Invitations not yet checked in are rechecked at entry and may require Admin approval. Visitors already inside are unaffected.',
                    ),
                  ],
                  policyRow(
                    'After expiry',
                    visitorApprovalOptions[draft['approvalMode']]!,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              section(
                icon: Icons.pets_outlined,
                title: 'Pet Entry',
                children: [
                  _select(
                    'Pet entry rule',
                    (draft['pets'] as Map)['mode'] as String,
                    const {
                      'allowed': 'Pets allowed',
                      'not_allowed': 'Pets not allowed',
                      'temporarily_restricted': 'Temporarily restricted',
                    },
                    (mode) {
                      final pets = draft['pets'] as Map;
                      pets['mode'] = mode;
                      if (mode != 'temporarily_restricted') {
                        pets['normalMode'] = mode;
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  policyRow(
                    'Saved restriction',
                    VisitorSchedule.status(
                      (config.policy['pets'] as Map)['restriction'] as Map?,
                      config.serverTime,
                    ),
                  ),
                  if ((draft['pets'] as Map)['mode'] ==
                      'temporarily_restricted') ...[
                    const SizedBox(height: 10),
                    _select(
                      'Rule after restriction',
                      (draft['pets'] as Map)['normalMode'] as String,
                      const {
                        'allowed': 'Pets allowed',
                        'not_allowed': 'Pets not allowed',
                      },
                      (value) => (draft['pets'] as Map)['normalMode'] = value,
                    ),
                    _dates('Pet restriction', _petStart, _petEnd),
                    note(
                      'Restriction covers the full arrival ±24-hour '
                      'credential window.',
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _saving ||
                          _conflict ||
                          config.timeZoneError != null ||
                          _enablingBlocked
                      ? null
                      : _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save visitor settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _activationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AdminTenantContext.instance.removeListener(_communityChanged);
    for (final controller in [
      _emStart,
      _emEnd,
      _petStart,
      _petEnd,
      _effectiveAt,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
