import 'package:flutter/material.dart';
import 'flat_details_modal.dart';
import 'flat_occupancy_grid_modal.dart';

/// Example usage of FlatDetailsModal
/// This demonstrates how to open the modal with different flat statuses
class FlatDetailsModalExample extends StatelessWidget {
  const FlatDetailsModalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flat Details Modal Examples'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildExampleButton(
              context,
              'Show Vacant Flat',
              _createVacantFlat(),
            ),
            const SizedBox(height: 16),
            _buildExampleButton(
              context,
              'Show Occupied Flat',
              _createOccupiedFlat(),
            ),
            const SizedBox(height: 16),
            _buildExampleButton(
              context,
              'Show Maintenance Flat',
              _createMaintenanceFlat(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleButton(BuildContext context, String label, FlatUnit unit) {
    return ElevatedButton(
      onPressed: () {
        FlatDetailsModal.show(
          context,
          unit: unit,
          onAssignResident: () {
            print('Action triggered for ${unit.id}');
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Action for ${unit.id} - Coming soon'),
                backgroundColor: const Color(0xFF2563EB),
              ),
            );
          },
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Text(label),
    );
  }

  FlatUnit _createVacantFlat() {
    return FlatUnit(
      id: 'A101',
      type: '3BHK',
      status: FlatStatus.vacant,
      floor: 10,
      area: '1500 Sqft',
    );
  }

  FlatUnit _createOccupiedFlat() {
    return FlatUnit(
      id: 'B205',
      type: '2BHK',
      residentName: 'John Doe',
      status: FlatStatus.occupied,
      floor: 5,
      area: '1200 Sqft',
    );
  }

  FlatUnit _createMaintenanceFlat() {
    return FlatUnit(
      id: 'C308',
      type: '3BHK',
      status: FlatStatus.maintenance,
      floor: 8,
      area: '1800 Sqft',
    );
  }
}
