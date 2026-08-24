import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            padding: EdgeInsets.all(20.w),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign Users to Flats',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Users without flat assignments will appear here',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
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
                        Icon(
                          Icons.error_outline,
                          size: 48.w,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(height: 16.h),
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
                final unassignedUsers = allUsers
                    .where(
                      (user) => user.flatId == null || user.flatId!.isEmpty,
                    )
                    .toList();

                if (unassignedUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 56.w,
                          color: Colors.green[400],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'All users are assigned',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'No unassigned users found',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(20.w),
                  itemCount: unassignedUsers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A100).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  color: Color(0xFFF4A100),
                  size: 24.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14.w, color: Color(0xFF6B7280)),
                        SizedBox(width: 4.w),
                        Text(
                          user.phone,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Unassigned Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Unassigned',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF4A100),
                  ),
                ),
              ),
            ],
          ),

          if (user.email != null && user.email!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.email, size: 14.w, color: Color(0xFF6B7280)),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    user.email!,
                    style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 16.h),

          // Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAssignFlatDialog(user),
              icon: Icon(Icons.home, size: 18.w),
              label: const Text('Assign to Flat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E4778),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
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
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            user.phone,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Building Selector
                    Text(
                      'Select Building',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    StreamBuilder<List<BuildingModel>>(
                      stream: _buildingService.getBuildings(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0.w),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        buildings = snapshot.data ?? [];

                        if (buildings.isEmpty) {
                          return Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'No buildings available. Please create a building first.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: selectedBuildingId,
                          decoration: InputDecoration(
                            hintText: 'Choose a building',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
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
                              selectedBuildingName = buildings
                                  .firstWhere((b) => b.id == value)
                                  .name;
                              selectedFlatId = null;
                              selectedFlatLabel = null;
                              isLoadingFlats = true;
                            });

                            // Load flats for selected building
                            if (value != null) {
                              final flatStream = _flatService.getFlats(value);
                              await for (final flatList in flatStream.take(1)) {
                                setState(() {
                                  flats = flatList
                                      .where((flat) => flat.status == 'vacant')
                                      .toList();
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
                      SizedBox(height: 20.h),

                      // Flat Selector
                      Text(
                        'Select Flat',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),

                      if (isLoadingFlats)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0.w),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (flats.isEmpty)
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'No vacant flats available in this building.',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Color(0xFFF4A100),
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedFlatId,
                          decoration: InputDecoration(
                            hintText: 'Choose a flat',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                          ),
                          items: flats.map((flat) {
                            return DropdownMenuItem(
                              value: flat.id,
                              child: Text(
                                '${flat.flatNumber} - ${flat.bhkType}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedFlatId = value;
                              selectedFlatLabel = flats
                                  .firstWhere((f) => f.id == value)
                                  .flatNumber;
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
                  onPressed:
                      (selectedBuildingId != null && selectedFlatId != null)
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
                    backgroundColor: const Color(0xFF0E4778),
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
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12.w),
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
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    '${user.name} assigned to $flatLabel successfully',
                  ),
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
                SizedBox(width: 12.w),
                Expanded(child: Text('Error: ${e.toString()}')),
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
