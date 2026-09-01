import 'package:flutter/material.dart';

import '../services/resident_visitor_service.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_page_components.dart';

class ResidentVisitorsPage extends StatefulWidget {
  const ResidentVisitorsPage({super.key, required this.session});

  final WebSession session;

  @override
  State<ResidentVisitorsPage> createState() => _ResidentVisitorsPageState();
}

class _ResidentVisitorsPageState extends State<ResidentVisitorsPage> {
  final ResidentVisitorService _service = ResidentVisitorService();

  Future<void> _addVisitor() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _AddVisitorDialog(session: widget.session, service: _service),
    );
    if (!mounted || added != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visitor added for Admin approval.')),
    );
  }

  @override
  Widget build(BuildContext context) => ResidentPageLayout(
    title: 'Visitors',
    subtitle: 'Expected and current visitors for your unit',
    child: SectionCard(
      title: 'My visitors',
      subtitle: 'Only visitors created for your resident account are shown',
      action: FilledButton.icon(
        onPressed: _addVisitor,
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
        label: const Text('Add visitor'),
        style: FilledButton.styleFrom(
          backgroundColor: RolePalette.resident.primary,
          textStyle: const TextStyle(fontSize: 11),
        ),
      ),
      child: StreamBuilder<List<ResidentVisitor>>(
        stream: _service.watchMyVisitors(widget.session),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              message:
                  'Visitors could not be loaded: ${_messageFor(snapshot.error!)}',
            );
          }
          final visitors = snapshot.data ?? const <ResidentVisitor>[];
          if (visitors.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              message: 'No visitors have been added for your unit.',
            );
          }
          return Column(
            children: [
              for (var index = 0; index < visitors.length; index++) ...[
                _VisitorRow(visitor: visitors[index]),
                if (index != visitors.length - 1)
                  const Divider(height: 24, color: WebDesign.border),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _VisitorRow extends StatelessWidget {
  const _VisitorRow({required this.visitor});

  final ResidentVisitor visitor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      final details = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: RolePalette.resident.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_outline,
              color: RolePalette.resident.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitor.name,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    visitor.purpose,
                    if (visitor.expectedArrival != null)
                      _dateTime(visitor.expectedArrival!),
                  ].join(' · '),
                  style: const TextStyle(color: WebDesign.muted, fontSize: 11),
                ),
                if (visitor.phoneNumber != null ||
                    visitor.vehicleNumber != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      visitor.phoneNumber,
                      visitor.vehicleNumber,
                    ].whereType<String>().join(' · '),
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
                if (visitor.isApproved && visitor.visitorPassCode != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Pass: ${visitor.visitorPassCode}',
                    style: TextStyle(
                      color: RolePalette.resident.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      final badge = _VisitorStatusBadge(visitor: visitor);
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            details,
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: badge),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: details),
          const SizedBox(width: 12),
          badge,
        ],
      );
    },
  );
}

class _VisitorStatusBadge extends StatelessWidget {
  const _VisitorStatusBadge({required this.visitor});

  final ResidentVisitor visitor;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (visitor.status) {
      'departed' || 'exited' => ('Departed', const Color(0xFF6B7280)),
      'checked_in' || 'inside' => ('Checked in', const Color(0xFF14805E)),
      'rejected' || 'cancelled' => ('Rejected', const Color(0xFFC43D3D)),
      _ when visitor.isApproved => ('Approved', const Color(0xFF14805E)),
      _ => ('Pending approval', const Color(0xFFE66A2C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddVisitorDialog extends StatefulWidget {
  const _AddVisitorDialog({required this.session, required this.service});

  final WebSession session;
  final ResidentVisitorService service;

  @override
  State<_AddVisitorDialog> createState() => _AddVisitorDialogState();
}

class _AddVisitorDialogState extends State<_AddVisitorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      setState(() => _error = 'Expected date and time are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final arrival = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      await widget.service.addExpectedVisitor(
        session: widget.session,
        visitorName: _nameController.text,
        purpose: _purposeController.text,
        expectedArrival: arrival,
        phoneNumber: _phoneController.text,
        vehicleNumber: _vehicleController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add expected visitor',
                      style: TextStyle(
                        color: WebDesign.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RequiredTextField(
                controller: _nameController,
                label: 'Visitor name',
              ),
              const SizedBox(height: 12),
              _RequiredTextField(
                controller: _purposeController,
                label: 'Purpose',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateButton = OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(
                      _date == null ? 'Expected date' : _dateOnly(_date!),
                    ),
                  );
                  final timeButton = OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickTime,
                    icon: const Icon(Icons.schedule_outlined, size: 17),
                    label: Text(
                      _time == null ? 'Expected time' : _timeOnly(_time!),
                    ),
                  );
                  if (constraints.maxWidth < 400) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dateButton,
                        const SizedBox(height: 8),
                        timeButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: dateButton),
                      const SizedBox(width: 10),
                      Expanded(child: timeButton),
                    ],
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFC43D3D),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: RolePalette.resident.primary,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add visitor'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RequiredTextField extends StatelessWidget {
  const _RequiredTextField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) =>
        value == null || value.trim().isEmpty ? '$label is required.' : null,
  );
}

String _dateTime(DateTime value) =>
    '${_dateOnly(value)} · '
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

String _dateOnly(DateTime value) =>
    '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';

String _timeOnly(TimeOfDay value) {
  final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
  final minute = _twoDigits(value.minute);
  final period = value.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _messageFor(Object error) {
  if (error is ResidentVisitorException) return error.message;
  return error.toString().replaceFirst('FirebaseException: ', '');
}
