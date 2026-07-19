import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/visitor_model.dart';
import '../components/app_segmented_control.dart';
import '../components/standard_screen.dart';
import '../services/visitor_firestore_service.dart';
import '../../visitor_qr_screen.dart';
import '../../add_expected_visitor_modal.dart';
import '../providers/language_provider.dart';

/// Pixel-Perfect Visitor Management Screen
/// Based on reference design with exact spacing and colors
/// Now with Firestore integration
class VisitorManagementScreenNew extends StatefulWidget {
  const VisitorManagementScreenNew({Key? key}) : super(key: key);

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
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          body: StandardScreen(
            title: 'visitor_management'.tr(),
            showBackButton: false,
            isScrollable: true,
            padding: EdgeInsets.zero,
            body: Column(
              children: [
                const SizedBox(height: 20),

                // Segmented Control
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppSegmentedControl(
                    segments: [
                      'pending'.tr(),
                      'approved'.tr(),
                      'deliveries'.tr(),
                    ],
                    selectedIndex: _selectedTabIndex,
                    onChanged: (index) {
                      setState(() => _selectedTabIndex = index);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Content - Stream from Firestore
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTabContent(languageProvider),
                ),

                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
          floatingActionButton: _buildFAB(),
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'error_loading_visitors'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFA3A3A3),
                    ),
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
          // Pending - not approved yet
          filteredVisitors = allVisitors
              .where((v) => v['isApproved'] == false && v['status'] == 'expected')
              .toList();
        } else if (_selectedTabIndex == 1) {
          // Approved - exclude departed/exited visitors
          filteredVisitors = allVisitors
              .where((v) => 
                v['isApproved'] == true && 
                v['status'] != 'departed' && 
                v['status'] != 'exited' &&
                v['status'] != 'cancelled'
              )
              .toList();
        } else {
          // Deliveries - for now, empty (can be implemented later)
          filteredVisitors = [];
        }

        // Empty state
        if (filteredVisitors.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    _selectedTabIndex == 0
                        ? Icons.pending_outlined
                        : _selectedTabIndex == 1
                            ? Icons.check_circle_outline
                            : Icons.local_shipping_outlined,
                    size: 64,
                    color: const Color(0xFFE5E5E5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedTabIndex == 0
                        ? 'No pending visitors'
                        : _selectedTabIndex == 1
                            ? 'No approved visitors'
                            : 'No deliveries',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA3A3A3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedTabIndex == 0
                        ? 'Add expected visitors using the + button.\nAdmin will approve your requests.'
                        : 'Admin-approved visitors will appear here',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFA3A3A3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Display visitors
        return Column(
          children: filteredVisitors
              .map((visitor) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildVisitorCard(
                      visitor,
                      languageProvider,
                      isPending: _selectedTabIndex == 0,
                      isApproved: _selectedTabIndex == 1,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildVisitorCard(
    Map<String, dynamic> visitor,
    LanguageProvider languageProvider, {
    bool isPending = false,
    bool isApproved = false,
  }) {
    // Extract data from Firestore document
    final visitorId = visitor['id'] as String;
    final visitorName = visitor['visitorName'] as String? ?? 'Unknown';
    final purpose = visitor['purpose'] as String? ?? 'No purpose';
    final expectedArrival = (visitor['expectedArrival'] as Timestamp?)?.toDate();
    final phoneNumber = visitor['phoneNumber'] as String?;
    final vehicleNumber = visitor['vehicleNumber'] as String?;
    
    // Format time
    String timeText = 'No time set';
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
        timeText = '$hour:$minute $period Today';
      } else if (visitDate == today.add(const Duration(days: 1))) {
        timeText = '$hour:$minute $period Tomorrow';
      } else {
        timeText = '$hour:$minute $period ${expectedArrival.day}/${expectedArrival.month}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    visitorName.isNotEmpty
                        ? visitorName[0].toUpperCase()
                        : 'V',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitorName,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      purpose,
                      style: const TextStyle(
                        color: Color(0xFFA3A3A3),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Color(0xFFA3A3A3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: const TextStyle(
                            color: Color(0xFFA3A3A3),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    // Show phone if available
                    if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 14,
                            color: Color(0xFFA3A3A3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phoneNumber,
                            style: const TextStyle(
                              color: Color(0xFFA3A3A3),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Status Badge
              if (isPending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE6EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Awaiting Approval',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              if (isApproved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Approved',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // Action Buttons
          if (isPending) ...[
            const SizedBox(height: 16),
            // Only show Reject button - Admin approves, not user
            _buildRejectButton(visitorId, visitorName),
          ],

          if (isApproved) ...[
            const SizedBox(height: 16),
            _buildViewQRButton(visitor),
          ],
        ],
      ),
    );
  }

  Widget _buildApproveButton(String visitorId, String visitorName) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: () => _approveVisitor(visitorId, visitorName),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Approve',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRejectButton(String visitorId, String visitorName) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () => _rejectVisitor(visitorId, visitorName),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Cancel Request',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          print('🔵 Opening QR screen for visitor ID: $visitorId');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisitorQRScreen(
                visitorId: visitorId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.qr_code_2, size: 20),
        label: const Text(
          'View QR Pass',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2563EB),
          side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
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
          borderRadius: BorderRadius.circular(16),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Future<void> _approveVisitor(String visitorId, String visitorName) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Approve visitor in Firestore
      final result = await _visitorService.approveVisitor(visitorId);

      // Close loading
      if (mounted) Navigator.pop(context);

      if (result.success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$visitorName approved'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to approve visitor'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _rejectVisitor(String visitorId, String visitorName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Visitor Request'),
        content: Text('Are you sure you want to cancel the visitor request for $visitorName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
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
              content: Text('Visitor request for $visitorName cancelled'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to cancel request'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
// This class is reserved for the Deliveries tab feature (Tab 3)
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
