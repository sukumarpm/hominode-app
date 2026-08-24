import 'package:flutter/material.dart';
import '../models/family_member.dart';
import '../models/vehicle.dart';
import '../widgets/family_card.dart';
import '../widgets/vehicle_card.dart';
import '../modals/add_edit_member_modal.dart';
import '../modals/add_edit_vehicle_modal.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../components/app_segmented_control.dart';
import '../components/standard_screen.dart';
import '../services/family_firestore_service.dart';
import '../services/vehicle_firestore_service.dart';

class FamilyVehiclesScreen extends StatefulWidget {
  const FamilyVehiclesScreen({super.key});

  @override
  State<FamilyVehiclesScreen> createState() => _FamilyVehiclesScreenState();
}

class _FamilyVehiclesScreenState extends State<FamilyVehiclesScreen> {
  int _selectedTab = 0; // 0: Family Members, 1: Vehicles
  List<FamilyMember> _familyMembers = [];
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  
  final _familyService = FamilyFirestoreService();
  final _vehicleService = VehicleFirestoreService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final members = await _familyService.getFamilyMembers();
      final vehicles = await _vehicleService.getVehicles();
      
      if (mounted) {
        setState(() {
          _familyMembers = members;
          _vehicles = vehicles;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Family & Vehicles',
      isScrollable: false,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          const SizedBox(height: 20),
          AppSegmentedControl(
            segments: const ['Family Members', 'Vehicles'],
            selectedIndex: _selectedTab,
            onChanged: (index) {
              setState(() => _selectedTab = index);
            },
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOldHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 16, 24),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
              ),
              const Text(
                'Family & Vehicles',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _selectedTab == 0 ? 'Manage your family members' : 'Manage your vehicles',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showAddModal,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
        ),
      );
    }

    if (_selectedTab == 0) {
      if (_familyMembers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No family members added yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the Add button to add a family member',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }
      
      return ListView.builder(
        key: const ValueKey('family'),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _familyMembers.length,
        itemBuilder: (context, index) {
          final member = _familyMembers[index];
          return FamilyCard(
            member: member,
            onDelete: member.isPrimary ? null : () => _deleteFamilyMember(member.id),
            onTap: () => _editFamilyMember(member),
          );
        },
      );
    } else {
      if (_vehicles.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No vehicles added yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the Add button to add a vehicle',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }
      
      return ListView.builder(
        key: const ValueKey('vehicles'),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          return VehicleCard(
            vehicle: vehicle,
            onDelete: () => _deleteVehicle(vehicle.id),
            onTap: () => _editVehicle(vehicle),
          );
        },
      );
    }
  }

  void _showAddModal() {
    if (_selectedTab == 0) {
      AddEditMemberModal.show(
        context,
        onSave: (member) async {
          final id = await _familyService.addFamilyMember(member);
          if (id != null) {
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Family member added successfully'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to add family member'),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
      );
    } else {
      AddEditVehicleModal.show(
        context,
        onSave: (vehicle) async {
          final id = await _vehicleService.addVehicle(vehicle);
          if (id != null) {
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Vehicle added successfully'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to add vehicle'),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
      );
    }
  }

  void _editFamilyMember(FamilyMember member) {
    AddEditMemberModal.show(
      context,
      member: member,
      onSave: (updated) async {
        final success = await _familyService.updateFamilyMember(updated);
        if (success) {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Family member updated successfully'),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to update family member'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      },
    );
  }

  void _editVehicle(Vehicle vehicle) {
    AddEditVehicleModal.show(
      context,
      vehicle: vehicle,
      onSave: (updated) async {
        final success = await _vehicleService.updateVehicle(updated);
        if (success) {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Vehicle updated successfully'),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to update vehicle'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _deleteFamilyMember(String id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: 'Delete Family Member',
      message: 'Are you sure you want to remove this family member? This action cannot be undone.',
    );

    if (confirmed && mounted) {
      final success = await _familyService.deleteFamilyMember(id);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Family member removed'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to remove family member'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteVehicle(String id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: 'Delete Vehicle',
      message: 'Are you sure you want to remove this vehicle? This action cannot be undone.',
    );

    if (confirmed && mounted) {
      final success = await _vehicleService.deleteVehicle(id);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Vehicle removed'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to remove vehicle'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }
}
