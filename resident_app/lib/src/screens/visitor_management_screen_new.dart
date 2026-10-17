import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../components/app_segmented_control.dart';
import '../components/resident_visitor_card_header.dart';
import '../components/resident_visitor_empty_state.dart';
import '../components/resident_visitor_page_header.dart';
import '../models/resident_visitor_lifecycle.dart';
import '../services/visitor_firestore_service.dart';
import '../services/visitor_qr_contract.dart';
import '../../visitor_qr_screen.dart';
import '../../add_expected_visitor_modal.dart';
import '../providers/language_provider.dart';
import '../widgets/resident_visitor_page_background.dart';

/// Pixel-Perfect Visitor Management Screen
/// Based on reference design with exact spacing and colors
/// Now with Firestore integration
class VisitorManagementScreenNew extends StatefulWidget {
  const VisitorManagementScreenNew({super.key});

  @override
  State<VisitorManagementScreenNew> createState() =>
      _VisitorManagementScreenNewState();
}

class _VisitorManagementScreenNewState
    extends State<VisitorManagementScreenNew> {
  int _selectedTabIndex = 0;
  final _visitorService = VisitorFirestoreService();

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return ResidentVisitorBackHandler(
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F9FD),
            body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              child: ResidentVisitorPageBackground(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      ResidentVisitorPageHeader(
                        title: 'visitor_management'.tr(),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
                        child: AppSegmentedControl(
                          segments: [
                            'visitor_tab_expected'.tr(),
                            'visitor_tab_checked_in'.tr(),
                            'visitor_tab_history'.tr(),
                            'deliveries'.tr(),
                          ],
                          selectedIndex: _selectedTabIndex,
                          scrollable: true,
                          onChanged: (index) {
                            setState(() => _selectedTabIndex = index);
                          },
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 110.h),
                          child: _buildTabContent(languageProvider),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButton: _buildFAB(),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(LanguageProvider languageProvider) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _visitorService.streamMyVisitors(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFDC2626),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'error_loading_visitors'.tr(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFFA3A3A3)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final allVisitors = snapshot.data ?? [];

        // Filter based on selected tab
        List<Map<String, dynamic>> filteredVisitors;

        if (_selectedTabIndex == 0) {
          filteredVisitors = allVisitors
              .where(ResidentVisitorLifecycle.isExpected)
              .toList();
        } else if (_selectedTabIndex == 1) {
          filteredVisitors = allVisitors
              .where(ResidentVisitorLifecycle.isCheckedIn)
              .toList();
        } else if (_selectedTabIndex == 2) {
          filteredVisitors = allVisitors
              .where(ResidentVisitorLifecycle.isHistory)
              .toList();
        } else {
          // Deliveries - for now, empty (can be implemented later)
          filteredVisitors = [];
        }

        // Empty state
        if (filteredVisitors.isEmpty) {
          return ResidentVisitorEmptyState.forTab(_selectedTabIndex);
        }

        // Display visitors
        return Column(
          children: filteredVisitors
              .map(
                (visitor) => Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: _buildVisitorCard(
                    visitor,
                    languageProvider,
                    isExpected: _selectedTabIndex == 0,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _formatRejectedAt(DateTime dateTime) {
    return DateFormat(
      'd MMM y, h:mm a',
      context.locale.toString(),
    ).format(dateTime);
  }

  Widget _buildVisitorCard(
    Map<String, dynamic> visitor,
    LanguageProvider languageProvider, {
    bool isExpected = false,
  }) {
    // Extract data from Firestore document
    final visitorId = visitor['id'] as String;
    final visitorName = visitor['visitorName'] as String? ?? 'unknown'.tr();
    final submittedPurpose = visitor['purpose'] as String?;
    final purpose = submittedPurpose?.trim().isNotEmpty == true
        ? submittedPurpose!
        : 'visitor_purpose_not_provided'.tr();
    final expectedArrival = (visitor['expectedArrival'] as Timestamp?)
        ?.toDate();
    final phoneNumber = visitor['phoneNumber'] as String?;
    final rejectedAt = (visitor['rejectedAt'] as Timestamp?)?.toDate();

    // Format time
    String timeText = 'visitor_time_not_set'.tr();
    if (expectedArrival != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final visitDate = DateTime(
        expectedArrival.year,
        expectedArrival.month,
        expectedArrival.day,
      );

      final hour = expectedArrival.hour > 12
          ? expectedArrival.hour - 12
          : expectedArrival.hour == 0
          ? 12
          : expectedArrival.hour;
      final minute = expectedArrival.minute.toString().padLeft(2, '0');
      final period = expectedArrival.hour >= 12 ? 'PM' : 'AM';

      if (visitDate == today) {
        timeText = '$hour:$minute $period ${'today'.tr()}';
      } else if (visitDate == today.add(const Duration(days: 1))) {
        timeText = '$hour:$minute $period ${'tomorrow'.tr()}';
      } else {
        timeText =
            '$hour:$minute $period ${expectedArrival.day}/${expectedArrival.month}';
      }
    }

    final statusKey = ResidentVisitorLifecycle.statusKeyFor(visitor);
    final adminDecisionKey = ResidentVisitorLifecycle.adminDecisionKeyFor(
      visitor,
    );
    final isDenied = statusKey == 'visitor_status_entry_denied';
    final isCheckedIn = statusKey == 'visitor_status_checked_in';
    final statusColor = isDenied || statusKey == 'visitor_status_rejected'
        ? const Color(0xFFDC2626)
        : isCheckedIn || adminDecisionKey == 'visitor_admin_approved'
        ? const Color(0xFF10B981)
        : const Color(0xFF0E4778);
    final statusBackgroundColor =
        isDenied || statusKey == 'visitor_status_rejected'
        ? const Color(0xFFFEE2E2)
        : isCheckedIn || adminDecisionKey == 'visitor_admin_approved'
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFE0E7FF);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(23.r),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082F73).withValues(alpha: .07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          ResidentVisitorCardHeader(
            visitorName: visitorName,
            purpose: purpose,
            timeText: timeText,
            phoneNumber: phoneNumber,
            statusLabel: statusKey.tr(),
            statusColor: statusColor,
            statusBackgroundColor: statusBackgroundColor,
            secondaryStatusLabel: adminDecisionKey?.tr(),
            rejectedAtLabel:
                statusKey == 'visitor_status_rejected' && rejectedAt != null
                ? '${'visitor_rejected_at'.tr()} ${_formatRejectedAt(rejectedAt)}'
                : null,
          ),

          // Action Buttons
          if (isExpected && visitor['isApproved'] != true) ...[
            SizedBox(height: 16.h),
            // Only show Reject button - Admin approves, not user
            _buildRejectButton(visitorId, visitorName),
          ],

          if (VisitorQrContract.canDisplay(visitor)) ...[
            SizedBox(height: 16.h),
            _buildViewQRButton(visitor),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectButton(String visitorId, String visitorName) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton(
        onPressed: () => _rejectVisitor(visitorId, visitorName),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          'cancel_request'.tr(),
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildViewQRButton(Map<String, dynamic> visitor) {
    final visitorId = visitor['id'] as String? ?? '';

    if (visitorId.isEmpty) {
      return const SizedBox();
    }

    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton.icon(
        onPressed: () {
          debugPrint('🔵 Opening QR screen for visitor ID: $visitorId');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisitorQRScreen(visitorId: visitorId),
            ),
          );
        },
        icon: Icon(Icons.qr_code_2, size: 20.w),
        label: Text(
          'view_qr_pass'.tr(),
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0E4778),
          side: const BorderSide(color: Color(0xFF0E4778), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      width: 56.w,
      height: 56.h,
      decoration: BoxDecoration(
        color: const Color(0xFF243143),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E4778).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Show modal - stream will automatically update on success
            await showAddExpectedVisitorModal(context);
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Icon(Icons.add, color: Colors.white, size: 28.w),
        ),
      ),
    );
  }

  Future<void> _rejectVisitor(String visitorId, String visitorName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('cancel_request'.tr()),
        content: Text(
          'visitor_cancel_confirmation'.tr(namedArgs: {'name': visitorName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: Text('yes_cancel'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Delete visitor from Firestore
      final result = await _visitorService.deleteVisitor(visitorId);

      // Close loading
      if (mounted) Navigator.pop(context);

      if (result.success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('visitor_cancelled'.tr()),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'visitor_cancel_error'.tr()),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('visitor_cancel_error'.tr()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }
}

// ============================================================================
// DELIVERY CLASS - FOR FUTURE IMPLEMENTATION
// ============================================================================
// This class is reserved for the Deliveries tab feature (Tab 4)
// Currently, the Deliveries tab shows an empty state
// Implement delivery tracking functionality here when needed

class Delivery {
  final String id;
  final String title;
  final String subtitle;
  final DateTime dateTime;
  final bool isReceived;

  Delivery({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dateTime,
    required this.isReceived,
  });
}
