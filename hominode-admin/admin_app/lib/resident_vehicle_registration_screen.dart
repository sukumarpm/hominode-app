import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/parking_service.dart';
import 'services/admin_service.dart';
import 'widgets/standard_header.dart';
import 'widgets/standard_bottom_nav.dart';

/// Resident Vehicle Registration Screen
/// Allows residents to register their vehicles (cars/bikes)
class ResidentVehicleRegistrationScreen extends StatefulWidget {
  final String residentId;
  final String buildingId;
  final String flatNumber;

  const ResidentVehicleRegistrationScreen({
    super.key,
    required this.residentId,
    required this.buildingId,
    required this.flatNumber,
  });

  @override
  State<ResidentVehicleRegistrationScreen> createState() =>
      _ResidentVehicleRegistrationScreenState();
}

class _ResidentVehicleRegistrationScreenState
    extends State<ResidentVehicleRegistrationScreen> {
  final ParkingService _parkingService = ParkingService();
  final AdminService _adminService = AdminService();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  String _selectedVehicleType = 'Car';
  bool _isLoading = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _registerVehicle() async {
    if (_vehicleNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter vehicle number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get resident name from Firestore
      final residentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.residentId)
          .get();

      final residentName = residentDoc['name'] ?? 'Unknown';

      await _parkingService.registerVehicle(
        vehicleNumber: _vehicleNumberController.text.toUpperCase(),
        vehicleType: _selectedVehicleType,
        ownerName: residentName,
        flatNumber: widget.flatNumber,
        buildingId: widget.buildingId,
        model: _modelController.text,
        color: _colorController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle registered successfully')),
        );
        _vehicleNumberController.clear();
        _modelController.clear();
        _colorController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        slivers: [
          const StandardHeader(title: 'Register Vehicle'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildVehicleTypeSelector(),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _vehicleNumberController,
                    label: 'Vehicle Number',
                    hint: 'e.g., MH02AB1234',
                    icon: Icons.directions_car,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _modelController,
                    label: 'Model (Optional)',
                    hint: 'e.g., Honda City',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _colorController,
                    label: 'Color (Optional)',
                    hint: 'e.g., Silver',
                    icon: Icons.palette,
                  ),
                  const SizedBox(height: 24),
                  _buildRegisterButton(),
                  const SizedBox(height: 24),
                  _buildRegisteredVehiclesList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 0),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E4778).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0E4778).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Register Your Vehicle',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Flat ${widget.flatNumber} • Building ${widget.buildingId}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTypeButton('Car', Icons.directions_car),
            const SizedBox(width: 12),
            _buildTypeButton('Bike', Icons.two_wheeler),
            const SizedBox(width: 12),
            _buildTypeButton('Scooter', Icons.electric_scooter),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(String type, IconData icon) {
    final isSelected = _selectedVehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedVehicleType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0E4778)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0E4778)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerVehicle,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: const Color(0xFFD1D5DB),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Register Vehicle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildRegisteredVehiclesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Registered Vehicles',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<VehicleModel>>(
          stream: _parkingService.getVehicles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final vehicles = snapshot.data ?? [];
            if (vehicles.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'No vehicles registered yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
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
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.directions_car,
                  color: Color(0xFF0E4778), size: 22),
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
                  '${vehicle.vehicleType}${vehicle.model.isNotEmpty ? ' • ${vehicle.model}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
      