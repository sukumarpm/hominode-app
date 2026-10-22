import 'package:flutter/material.dart';
import 'apartment_images_management_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'desktop/admin_desktop_page_frame.dart';
import 'services/building_service.dart';
import 'services/flat_service.dart';
import 'services/user_service.dart';
import 'widgets/add_building_modal.dart';
import 'widgets/building_deletion_dialog.dart';
import 'widgets/assign_resident_modal.dart';
import 'widgets/flat_details_modal.dart';
import 'widgets/flat_occupancy_grid_modal.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/standard_header.dart';

class ManageBuildingsPage extends StatefulWidget {
  const ManageBuildingsPage({super.key});

  @override
  State<ManageBuildingsPage> createState() => _ManageBuildingsPageState();
}

class _ManageBuildingsPageState extends State<ManageBuildingsPage> {
  final BuildingService _buildingService = BuildingService();
  final FlatService _flatService = FlatService();
  final UserService _userService = UserService();

  Future<void> _addNewBuilding(BuildingInput buildingInput) async {
    try {
      await _buildingService.addBuilding(
        name: buildingInput.name,
        floors: buildingInput.floors,
        flatsPerFloor: buildingInput.flatsPerFloor,
        totalFlats: buildingInput.totalFlats,
        flatBhkConfig: buildingInput.flatBhkConfig,
        structureType: buildingInput.structureType,
        unitType: buildingInput.unitType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Building ${buildingInput.name} added successfully'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add building: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _editBuilding(String id, BuildingInput buildingInput) async {
    await _buildingService.updateBuilding(
      id: id,
      name: buildingInput.name,
      floors: buildingInput.floors,
      flatsPerFloor: buildingInput.flatsPerFloor,
      totalFlats: buildingInput.totalFlats,
      flatBhkConfig: buildingInput.flatBhkConfig,
      structureType: buildingInput.structureType,
      unitType: buildingInput.unitType,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Building ${buildingInput.name} updated successfully'),
          backgroundColor: const Color(0xFF0E4778),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _deletionOpen = false;

  Future<void> _deleteBuilding(String id, String name) async {
    if (_deletionOpen) return;
    _deletionOpen = true;
    try {
      final deleted = await showBuildingDeletionDialog(
        context: context,
        buildingName: name,
        validate: () => _buildingService.validateBuildingDeletion(id),
        delete: () => _buildingService.deleteBuilding(id),
      );
      if (deleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Building $name deleted successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      _deletionOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Buildings & Flats',
        subtitle: 'Manage community buildings, flats, and occupancy.',
        actions: [
          AdminDesktopPrimaryAction(
            label: 'Add Building',
            icon: Icons.add_business_outlined,
            onPressed: () =>
                AddBuildingModal.show(context, onSave: _addNewBuilding),
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildBuildingsList(), const SizedBox(height: 24)],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Manage Buildings'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleRow(),
                SizedBox(height: 16.h),
                _buildBuildingsList(),
                SizedBox(height: 80.h),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 1),
    );
  }

  Widget _buildTitleRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Building Management',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              AddBuildingModal.show(context, onSave: _addNewBuilding);
            },
            icon: Icon(Icons.add, size: 18.w),
            label: const Text('Add Building'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              textStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingsList() {
    return StreamBuilder<List<BuildingModel>>(
      stream: _buildingService.getBuildings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading buildings: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14.sp),
                  ),
                ],
              ),
            ),
          );
        }

        final buildings = snapshot.data ?? [];

