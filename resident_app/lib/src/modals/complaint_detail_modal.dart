// lib/src/modals/complaint_detail_modal.dart
// Centered modal overlay for complaint details with timeline

import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../models/staff_model.dart';
import '../screens/chat_with_technician_screen.dart';
import '../services/complaint_firestore_service.dart';
import '../services/complaint_image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

// ============================================================================
// COLOR TOKENS
// ============================================================================
const kPrimary = Color(0xFF2563EB);
const kModalBackground = Color(0xFFFFFFFF);
const kOverlayDim = Color(0x5C000000); // rgba(0,0,0,0.36)
const kStatusInProgressBg = Color(0xFFFFF3E6);
const kStatusInProgressText = Color(0xFFFF7A00);
const kTimelineDone = Color(0xFF1DB954);
const kTimelineInProgress = Color(0xFFFF7A00);
const kTimelinePending = Color(0xFFC4C4C4);
const kTextTitle = Color(0xFF111111);
const kTextMuted = Color(0xFF7A7A7A);
const kCardBorder = Color(0xFFE6E6E6);

// ============================================================================
// TIMELINE STATUS ENUM
// ============================================================================
enum TimelineStatus { pending, inProgress, done }

// ============================================================================
// TIMELINE EVENT MODEL
// ============================================================================
class TimelineEvent {
  final String id;
  final String text;
  final String datetime;
  final TimelineStatus status;

  TimelineEvent({
    required this.id,
    required this.text,
    required this.datetime,
    required this.status,
  });
}

