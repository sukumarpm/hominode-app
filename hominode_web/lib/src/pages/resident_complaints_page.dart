import 'package:flutter/material.dart';

import '../services/resident_complaint_service.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_page_components.dart';

const List<String> _residentComplaintCategories = [
  'plumbing',
  'electrical',
  'maintenance',
  'cleaning',
  'security',
  'other',
];

class ResidentComplaintsPage extends StatefulWidget {
  const ResidentComplaintsPage({super.key, required this.session});

  final WebSession session;

  @override
  State<ResidentComplaintsPage> createState() => _ResidentComplaintsPageState();
}

class _ResidentComplaintsPageState extends State<ResidentComplaintsPage> {
  final ResidentComplaintService _service = ResidentComplaintService();
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) => ResidentPageLayout(
    title: 'Complaints',
    subtitle: 'Track complaints for your registered unit',
    child: SectionCard(
      title: 'My complaints',
      subtitle:
          'Only complaints created by your resident account in this community',
      action: FilledButton.icon(
        onPressed: _showCreateComplaintDialog,
        icon: const Icon(Icons.add_circle_outline, size: 17),
        label: const Text('New complaint'),
        style: FilledButton.styleFrom(
          backgroundColor: RolePalette.resident.primary,
          textStyle: const TextStyle(fontSize: 11),
        ),
      ),
      child: StreamBuilder<List<ResidentComplaint>>(
        stream: _service.watchMyComplaints(widget.session),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              message:
                  'Complaints could not be loaded: ${_messageFor(snapshot.error!)}',
            );
          }

          final complaints = snapshot.data ?? const <ResidentComplaint>[];
          final openCount = complaints
              .where((complaint) => !complaint.isCompleted)
              .length;
          final completedCount = complaints
              .where((complaint) => complaint.isCompleted)
              .length;

          final filtered = complaints
              .where((complaint) {
                if (_statusFilter == 'active') {
                  return !complaint.isCompleted;
                }
                if (_statusFilter == 'completed') {
                  return complaint.isCompleted;
                }
                return true;
              })
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill(label: 'Total', value: complaints.length),
                  _MetricPill(label: 'Active', value: openCount),
                  _MetricPill(label: 'Completed', value: completedCount),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Filter',
                    style: TextStyle(
                      color: WebDesign.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        _FilterChip(
                          label: 'Active',
                          selected: _statusFilter == 'active',
                          onTap: () => setState(() => _statusFilter = 'active'),
                        ),
                        _FilterChip(
                          label: 'Completed',
                          selected: _statusFilter == 'completed',
                          onTap: () =>
                              setState(() => _statusFilter = 'completed'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (complaints.isEmpty)
                const EmptyState(
                  icon: Icons.report_problem_outlined,
                  message:
                      'No complaints are available yet. Create one to get started.',
                )
              else if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  message: 'No complaints match this filter.',
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      _ComplaintRow(
                        complaint: filtered[i],
                        onTap: () =>
                            _showComplaintDetails(context, filtered[i]),
                      ),
                      if (i != filtered.length - 1)
                        const Divider(height: 24, color: WebDesign.border),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _showCreateComplaintDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = _residentComplaintCategories.first;
    var submitting = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) => AlertDialog(
          title: const Text('New complaint'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    items: _residentComplaintCategories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(_labelForCategory(category)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: submitting
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedCategory = value;
                            });
                          },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: titleController,
                    enabled: !submitting,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Please enter a title';
                      }
                      if (text.length < 5) {
                        return 'Title must be at least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descriptionController,
                    enabled: !submitting,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Please enter a description';
                      if (text.length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                      });
                      try {
                        await _service.createComplaint(
                          session: widget.session,
                          title: titleController.text,
                          description: descriptionController.text,
                          category: selectedCategory,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop(true);
                      } catch (error) {
                        if (!dialogBuildContext.mounted) return;
                        setDialogState(() {
                          submitting = false;
                        });
                        ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                          SnackBar(content: Text(_messageFor(error))),
                        );
                      }
                    },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully.')),
      );
    }
  }

  Future<void> _showComplaintDetails(
    BuildContext context,
    ResidentComplaint complaint,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complaint details'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Title', complaint.title),
                _detailRow('Category', _labelForCategory(complaint.category)),
                _detailRow('Status', _statusLabel(complaint.status)),
                _detailRow('Created', _formatDateTime(complaint.createdAt)),
                if (complaint.updatedAt != null)
                  _detailRow('Updated', _formatDateTime(complaint.updatedAt!)),
                if (complaint.flatLabel != null)
                  _detailRow('Unit', complaint.flatLabel!),
                if (complaint.assignedTo != null)
                  _detailRow('Assigned to', complaint.assignedTo!),
                if (complaint.technicianPhone != null)
                  _detailRow('Technician phone', complaint.technicianPhone!),
                if (complaint.progress != null)
                  _detailRow('Progress', complaint.progress!),
                if (complaint.resolution != null)
                  _detailRow('Resolution', complaint.resolution!),
                if (complaint.resolvedAt != null)
                  _detailRow(
                    'Resolved at',
                    _formatDateTime(complaint.resolvedAt!),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Description',
                  style: TextStyle(
                    color: WebDesign.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  complaint.description,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.complaint, required this.onTap});

  final ResidentComplaint complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(complaint.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: status.$2.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(status.$3, color: status.$2, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.title,
                    style: const TextStyle(
                      color: WebDesign.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_labelForCategory(complaint.category)} · ${_formatDateTime(complaint.createdAt)}',
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.$2.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.$1,
                    style: TextStyle(
                      color: status.$2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (complaint.assignedTo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    complaint.assignedTo!,
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: RolePalette.resident.soft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(
        color: RolePalette.resident.primary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? RolePalette.resident.primary
            : RolePalette.resident.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : RolePalette.resident.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

Widget _detailRow(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: WebDesign.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: WebDesign.text,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    ],
  ),
);

(String, Color, IconData) _statusStyle(String status) {
  switch (status) {
    case 'completed':
      return ('Completed', const Color(0xFF14805E), Icons.check_circle_outline);
    case 'inprogress':
      return ('In progress', const Color(0xFFE66A2C), Icons.handyman_outlined);
    default:
      return (
        'Pending',
        const Color(0xFFC43D3D),
        Icons.pending_actions_outlined,
      );
  }
}

String _statusLabel(String status) => _statusStyle(status).$1;

String _labelForCategory(String category) {
  final text = category.trim().toLowerCase();
  if (text.isEmpty) return 'Other';
  return text[0].toUpperCase() + text.substring(1);
}

String _formatDateTime(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour == 0
      ? 12
      : (date.hour > 12 ? date.hour - 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
}

String _messageFor(Object error) {
  if (error is ResidentComplaintException) {
    return error.message;
  }
  return error.toString();
}
