import 'package:flutter/material.dart';

import 'services/building_service.dart';
import 'services/flat_service.dart';
import 'services/user_service.dart';
import 'widgets/add_building_modal.dart';
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
    try {
      await _buildingService.updateBuilding(
        id: id,
        name: buildingInput.name,
        floors: buildingInput.floors,
        flatsPerFloor: buildingInput.flatsPerFloor,
        totalFlats: buildingInput.totalFlats,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Building ${buildingInput.name} updated successfully',
            ),
            backgroundColor: const Color(0xFF2563EB),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update building: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteBuilding(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text(
          'Are you sure you want to delete $name? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _buildingService.deleteBuilding(id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Building $name deleted successfully'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete building: $e'),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 16),
                _buildBuildingsList(),
                const SizedBox(height: 80),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Building Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              AddBuildingModal.show(context, onSave: _addNewBuilding);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Building'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading buildings: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
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
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.apartment, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No buildings yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your first building to get started',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: buildings.map((building) {
            return _buildBuildingCard(building);
          }).toList(),
        );
      },
    );
  }

  Widget _buildBuildingCard(BuildingModel building) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 16),
          _buildStatsRow(building),
          const SizedBox(height: 16),
          _buildOccupancyBar(building),
        ],
      ),
    );
  }

  Widget _buildCardHeader(BuildingModel building) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.apartment,
            color: Color(0xFF2563EB),
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                building.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${building.floors} Floors • ${building.flatsPerFloor} Flats/Floor',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        _buildActionIcons(building),
      ],
    );
  }

  Widget _buildActionIcons(BuildingModel building) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(Icons.grid_view, const Color(0xFF9CA3AF), () {
          _showFlatOccupancyGrid(building);
        }),
        const SizedBox(width: 8),
        _buildIconButton(Icons.edit_outlined, const Color(0xFF9CA3AF), () {
          _handleEditBuilding(building);
        }),
        const SizedBox(width: 8),
        _buildIconButton(Icons.delete_outline, const Color(0xFFEF4444), () {
          _deleteBuilding(building.id, building.name);
        }),
      ],
    );
  }

  void _handleEditBuilding(BuildingModel building) {
    AddBuildingModal.show(
      context,
      existingBuilding: building,
      onSave: (updatedBuilding) => _editBuilding(building.id, updatedBuilding),
    );
  }

  void _showFlatOccupancyGrid(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Load real flat data from Firestore
    _flatService
        .getFlatsForBuilding(building.id)
        .first
        .then((flats) {
          Navigator.pop(context); // Close loading

          if (flats.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No flats found for this building'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
            return;
          }

          // Convert to FloorOccupancy format
          final floorMap = <int, List<FlatUnit>>{};

          for (var flat in flats) {
            if (!floorMap.containsKey(flat.floor)) {
              floorMap[flat.floor] = [];
            }

            floorMap[flat.floor]!.add(
              FlatUnit(
                id:
                    flat.flatId ??
                    flat.id, // Use flatId (A001, A002, etc.) if available, fallback to document ID
                docId: flat.id, // Store the Firestore document ID
                type: flat.type,
                residentName: flat.residentName,
                status: _getFlatStatus(flat.status),
                floor: flat.floor,
                area: flat.area,
              ),
            );
          }

          // Convert to list and sort by floor descending
          final floorOccupancy =
              floorMap.entries
                  .map(
                    (entry) => FloorOccupancy(
                      floorNumber: entry.key,
                      flats: entry.value,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.floorNumber.compareTo(a.floorNumber));

          FlatOccupancyGridModal.show(
            context,
            towerName: building.name,
            data: floorOccupancy,
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
                  Navigator.of(context).pop(); // Close flat details modal

                  // Show assign resident modal with real data
                  await AssignResidentModal.show(
                    context,
                    flatId: unit.id,
                    flatLabel: unit.id,
                    loadResidents: () async {
                      // Fetch real users from Firestore
                      final users = await _userService
                          .getAvailableUsers()
                          .first;
                      return users.map((user) {
                        return ResidentSummary(
                          id: user.id,
                          name: user.name,
                          uniqueId: user.residentId,
                          status: user.isAssigned
                              ? ResidentStatus.assigned
                              : ResidentStatus.available,
                          flatLabel: user.flatLabel,
                        );
                      }).toList();
                    },
                    onAssign: (request) async {
                      try {
                        // Get user details
                        final user = await _userService.getUserById(
                          request.residentId,
                        );
                        if (user == null) {
                          throw Exception('User not found');
                        }

                        // Assign user to flat in users collection
                        await _userService.assignUserToFlat(
                          userId: user.id,
                          flatId: request.flatId,
                          flatLabel: unit.id,
                          buildingId: building.id,
                          buildingName: building.name,
                          ownershipType: request.ownershipType,
                        );

                        // Update flat status in flats collection
                        await _flatService.assignResident(
                          flatId: unit.docId, // Use Firestore document ID
                          residentName: user.name,
                          residentId: user.id,
                        );

                        // Sync building occupancy
                        await _buildingService.syncOccupancyFromFlats(
                          building.id,
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${user.name} assigned to ${unit.id} successfully',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
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
                      print('\n🔵 onAssignNew callback triggered!');
                      print('Request data:');
                      print('  - Name: ${request.name}');
                      print('  - Phone: ${request.phone}');
                      print('  - Email: ${request.email}');
                      print('  - Password: ${request.generatedPassword}');
                      print('  - FlatId: ${request.flatId}');
                      print('  - BuildingId: ${building.id}');
                      print('  - BuildingName: ${building.name}');

                      try {
                        print(
                          '\n🔵 Calling UserService.createUser() with building details...',
                        );
                        // Create new resident WITHOUT Firebase Auth (resident creates account on first login)
                        final residentUid = await _userService.createUser(
                          name: request.name,
                          email: request.email,
                          phone: request.phone,
                          password: request.generatedPassword,
                          familyMembers: request.familyMembers,
                          buildingId: building.id,
                          buildingName: building.name,
                        );

                        print('\n🔵 Resident created with UID: $residentUid');
                        print('🔵 Resident stored with:');
                        print(
                          '   - Admin details (adminId, adminName, adminEmail, adminPhone, organization)',
                        );
                        print(
                          '   - Building details (buildingId: ${building.id}, buildingName: ${building.name})',
                        );
                        print('🔵 Now assigning to flat...');

                        // Assign resident to flat
                        await _userService.assignUserToFlat(
                          userId: residentUid,
                          flatId: request.flatId,
                          flatLabel: unit.id,
                          buildingId: building.id,
                          buildingName: building.name,
                          ownershipType: request.ownershipType,
                        );

                        print('🔵 Resident assigned to flat');
                        print('🔵 Now updating flat status...');

                        // Update flat status
                        await _flatService.assignResident(
                          flatId: unit.docId, // Use Firestore document ID
                          residentName: request.name,
                          residentId: residentUid,
                        );

                        print('🔵 Flat status updated');
                        print('🔵 Now syncing building occupancy...');

                        // Sync building occupancy
                        await _buildingService.syncOccupancyFromFlats(
                          building.id,
                        );

                        print('🔵 Building occupancy synced');
                        print('✅ ALL OPERATIONS COMPLETED SUCCESSFULLY!');
                        print(
                          '✅ Resident stored with complete admin + building + flat details\n',
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${request.name} created and assigned to ${unit.id}',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e, stackTrace) {
                        print('\n❌ ERROR in onAssignNew callback!');
                        print('Error: $e');
                        print('Stack trace: $stackTrace');

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to create and assign resident: $e',
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                        rethrow;
                      }
                    },
                  );
                },
                onStatusChange: (newStatus) async {
                  try {
                    // Update flat status in Firestore
                    String statusString;
                    switch (newStatus) {
                      case FlatStatus.vacant:
                        statusString = 'vacant';
                        // Remove resident if changing to vacant
                        if (unit.status == FlatStatus.occupied) {
                          await _flatService.removeResident(unit.docId);
                          // Also remove flat assignment from user
                          // Find user by flatId and remove assignment
                          final users = await _userService.getUsers().first;
                          final assignedUser = users.firstWhere(
                            (u) => u.flatId == unit.id,
                            orElse: () => throw Exception('User not found'),
                          );
                          await _userService.removeUserFromFlat(
                            assignedUser.id,
                          );
                        }
                        break;
                      case FlatStatus.occupied:
                        statusString = 'occupied';
                        break;
                      case FlatStatus.maintenance:
                        statusString = 'maintenance';
                        break;
                    }

                    await _flatService.updateFlatStatus(
                      flatId: unit.id,
                      status: statusString,
                    );

                    // Sync building occupancy
                    await _buildingService.syncOccupancyFromFlats(building.id);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Flat ${unit.id} status updated to $statusString',
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update flat status: $e'),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        })
        .catchError((error) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load flats: $error'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        });
  }

  FlatStatus _getFlatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return FlatStatus.occupied;
      case 'maintenance':
        return FlatStatus.maintenance;
      default:
        return FlatStatus.vacant;
    }
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildStatsRow(BuildingModel building) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            label: 'Total Flats',
            value: building.totalFlats.toString(),
            bgColor: const Color(0xFFECFDF3),
            textColor: const Color(0xFF15803D),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
            label: 'Occupied',
            value: building.occupied.toString(),
            bgColor: const Color(0xFFEFF6FF),
            textColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
            label: 'Vacant',
            value: building.vacant.toString(),
            bgColor: const Color(0xFFFEF9C3),
            textColor: const Color(0xFFA16207),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
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
            const Text(
              'Occupancy Rate',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${building.occupancyRate}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: building.occupancyRate / 100,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
