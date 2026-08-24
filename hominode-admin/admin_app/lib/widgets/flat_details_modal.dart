import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'flat_occupancy_grid_modal.dart'; // Import for FlatUnit and FlatStatus
import 'assign_resident_modal.dart';
import 'flat_maintenance_modal.dart';
import 'flat_occupied_modal.dart';
import '../services/user_service.dart';
import '../services/flat_service.dart';
import '../services/building_service.dart';

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
  static Future<void> show(
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
      barrierLabel: 'Close flat details',
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
  final bool _isLoading = false;

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
                      SizedBox(height: 20.h),
                      _buildPrimaryButton(),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 44.w),
            child: Column(
              children: [
                Text(
                  widget.unit.id,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'View and manage flat details, resident information, and status.',
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
              label: 'Close flat details',
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
            Expanded(child: _buildLabel('Floors')),
            SizedBox(width: 16.w),
            Expanded(child: _buildLabel('Flats per Floor')),
          ],
        ),
        SizedBox(height: 16.h),
        // Row 2: Values
        Row(
          children: [
            Expanded(child: _buildValue('Floor ${widget.unit.floor}')),
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
        return 'This flat is currently vacant. You can assign a resident or change its status.';
      case FlatStatus.occupied:
        return 'This flat is currently occupied. View resident details or update information.';
      case FlatStatus.maintenance:
        return 'This flat is under maintenance. Update status when work is complete.';
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
    }
  }

  Future<void> _handlePrimaryAction() async {
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
                // Fetch ALL users from Firestore (assigned + unassigned)
                final users = await widget.userService!
                    .getAllResidentsWithStatus()
                    .first;
                print(
                  '🔵 Fetched ${users.length} users from Firestore (all statuses)',
                );
                return users.map((user) {
                  final isAssigned =
                      user.flatId != null && user.flatId!.isNotEmpty;
                  return ResidentSummary(
                    id: user.id,
                    name: user.name,
                    uniqueId: user.residentId,
                    status: isAssigned
                        ? ResidentStatus.assigned
                        : ResidentStatus.available,
                    flatLabel: user.flatLabel,
                  );
                }).toList();
              }
            : null,
        onAssign: (request) async {
          print('\n🟢 onAssign callback triggered (existing resident)');

          if (widget.userService == null ||
              widget.flatService == null ||
              widget.buildingService == null) {
            print('⚠️  Services not available, using fallback');
            await Future.delayed(const Duration(milliseconds: 800));
            widget.onStatusChange?.call(FlatStatus.occupied);
            if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          }

          try {
            // Get user details
            final user = await widget.userService!.getUserById(
              request.residentId,
            );
            if (user == null) {
              throw Exception('User not found');
            }

            // Assign user to flat in users collection
            await widget.userService!.assignUserToFlat(
              userId: user.id,
              flatId: request.flatId, // Sequential ID (T001, A101, etc.)
              flatLabel: widget.unit.id,
              buildingId: widget.buildingId,
              buildingName: widget.buildingName,
              ownershipType: request.ownershipType,
            );

            // Update flat status in flats collection using Firestore document ID
            await widget.flatService!.assignResident(
              flatId: widget.unit.docId, // Use Firestore document ID
              residentName: user.name,
              residentId: user.id,
            );

            // Sync building occupancy
            if (widget.buildingId != null) {
              await widget.buildingService!.syncOccupancyFromFlats(
                widget.buildingId!,
              );
            }

            // Update flat status to occupied
            widget.onStatusChange?.call(FlatStatus.occupied);

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
          print('  - Password: ${request.generatedPassword}');
          print('  - FlatId: ${request.flatId}');

          if (widget.userService == null ||
              widget.flatService == null ||
              widget.buildingService == null) {
            print('⚠️  Services not available, cannot create resident');
            throw Exception('Services not configured');
          }

          try {
            print('\n🔵 Step 1: Creating resident in Firestore...');
            // Create new resident WITHOUT Firebase Auth (resident creates account on first login)
            final residentUid = await widget.userService!.createUser(
              name: request.name,
              email: request.email,
              phone: request.phone,
              password: request.generatedPassword,
              buildingId: widget.buildingId,
              buildingName: widget.buildingName,
              familyMembers: request.familyMembers,
            );

            print('\n🔵 Step 2: Resident created with UID: $residentUid');
            print('🔵 Now assigning to flat...');

            // Assign resident to flat
            await widget.userService!.assignUserToFlat(
              userId: residentUid,
              flatId: request.flatId,
              flatLabel: widget.unit.id,
              buildingId: widget.buildingId,
              buildingName: widget.buildingName,
              ownershipType: request.ownershipType,
            );

            print('🔵 Step 3: Resident assigned to flat');
            print('🔵 Now updating flat status...');

            // Update flat status
            await widget.flatService!.assignResident(
              flatId: widget
                  .unit
                  .docId, // Use Firestore document ID, not sequential ID
              residentName: request.name,
              residentId: residentUid,
            );

            print('🔵 Step 4: Flat status updated');
            print('🔵 Now syncing building occupancy...');

            // Sync building occupancy
            if (widget.buildingId != null) {
              await widget.buildingService!.syncOccupancyFromFlats(
                widget.buildingId!,
              );
            }

            print('🔵 Step 5: Building occupancy synced');
            print('✅ ALL OPERATIONS COMPLETED SUCCESSFULLY!\n');

            // Update flat status to occupied
            widget.onStatusChange?.call(FlatStatus.occupied);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${request.name} created and assigned to ${widget.unit.id}',
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
                  content: Text('Failed to create and assign resident: $e'),
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
        onStatusChange: (newStatus) {
          // Update flat status
          widget.onStatusChange?.call(newStatus);

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
        onStatusChange: (newStatus) {
          // Update flat status
          widget.onStatusChange?.call(newStatus);

          // Close this modal after status change
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      );
    }
  }
}
