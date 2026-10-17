import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/billing_schedule_v2.dart';

const _maxRecurringChargeLines = 20;
const _scheduleAttemptPrefix = 'admin_billing_schedule_v2_unresolved';

String billingScheduleAttemptStorageKeyV2(
  String adminUid,
  String communityId,
) =>
    '$_scheduleAttemptPrefix:${base64UrlEncode(utf8.encode(jsonEncode([adminUid, communityId]))).replaceAll('=', '')}';

class _ChargeDraft {
  final String id;
  final String code;
  final TextEditingController label;
  final TextEditingController amount;

  _ChargeDraft(this.id, {this.code = 'maintenance'})
    : label = TextEditingController(),
      amount = TextEditingController();

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class CreateBillingScheduleV2Dialog extends StatefulWidget {
  final String adminUid;
  final String communityId;
  final BillingScheduleV2Gateway gateway;
  final VoidCallback onCreated;

  const CreateBillingScheduleV2Dialog({
    super.key,
    required this.adminUid,
    required this.communityId,
    required this.gateway,
    required this.onCreated,
  });

  @override
  State<CreateBillingScheduleV2Dialog> createState() =>
      _CreateBillingScheduleV2DialogState();
}

class _CreateBillingScheduleV2DialogState
    extends State<CreateBillingScheduleV2Dialog> {
  final _formKey = GlobalKey<FormState>();
  final _generationDay = TextEditingController(text: '1');
  final _dueDay = TextEditingController(text: '1');
  final _startPeriod = TextEditingController(text: _currentPeriod());
  final _endPeriod = TextEditingController();
  final List<_ChargeDraft> _chargeLines = [_ChargeDraft('line_1')];
  String _scope = 'community';
  String _buildingId = '';
  String _flatId = '';
  final Set<String> _flatIds = {};
  List<BillingScheduleTargetV2> _buildings = const [];
  List<BillingScheduleTargetV2> _units = const [];
  bool _loadingTargets = false;
  bool _targetsLoaded = false;
  bool _restoring = true;
  bool _busy = false;
  bool _submissionInFlight = false;
  bool _created = false;
  String? _error;
  String? _targetError;
  Map<String, dynamic>? _savedAttempt;
  int _lineSequence = 1;

  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _restoreAttempt();
  }

  @override
  void dispose() {
    _generationDay.dispose();
    _dueDay.dispose();
    _startPeriod.dispose();
    _endPeriod.dispose();
    for (final line in _chargeLines) {
      line.dispose();
    }
    super.dispose();
  }

  String get _storageKey =>
      billingScheduleAttemptStorageKeyV2(widget.adminUid, widget.communityId);

