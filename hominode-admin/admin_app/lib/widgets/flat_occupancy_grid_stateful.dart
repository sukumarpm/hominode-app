import 'package:flutter/material.dart';
import 'flat_occupancy_grid_modal.dart';
import 'assign_resident_modal.dart';
import 'flat_maintenance_modal.dart';
import 'flat_occupied_modal.dart';
import '../services/user_service.dart';
import '../services/flat_service.dart';
import '../services/building_service.dart';

/// Stateful wrapper for Flat Occupancy Grid that properly handles status updates
/// This ensures the grid rebuilds and colors update when flat status changes
class FlatOccupancyGridStateful extends StatefulWidget {
  final String towerName;
  final String buildingId;
  final String buildingName;
  final List<FloorOccupancy> initialData;

  const FlatOccupancyGridStateful({
    super.key,
    required this.towerName,
    required this.buildingId,
    required this.buildingName,
    required this.initialData,
  });

  static Future<void> show(
    BuildContext context, {
    required String towerName,
    required String buildingId,
    required String buildingName,
    required List<FloorOccupancy> data,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatOccupancyGridStateful(
          towerName: towerName,
          buildingId: buildingId,
          buildingName: buildingName,
          initialData: data,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FlatOccupancyGridStateful> createState() => _FlatOccupancyGridStatefulState();
}

class _FlatOccupancyGridStatefulState extends State<FlatOccupancyGridStateful> {
  late List<FloorOccupancy> _floorData;
  final UserService _userService = UserService();
  final FlatService _flatService = FlatService();
  final BuildingService _buildingService = BuildingService();

  @override
  void initState() {
    super.initState();
    _floorData = widget.initialData;
  }

  void _handleFlatTap(FlatUnit unit) {
    // DIRECT modal opening based on status - no intermediary
    switch (unit.status) {
      case FlatStatus.vacant:
        // Vacant flats: Open Assign Resident Modal DIRECTLY
        _openAssignResidentModal(unit);
        break;
        
      case FlatStatus.maintenance:
        // Maintenance flats: Open Maintenance Modal DIRECTLY
        _openMaintenanceModal(unit);
        break;
        
      case FlatStatus.occupied:
        // Occupied flats: Open Occupied Details Modal DIRECTLY
        _openOccupiedModal(unit);
        break;
    }
  }

  void _openAssignResidentModal(FlatUnit unit) {
    print('\n🟢 Opening Assign Resident Modal for ${unit.id}');
    
    AssignResidentModal.show(
      context,
      flatId: unit.id,
      flatLabel: unit.id,
      loadResidents: () async {
        print('🟢 Loading residents from Firestore...');
        // Fetch ALL users from Firestore (assigned + unassigned)
        final users = await _userService.getAllResidentsWithStatus().first;
        print('🟢 Loaded ${users.length} residents (all statuses)');
        return users.map((user) {
          final isAssigned = user.flatId != null && user.flatId!.isNotEmpty;
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
      },
      onAssign: (request) async {
        print('\n🟢 onAssign callback triggered');
        try {
          // Get user details
          final user = await _userService.getUserById(request.residentId);
          if (user == null) {
            throw Exception('User not found');
          }
          
          // Assign user to flat in users collection
          await _userService.assignUserToFlat(
            userId: user.id,
            flatId: request.flatId,
            flatLabel: unit.id,
            buildingId: widget.buildingId,
            buildingName: widget.buildingName,
            ownershipType: request.ownershipType,
          );
          
          // Update flat status in flats collection
          await _flatService.assignResident(
            flatId: unit.docId,  // Use Firestore document ID
            residentName: user.name,
            residentId: user.id,
          );
          
          // Sync building occupancy
          await _buildingService.syncOccupancyFromFlats(widget.buildingId);
          
          // Update local state
          _updateFlatStatus(unit.id, FlatStatus.occupied);
          
          if (mounted) {
            Navigator.of(context).pop(); // Close assign modal
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${user.name} assigned to ${unit.id} successfully'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
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
        print('Request data:');
        print('  - Name: ${request.name}');
        print('  - Phone: ${request.phone}');
        print('  - Email: ${request.email}');
        print('  - Password: ${request.generatedPassword}');
        print('  - FlatId: ${request.flatId}');
        
        try {
          print('\n🟢 Calling UserService.createUser()...');
          // Create new resident WITHOUT Firebase Auth (resident creates account on first login)
          final residentUid = await widget.userService.createUser(
            name: request.name,
            email: request.email,
            phone: request.phone,
            password: request.generatedPassword,
            familyMembers: request.familyMembers,
            buildingId: widget.buildingId,
            buildingName: widget.buildingName,
          );
          
          print('\n🟢 Resident created with UID: $residentUid');
          print('🟢 Now assigning to flat...');
          
          // Assign resident to flat
          await widget.userService.assignUserToFlat(
            userId: residentUid,
            flatId: request.flatId,
            flatLabel: unit.id,
            buildingId: widget.buildingId,
            buildingName: widget.buildingName,
            ownershipType: request.ownershipType,
          );
          
          print('🟢 Resident assigned to flat');
          print('🟢 Now updating flat status...');
          
          // Update flat status
          await _flatService.assignResident(
            flatId: unit.docId,  // Use Firestore document ID
            residentName: request.name,
            residentId: residentUid,
          );
          
          print('🟢 Flat status updated');
          print('🟢 Now syncing building occupancy...');
          
          // Sync building occupancy
          await _buildingService.syncOccupancyFromFlats(widget.buildingId);
          
          print('🟢 Building occupancy synced');
          
          // Update local state
          _updateFlatStatus(unit.id, FlatStatus.occupied);
          
          print('✅ ALL OPERATIONS COMPLETED SUCCESSFULLY!\n');
          
          if (mounted) {
            Navigator.of(context).pop(); // Close assign modal
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${request.name} created and assigned to ${unit.id}'),
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
  }

  void _openMaintenanceModal(FlatUnit unit) {
    FlatMaintenanceModal.show(
      context,
      unit: unit,
      onStatusChange: (newStatus) {
        // Update flat status from maintenance to new status
        _updateFlatStatus(unit.id, newStatus);
      },
    );
  }

  void _openOccupiedModal(FlatUnit unit) {
    FlatOccupiedModal.show(
      context,
      unit: unit,
      onStatusChange: (newStatus) {
        // Update flat status (remove resident or change status)
        _updateFlatStatus(unit.id, newStatus);
      },
    );
  }

  void _updateFlatStatus(String flatId, FlatStatus newStatus) {
    setState(() {
      for (var floor in _floorData) {
        for (var flat in floor.flats) {
          if (flat.id == flatId) {
            flat.updateStatus(newStatus);
            print('✅ Flat $flatId status updated to: ${_getStatusName(newStatus)}');
            print('   Color will change to: ${_getColorName(newStatus)}');
            break;
          }
        }
      }
    });
  }

  String _getStatusName(FlatStatus status) {
    switch (status) {
      case FlatStatus.occupied:
        return 'Occupied';
      case FlatStatus.vacant:
        return 'Vacant';
      case FlatStatus.maintenance:
        return 'Maintenance';
    }
  }

  String _getColorName(FlatStatus status) {
    switch (status) {
      case FlatStatus.occupied:
        return 'Green (#10B981)';
      case FlatStatus.vacant:
        return 'Grey (#E5E7EB)';
      case FlatStatus.maintenance:
        return 'Yellow (#FBBF24)';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use FlatOccupancyGridModal but with our stateful data
    return FlatOccupancyGridModal(
      towerName: widget.towerName,
      data: _floorData,
      onFlatTap: _handleFlatTap,
    );
  }
}
