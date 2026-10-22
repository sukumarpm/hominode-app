import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/complaint_models.dart';
import '../services/complaint_service.dart';
import '../services/staff_vendor_service.dart';
import 'complaint_attachments.dart';
import 'status_chip.dart';

class ComplaintDetailModal extends StatefulWidget {
  const ComplaintDetailModal({
    super.key,
    required this.complaint,
    this.onComplaintUpdated,
    this.complaintService,
    this.staffVendorService,
    this.attachmentsOverride,
  });

  final ComplaintEntry complaint;
  final Function(ComplaintEntry)? onComplaintUpdated;
  final ComplaintService? complaintService;
  final StaffVendorService? staffVendorService;
  @visibleForTesting
  final Widget? attachmentsOverride;

  static void show(
    BuildContext context, {
    required ComplaintEntry complaint,
    Function(ComplaintEntry)? onComplaintUpdated,
    ComplaintService? complaintService,
    StaffVendorService? staffVendorService,
    Widget? attachmentsOverride,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ComplaintDetailModal(
        complaint: complaint,
        onComplaintUpdated: onComplaintUpdated,
        complaintService: complaintService,
        staffVendorService: staffVendorService,
        attachmentsOverride: attachmentsOverride,
      ),
    );
  }

  @override
  State<ComplaintDetailModal> createState() => _ComplaintDetailModalState();
}

class _ComplaintDetailModalState extends State<ComplaintDetailModal> {
  static const _teams = <(String, String)>[
    ('management', 'Management'),
    ('security', 'Security'),
    ('maintenance', 'Maintenance'),
    ('cleaning', 'Cleaning'),
    ('administration', 'Administration'),
    ('vendor', 'Vendor'),
    ('other', 'Other'),
  ];

