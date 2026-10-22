import '../services/resident_private_images.dart';
import '../services/resident_image_operations.dart';
// lib/src/modals/complaint_detail_modal.dart
// Centered modal overlay for complaint details with timeline

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/complaint.dart';
import '../models/staff_model.dart';
import '../screens/chat_with_technician_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

// ============================================================================
// COLOR TOKENS
// ============================================================================
const kPrimary = Color(0xFF172B4D);
const kModalBackground = Color(0xFFFCFDFE);
const kOverlayDim = Color(0x5C000000); // rgba(0,0,0,0.36)
const kStatusInProgressBg = Color(0xFFFFF3E6);
const kStatusInProgressText = Color(0xFFFF7A00);
const kTimelineDone = Color(0xFF1DB954);
const kTimelineInProgress = Color(0xFFFF7A00);
const kTimelinePending = Color(0xFFC4C4C4);
const kTextTitle = Color(0xFF172B4D);
const kTextMuted = Color(0xFF52627A);
const kCardBorder = Color(0xFFDCE5EF);

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
          scale: Tween<double>(
            begin: 0.9,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
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
  final FirebaseFirestore? firestoreOverride;
  final Stream<Complaint>? complaintUpdates;
  final Future<String?> Function(String communityId)?
  communitySupportPhoneLoader;

  const ComplaintDetailModal({
    super.key,
    required this.complaint,
    this.assignedStaff,
    this.onChat,
    this.onDelete,
    this.firestoreOverride,
    this.complaintUpdates,
    this.communitySupportPhoneLoader,
  });

  @override
  State<ComplaintDetailModal> createState() => _ComplaintDetailModalState();
}

class _ComplaintDetailModalState extends State<ComplaintDetailModal> {
  final bool _isLoading = false;
  late final FirebaseFirestore _firestore =
      widget.firestoreOverride ?? FirebaseFirestore.instance;
  late final Future<String?>? _managementPhone = _loadCommunitySupportPhone(
    widget.complaint.communityId,
  );

  Future<String?>? _loadCommunitySupportPhone(String? communityId) {
    final id = communityId?.trim();
    if (id == null || id.isEmpty) return null;
    final loader = widget.communitySupportPhoneLoader;
    if (loader != null) return loader(id);
    return _firestore
        .collection('communities')
        .doc(id)
        .get()
        .then((snapshot) {
          final phone = snapshot.data()?['supportPhone'];
          return phone is String && phone.trim().isNotEmpty
              ? phone.trim()
              : null;
        })
        .catchError((Object _) => null);
  }

  // Generate timeline based on actual complaint status
  List<TimelineEvent> _getTimeline(Complaint complaint, StaffModel? staff) {
    final events = <TimelineEvent>[];

    print('🔄 Generating timeline for complaint ${complaint.id}');
    print('📊 Current status: ${complaint.status}');
    print('👤 Assigned staff: ${staff?.name ?? "none"}');

    // 1. Complaint Submitted (always done)
    events.add(
      TimelineEvent(
        id: '1',
        text: 'Complaint Submitted',
        datetime: _formatDate(complaint.createdDate),
        status: TimelineStatus.done,
      ),
    );

    // 2. Assigned to Staff
    final team = complaintAssignmentTeamDisplay(complaint.assignedTeam);
    final assignedPerson = _residentAssignedPerson(complaint, staff);
    if (team != null || assignedPerson != null) {
      final assignment = [
        if (team != null) team,
        if (assignedPerson != null) assignedPerson,
      ].join(' · ');
      events.add(
        TimelineEvent(
          id: '2',
          text: team != null
              ? 'Responsible team: $assignment'
              : 'Assigned to: $assignment',
          datetime: _formatDate(
            complaint.createdDate.add(const Duration(hours: 1)),
          ),
          status: TimelineStatus.done,
        ),
      );
    } else if (complaint.status == ComplaintStatus.pending) {
      events.add(
        TimelineEvent(
          id: '2',
          text: 'Management review',
          datetime: 'Awaiting update',
          status: TimelineStatus.pending,
        ),
      );
      return events;
    }

    // 3. Work in Progress
    if (complaint.status == ComplaintStatus.inProgress) {
      events.add(
        TimelineEvent(
          id: '3',
          text: 'Work in Progress',
          datetime: _formatDate(
            complaint.createdDate.add(const Duration(hours: 2)),
          ),
          status: TimelineStatus.inProgress,
        ),
      );

      events.add(
        TimelineEvent(
          id: '4',
          text: 'Work Completion',
          datetime: 'In Progress',
          status: TimelineStatus.pending,
        ),
      );
      print('✅ Timeline: In Progress');
    } else if (complaint.status == ComplaintStatus.completed) {
      events.add(
        TimelineEvent(
          id: '3',
          text: 'Work in Progress',
          datetime: _formatDate(
            complaint.createdDate.add(const Duration(hours: 2)),
          ),
          status: TimelineStatus.done,
        ),
      );

      events.add(
        TimelineEvent(
          id: '4',
          text: 'Work Completed',
          datetime: _formatDate(
            complaint.createdDate.add(const Duration(days: 1)),
          ),
          status: TimelineStatus.done,
        ),
      );
      print('✅ Timeline: Completed');
    }

    return events;
  }

