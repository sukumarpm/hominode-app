import 'package:flutter/material.dart';
import '../services/parking_service.dart';

class AssignVehicleToSlotModal {
  static void show(
    BuildContext context, {
    required String slotId,
    required String buildingId,
    required VoidCallback onAssigned,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignVehicleToSlotModalContent(
        slotId: slotId,
        buildingId: buildingId,
        onAssigned: onAssigned,
      ),
    );
  }
}

class _AssignVehicleToSlotModalContent extends StatefulWidget {
  final String slotId;
  final String buildingId;
  final VoidCallback onAssigned;

  const _AssignVehicleToSlotModalContent({
    required this.slotId,
    required this.buildingId,
    required this.onAssigned,
  });

  @override
  State<_AssignVehicleToSlotModalContent> createState() =>
      _AssignVehicleToSlotModalContentState();
}

class _AssignVehicleToSlotModalContentState
    extends State<_AssignVehicleToSlotModalContent> {
  final ParkingService _parkingService = ParkingService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isAssigning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _assignVehicle(VehicleModel vehicle) async {
    setState(() => _isAssigning = true);

    try {
      await _parkingService.assignVehicleToSlot(
        slotId: widget.slotId,
        vehicleId: vehicle.id,
        userId: vehicle.userId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle assigned to slot successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Assign Vehicle to Slot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.close, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF111111)),
                    decoration: InputDecoration(
                      hintText: 'Search by vehicle number...',
                      hintStyle: const TextStyle(
                          fontSize: 14, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFF9CA3AF), size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB), width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Vehicle List
            Expanded(
              child: StreamBuilder<List<VehicleModel>>(
                stream: _parkingService.getVehicles(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var vehicles = snapshot.data ?? [];

                  // Filter by search and building
                  final query = _searchQuery.toLowerCase();
                  vehicles = vehicles
                      .where((v) =>
                          v.buildingId == widget.buildingId &&
                          (query.isEmpty ||
                              v.vehicleNumber.toLowerCase().contains(query)))
                      .toList();

                  if (vehicles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'No vehicles found',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return _buildVehicleOption(vehicle);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOption(VehicleModel vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAssigning ? null : () => _assignVehicle(vehicle),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.directions_car,
                        color: Color(0xFF2563EB), size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.vehicleNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle.vehicleType}${vehicle.color.isNotEmpty ? ' • ${vehicle.color}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAssigning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