  late final ComplaintService _service =
      widget.complaintService ?? ComplaintService();
  late final StaffVendorService _staffVendorService =
      widget.staffVendorService ?? StaffVendorService();
  late ComplaintStatus _status = widget.complaint.status;
  late String? _team = _initialTeam(widget.complaint.assignedTeam);
  Stream<List<StaffMember>>? _staffStream;
  Stream<List<VendorModel>>? _vendorStream;
  String? _selectedDirectoryContactId;
  String? _personFieldError;
  String? _directoryError;
  late final TextEditingController _assigneeController = TextEditingController(
    text: widget.complaint.assignedTo ?? '',
  );
  final TextEditingController _progressController = TextEditingController();
  final TextEditingController _resolutionController = TextEditingController();
  bool _saving = false;
  // Do not turn a prefilled legacy assignment into a new entry on status save.
  // Only an explicit user edit may supply an assignedTo patch.
  bool _personEdited = false;
  // An assignment change requires explicit opt-in. Status/team saves ignore
  // any prefilled or keyboard-modified legacy person value by default.
  bool _editingPerson = false;

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
    final keyboardInsets = MediaQuery.viewInsetsOf(context).vertical;
    final availableHeight = (media.height - keyboardInsets - 40.h)
        .clamp(0.0, media.height)
        .toDouble();
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: availableHeight * 0.9,
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
                    CheckboxListTile(
                      key: const ValueKey('complaint-edit-person-assignment'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Change assigned person / vendor'),
                      subtitle: const Text(
                        'Leave unchecked to keep the existing assignment.',
                      ),
                      value: _editingPerson,
                      onChanged: _saving ? null : _setEditingPerson,
                    ),
                    if (_editingPerson) _buildPersonAssignmentEditor(),
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
        helperText:
            'Updates are resident-visible. Do not include private phone numbers or email addresses.',
        helperMaxLines: 3,
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

  void _setEditingPerson(bool? value) {
    final editing = value ?? false;
    if (editing && _staffStream == null && _vendorStream == null) {
      try {
        _staffStream = _staffVendorService.getStaffMembers(
          propagateErrors: true,
        );
        _vendorStream = _staffVendorService.getVendors(propagateErrors: true);
      } catch (_) {
        _directoryError = 'Directory contacts are unavailable right now.';
      }
    }
    setState(() => _editingPerson = editing);
  }

  Widget _buildPersonAssignmentEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_directoryError != null)
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            _directoryError!,
            style: const TextStyle(color: Colors.black54),
          ),
        )
      else if (_staffStream != null && _vendorStream != null)
        StreamBuilder<List<StaffMember>>(
          stream: _staffStream,
          builder: (context, staffSnapshot) => StreamBuilder<List<VendorModel>>(
            stream: _vendorStream,
            builder: (context, vendorSnapshot) {
              if (staffSnapshot.hasError || vendorSnapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Directory contacts could not be loaded. You can enter a name below.',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }
              if ((!staffSnapshot.hasData || !vendorSnapshot.hasData) &&
                  !staffSnapshot.hasError &&
                  !vendorSnapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                );
              }
              final contacts = _directoryContacts(
                staffSnapshot.data ?? const [],
                vendorSnapshot.data ?? const [],
              );
              final selectedId =
                  contacts.any(
                    (contact) => contact.id == _selectedDirectoryContactId,
                  )
                  ? _selectedDirectoryContactId
                  : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'complaint-directory-contact-${selectedId ?? 'none'}',
                    ),
                    initialValue: selectedId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Community directory contact (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Choose a staff or vendor contact'),
                      ),
                      for (final contact in contacts)
                        DropdownMenuItem<String>(
                          value: contact.id,
                          child: Text(
                            contact.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (id) => _selectDirectoryContact(id, contacts),
                  ),
                  if (staffSnapshot.hasData &&
                      vendorSnapshot.hasData &&
                      contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'No staff or vendor contacts are available in this community. Enter a name below.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  SizedBox(height: 10.h),
                ],
              );
            },
          ),
        ),
      TextField(
        controller: _assigneeController,
        enabled: !_saving,
        onChanged: (value) {
          setState(() {
            _personEdited = true;
            _selectedDirectoryContactId = null;
            _personFieldError = _personErrorFor(value);
          });
        },
        maxLength: 240,
        decoration: InputDecoration(
          labelText: 'Person / vendor name (optional)',
          hintText: 'Name only; use community support contact',
          helperText: 'Do not enter private phone numbers or email addresses.',
          helperMaxLines: 3,
          errorText: _personFieldError,
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  );

  List<_ComplaintDirectoryContact> _directoryContacts(
    List<StaffMember> staff,
    List<VendorModel> vendors,
  ) {
    final contacts = <_ComplaintDirectoryContact>[];
    for (final member in staff) {
      final name = member.name.trim();
      if (name.isEmpty || member.status.toLowerCase() == 'inactive') continue;
      if (_personErrorFor(name) != null) continue;
      contacts.add(
        _ComplaintDirectoryContact(
          id: 'staff:${member.id}',
          assignableName: name,
          label: member.role.trim().isEmpty
              ? name
              : '$name · ${member.role.trim()}',
        ),
      );
    }
    for (final vendor in vendors) {
      if (vendor.status.toLowerCase() == 'inactive') continue;
      final name = vendor.contactPerson.trim().isNotEmpty
          ? vendor.contactPerson.trim()
          : vendor.businessName.trim();
      if (name.isEmpty || _personErrorFor(name) != null) continue;
      final label =
          vendor.contactPerson.trim().isEmpty ||
              vendor.businessName.trim().isEmpty
          ? name
          : '${vendor.businessName.trim()} · ${vendor.contactPerson.trim()}';
      contacts.add(
        _ComplaintDirectoryContact(
          id: 'vendor:${vendor.id}',
          assignableName: name,
          label: label,
        ),
      );
    }
    contacts.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return contacts;
  }

  void _selectDirectoryContact(
    String? id,
    List<_ComplaintDirectoryContact> contacts,
  ) {
    final selected = contacts.where((contact) => contact.id == id).firstOrNull;
    setState(() {
      _selectedDirectoryContactId = selected?.id;
      _personEdited = true;
      _personFieldError = null;
      _assigneeController.text = selected?.assignableName ?? '';
    });
  }

  String? _personErrorFor(String value) {
    final email = RegExp(r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b');
    final digitCount = RegExp(r'\d').allMatches(value).length;
    if (email.hasMatch(value) || digitCount >= 7) {
      return 'Enter a name only. Use community support contact for phone or email.';
    }
    return null;
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
            onPressed:
                _saving ||
                    (_editingPerson &&
                        _personEdited &&
                        _personFieldError != null)
                ? null
                : _save,
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
    if (_editingPerson && _personEdited && _personFieldError != null) return;
    setState(() => _saving = true);
    try {
      final teamPatch = _changedTeamPatch;
      final personPatch = _changedPersonPatch;
      final result = await _service.updateManualWorkflow(
        complaintId: widget.complaint.id,
        status: _status,
        assignedTeam: teamPatch,
        assignedTo: personPatch,
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
        // Mirror fields actually persisted, not any ignored input edits.
        assignedTeam: teamPatch == null
            ? widget.complaint.assignedTeam
            : (teamPatch.isEmpty ? null : teamPatch),
        assignedTo: personPatch == null
            ? widget.complaint.assignedTo
            : (personPatch.isEmpty ? null : personPatch),
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

  String? get _changedTeamPatch {
    final current = _teamValue?.trim();
    final original = widget.complaint.assignedTeam?.trim();
    if ((current ?? '').isEmpty && (original ?? '').isEmpty) return null;
    if (current == original) return null;
    return current ?? '';
  }

  String? get _changedPersonPatch {
    // Status and team updates must not write or revalidate untouched person data.
    if (!_editingPerson || !_personEdited) return null;
    final current = _assigneeController.text.trim();
    final original = widget.complaint.assignedTo?.trim() ?? '';
    if (current == original) return null;
    return current;
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

class _ComplaintDirectoryContact {
  const _ComplaintDirectoryContact({
    required this.id,
    required this.assignableName,
    required this.label,
  });

  final String id;
  final String assignableName;
  final String label;
}
