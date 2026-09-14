import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/building_service.dart';
import '../services/flat_service.dart';
import '../services/user_service.dart';
import 'assign_resident_modal.dart';
import 'flat_maintenance_modal.dart';
import 'flat_occupancy_grid_modal.dart'; // Import for FlatUnit and FlatStatus
import 'flat_occupied_modal.dart';

/// Pixel-perfect "Flat Details – Vacant" overlay modal
/// Opens when admin taps a vacant flat tile in the Flat Occupancy Grid
class FlatDetailsModal extends StatefulWidget {
  final FlatUnit unit;
  final VoidCallback? onAssignResident;
  final Function(FlatStatus newStatus)? onStatusChange;
  final UserService? userService;
  final FlatService? flatService;
  final BuildingService? buildingService;
  final String? buildingId;
  final String? buildingName;

  const FlatDetailsModal({
    super.key,
    required this.unit,
    this.onAssignResident,
    this.onStatusChange,
    this.userService,
    this.flatService,
    this.buildingService,
    this.buildingId,
    this.buildingName,
  });

  /// Show the modal with fade-in and scale animation
  static Future<bool?> show(
    BuildContext context, {
    required FlatUnit unit,
    VoidCallback? onAssignResident,
    Function(FlatStatus newStatus)? onStatusChange,
    UserService? userService,
    FlatService? flatService,
    BuildingService? buildingService,
    String? buildingId,
    String? buildingName,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close unit details',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatDetailsModal(
          unit: unit,
          onAssignResident: onAssignResident,
          onStatusChange: onStatusChange,
          userService: userService,
          flatService: flatService,
          buildingService: buildingService,
          buildingId: buildingId,
          buildingName: buildingName,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FlatDetailsModal> createState() => _FlatDetailsModalState();
}

class _FlatDetailsModalState extends State<FlatDetailsModal> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
          maxHeight: screenHeight * 0.85,
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          elevation: 8,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailsGrid(),
                      SizedBox(height: 24.h),
                      _buildInfoBanner(),

                      if (widget.unit.status == FlatStatus.reserved) ...[
                        SizedBox(height: 20.h),
                        _buildReservationDetails(),
                        SizedBox(height: 20.h),
                        _buildCancelReservationButton(),
                      ],

                      if (widget.unit.status != FlatStatus.reserved) ...[
                        SizedBox(height: 20.h),
                        _buildPrimaryButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelReservationButton() {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _confirmCancelReservation,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB91C1C),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFB91C1C),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel_outlined),
                  SizedBox(width: 8.w),
                  Text(
                    'Cancel Reservation',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmCancelReservation() async {
    final onboardingId = widget.unit.reservedOnboardingId?.trim();

    if (onboardingId == null || onboardingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation information is incomplete. Cancellation was not performed.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final residentName = widget.unit.reservedForName?.trim().isNotEmpty == true
        ? widget.unit.reservedForName!.trim()
        : 'this resident';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Reservation?'),
          content: Text(
            '$residentName\'s reservation for ${widget.unit.id} will be cancelled. '
            'The unit will become vacant and the resident will remain available for reassignment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Reservation'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Reservation'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _cancelReservation(onboardingId);
  }

  Future<void> _cancelReservation(String onboardingId) async {
    if (widget.userService == null ||
        widget.buildingId == null ||
        widget.buildingId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation service is unavailable. No changes were made.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔴 CANCEL RESERVATION PAYLOAD');
      debugPrint('   onboardingId: $onboardingId');
      debugPrint('   buildingId: ${widget.buildingId}');
      debugPrint('   unit.id: ${widget.unit.id}');
      debugPrint('   unit.docId: ${widget.unit.docId}');
      debugPrint(
        '   reservedOnboardingId: ${widget.unit.reservedOnboardingId}',
      );
      debugPrint('   reservedForName: ${widget.unit.reservedForName}');
      debugPrint('   unit.status: ${widget.unit.status}');
      await widget.userService!.cancelResidentOnboardingReservation(
        onboardingId: onboardingId,
        buildingId: widget.buildingId!.trim(),
        flatId: widget.unit.docId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reservation for ${widget.unit.id} cancelled successfully.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel reservation: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _editUnitName() async {
    if (widget.flatService == null ||
        widget.buildingId == null ||
        widget.buildingId!.trim().isEmpty) {
      return;
    }

    final controller = TextEditingController(text: widget.unit.id);

    final newLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Unit Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Unit Name',
              hintText: 'Example: A-101, Villa-03',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newLabel == null || newLabel.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.flatService!.renameUnit(
        flatDocumentId: widget.unit.docId,
        buildingId: widget.buildingId!,
        newLabel: newLabel,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit renamed to ${newLabel.trim()} successfully.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildReservationDetails() {
    final name = widget.unit.reservedForName?.trim();
    final residentType = widget.unit.reservedResidentType?.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reservation Details',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9A3412),
            ),
          ),
          SizedBox(height: 14.h),

          _buildReservationRow(
            'Reserved For',
            name?.isNotEmpty == true ? name! : 'Pending resident',
          ),

          if (residentType?.isNotEmpty == true) ...[
            SizedBox(height: 10.h),
            _buildReservationRow(
              'Resident Type',
              _formatResidentType(residentType!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReservationRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF78716C),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF292524),
            ),
          ),
        ),
      ],
    );
  }

  String _formatResidentType(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 44.w),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.unit.id,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      tooltip: 'Edit unit name',
                      onPressed: _isLoading ? null : _editUnitName,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  'View and manage unit details, resident information, and status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Semantics(
              label: 'Close unit details',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22.r),
                child: Container(
                  width: 44.w,
                  height: 44.h,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 22.w,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Column(
      children: [
        // Row 1: Labels
        Row(
          children: [
            Expanded(
              child: _buildLabel(
                widget.unit.usesFloors ? 'Floor' : 'Unit Type',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(child: _buildLabel('Configuration')),
          ],
        ),
        SizedBox(height: 16.h),
        // Row 2: Values
        Row(
          children: [
            Expanded(
              child: _buildValue(
                widget.unit.usesFloors
                    ? 'Floor ${widget.unit.floor}'
                    : widget.unit.unitType.label,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(child: _buildValue(widget.unit.type)),
          ],
        ),
        SizedBox(height: 24.h),
        // Row 3: Labels
        Row(
          children: [
            Expanded(child: _buildLabel('Area')),
            SizedBox(width: 16.w),
            Expanded(child: _buildLabel('Status')),
          ],
        ),
        SizedBox(height: 16.h),
        // Row 4: Values
        Row(
          children: [
            Expanded(child: _buildValue(widget.unit.area)),
            SizedBox(width: 16.w),
            Expanded(child: _buildStatusPill()),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildValue(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildStatusPill() {
    // TODO: Support dynamic status colors and labels for occupied/maintenance
    final statusText = _getStatusText(widget.unit.status);
    final backgroundColor = _getStatusBackgroundColor(widget.unit.status);
    final textColor = _getStatusTextColor(widget.unit.status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  String _getStatusText(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return 'Vacant';
      case FlatStatus.occupied:
        return 'Occupied';
      case FlatStatus.maintenance:
        return 'Maintenance';
      case FlatStatus.reserved:
        return 'Reserved';
    }
  }

  Color _getStatusBackgroundColor(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return const Color(0xFFD1D5DB);
      case FlatStatus.occupied:
        return const Color(0xFF10B981);
      case FlatStatus.maintenance:
        return const Color(0xFFFBBF24);
      case FlatStatus.reserved:
        return const Color(0xFF3B82F6); // Blue color for reserved flats
    }
  }

  Color _getStatusTextColor(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return const Color(0xFF374151);
      case FlatStatus.occupied:
        return Colors.white;
      case FlatStatus.maintenance:
        return const Color(0xFF78350F);
      case FlatStatus.reserved:
        return Colors.white;
    }
  }

  Widget _buildInfoBanner() {
    // TODO: Make banner text dynamic based on status
    final bannerText = _getBannerText(widget.unit.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        bannerText,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0E4778),
          height: 1.5,
        ),
      ),
    );
  }

  String _getBannerText(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return 'This unit is currently vacant. You can assign a resident or change its status.';
      case FlatStatus.occupied:
        return 'This unit is currently occupied. View resident details or update information.';
      case FlatStatus.maintenance:
        return 'This unit is under maintenance. Update status when work is complete.';
      case FlatStatus.reserved:
        final residentName = widget.unit.reservedForName?.trim();

        if (residentName != null && residentName.isNotEmpty) {
          return 'This unit is reserved for $residentName. The resident onboarding is still pending.';
        }

        return 'This unit is reserved for a pending resident onboarding.';
    }
  }

  Widget _buildPrimaryButton() {
    final buttonLabel = _getButtonLabel(widget.unit.status);

    return Semantics(
      label: buttonLabel,
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56.h,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handlePrimaryAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0E4778),
            disabledBackgroundColor: const Color(0x662563EB), // 40% opacity
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24.w,
                  height: 24.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  buttonLabel,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  String _getButtonLabel(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return 'Assign Resident';
      case FlatStatus.maintenance:
        return 'Update Status';
      case FlatStatus.occupied:
        return 'View Details';
      case FlatStatus.reserved:
        return 'Reserved';
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (widget.unit.status == FlatStatus.reserved) {
      throw StateError(
        'Reserved units cannot be assigned or manually changed.',
      );
    }
    if (widget.unit.status == FlatStatus.vacant) {
      // ONLY vacant flats can assign residents
      print('\n🟡 FlatDetailsModal: Opening AssignResidentModal');
      print('   - FlatId: ${widget.unit.id}');
      print('   - DocId: ${widget.unit.docId}');
      print('   - Has UserService: ${widget.userService != null}');
      print('   - Has FlatService: ${widget.flatService != null}');
      print('   - Has BuildingService: ${widget.buildingService != null}');
      print('   - BuildingId: ${widget.buildingId}');

      await AssignResidentModal.show(
        context,
        flatId: widget.unit.id,
        flatLabel: widget.unit.id,
        loadResidents: widget.userService != null
            ? () async {
                print('\n🔵 loadResidents callback triggered');

                final users = await widget.userService!
                    .getAvailableUsers()
                    .first;

                final registeredResidents = users.map((user) {
                  return ResidentSummary(
                    id: user.id,
                    name: user.name,
                    uniqueId: user.residentId,
                    status: ResidentStatus.available,
                    flatLabel: user.flatLabel,
                    source: ResidentSource.registered,
                    residentType: user.ownershipType,
                  );
                }).toList();

                final onboardings = await widget.userService!
                    .getUnassignedPendingOnboardings();

                final pendingResidents = onboardings.map((resident) {
                  return ResidentSummary(
                    id: resident.id,
                    name: resident.name,
                    uniqueId: resident.phone,
                    status: ResidentStatus.pendingRegistration,
                    source: ResidentSource.onboarding,
                    residentType: resident.residentType,
                  );
                }).toList();

                print(
                  '🔵 Loaded ${registeredResidents.length} registered '
                  'and ${pendingResidents.length} pending residents',
                );

                return [...registeredResidents, ...pendingResidents];
              }
            : null,
        onAssign: (request) async {
          print('\n🟢 onAssign callback triggered');

          if (widget.userService == null) {
            throw StateError(
              'Resident assignment service is unavailable. '
              'No unit status was changed.',
            );
          }

          if (widget.buildingId == null || widget.buildingId!.trim().isEmpty) {
            throw StateError(
              'Building is unavailable for resident assignment.',
            );
          }

          try {
            if (request.source == ResidentSource.onboarding) {
              await widget.userService!.assignOnboardingToFlat(
                onboardingId: request.residentId,
                buildingId: widget.buildingId!,
                flatId: widget.unit.docId,
              );
              return;
            }

            final user = await widget.userService!.getUserById(
              request.residentId,
            );

            if (user == null) {
              throw Exception('User not found');
            }

            await widget.userService!.assignUserToFlat(
              userId: user.id,
              flatId: widget.unit.docId,
              flatLabel: widget.unit.id,
              buildingId: widget.buildingId,
              buildingName: widget.buildingName,
              ownershipType: request.ownershipType,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${user.name} assigned to ${widget.unit.id} successfully',
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            }
          } catch (e) {
            print('❌ Error in onAssign: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to assign resident: $e'),
                  backgroundColor: const Color(0xFFEF4444),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            rethrow;
          }
        },
        onAssignNew: (request) async {
          print('\n🟢 onAssignNew callback triggered!');
          print('🟢 Calling UserService.createUser()...');
          print('Request data:');
          print('  - Name: ${request.name}');
          print('  - Phone: ${request.phone}');
          print('  - Email: ${request.email}');
          print('  - FlatId: ${request.flatId}');

          if (widget.userService == null ||
              widget.flatService == null ||
              widget.buildingService == null) {
            print('⚠️  Services not available, cannot create resident');
            throw Exception('Services not configured');
          }

          try {
            await widget.userService!.createUser(
              name: request.name,
              email: request.email,
              phone: request.phone,
              residentType: request.ownershipType,
              buildingId: widget.buildingId,
              buildingName: widget.buildingName,
              unitReference: request.flatId,
              familyMembers: request.familyMembers,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${request.name} onboarding created. Unit assignment waits for OTP registration and Admin approval.',
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 3),
                ),
              );
              Navigator.of(context).pop();
            }
          } catch (e, stackTrace) {
            print('\n❌ ERROR in onAssignNew callback!');
            print('Error: $e');
            print('Stack trace: $stackTrace');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to create resident onboarding: $e'),
                  backgroundColor: const Color(0xFFEF4444),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            rethrow;
          }
        },
      );
    } else if (widget.unit.status == FlatStatus.maintenance) {
      // Maintenance flats can change status
      await FlatMaintenanceModal.show(
        context,
        unit: widget.unit,
        onStatusChange: (newStatus) async {
          // Update flat status
          await widget.onStatusChange?.call(newStatus);

          // Close this modal after status change
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      );
    } else if (widget.unit.status == FlatStatus.occupied) {
      // Occupied flats show detailed resident information
      await FlatOccupiedModal.show(
        context,
        unit: widget.unit,
        onStatusChange: (newStatus) async {
          // Update flat status
          await widget.onStatusChange?.call(newStatus);

          // Close this modal after status change
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      );
    }
  }
}
