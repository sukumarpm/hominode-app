import 'package:flutter/material.dart';
import 'services/user_service.dart';
import 'services/building_service.dart';
import 'services/flat_service.dart';
import 'widgets/standard_header.dart';

class UnassignedUsersScreen extends StatefulWidget {
  const UnassignedUsersScreen({super.key});

  @override
  State<UnassignedUsersScreen> createState() => _UnassignedUsersScreenState();
}

class _UnassignedUsersScreenState extends State<UnassignedUsersScreen> {
  final UserService _userService = UserService();
  final BuildingService _buildingService = BuildingService();
  final FlatService _flatService = FlatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const StandardAppBar(
        title: 'Unassigned Users',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign Users to Flats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Users without flat assignments will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _userService.getUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading users',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  );
                }

                final allUsers = snapshot.data ?? [];
                
                // Filter for unassigned users (flatId == null)
                final unassignedUsers = allUsers.where((user) => user.flatId == null || user.flatId!.isEmpty).toList();

                if (unassignedUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 56, color: Colors.green[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'All users are assigned',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No unassigned users found',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: unassignedUsers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildUserCard(unassignedUsers[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A100).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFF4A100),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          user.phone,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Unassigned Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Unassigned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF4A100),
                  ),
                ),
              ),
            ],
          ),
          
          if (user.email != null && user.email!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.email, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user.email!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAssignFlatDialog(user),
              icon: const Icon(Icons.home, size: 18),
              label: const Text('Assign to Flat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignFlatDialog(UserModel user) async {
    String? selectedBuildingId;
    String? selectedBuildingName;
    String? selectedFlatId;
    String? selectedFlatLabel;
    List<BuildingModel> buildings = [];
    List<FlatModel> flats = [];
    bool isLoadingFlats = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Assign ${user.name} to Flat'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.phone,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Building Selector
                    const Text(
                      'Select Building',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<BuildingModel>>(
                      stream: _buildingService.getBuildings(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        buildings = snapshot.data ?? [];

                        if (buildings.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'No buildings available. Please create a building first.',
                              style: TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: selectedBuildingId,
                          decoration: InputDecoration(
                            hintText: 'Choose a building',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: buildings.map((building) {
                            return DropdownMenuItem(
                              value: building.id,
                              child: Text(building.name),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              selectedBuildingId = value;
                              selectedBuildingName = buildings.firstWhere((b) => b.id == value).name;
                              selectedFlatId = null;
                              selectedFlatLabel = null;
                              isLoadingFlats = true;
                            });

                            // Load flats for selected building
                            if (value != null) {
                              final flatStream = _flatService.getFlats(value);
                              await for (final flatList in flatStream.take(1)) {
                                setState(() {
                                  flats = flatList.where((flat) => flat.status == 'vacant').toList();
                                  isLoadingFlats = false;
                                });
                                break;
                              }
                            }
                          },
                        );
                      },
                    ),
                    
                    if (selectedBuildingId != null) ...[
                      const SizedBox(height: 20),
                      
                      // Flat Selector
                      const Text(
                        'Select Flat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      if (isLoadingFlats)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (flats.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No vacant flats available in this building.',
                            style: TextStyle(fontSize: 13, color: Color(0xFFF4A100)),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedFlatId,
                          decoration: InputDecoration(
                            hintText: 'Choose a flat',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: flats.map((flat) {
                            return DropdownMenuItem(
                              value: flat.id,
                              child: Text('${flat.flatNumber} - ${flat.bhkType}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedFlatId = value;
                              selectedFlatLabel = flats.firstWhere((f) => f.id == value).flatNumber;
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (selectedBuildingId != null && selectedFlatId != null)
                      ? () async {
                          Navigator.pop(context);
                          await _assignUserToFlat(
                            user: user,
                            buildingId: selectedBuildingId!,
                            buildingName: selectedBuildingName!,
                            flatId: selectedFlatId!,
                            flatLabel: selectedFlatLabel!,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignUserToFlat({
    required UserModel user,
    required String buildingId,
    required String buildingName,
    required String flatId,
    required String flatLabel,
  }) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Assigning user to flat...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Assign user to flat
      await _userService.assignUserToFlat(
        userId: user.id,
        flatId: flatId,
        flatLabel: flatLabel,
        buildingId: buildingId,
        buildingName: buildingName,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${user.name} assigned to $flatLabel successfully'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error assigning user to flat: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