  Future<void> _restoreAttempt() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw != null) {
        final parsed = jsonDecode(raw);
        _savedAttempt = validateBillingScheduleRequestV2(parsed);
      }
    } catch (_) {
      _error =
          'A saved billing request could not be read. Close and reopen this form or contact support.';
    }
    if (mounted) setState(() => _restoring = false);
  }

  Future<void> _loadTargets() async {
    if (_targetsLoaded || _loadingTargets) return;
    setState(() {
      _loadingTargets = true;
      _targetError = null;
    });
    try {
      final results = await Future.wait([
        widget.gateway.loadBillingScheduleBuildings(widget.communityId),
        widget.gateway.loadBillingScheduleUnits(widget.communityId),
      ]);
      if (!mounted) return;
      setState(() {
        _buildings = results[0];
        _units = results[1];
        _targetsLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _targetError =
              'Buildings and units could not be loaded. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTargets = false);
    }
  }

  void _setScope(String? scope) {
    if (scope == null) return;
    setState(() {
      _scope = scope;
      _buildingId = '';
      _flatId = '';
      _flatIds.clear();
      _error = null;
    });
    if (scope != 'community') _loadTargets();
  }

  List<BillingScheduleTargetV2> get _unitsInBuilding =>
      _units.where((unit) => unit.buildingId == _buildingId).toList();

  void _addChargeLine() {
    if (_chargeLines.length >= _maxRecurringChargeLines) return;
    setState(() {
      _lineSequence++;
      _chargeLines.add(_ChargeDraft('line_$_lineSequence'));
    });
  }

  Map<String, dynamic> _buildRequest() {
    final generationDay = int.tryParse(_generationDay.text.trim());
    final dueDay = int.tryParse(_dueDay.text.trim());
    if (generationDay == null || dueDay == null) {
      throw const FormatException('Enter a valid generation day and due day.');
    }
    final chargeLines = <Map<String, dynamic>>[];
    for (final line in _chargeLines) {
      final code = line.code;
      const labels = {
        'maintenance': 'Maintenance',
        'water': 'Water',
        'parking': 'Parking',
        'service': 'Service',
        'electricity': 'Electricity',
        'security': 'Security',
        'other': 'Other',
      };
      final label = code == 'custom'
          ? line.label.text.replaceAll(RegExp(r'\s+'), ' ').trim()
          : labels[code]!;
      final amount = parseBillingScheduleRupeesToMinorUnits(line.amount.text);
      if (amount == null) {
        throw const FormatException(
          'Enter a positive INR amount with up to two decimal places for each charge.',
        );
      }
      chargeLines.add({
        'lineId': line.id,
        'code': code,
        'label': label,
        'amountMinor': amount,
      });
    }
    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'communityId': widget.communityId,
      'currency': 'INR',
      'frequency': 'monthly',
      'idempotencyKey': createBillingScheduleIdempotencyKeyV2(),
      'scope': _scope,
      'generationDay': generationDay,
      'dueDay': dueDay,
      'startBillingPeriod': _startPeriod.text.trim(),
      'endBillingPeriod': _endPeriod.text.trim().isEmpty
          ? null
          : _endPeriod.text.trim(),
      'chargeLines': chargeLines,
    };
    if (_scope == 'building') payload['buildingId'] = _buildingId;
    if (_scope == 'unit') {
      payload['buildingId'] = _buildingId;
      payload['flatId'] = _flatId;
    }
    if (_scope == 'units') payload['flatIds'] = _flatIds.toList()..sort();
    return validateBillingScheduleRequestV2(payload);
  }

  Future<void> _submitNew() async {
    if (_busy ||
        _submissionInFlight ||
        _savedAttempt != null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    _submissionInFlight = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    Map<String, dynamic> payload;
    try {
      payload = _buildRequest();
    } on FormatException catch (failure) {
      setState(() {
        _error = failure.message;
        _busy = false;
      });
      _submissionInFlight = false;
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _storageKey,
        jsonEncode(payload),
      );
      if (!saved) throw StateError('Billing request persistence failed.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'The request could not be saved safely, so it was not submitted.';
          _busy = false;
        });
      }
      _submissionInFlight = false;
      return;
    }
    if (!mounted) {
      _submissionInFlight = false;
      return;
    }
    setState(() => _savedAttempt = payload);
    await _submitSaved(payload, alreadyBusy: true);
  }

  Future<void> _submitSaved(
    Map<String, dynamic> payload, {
    bool alreadyBusy = false,
  }) async {
    if (!alreadyBusy) {
      if (_busy || _submissionInFlight) return;
      _submissionInFlight = true;
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await widget.gateway.createBillingScheduleV2(payload);
      final preferences = await SharedPreferences.getInstance();
      final removed = await preferences.remove(_storageKey);
      if (!removed) {
        throw StateError('Billing request recovery marker remains.');
      }
      if (!mounted) return;
      setState(() {
        _savedAttempt = null;
        _created = true;
      });
      widget.onCreated();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The result is unresolved. The exact request was saved; retry it to safely recover the result.',
        );
      }
    } finally {
      _submissionInFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chargeLineEditor(_ChargeDraft line, int index) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('charge-code-${line.id}-${line.code}'),
                  initialValue: line.code,
                  decoration: InputDecoration(
                    labelText: 'Charge ${index + 1} type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance'),
                    ),
                    DropdownMenuItem(value: 'water', child: Text('Water')),
                    DropdownMenuItem(value: 'parking', child: Text('Parking')),
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(
                      value: 'electricity',
                      child: Text('Electricity'),
                    ),
                    DropdownMenuItem(
                      value: 'security',
                      child: Text('Security'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            final replacement = _ChargeDraft(
                              line.id,
                              code: value,
                            );
                            replacement.label.text = line.label.text;
                            replacement.amount.text = line.amount.text;
                            _chargeLines[index].dispose();
                            _chargeLines[index] = replacement;
                          });
                        },
                ),
              ),
              if (_chargeLines.length > 1)
                IconButton(
                  tooltip: 'Remove charge line',
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _chargeLines.removeAt(index).dispose(),
                        ),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (line.code == 'custom')
            TextFormField(
              controller: line.label,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Custom charge label',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a charge label.'
                  : null,
            ),
          TextFormField(
            controller: line.amount,
            key: ValueKey('billing-schedule-amount-${line.id}'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (INR)',
              prefixText: '₹ ',
            ),
            validator: (value) =>
                parseBillingScheduleRupeesToMinorUnits(value ?? '') == null
                ? 'Enter a positive amount with up to two decimals.'
                : null,
          ),
        ],
      ),
    ),
  );

  Widget _buildScopeFields() {
    if (_scope == 'community') return const SizedBox.shrink();
    if (_targetError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _targetError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: _busy ? null : _loadTargets,
            child: const Text('Retry loading units'),
          ),
        ],
      );
    }
    if (_loadingTargets) return const LinearProgressIndicator();
    if (_scope == 'units') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select units'),
          if (_units.isEmpty)
            const Text('No units are available in this community.'),
          for (final unit in _units)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(unit.label),
              subtitle: unit.buildingId == null
                  ? null
                  : Text('Building ${unit.buildingId}'),
              value: _flatIds.contains(unit.id),
              onChanged: _busy
                  ? null
                  : (selected) => setState(() {
                      if (selected == true) {
                        _flatIds.add(unit.id);
                      } else {
                        _flatIds.remove(unit.id);
                      }
                    }),
            ),
          if (_flatIds.isEmpty) const Text('Select at least one unit.'),
        ],
      );
    }
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('billing-building-$_buildingId'),
          initialValue: _buildingId.isEmpty ? null : _buildingId,
          decoration: const InputDecoration(labelText: 'Building'),
          items: _buildings
              .map(
                (building) => DropdownMenuItem(
                  value: building.id,
                  child: Text(building.label),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _buildingId = value ?? '';
                  _flatId = '';
                }),
          validator: (value) =>
              value == null || value.isEmpty ? 'Select a building.' : null,
        ),
        if (_scope == 'unit')
          DropdownButtonFormField<String>(
            key: ValueKey('billing-unit-$_flatId-$_buildingId'),
            initialValue: _flatId.isEmpty ? null : _flatId,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: _unitsInBuilding
                .map(
                  (unit) =>
                      DropdownMenuItem(value: unit.id, child: Text(unit.label)),
                )
                .toList(),
            onChanged: _busy || _buildingId.isEmpty
                ? null
                : (value) => setState(() => _flatId = value ?? ''),
            validator: (value) =>
                value == null || value.isEmpty ? 'Select a unit.' : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _created
        ? 'Recurring Schedule Created'
        : 'Create Recurring Billing Schedule';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: _restoring
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: _created
                    ? const Text(
                        'Your monthly billing schedule was created successfully.',
                      )
                    : _savedAttempt != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'An earlier schedule request has an unresolved result. Retry the exact saved request before creating another schedule.',
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Community: ${widget.communityId}'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _scope,
                              decoration: const InputDecoration(
                                labelText: 'Schedule scope',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'community',
                                  child: Text('Entire community'),
                                ),
                                DropdownMenuItem(
                                  value: 'building',
                                  child: Text('Building'),
                                ),
                                DropdownMenuItem(
                                  value: 'unit',
                                  child: Text('One unit'),
                                ),
                                DropdownMenuItem(
                                  value: 'units',
                                  child: Text('Selected units'),
                                ),
                              ],
                              onChanged: _busy ? null : _setScope,
                            ),
                            _buildScopeFields(),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _generationDay,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Generation day (1–28)',
                                    ),
                                    validator: (value) => _dayError(value),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dueDay,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Due day (1–28)',
                                    ),
                                    validator: (value) {
                                      final error = _dayError(value);
                                      if (error != null) return error;
                                      final due =
                                          int.tryParse((value ?? '').trim()) ??
                                          0;
                                      final generation =
                                          int.tryParse(
                                            _generationDay.text.trim(),
                                          ) ??
                                          0;
                                      return due < generation
                                          ? 'Due day must be on or after generation day.'
                                          : null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            TextFormField(
                              controller: _startPeriod,
                              decoration: const InputDecoration(
                                labelText: 'Start billing period (YYYY-MM)',
                              ),
                              validator: (value) =>
                                  _periodError(value, required: true),
                            ),
                            TextFormField(
                              controller: _endPeriod,
                              decoration: const InputDecoration(
                                labelText:
                                    'End billing period (optional, YYYY-MM)',
                              ),
                              validator: (value) => _periodError(value),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Monthly recurring charge lines',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            for (
                              var index = 0;
                              index < _chargeLines.length;
                              index++
                            )
                              _chargeLineEditor(_chargeLines[index], index),
                            if (_chargeLines.length < _maxRecurringChargeLines)
                              TextButton.icon(
                                onPressed: _busy ? null : _addChargeLine,
                                icon: const Icon(Icons.add),
                                label: const Text('Add charge line'),
                              ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(_created ? 'Done' : 'Cancel'),
        ),
        if (!_created && !_restoring)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : _savedAttempt == null
                ? _submitNew
                : () => _submitSaved(_savedAttempt!),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.repeat),
            label: Text(
              _busy
                  ? 'Creating…'
                  : _savedAttempt == null
                  ? 'Create Schedule'
                  : 'Retry Saved Request',
            ),
          ),
      ],
    );
  }

  String? _dayError(String? value) {
    final day = int.tryParse((value ?? '').trim());
    if (day == null || day < 1 || day > 28) return 'Enter a day from 1 to 28.';
    return null;
  }

  String? _periodError(String? value, {bool required = false}) {
    final period = (value ?? '').trim();
    if (!required && period.isEmpty) return null;
    if (!RegExp(r'^(20\d{2}|2100)-(0[1-9]|1[0-2])$').hasMatch(period)) {
      return 'Use YYYY-MM format.';
    }
    if (!required && period.compareTo(_startPeriod.text.trim()) < 0) {
      return 'End period cannot be before start period.';
    }
    return null;
  }
}
