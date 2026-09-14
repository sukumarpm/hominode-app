import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'desktop/admin_desktop_page_frame.dart';
import 'services/parking_service.dart';
import 'services/auth_service.dart';
import 'widgets/standard_header.dart';

class ResidentVehicleManagementScreen extends StatefulWidget {
  const ResidentVehicleManagementScreen({super.key});

  @override
  State<ResidentVehicleManagementScreen> createState() =>
      _ResidentVehicleManagementScreenState();
}

class _ResidentVehicleManagementScreenState
    extends State<ResidentVehicleManagementScreen> {
  final ParkingService _parkingService = ParkingService();
  final AuthService _authService = AuthService();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  String _selectedVehicleType = 'Car';
  bool _isLoading = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _registerVehicle() async {
    if (_vehicleNumberController.text.isEmpty) {
      _showError('Please enter vehicle number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.getCurrentUserId();
      final buildingId = await _authService.getCurrentBuildingId();

      if (userId == null || buildingId == null) {
        throw Exception('User or building information not available');
      }

      await _parkingService.registerVehicle(
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleType: _selectedVehicleType,
        userId: userId,
        buildingId: buildingId,
        color: _colorController.text.trim(),
      );

      if (mounted) {
        _vehicleNumberController.clear();
        _colorController.clear();
        setState(() => _selectedVehicleType = 'Car');
        _showSuccess('Vehicle registered successfully');
      }
    } catch (e) {
      _showError('Failed to register vehicle: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Resident Vehicles',
        subtitle: 'Register and manage vehicles associated with residents.',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAddVehicleSection(),
              SizedBox(height: 24.h),
              _buildMyVehiclesSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'My Vehicles'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24.h),
                _buildAddVehicleSection(),
                SizedBox(height: 32.h),
                _buildMyVehiclesSection(),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Register New Vehicle',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Number
                Text(
                  'Vehicle Number',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _vehicleNumberController,
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF111111)),
                  decoration: InputDecoration(
                    hintText: 'e.g., MH02AB1234',
                    hintStyle: TextStyle(
                      fontSize: 14.sp,
                      color: Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(
                        color: Color(0xFF0E4778),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Vehicle Type
                Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedVehicleType,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: ['Car', 'Bike', 'Scooter']
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              child: Text(type),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedVehicleType = value);
                      }
                    },
                  ),
                ),
                SizedBox(height: 16.h),

                // Color
                Text(
                  'Color (Optional)',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _colorController,
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF111111)),
                  decoration: InputDecoration(
                    hintText: 'e.g., White, Black',
                    hintStyle: TextStyle(
                      fontSize: 14.sp,
                      color: Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(
                        color: Color(0xFF0E4778),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerVehicle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4778),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Register Vehicle',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyVehiclesSection() {
    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Vehicles',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          SizedBox(height: 16.h),
          StreamBuilder<List<VehicleModel>>(
            stream: _parkingService.getUserVehicles(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final vehicles = snapshot.data ?? [];

              if (vehicles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 48.w,
                        color: Colors.grey[300],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'No vehicles registered',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  return _buildVehicleCard(vehicle);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Icon(
                Icons.directions_car,
                color: Color(0xFF0E4778),
                size: 24.w,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.vehicleNumber,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${vehicle.vehicleType}${vehicle.color.isNotEmpty ? ' • ${vehicle.color}' : ''}',
                  style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteVehicle(vehicle.id),
            icon: Icon(
              Icons.delete_outline,
              color: Color(0xFFEF4444),
              size: 20.w,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _parkingService.deleteVehicle(vehicleId);
        _showSuccess('Vehicle deleted');
      } catch (e) {
        _showError('Failed to delete vehicle: $e');
      }
    }
  }
}
