import 'package:flutter/material.dart';
import '../models/complaint_models.dart';
import '../services/staff_vendor_service.dart';
import '../services/complaint_service.dart';
import 'status_chip.dart';

class ComplaintDetailModal extends StatefulWidget {
  final ComplaintEntry complaint;
  final Function(ComplaintEntry)? onComplaintUpdated;

  const ComplaintDetailModal({
    super.key,
    required this.complaint,
    this.onComplaintUpdated,
  });

  static void show(
    BuildContext context, {
    required ComplaintEntry complaint,
    Function(ComplaintEntry)? onComplaintUpdated,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ComplaintDetailModal(
        complaint: complaint,
        onComplaintUpdated: onComplaintUpdated,
      ),
    );
  }

  @override
  State<ComplaintDetailModal> createState() => _ComplaintDetailModalState();
}

class _ComplaintDetailModalState extends State<ComplaintDetailModal> {
  late ComplaintStatus _selectedStatus;
  String _selectedAssignee = 'Unassigned';
  final TextEditingController _commentController = TextEditingController();
  final StaffVendorService _staffVendorService = StaffVendorService();
  final ComplaintService _complaintService = ComplaintService();

  List<String> _assigneeOptions = ['Unassigned'];
  bool _isLoadingAssignees = true;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.complaint.status;
    // Initialize assignee from existing complaint
    _selectedAssignee = widget.complaint.assignedTo ?? 'Unassigned';
    _loadAssignees();
  }

  void _loadAssignees() async {
    print('ComplaintDetailModal: Loading staff and vendors from Firestore');
    
    try {
      // Fetch staff members
      final staffStream = _staffVendorService.getStaffMembers();
      final vendorStream = _staffVendorService.getVendors();
      
      // Listen to both streams
      staffStream.listen((staffList) {
        print('ComplaintDetailModal: Received ${staffList.length} staff members');
        
        vendorStream.listen((vendorList) {
          print('ComplaintDetailModal: Received ${vendorList.length} vendors');
          
          setState(() {
            _assigneeOptions = ['Unassigned'];
            
            // Add staff members
            for (var staff in staffList) {
              _assigneeOptions.add('${staff.name} (${staff.role})');
            }
            
            // Add vendors
            for (var vendor in vendorList) {
              _assigneeOptions.add('${vendor.contactPerson} - ${vendor.businessName} (${vendor.category})');
            }
            
            _isLoadingAssignees = false;
            print('ComplaintDetailModal: Total assignees available: ${_assigneeOptions.length}');
          });
        });
      });
    } catch (e) {
      print('ComplaintDetailModal ERROR: Failed to load assignees: $e');
      setState(() {
        _isLoadingAssignees = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusChips(),
                    const SizedBox(height: 16),
                    _buildWorkflowProgress(),
                    const SizedBox(height: 16),
                    _buildResidentInfo(),
                    const SizedBox(height: 16),
                    _buildDescription(),
                    const SizedBox(height: 16),
                    
                    // Status-based sections
                    if (_selectedStatus == ComplaintStatus.pending) ...[
                      _buildPendingWorkflow(),
                    ] else if (_selectedStatus == ComplaintStatus.inProgress) ...[
                      _buildInProgressWorkflow(),
                    ] else if (_selectedStatus == ComplaintStatus.resolved) ...[
                      _buildResolvedWorkflow(),
                    ],
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complaint #${widget.complaint.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.complaint.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            color: const Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.complaint.priority.color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.complaint.priority.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(status: _selectedStatus),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.complaint.category.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResidentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Resident:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.complaint.residentName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Unit:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.complaint.unit,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF10B981),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(widget.complaint.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            widget.complaint.description ?? 'No description provided.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildAttachmentsSection(),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments (1)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: InkWell(
            onTap: _viewAttachments,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(
                    Icons.attachment,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View attachments',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignToDropdown({String? label, String? key}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label ?? 'Assign to',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: _isLoadingAssignees
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading staff and vendors...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: key != null ? ValueKey(key) : null,
                    value: _selectedAssignee,
                    isExpanded: true,
                    items: _assigneeOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF374151),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedAssignee = newValue;
                        });
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }



  Widget _buildAddComment() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Add a comment or note about this complaint...',
          hintStyle: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: _buildStatusBasedActions(),
    );
  }

  Widget _buildStatusBasedActions() {
    switch (_selectedStatus) {
      case ComplaintStatus.pending:
        return Column(
          children: [
            // Primary workflow action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedAssignee != 'Unassigned' ? _handleAssignAndStart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  disabledForegroundColor: const Color(0xFF9CA3AF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _selectedAssignee != 'Unassigned' 
                          ? 'Assign & Start Work' 
                          : 'Select Staff First',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Secondary actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _contactResident,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Contact Resident',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleUpdate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case ComplaintStatus.inProgress:
        // If no staff assigned, show assignment required message
        if (_selectedAssignee == 'Unassigned') {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Text(
                  'Staff assignment required for In Progress complaints',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = ComplaintStatus.pending;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Go Back to Assign Staff',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        
        // Normal in-progress actions when staff is assigned
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleMarkResolved,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Mark as Resolved',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _contactResident,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Contact Resident',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleUpdate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case ComplaintStatus.resolved:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _contactResident,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Contact Resident',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  void _handleAssignAndStart() async {
    if (_selectedAssignee == 'Unassigned') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign a staff member first'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Move to In Progress status
      setState(() {
        _selectedStatus = ComplaintStatus.inProgress;
      });

      // Save to Firestore
      print('ComplaintDetailModal: Starting work on complaint ${widget.complaint.id}');
      await _complaintService.updateComplaintStatusAndAssignment(
        widget.complaint.id,
        'in-progress',
        _selectedAssignee,
      );
      print('ComplaintDetailModal: Successfully started work in Firestore');

      // Create updated complaint
      final updatedComplaint = ComplaintEntry(
        id: widget.complaint.id,
        priority: widget.complaint.priority,
        status: _selectedStatus,
        title: widget.complaint.title,
        residentName: widget.complaint.residentName,
        unit: widget.complaint.unit,
        date: widget.complaint.date,
        category: widget.complaint.category,
        assignedTo: _selectedAssignee,
        description: widget.complaint.description,
      );

      // Call callback to update parent state
      if (widget.onComplaintUpdated != null) {
        widget.onComplaintUpdated!(updatedComplaint);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work started - Assigned to $_selectedAssignee'),
            backgroundColor: const Color(0xFF2563EB),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('ComplaintDetailModal ERROR: Failed to start work: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start work: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleMarkResolved() async {
    try {
      // Move to Resolved status
      setState(() {
        _selectedStatus = ComplaintStatus.resolved;
      });

      // Save to Firestore
      print('ComplaintDetailModal: Marking complaint ${widget.complaint.id} as resolved');
      await _complaintService.updateComplaintStatusAndAssignment(
        widget.complaint.id,
        'resolved',
        _selectedAssignee == 'Unassigned' ? '' : _selectedAssignee,
      );
      print('ComplaintDetailModal: Successfully marked as resolved in Firestore');

      // Create updated complaint
      final updatedComplaint = ComplaintEntry(
        id: widget.complaint.id,
        priority: widget.complaint.priority,
        status: _selectedStatus,
        title: widget.complaint.title,
        residentName: widget.complaint.residentName,
        unit: widget.complaint.unit,
        date: widget.complaint.date,
        category: widget.complaint.category,
        assignedTo: _selectedAssignee,
        description: widget.complaint.description,
      );

      // Call callback to update parent state
      if (widget.onComplaintUpdated != null) {
        widget.onComplaintUpdated!(updatedComplaint);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint resolved by $_selectedAssignee'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('ComplaintDetailModal ERROR: Failed to mark as resolved: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as resolved: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleUpdate() async {
    // Create updated complaint
    final updatedComplaint = ComplaintEntry(
      id: widget.complaint.id,
      priority: widget.complaint.priority,
      status: _selectedStatus,
      title: widget.complaint.title,
      residentName: widget.complaint.residentName,
      unit: widget.complaint.unit,
      date: widget.complaint.date,
      category: widget.complaint.category,
      assignedTo: _selectedAssignee == 'Unassigned' ? null : _selectedAssignee,
      description: widget.complaint.description,
    );

    try {
      // Save to Firestore
      print('ComplaintDetailModal: Updating complaint ${widget.complaint.id} in Firestore');
      
      // Convert status to Firestore format
      String firestoreStatus = _selectedStatus == ComplaintStatus.pending 
          ? 'pending' 
          : _selectedStatus == ComplaintStatus.inProgress 
              ? 'in-progress' 
              : 'resolved';
      
      // Update both status and assignment in Firestore
      await _complaintService.updateComplaintStatusAndAssignment(
        widget.complaint.id,
        firestoreStatus,
        _selectedAssignee == 'Unassigned' ? '' : _selectedAssignee,
      );
      
      print('ComplaintDetailModal: Successfully updated complaint in Firestore');
      
      // Call callback to update parent state
      if (widget.onComplaintUpdated != null) {
        widget.onComplaintUpdated!(updatedComplaint);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint #${widget.complaint.id} updated successfully'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );

        // Close modal
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('ComplaintDetailModal ERROR: Failed to update complaint: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update complaint: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  // Status-specific UI components
  Widget _buildCurrentAssignment() {
    if (_selectedAssignee == 'Unassigned') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                SizedBox(width: 8),
                Text(
                  'Staff Assignment Required',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'In Progress complaints must have a staff member assigned to handle the work.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = ComplaintStatus.pending;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text(
                  'Assign Staff First',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Currently Assigned To',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedAssignee,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Working',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  // Workflow Progress Indicator
  Widget _buildWorkflowProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Workflow',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWorkflowStep(
                'New',
                _selectedStatus == ComplaintStatus.pending,
                true,
                Icons.assignment_outlined,
              ),
              _buildWorkflowArrow(),
              _buildWorkflowStep(
                'Assigned',
                _selectedStatus == ComplaintStatus.inProgress,
                _selectedAssignee != 'Unassigned',
                Icons.person_outline,
              ),
              _buildWorkflowArrow(),
              _buildWorkflowStep(
                'Resolved',
                _selectedStatus == ComplaintStatus.resolved,
                _selectedStatus == ComplaintStatus.resolved,
                Icons.check_circle_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(String label, bool isActive, bool isCompleted, IconData icon) {
    Color color;
    if (isCompleted) {
      color = const Color(0xFF10B981); // Green for completed
    } else if (isActive) {
      color = const Color(0xFF2563EB); // Blue for active
    } else {
      color = const Color(0xFF9CA3AF); // Gray for pending
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              size: 16,
              color: isCompleted ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: const Icon(
        Icons.arrow_forward,
        size: 16,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  // Pending Status Workflow
  Widget _buildPendingWorkflow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.pending_actions, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Pending Review',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This complaint is awaiting review and staff assignment. Please assign appropriate staff to begin work.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF78350F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Assignment Section
        _buildAssignmentSection(),
        const SizedBox(height: 16),
        
        // Comments Section
        _buildCommentsSection(),
      ],
    );
  }

  // In Progress Status Workflow
  Widget _buildInProgressWorkflow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Header with Progress Indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF8B5CF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.work_outline, 
                      color: Colors.white, 
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work in Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Active complaint being handled',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B21A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _selectedAssignee != 'Unassigned' 
                    ? 'Staff member $_selectedAssignee is actively working on resolving this complaint. You can monitor progress, update assignments, or mark as resolved when work is completed.'
                    : 'This complaint is marked as In Progress but requires staff assignment to continue. Please assign a staff member to handle the work.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B21A8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Assignment Section (if staff assigned, show current assignment; if not, show assignment form)
        if (_selectedAssignee != 'Unassigned') ...[
          _buildCurrentAssignmentSection(),
          const SizedBox(height: 16),
          _buildReassignmentSection(),
        ] else ...[
          _buildAssignmentSection(),
        ],
        const SizedBox(height: 16),
        
        // Progress Notes Section
        _buildCommentsSection(),
      ],
    );
  }

  Widget _buildCurrentAssignmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person, 
                  color: Colors.white, 
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Currently Assigned To',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2563EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    _selectedAssignee.split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAssignee,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Started: ${_formatDate(DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'WORKING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Resolved Status Workflow
  Widget _buildResolvedWorkflow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Complaint Resolved',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _selectedAssignee != 'Unassigned' 
                    ? 'This complaint has been successfully resolved by $_selectedAssignee.'
                    : 'This complaint has been marked as resolved.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Resolution Details
        _buildResolutionDetails(),
        const SizedBox(height: 16),
        
        // Reopen Option
        _buildReopenSection(),
      ],
    );
  }

  // Standardized Section Methods
  Widget _buildAssignmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text(
                'Staff Assignment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAssignToDropdown(label: 'Staff Assignment', key: 'main_assignment'),
          if (_selectedAssignee == 'Unassigned') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Please assign staff to proceed with this complaint',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReassignmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF8B5CF6), size: 18),
              SizedBox(width: 8),
              Text(
                'Reassign Staff',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Change the assigned staff member if needed',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          _buildAssignToDropdown(label: 'Reassign to', key: 'reassignment'),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.comment_outlined, color: Color(0xFF6B7280), size: 18),
              SizedBox(width: 8),
              Text(
                'Add Comment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAddComment(),
        ],
      ),
    );
  }

  Widget _buildResolutionDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Resolution Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedAssignee != 'Unassigned') ...[
            Row(
              children: [
                const Text(
                  'Resolved by:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedAssignee,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Text(
                'Completed on:',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReopenSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.refresh, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text(
                'Need to Reopen?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'If the issue persists or was not properly resolved, you can reopen this complaint.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = ComplaintStatus.pending;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'Reopen Complaint',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced In Progress Sections
  Widget _buildInProgressAssignmentStatus() {
    if (_selectedAssignee == 'Unassigned') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                SizedBox(width: 8),
                Text(
                  'Staff Assignment Required',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This complaint is marked as In Progress but no staff member is assigned. Work cannot proceed without proper assignment.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = ComplaintStatus.pending;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Go Back to Assign',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Show assignment dropdown inline
                      setState(() {
                        // This will trigger the assignment section to show
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Assign Now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAssignToDropdown(label: 'Assign Staff Member', key: 'error_assignment'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person, 
                  color: Colors.white, 
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Currently Assigned To',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2563EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    _selectedAssignee.split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAssignee,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Started: ${_formatDate(DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'WORKING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: Color(0xFF8B5CF6), size: 18),
              SizedBox(width: 8),
              Text(
                'Work Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress Steps
          Column(
            children: [
              _buildProgressStep(
                'Work Started',
                'Staff member has been assigned and work has begun',
                true,
                Icons.play_circle_filled,
              ),
              _buildProgressStep(
                'In Progress',
                'Currently working on resolving the complaint',
                true,
                Icons.work,
              ),
              _buildProgressStep(
                'Ready for Review',
                'Work completed, awaiting final review',
                false,
                Icons.rate_review,
              ),
              _buildProgressStep(
                'Resolved',
                'Complaint fully resolved and closed',
                false,
                Icons.check_circle,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Add progress update functionality
                  },
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text(
                    'Update Progress',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleMarkResolved,
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text(
                    'Mark Resolved',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String title, String description, bool isCompleted, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                width: 2,
              ),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              size: 16,
              color: isCompleted ? Colors.white : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressReassignmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF8B5CF6), size: 18),
              SizedBox(width: 8),
              Text(
                'Change Assignment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Need to reassign this complaint to a different staff member? This will notify the new assignee.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildAssignToDropdown(label: 'New Assignee', key: 'progress_reassignment'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Handle reassignment
                _handleUpdate();
              },
              icon: const Icon(Icons.person_add_alt, size: 16),
              label: const Text(
                'Reassign Complaint',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.note_add, color: Color(0xFF6B7280), size: 18),
              SizedBox(width: 8),
              Text(
                'Progress Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Add notes about work progress, updates, or any issues encountered',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          _buildAddComment(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Notes will be visible to all staff members working on this complaint',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _viewAttachments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attachments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF2563EB)),
              title: const Text('complaint_image.jpg'),
              subtitle: const Text('2.3 MB • Image'),
              trailing: IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  // Handle download
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading attachment...'),
                      backgroundColor: Color(0xFF2563EB),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactResident() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Resident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact ${widget.complaint.residentName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unit: ${widget.complaint.unit}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling ${widget.complaint.residentName}...'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sending message to ${widget.complaint.residentName}...'),
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}



// Reusable Primary Button Widget
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: borderColor != null 
                ? BorderSide(color: borderColor!, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}