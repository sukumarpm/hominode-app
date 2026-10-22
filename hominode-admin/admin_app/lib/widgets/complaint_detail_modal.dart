import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/complaint_models.dart';
import '../services/complaint_service.dart';
import 'complaint_attachments.dart';
import 'status_chip.dart';

class ComplaintDetailModal extends StatefulWidget {
  const ComplaintDetailModal({
    super.key,
    required this.complaint,
    this.onComplaintUpdated,
    this.complaintService,
    this.attachmentsOverride,
  });

  final ComplaintEntry complaint;
  final Function(ComplaintEntry)? onComplaintUpdated;
  final ComplaintService? complaintService;
  @visibleForTesting
  final Widget? attachmentsOverride;

  static void show(
    BuildContext context, {
    required ComplaintEntry complaint,
    Function(ComplaintEntry)? onComplaintUpdated,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ComplaintDetailModal(
        complaint: complaint,
        onComplaintUpdated: onComplaintUpdated,
      ),
    );
  }

  @override
  State<ComplaintDetailModal> createState() => _ComplaintDetailModalState();
}

class _ComplaintDetailModalState extends State<ComplaintDetailModal> {
  static const _teams = <(String, String)>[
    ('security', 'Security'),
    ('maintenance', 'Maintenance'),
    ('cleaning', 'Cleaning'),
    ('administration', 'Administration'),
    ('vendor', 'Vendor'),
    ('other', 'Other'),
  ];

  late final ComplaintService _service =
      widget.complaintService ?? ComplaintService();
  late ComplaintStatus _status = widget.complaint.status;
  late String? _team = _initialTeam(widget.complaint.assignedTeam);
  late final TextEditingController _assigneeController = TextEditingController(
    text: widget.complaint.assignedTo ?? '',
  );
  final TextEditingController _progressController = TextEditingController();
  final TextEditingController _resolutionController = TextEditingController();
  bool _saving = false;

  String? _initialTeam(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (_teams.any((team) => team.$1 == normalized)) return normalized;
    return 'legacy:$normalized';
  }

  String? get _teamValue {
    final value = _team;
    if (value == null) return null;
    return value.startsWith('legacy:') ? value.substring(7) : value;
  }