// ============================================================================
// HELPER: SHOW COMPLAINT DETAIL MODAL
// ============================================================================
/// Opens the complaint detail modal with fade+scale animation
void showComplaintDetailModal(
  BuildContext context,
  Complaint complaint, {
  StaffModel? assignedStaff,
  VoidCallback? onChat,
  VoidCallback? onDelete,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Complaint Details',
    barrierColor: kOverlayDim,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return ComplaintDetailModal(
        complaint: complaint,
        assignedStaff: assignedStaff,
        onChat: onChat,
        onDelete: onDelete,
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

// ============================================================================
// COMPLAINT DETAIL MODAL WIDGET
// ============================================================================
class ComplaintDetailModal extends StatefulWidget {
  final Complaint complaint;
  final StaffModel? assignedStaff;
  final VoidCallback? onChat;
  final VoidCallback? onDelete;

  const ComplaintDetailModal({
    Key? key,
    required this.complaint,
    this.assignedStaff,
    this.onChat,
    this.onDelete,
  }) : super(key: key);

  @override
  State<ComplaintDetailModal> createState() => _ComplaintDetailModalState();
}

class _ComplaintDetailModalState extends State<ComplaintDetailModal> {
  bool _isLoading = false;
  final ComplaintFirestoreService _complaintService = ComplaintFirestoreService.instance;

  // Generate timeline based on actual complaint status
  List<TimelineEvent> _getTimeline(Complaint complaint, StaffModel? staff) {
    final events = <TimelineEvent>[];
    
    print('🔄 Generating timeline for complaint ${complaint.id}');
    print('📊 Current status: ${complaint.status}');
    print('👤 Assigned staff: ${staff?.name ?? "none"}');
    
    // 1. Complaint Submitted (always done)
    events.add(TimelineEvent(
      id: '1',
      text: 'Complaint Submitted',
      datetime: _formatDate(complaint.createdDate),
      status: TimelineStatus.done,
    ));

    // 2. Assigned to Staff
    if (staff != null || complaint.assignedTo != null) {
      final staffName = staff?.name ?? complaint.assignedTo ?? 'Staff';
      events.add(TimelineEvent(
        id: '2',
        text: 'Assigned to $staffName',
        datetime: _formatDate(complaint.createdDate.add(const Duration(hours: 1))),
        status: TimelineStatus.done,
      ));
    } else if (complaint.status == ComplaintStatus.pending) {
      events.add(TimelineEvent(
        id: '2',
        text: 'Waiting for Staff Assignment',
        datetime: 'Pending',
        status: TimelineStatus.pending,
      ));
      print('✅ Timeline: Pending assignment');
      return events; // Stop here if still pending
    }

    // 3. Work in Progress
    if (complaint.status == ComplaintStatus.inProgress) {
      events.add(TimelineEvent(
        id: '3',
        text: 'Work in Progress',
        datetime: _formatDate(complaint.createdDate.add(const Duration(hours: 2))),
        status: TimelineStatus.inProgress,
      ));
      
      events.add(TimelineEvent(
        id: '4',
        text: 'Work Completion',
        datetime: 'In Progress',
        status: TimelineStatus.pending,
      ));
      print('✅ Timeline: In Progress');
    } else if (complaint.status == ComplaintStatus.completed) {
      events.add(TimelineEvent(
        id: '3',
        text: 'Work in Progress',
        datetime: _formatDate(complaint.createdDate.add(const Duration(hours: 2))),
        status: TimelineStatus.done,
      ));
      
      events.add(TimelineEvent(
        id: '4',
        text: 'Work Completed',
        datetime: _formatDate(complaint.createdDate.add(const Duration(days: 1))),
        status: TimelineStatus.done,
      ));
      print('✅ Timeline: Completed');
    }

    return events;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _handleChatPressed(Complaint complaint) async {
    // Check if technician is assigned
    if (complaint.assignedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No technician assigned yet. Please wait for assignment.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Close modal first
    Navigator.pop(context);
    
    // Navigate to chat screen with actual technician data
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatWithTechnicianScreen(
          chatId: 'complaint_${complaint.id}',
          technicianName: complaint.assignedTo!,
          technicianRole: _getTechnicianRole(complaint.category),
          technicianPhone: complaint.technicianPhone,
        ),
      ),
    );

    widget.onChat?.call();
  }

  String _getTechnicianRole(ComplaintCategory category) {
    switch (category) {
      case ComplaintCategory.plumbing:
        return 'Plumbing Technician';
      case ComplaintCategory.electrical:
        return 'Electrical Technician';
      case ComplaintCategory.maintenance:
        return 'Maintenance Technician';
      case ComplaintCategory.cleaning:
        return 'Cleaning Staff';
      case ComplaintCategory.security:
        return 'Security Personnel';
      case ComplaintCategory.other:
        return 'Support Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.id)
          .snapshots(),
      builder: (context, snapshot) {
        // Use real-time data if available, otherwise use widget data
        Complaint currentComplaint = widget.complaint;
        
        if (snapshot.hasData && snapshot.data != null) {
          try {
            currentComplaint = _complaintService.complaintFromFirestore(snapshot.data!);
            print('🔄 Real-time update: ${currentComplaint.status}');
          } catch (e) {
            print('❌ Error parsing real-time data: $e');
          }
        }
        
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: kModalBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(currentComplaint),

                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon + Title + Status + Date
                          _buildTitleSection(currentComplaint),

                          const SizedBox(height: 24),

                          // Description
                          _buildDescriptionSection(currentComplaint),

                          const SizedBox(height: 24),

                          // Image (if available)
                          _buildImageSection(currentComplaint),

                          const SizedBox(height: 24),

                          // Assigned Staff Details
                          if (widget.assignedStaff != null)
                            _buildStaffDetailsSection(currentComplaint),

                          if (widget.assignedStaff != null)
                            const SizedBox(height: 24),

                          // Timeline
                          _buildTimelineSection(currentComplaint),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // CTA Button
                  _buildCTAButton(currentComplaint),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: kCardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Complaint Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kTextTitle,
              ),
            ),
          ),
          // Delete button (only for pending complaints)
          if (complaint.status == ComplaintStatus.pending && widget.onDelete != null)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                padding: EdgeInsets.zero,
                tooltip: 'Delete Complaint',
              ),
            ),
          // Close button (44x44 touch target)
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: kTextMuted, size: 24),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(Complaint complaint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon box - dynamically based on category
        IconBox(
          icon: _getIconForCategory(complaint.category),
          color: _getIconColor(complaint.category),
          backgroundColor: _getIconBackgroundColor(complaint.category),
        ),

        const SizedBox(width: 16),

        // Title, status, date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                complaint.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: kTextTitle,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              _buildDynamicStatusBadge(complaint.status),
              const SizedBox(height: 8),
              Text(
                complaint.formattedDate,
                style: const TextStyle(
                  fontSize: 14,
                  color: kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicStatusBadge(ComplaintStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case ComplaintStatus.pending:
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = 'Pending';
        break;
      case ComplaintStatus.inProgress:
        backgroundColor = kStatusInProgressBg;
        textColor = kStatusInProgressText;
        label = 'In Progress';
        break;
      case ComplaintStatus.completed:
        backgroundColor = const Color(0xFFE8FDEB);
        textColor = const Color(0xFF10B981);
        label = 'Completed';
        break;
    }

    return StatusBadge(
      label: label,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  Widget _buildDescriptionSection(Complaint complaint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextTitle,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          complaint.description,
          style: const TextStyle(
            fontSize: 15,
            color: kTextMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(Complaint complaint) {
    // Fetch image from Firestore using flow function pattern
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .doc(complaint.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final imageData = data?['imageUrl'] as String?;

        if (imageData == null || imageData.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attached Image',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kTextTitle,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImageFromData(imageData),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageFromData(String imageData) {
    try {
      // Check if it's a data URL (base64)
      if (imageData.startsWith('data:')) {
        // Extract base64 part
        final base64String = imageData.split(',').last;
        final bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: double.infinity,
            height: 250,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            ),
          ),
        );
      } else {
        // Fallback for network URLs
        return CachedNetworkImage(
          imageUrl: imageData,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: double.infinity,
            height: 250,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: double.infinity,
            height: 250,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error displaying image: $e');
      return Container(
        width: double.infinity,
        height: 250,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildStaffDetailsSection(Complaint complaint) {
    final staff = widget.assignedStaff!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Staff',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextTitle,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: kPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.roleDisplayName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStaffActionRow(
            Icons.phone_outlined,
            staff.phone,
            'Call',
            () => _handleCallStaff(staff.phone),
          ),
          const SizedBox(height: 8),
          _buildStaffActionRow(
            Icons.chat_bubble_outline,
            'Chat with ${staff.name.split(' ').first}',
            'Chat',
            () => _handleChatPressed(complaint),
          ),
          if (staff.email != null) ...[
            const SizedBox(height: 8),
            _buildStaffInfoRow(Icons.email_outlined, staff.email!),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffActionRow(IconData icon, String text, String action, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kPrimary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: kPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: kTextTitle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              action,
              style: const TextStyle(
                fontSize: 13,
                color: kPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 14, color: kPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffInfoRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: kTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCallStaff(String phoneNumber) async {
    // Remove any formatting from phone number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Staff Member'),
        content: Text('Do you want to call $phoneNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // In a real app, use url_launcher package
      // await launchUrl(Uri.parse('tel:$cleanNumber'));
      
      // For now, show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling $phoneNumber...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildTimelineSection(Complaint complaint) {
    final timeline = _getTimeline(complaint, widget.assignedStaff);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextTitle,
            ),
          ),
          const SizedBox(height: 16),
          ...timeline.map((event) => TimelineRow(event: event)),
        ],
      ),
    );
  }

  Widget _buildCTAButton(Complaint complaint) {
    // Show different buttons based on status
    if (complaint.status == ComplaintStatus.pending) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFFF97316), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for staff assignment',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFF97316),
                        fontWeight: FontWeight.w500,
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

    if (complaint.status == ComplaintStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8FDEB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Work completed successfully',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // In Progress - show chat button
    return Container(
      padding: const EdgeInsets.all(24),
      child: PrimaryButton(
        label: 'Chat With Technician',
        icon: Icons.chat_bubble_outline,
        onPressed: _isLoading ? null : () => _handleChatPressed(complaint),
        isLoading: _isLoading,
      ),
    );
  }

  // Helper methods for category-based styling
  IconData _getIconForCategory(ComplaintCategory category) {
    switch (category) {
      case ComplaintCategory.plumbing:
        return Icons.water_drop_outlined;
      case ComplaintCategory.electrical:
        return Icons.bolt_outlined;
      case ComplaintCategory.maintenance:
        return Icons.build_outlined;
      case ComplaintCategory.cleaning:
        return Icons.cleaning_services_outlined;
      case ComplaintCategory.security:
        return Icons.security_outlined;
      case ComplaintCategory.other:
        return Icons.help_outline;
    }
  }

  Color _getIconColor(ComplaintCategory category) {
    switch (category) {
      case ComplaintCategory.plumbing:
        return const Color(0xFF3B82F6);
      case ComplaintCategory.electrical:
        return const Color(0xFFF59E0B);
      case ComplaintCategory.maintenance:
        return const Color(0xFF10B981);
      case ComplaintCategory.cleaning:
        return const Color(0xFF8B5CF6);
      case ComplaintCategory.security:
        return const Color(0xFFEF4444);
      case ComplaintCategory.other:
        return const Color(0xFF6B7280);
    }
  }

  Color _getIconBackgroundColor(ComplaintCategory category) {
    switch (category) {
      case ComplaintCategory.plumbing:
        return const Color(0xFFEAF1FF);
      case ComplaintCategory.electrical:
        return const Color(0xFFFFF3E8);
      case ComplaintCategory.maintenance:
        return const Color(0xFFE8FDEB);
      case ComplaintCategory.cleaning:
        return const Color(0xFFEDE9FF);
      case ComplaintCategory.security:
        return const Color(0xFFFEE2E2);
      case ComplaintCategory.other:
        return const Color(0xFFF3F4F6);
    }
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

/// Rounded square icon container
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const IconBox({
    Key? key,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

/// Status badge pill
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    Key? key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// Timeline row with colored dot
class TimelineRow extends StatelessWidget {
  final TimelineEvent event;

  const TimelineRow({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored dot (12x12)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: dotColorForStatus(event.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Text(
              '${event.text} - ${event.datetime}',
              style: const TextStyle(
                fontSize: 15,
                color: kTextMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary button with loading state
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    Key? key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// UTILITY FUNCTIONS (unit-testable)
// ============================================================================

/// Returns dot color based on timeline status
Color dotColorForStatus(TimelineStatus status) {
  switch (status) {
    case TimelineStatus.done:
      return kTimelineDone;
    case TimelineStatus.inProgress:
      return kTimelineInProgress;
    case TimelineStatus.pending:
      return kTimelinePending;
  }
}

// ============================================================================
// SUMMARY
// ============================================================================
// 1. Paste file at: lib/src/modals/complaint_detail_modal.dart
// 2. Assets required: None (using Flutter Icons)
// 3. Usage: showComplaintDetailModal(context, complaint, onChat: () { /* navigate */ });
