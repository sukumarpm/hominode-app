import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'desktop/admin_desktop_page_frame.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/standard_header.dart';
import 'services/parking_service.dart';
import 'services/admin_service.dart';
import 'widgets/add_parking_slot_modal.dart';

class ParkingManagementScreenEnhanced extends StatefulWidget {
  const ParkingManagementScreenEnhanced({super.key});

  @override
  State<ParkingManagementScreenEnhanced> createState() =>
      _ParkingManagementScreenEnhancedState();
}

class _ParkingManagementScreenEnhancedState
    extends State<ParkingManagementScreenEnhanced>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ParkingService _parkingService = ParkingService();
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index == _currentTab) return;
    HapticFeedback.selectionClick();
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Parking',
        subtitle: 'Manage parking slots, vehicles, and violations.',
        actions: [
          AdminDesktopPrimaryAction(
            label: 'Add Parking Slot',
            icon: Icons.add_road_outlined,
            onPressed: _showAddParkingSlotModal,
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              SizedBox(height: 16.h),
              _buildStatisticsSection(),
              SizedBox(height: 16.h),
              _buildUnauthorizedVehicleAlert(),
              SizedBox(height: 18.h),
              _buildTabBar(),
              SizedBox(height: 14.h),
              _buildTabContent(),
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
          const StandardHeader(title: 'Parking Management'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                _buildSectionHeader(),
                SizedBox(height: 16.h),
                _buildSearchBar(),
                SizedBox(height: 20.h),
                _buildStatisticsSection(),
                SizedBox(height: 20.h),
                _buildUnauthorizedVehicleAlert(),
                SizedBox(height: 24.h),
                _buildTabBar(),
                SizedBox(height: 16.h),
                _buildTabContent(),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 5),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Parking Slots',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddParkingSlotModal,
            icon: Icon(Icons.add, size: 18.w),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(fontSize: 14.sp, color: Color(0xFF111111)),
        decoration: InputDecoration(
          hintText: 'Search by slot number or vehicle type...',
          hintStyle: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20.w),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 12.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFF0E4778), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return StreamBuilder<List<ParkingSlotModel>>(
      stream: _parkingService.getParkingSlots(),
      builder: (context, slotsSnapshot) {
        return StreamBuilder<List<VehicleModel>>(
          stream: _parkingService.getVehicles(),
          builder: (context, vehiclesSnapshot) {
            final slots = slotsSnapshot.data ?? [];
            final vehicles = vehiclesSnapshot.data ?? [];

            final totalSlots = slots.length;
            final occupiedSlots = slots.where((s) => s.isOccupied).length;
            final vacantSlots = totalSlots - occupiedSlots;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Slots',
                      totalSlots.toString(),
                      const Color(0xFF0E4778),
                      Icons.local_parking,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      'Occupied',
                      occupiedSlots.toString(),
                      const Color(0xFF16A34A),
                      Icons.check_circle,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20.w),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            _buildTabButton('Slots', 0),
            _buildTabButton('Vehicles', 1),
            _buildTabButton('Violations', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0E4778) : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: IndexedStack(
        index: _currentTab,
        children: [
          _buildSlotsTab(),
          _buildVehiclesTab(),
          _buildViolationsTab(),
        ],
      ),
    );
  }

  Widget _buildUnauthorizedVehicleAlert() {
    return StreamBuilder<List<ParkingViolationModel>>(
      stream: _parkingService.getViolations(),
      builder: (context, snapshot) {
        final violations = snapshot.data ?? [];
        if (violations.isEmpty) {
          return const SizedBox.shrink();
        }

        final violation = violations.first;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 20.w,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unauthorized Vehicle Alert',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Vehicle: ${violation.vehicleNumber}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _resolveViolation(violation.id),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                  ),
                  child: Text(
                    'Resolve',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotsTab() {
    return StreamBuilder<List<ParkingSlotModel>>(
      stream: _parkingService.getParkingSlots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var slots = snapshot.data ?? [];

        // Filter by search
        final query = _searchQuery.toLowerCase();
        if (query.isNotEmpty) {
          slots = slots
              .where(
                (slot) =>
                    slot.slotNumber.toLowerCase().contains(query) ||
                    slot.slotType.toLowerCase().contains(query),
              )
              .toList();
        }

        if (slots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_parking_outlined,
                  size: 48.w,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 12.h),
                Text(
                  'No parking slots found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return _buildSlotListItem(slot);
          },
        );
      },
    );
  }

  Widget _buildSlotListItem(ParkingSlotModel slot) {
    final isOccupied = slot.isOccupied;
    final statusColor = isOccupied
        ? const Color(0xFF16A34A)
        : const Color(0xFF9CA3AF);
    final statusLabel = isOccupied ? 'Occupied' : 'Vacant';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Icon(
                    Icons.local_parking,
                    color: statusColor,
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
                      'Slot ${slot.slotNumber}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      slot.slotType,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (isOccupied) ...[
            SizedBox(height: 12.h),
            _buildSlotDetailsSection(slot),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotDetailsSection(ParkingSlotModel slot) {
    return FutureBuilder<ParkingSlotDetailModel?>(
      future: _parkingService.getParkingSlotDetails(slot.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final details = snapshot.data!;
        return Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details.vehicle != null) ...[
                Text(
                  'Vehicle: ${details.vehicle!.vehicleNumber}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Type: ${details.vehicle!.vehicleType} • Color: ${details.vehicle!.color}',
                  style: TextStyle(fontSize: 11.sp, color: Color(0xFF6B7280)),
                ),
              ],
              if (details.userDetails != null) ...[
                SizedBox(height: 8.h),
                Text(
                  'Owner: ${details.ownerName}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  details.ownerPhone,
                  style: TextStyle(fontSize: 11.sp, color: Color(0xFF6B7280)),
                ),
              ],
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _removeVehicleFromSlot(slot.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  child: Text(
                    'Remove Vehicle',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehiclesTab() {
    return StreamBuilder<List<VehicleModel>>(
      stream: _parkingService.getVehicles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var vehicles = snapshot.data ?? [];

        // Filter by search
        final query = _searchQuery.toLowerCase();
        if (query.isNotEmpty) {
          vehicles = vehicles
              .where(
                (v) =>
                    v.vehicleNumber.toLowerCase().contains(query) ||
                    v.vehicleType.toLowerCase().contains(query),
              )
              .toList();
        }

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
                  'No vehicles found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
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
            return _buildVehicleListItem(vehicle);
          },
        );
      },
    );
  }

  Widget _buildVehicleListItem(VehicleModel vehicle) {
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
                  '${vehicle.vehicleType} • ${vehicle.color}',
                  style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              vehicle.vehicleType,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0E4778),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationsTab() {
    return StreamBuilder<List<ParkingViolationModel>>(
      stream: _parkingService.getViolations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final violations = snapshot.data ?? [];

        if (violations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48.w,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 12.h),
                Text(
                  'No violations found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: violations.length,
          itemBuilder: (context, index) {
            final violation = violations[index];
            return _buildViolationListItem(violation);
          },
        );
      },
    );
  }

  Widget _buildViolationListItem(ParkingViolationModel violation) {
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
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
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
                  violation.vehicleNumber,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${violation.violationType} • ₹${violation.fineAmount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFB923C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              violation.status,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFB923C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddParkingSlotModal() {
    AddParkingSlotModal.show(
      context,
      onSlotAdded: () {
        setState(() {});
      },
    );
  }

  Future<void> _removeVehicleFromSlot(String slotId) async {
    try {
      await _parkingService.removeVehicleFromSlot(slotId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle removed from slot')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _resolveViolation(String violationId) async {
    try {
      await _parkingService.resolveViolation(violationId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Violation resolved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