  @override
  void dispose() {
    _assigneeController.dispose();
    _progressController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: media.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _priorityBadge(),
                        // This reflects the last persisted status, not the
                        // dropdown selection while a write is still pending.
                        StatusChip(status: widget.complaint.status),
                        _categoryBadge(),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    _residentInfo(),
                    SizedBox(height: 16.h),
                    _sectionTitle('Description'),
                    SizedBox(height: 8.h),
                    _readOnlyText(
                      widget.complaint.description?.trim().isNotEmpty == true
                          ? widget.complaint.description!.trim()
                          : 'No description provided.',
                    ),
                    SizedBox(height: 16.h),
                    widget.attachmentsOverride ??
                        ComplaintAttachments(complaintId: widget.complaint.id),
                    SizedBox(height: 20.h),
                    _sectionTitle('Update complaint'),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<ComplaintStatus>(
                      key: const ValueKey('complaint-status-dropdown'),
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: ComplaintStatus.values
                          .map(
                            (status) => DropdownMenuItem<ComplaintStatus>(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('complaint-team-dropdown'),
                      initialValue: _team,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Responsible team (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No team selected'),
                        ),
                        ..._teams.map(
                          (team) => DropdownMenuItem<String>(
                            value: team.$1,
                            child: Text(team.$2),
                          ),
                        ),
                        if (_team?.startsWith('legacy:') == true)
                          DropdownMenuItem<String>(
                            value: _team,
                            child: Text('Existing: ${_teamValue!}'),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _team = value),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _assigneeController,
                      enabled: !_saving,
                      maxLength: 240,
                      decoration: const InputDecoration(
                        labelText: 'Person / vendor (optional)',
                        hintText: 'Name or contact details',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_status == ComplaintStatus.inProgress) ...[
                      SizedBox(height: 4.h),
                      _noteField(
                        controller: _progressController,
                        label: 'Progress note (optional)',
                        hint: 'Record the latest work or update',
                      ),
                    ],
                    if (_status == ComplaintStatus.resolved) ...[
                      SizedBox(height: 4.h),
                      _noteField(
                        controller: _resolutionController,
                        label: 'Resolution note (optional)',
                        hint: 'Describe how the complaint was resolved',
                      ),
                    ],
                    _notesHistory(
                      'Progress notes',
                      widget.complaint.progressNotes,
                    ),
                    _notesHistory(
                      'Resolution notes',
                      widget.complaint.resolutionNotes,
                    ),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 14.h),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complaint #${widget.complaint.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4.h),
              Text(
                widget.complaint.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          tooltip: 'Close complaint details',
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _priorityBadge() =>
      _badge(widget.complaint.priority.label, widget.complaint.priority.color);

  Widget _categoryBadge() => _badge(
    widget.complaint.category.label,
    const Color(0xFF6B7280),
    background: const Color(0xFFF3F4F6),
  );

  Widget _badge(String label, Color color, {Color? background}) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _residentInfo() => Container(
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resident: ${widget.complaint.residentName}'),
        SizedBox(height: 5.h),
        Text('Unit: ${widget.complaint.unit}'),
        SizedBox(height: 5.h),
        Text('Reported: ${_formatDate(widget.complaint.date)}'),
        if (_teamValue != null ||
            widget.complaint.assignedTo?.trim().isNotEmpty == true) ...[
          SizedBox(height: 8.h),
          Text(
            'Current assignment: ${[if (_teamValue != null) _teamLabel(_teamValue!), if (widget.complaint.assignedTo?.trim().isNotEmpty == true) widget.complaint.assignedTo!.trim()].join(' · ')}',
          ),
        ],
      ],
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
  );

  Widget _readOnlyText(String text) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(6.r),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Text(text),
  );

  Widget _noteField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) => Padding(
    padding: EdgeInsets.only(top: 12.h),
    child: TextField(
      controller: controller,
      enabled: !_saving,
      maxLength: 2000,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _notesHistory(String title, List<String> notes) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          SizedBox(height: 6.h),
          for (final note in notes)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text('• $note'),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() => Padding(
    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: ElevatedButton(
            key: const ValueKey('save-complaint-update'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save updates'),
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await _service.updateManualWorkflow(
        complaintId: widget.complaint.id,
        status: _status,
        assignedTeam: _teamValue,
        assignedTo: _assigneeController.text,
        progressNote: _progressController.text,
        resolutionNote: _resolutionController.text,
      );
      if (!mounted) return;

      final saved = ComplaintEntry(
        id: widget.complaint.id,
        priority: widget.complaint.priority,
        status: _status,
        title: widget.complaint.title,
        residentName: widget.complaint.residentName,
        unit: widget.complaint.unit,
        date: widget.complaint.date,
        category: widget.complaint.category,
        assignedTeam: _teamValue,
        assignedTo: _assigneeController.text.trim().isEmpty
            ? null
            : _assigneeController.text.trim(),
        description: widget.complaint.description,
        progressNotes: [
          ...widget.complaint.progressNotes,
          if (_progressController.text.trim().isNotEmpty)
            _progressController.text.trim(),
        ],
        resolutionNotes: [
          ...widget.complaint.resolutionNotes,
          if (_resolutionController.text.trim().isNotEmpty)
            _resolutionController.text.trim(),
        ],
      );
      widget.onComplaintUpdated?.call(saved);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        setState(() => _saving = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.notificationSent
                ? 'Complaint updated and resident notified.'
                : result.notificationError == null
                ? 'Complaint updated.'
                : 'Complaint updated, but resident notification failed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint update failed: $error')),
      );
    }
  }

  String _teamLabel(String team) {
    for (final option in _teams) {
      if (option.$1 == team) return option.$2;
    }
    return team.startsWith('legacy:') ? team.substring(7) : team;
  }

  static String _statusLabel(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return 'New';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