  String? _residentAssignedPerson(Complaint complaint, StaffModel? staff) {
    final assignedPerson = complaintResidentVisibleAssignee(
      complaint.assignedTo,
    );
    if (assignedPerson != null) return assignedPerson;
    if (complaint.assignedStaffId?.trim().isNotEmpty == true) {
      return complaintResidentVisibleAssignee(staff?.name);
    }
    return null;
  }

  Widget _buildResponsibleAssignmentSection(
    Complaint complaint,
    StaffModel? staff,
  ) {
    final team = complaintAssignmentTeamDisplay(complaint.assignedTeam);
    final person = _residentAssignedPerson(complaint, staff);
    return Container(
      key: const ValueKey('complaint-responsible-assignment'),
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Responsible Assignment',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: kTextTitle,
            ),
          ),
          SizedBox(height: 12.h),
          if (team != null) _assignmentDetailRow('Responsible team', team),
          if (person != null) ...[
            if (team != null) SizedBox(height: 8.h),
            _assignmentDetailRow('Assigned person/vendor', person),
          ],
          if (team == null && person == null)
            Text(
              'Unassigned',
              style: TextStyle(fontSize: 14.sp, color: kTextMuted),
            ),
        ],
      ),
    );
  }

  Widget _assignmentDetailRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 12.sp, color: kTextMuted),
      ),
      SizedBox(height: 2.h),
      Text(
        value,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: kTextTitle,
        ),
      ),
    ],
  );

  String _formatDate(DateTime date) {
    final months = [
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
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _handleChatPressed(Complaint complaint) async {
    // Check if technician is assigned
    if (complaint.assignedStaffId?.trim().isNotEmpty != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Management is coordinating this work. A staff chat is not available for this assignment.',
          ),
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
          technicianName: widget.assignedStaff?.name ?? 'Assigned technician',
          technicianRole: _getTechnicianRole(complaint.category),
          technicianPhone: null,
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
    return StreamBuilder<Complaint>(
      stream:
          widget.complaintUpdates ??
          _firestore
              .collection('complaints')
              .doc(widget.complaint.id)
              .snapshots()
              .where((snapshot) => snapshot.data() != null)
              .map(
                (snapshot) =>
                    complaintFromFirestoreData(snapshot.id, snapshot.data()!),
              ),
      builder: (context, snapshot) {
        // Use real-time data if available, otherwise use widget data
        final currentComplaint = snapshot.data ?? widget.complaint;

        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 500.w),
            margin: EdgeInsets.symmetric(vertical: 40.h),
            decoration: BoxDecoration(
              color: kModalBackground,
              borderRadius: BorderRadius.circular(20.r),
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
                      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon + Title + Status + Date
                          _buildTitleSection(currentComplaint),

                          SizedBox(height: 24.h),

                          // Description
                          _buildDescriptionSection(currentComplaint),

                          SizedBox(height: 24.h),

                          _buildResponsibleAssignmentSection(
                            currentComplaint,
                            widget.assignedStaff,
                          ),

                          SizedBox(height: 24.h),

                          // Image (if available)
                          _buildImageSection(currentComplaint),

                          SizedBox(height: 24.h),

                          // Timeline
                          _buildTimelineSection(currentComplaint),

                          if (currentComplaint.progressNotes.isNotEmpty ||
                              currentComplaint.resolutionNotes.isNotEmpty) ...[
                            SizedBox(height: 20.h),
                            _buildAdminNotesSection(currentComplaint),
                          ],

                          SizedBox(height: 24.h),
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
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 16.w, 20.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kCardBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Complaint Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: kTextTitle,
              ),
            ),
          ),
          // Delete button (only for pending complaints)
          if (complaint.status == ComplaintStatus.pending &&
              widget.onDelete != null)
            SizedBox(
              width: 44.w,
              height: 44.h,
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
                icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.w),
                padding: EdgeInsets.zero,
                tooltip: 'Delete Complaint',
              ),
            ),
          // Close button (44x44 touch target)
          SizedBox(
            width: 44.w,
            height: 44.h,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: kTextMuted, size: 24.w),
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

        SizedBox(width: 16.w),

        // Title, status, date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                complaint.title,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w600,
                  color: kTextTitle,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 8.h),
              _buildDynamicStatusBadge(complaint.status),
              SizedBox(height: 8.h),
              Text(
                complaint.formattedDate,
                style: TextStyle(fontSize: 14.sp, color: kTextMuted),
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
        label = 'New';
        break;
      case ComplaintStatus.inProgress:
        backgroundColor = kStatusInProgressBg;
        textColor = kStatusInProgressText;
        label = 'In Progress';
        break;
      case ComplaintStatus.completed:
        backgroundColor = const Color(0xFFE8FDEB);
        textColor = const Color(0xFF10B981);
        label = 'Resolved';
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
        Text(
          'Description',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: kTextTitle,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          complaint.description,
          style: TextStyle(fontSize: 15.sp, color: kTextMuted, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildImageSection(Complaint complaint) {
    final imageData = complaint.imageUrl;
    if (imageData == null || imageData.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attached Image',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: kTextTitle,
          ),
        ),
        SizedBox(height: 12.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: _buildImageFromData(imageData),
        ),
      ],
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
            height: 250.h,
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.image_not_supported,
                size: 48.w,
                color: Colors.grey,
              ),
            ),
          ),
        );
      } else {
        // Fallback for network URLs
        if (imageData.startsWith(privateImagePrefix)) {
          return Image(
            image: residentImageProvider(imageData),
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              width: double.infinity,
              height: 250.h,
              color: Colors.grey[200],
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 48.w,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }
        return CachedNetworkImage(
          imageUrl: imageData,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: double.infinity,
            height: 250.h,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: double.infinity,
            height: 250.h,
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.image_not_supported,
                size: 48.w,
                color: Colors.grey,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error displaying image: $e');
      return Container(
        width: double.infinity,
        height: 250.h,
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 48.w,
            color: Colors.grey,
          ),
        ),
      );
    }
  }

  Widget _buildTimelineSection(Complaint complaint) {
    final timeline = _getTimeline(complaint, widget.assignedStaff);
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: kTextTitle,
            ),
          ),
          SizedBox(height: 16.h),
          ...timeline.map((event) => TimelineRow(event: event)),
        ],
      ),
    );
  }

  Widget _buildAdminNotesSection(Complaint complaint) {
    final notes = <(String, String)>[
      for (final note in complaint.progressNotes) ('Progress update', note),
      for (final note in complaint.resolutionNotes) ('Resolution', note),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Management updates',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: kTextTitle,
            ),
          ),
          SizedBox(height: 10.h),
          for (final (label, note) in notes)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    note,
                    style: TextStyle(fontSize: 14.sp, color: kTextTitle),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCTAButton(Complaint complaint) {
    if (complaint.status == ComplaintStatus.pending) {
      return Container(
        padding: EdgeInsets.all(24.w),
        child: _managementUpdateCard(
          'Management is reviewing your complaint.',
          background: const Color(0xFFFFF3E8),
          foreground: const Color(0xFFF97316),
        ),
      );
    }

    if (complaint.status == ComplaintStatus.completed) {
      return Container(
        padding: EdgeInsets.all(24.w),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFE8FDEB),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF10B981),
                size: 24.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Work completed successfully',
                  style: TextStyle(
                    fontSize: 15.sp,
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

    if (complaint.assignedStaffId?.trim().isNotEmpty != true) {
      return Container(
        padding: EdgeInsets.all(24.w),
        child: _managementUpdateCard(
          'Work is in progress. Contact management for updates.',
          background: const Color(0xFFEFF6FF),
          foreground: kTextTitle,
        ),
      );
    }

    // In Progress with an account-backed assignment: show chat button.
    return Container(
      padding: EdgeInsets.all(24.w),
      child: PrimaryButton(
        label: 'Chat With Technician',
        icon: Icons.chat_bubble_outline,
        onPressed: _isLoading ? null : () => _handleChatPressed(complaint),
        isLoading: _isLoading,
      ),
    );
  }

  Widget _managementUpdateCard(
    String message, {
    required Color background,
    required Color foreground,
  }) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(fontSize: 14.sp, color: foreground),
        ),
        SizedBox(height: 8.h),
        FutureBuilder<String?>(
          future: _managementPhone,
          builder: (context, snapshot) {
            final phone = snapshot.data;
            return Text(
              phone == null
                  ? 'Contact your community management for assistance.'
                  : 'Community support: $phone',
              style: TextStyle(fontSize: 14.sp, color: kTextTitle),
            );
          },
        ),
      ],
    ),
  );

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
    super.key,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64.w,
      height: 64.h,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Icon(icon, color: color, size: 32.w),
    );
  }
}

/// Status badge pill
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14.sp,
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

  const TimelineRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored dot (12x12)
          Container(
            width: 12.w,
            height: 12.h,
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(
              color: dotColorForStatus(event.status),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          // Text
          Expanded(
            child: Text(
              '${event.text} - ${event.datetime}',
              style: TextStyle(fontSize: 15.sp, color: kTextMuted, height: 1.4),
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
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22.w),
                    SizedBox(width: 12.w),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                      ),
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