        if (buildings.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                children: [
                  Icon(Icons.apartment, size: 64.w, color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Text(
                    'No buildings yet',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Add your first building to get started',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        if (AdminDesktopPresentationScope.isActive(context)) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1180 ? 3 : 2;
              const spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: buildings
                    .map(
                      (building) => SizedBox(
                        width: itemWidth,
                        child: _buildBuildingCard(building),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          );
        }

        return Column(
          children: buildings.map(_buildBuildingCard).toList(growable: false),
        );
      },
    );
  }

  Widget _buildBuildingCard(BuildingModel building) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(building),
          SizedBox(height: 16.h),
          _buildStatsRow(building),
          SizedBox(height: 16.h),
          _buildOccupancyBar(building),
          SizedBox(height: 16.h),
          _buildActionIcons(building),
        ],
      ),
    );
  }

  Widget _buildCardHeader(BuildingModel building) {
    return Row(
      children: [
        Container(
          width: 56.w,
          height: 56.h,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Icons.apartment, color: Color(0xFF0E4778), size: 28.w),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                building.name,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                building.structureType.usesFloors
                    ? '${building.floors} Floors • ${building.flatsPerFloor} Units/Floor'
                    : building.structureType.label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcons(BuildingModel building) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuildingPhotoManagementButton(buildingId: building.id),
        SizedBox(height: 4.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Manage units',
              constraints: const BoxConstraints.tightFor(
                width: kMinInteractiveDimension,
                height: kMinInteractiveDimension,
              ),
              onPressed: () => _showFlatOccupancyGrid(building),
              icon: const Icon(Icons.grid_view),
            ),
            IconButton(
              tooltip: 'Edit building',
              constraints: const BoxConstraints.tightFor(
                width: kMinInteractiveDimension,
                height: kMinInteractiveDimension,
              ),
              onPressed: () => _handleEditBuilding(building),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete building',
              constraints: const BoxConstraints.tightFor(
                width: kMinInteractiveDimension,
                height: kMinInteractiveDimension,
              ),
              color: const Color(0xFFEF4444),
              onPressed: () => _deleteBuilding(building.id, building.name),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    );
  }

  bool _isOpeningBuildingEdit = false;

  Future<void> _handleEditBuilding(BuildingModel building) async {
    if (_isOpeningBuildingEdit) return;
    _isOpeningBuildingEdit = true;
    try {
      final flats = await _flatService.getFlatsForBuildingFromServer(
        building.id,
      );
      if (!mounted) return;
      await AddBuildingModal.show(
        context,
        existingBuilding: building,
        existingFlats: flats,
        onSave: (updatedBuilding) =>
            _editBuilding(building.id, updatedBuilding),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load building units: $error')),
        );
      }
    } finally {
      _isOpeningBuildingEdit = false;
    }
  }

  List<FloorOccupancy> _toFloorOccupancy(List<FlatModel> flats) {
    final floorMap = <int, List<FlatUnit>>{};

    for (final flat in flats) {
      floorMap.putIfAbsent(
        flat.usesFloors ? flat.floor : 0,
        () => <FlatUnit>[],
      );

      floorMap[flat.usesFloors ? flat.floor : 0]!.add(
        FlatUnit(
          id: flat.flatId ?? flat.id,
          docId: flat.id,
          type: flat.type,
          unitType: flat.unitType,
          unitIndex: flat.unitIndex,
          residentName: flat.residentName,
          residentUserId: flat.residentUserId,
          reservedOnboardingId: flat.reservedOnboardingId,
          reservedForName: flat.reservedForName,
          reservedResidentType: flat.reservedResidentType,
          status: _getFlatStatus(flat.status),
          floor: flat.floor,
          area: flat.area,
        ),
      );
    }

    final result = floorMap.entries
        .map(
          (entry) => FloorOccupancy(floorNumber: entry.key, flats: entry.value),
        )
        .toList();

    result.sort((a, b) => b.floorNumber.compareTo(a.floorNumber));

    return result;
  }

  void _showFlatOccupancyGrid(BuildingModel building) {
    final occupancyStream = _flatService
        .getFlatsForBuilding(building.id)
        .map(_toFloorOccupancy);

    FlatOccupancyGridModal.show(
      context,
      towerName: building.name,
      dataStream: occupancyStream,
      onFlatTap: (unit) async {
        await FlatDetailsModal.show(
          context,
          unit: unit,
          userService: _userService,
          flatService: _flatService,
          buildingService: _buildingService,
          buildingId: building.id,
          buildingName: building.name,

          onAssignResident: () async {
            final latestFlat = await _flatService.getFlatFromServer(unit.docId);

            if (latestFlat == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unable to verify the unit. Please try again.',
                    ),
                  ),
                );
              }
              return;
            }

            final isSafelyVacant =
                latestFlat.status == 'vacant' &&
                latestFlat.reservedOnboardingId == null &&
                latestFlat.residentUserId == null;

            if (!isSafelyVacant) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      latestFlat.status == 'reserved'
                          ? 'This unit is already reserved.'
                          : 'This unit is no longer available.',
                    ),
                  ),
                );
              }
              return;
            }

            Navigator.of(context).pop();

            await AssignResidentModal.show(
              context,
              flatId: unit.id,
              flatLabel: unit.id,

              loadResidents: () async {
                final users = await _userService.getAvailableUsers().first;

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

                final onboardings = await _userService
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

                return [...registeredResidents, ...pendingResidents];
              },

              onAssign: (request) async {
                if (request.source == ResidentSource.onboarding) {
                  await _userService.assignOnboardingToFlat(
                    onboardingId: request.residentId,
                    buildingId: building.id,
                    flatId: unit.docId,
                  );

                  return;
                }

                final user = await _userService.getUserById(request.residentId);

                if (user == null) {
                  throw Exception('User not found');
                }

                await _userService.assignUserToFlat(
                  userId: user.id,
                  flatId: unit.docId,
                  flatLabel: unit.id,
                  buildingId: building.id,
                  buildingName: building.name,
                  ownershipType: request.ownershipType,
                );
              },

              onAssignNew: (request) async {
                try {
                  await _userService.createUser(
                    name: request.name,
                    email: request.email,
                    phone: request.phone,
                    residentType: request.ownershipType,
                    familyMembers: request.familyMembers,
                    buildingId: building.id,
                    buildingName: building.name,
                    unitReference: request.flatId,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${request.name} onboarding created. '
                          'Unit assignment waits for OTP registration '
                          'and Admin approval.',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  rethrow;
                }
              },
            );
          },

          onStatusChange: (newStatus) async {
            final hasResidentPointer =
                unit.residentUserId?.trim().isNotEmpty == true;

            if (unit.status == FlatStatus.occupied ||
                unit.status == FlatStatus.reserved ||
                hasResidentPointer) {
              if (newStatus == FlatStatus.occupied) {
                return;
              }

              throw StateError(
                'Resident-linked units can change occupancy '
                'only through explicit resident lifecycle actions.',
              );
            }

            String statusString;

            switch (newStatus) {
              case FlatStatus.vacant:
                statusString = 'vacant';
                break;

              case FlatStatus.reserved:
                throw StateError(
                  'A unit can be reserved only through '
                  'resident onboarding assignment.',
                );

              case FlatStatus.occupied:
                throw StateError(
                  'Assign a resident through the trusted '
                  'assignment flow.',
                );

              case FlatStatus.maintenance:
                statusString = 'maintenance';
                break;
            }

            await _flatService.updateFlatStatus(
              flatDocumentId: unit.docId,
              buildingId: building.id,
              status: statusString,
            );

            await _buildingService.syncOccupancyFromFlats(building.id);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Unit ${unit.id} status updated to '
                    '$statusString',
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }

  FlatStatus _getFlatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return FlatStatus.occupied;
      case 'reserved':
        return FlatStatus.reserved;
      case 'maintenance':
        return FlatStatus.maintenance;
      case 'vacant':
        return FlatStatus.vacant;
      default:
        return FlatStatus.maintenance;
    }
  }

  Widget _buildStatsRow(BuildingModel building) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            label: 'Total Units',
            value: building.totalFlats.toString(),
            bgColor: const Color(0xFFECFDF3),
            textColor: const Color(0xFF15803D),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildStatChip(
            label: 'Occupied',
            value: building.occupied.toString(),
            bgColor: const Color(0xFFEFF6FF),
            textColor: const Color(0xFF0E4778),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildStatChip(
            label: 'Vacant',
            value: building.vacant.toString(),
            bgColor: const Color(0xFFFEF9C3),
            textColor: const Color(0xFFA16207),
          ),
        ),
        Expanded(
          child: _buildStatChip(
            label: 'Reserved',
            value: building.reserved.toString(),
            bgColor: const Color(0xFFFFF4E5),
            textColor: const Color(0xFF92400E),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyBar(BuildingModel building) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Occupancy Rate',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${building.occupancyRate}%',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0E4778),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(999.r),
          child: LinearProgressIndicator(
            value: building.occupancyRate / 100,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0E4778)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class BuildingPhotoManagementButton extends StatelessWidget {
  const BuildingPhotoManagementButton({
    super.key,
    required this.buildingId,
    this.destinationBuilder,
  });

  final String buildingId;
  final Widget Function(BuildContext context, String buildingId)?
  destinationBuilder;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) =>
            destinationBuilder?.call(routeContext, buildingId) ??
            ApartmentImagesManagementScreen(buildingId: buildingId),
      ),
    ),
    icon: const Icon(Icons.photo_library_outlined),
    label: const Text('Manage Photos'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, kMinInteractiveDimension),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      foregroundColor: const Color(0xFF0E4778),
      side: const BorderSide(color: Color(0xFF0E4778)),
    ),
  );
}
