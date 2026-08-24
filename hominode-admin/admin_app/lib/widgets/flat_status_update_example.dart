import 'package:flutter/material.dart';
import 'flat_occupancy_grid_modal.dart';
import 'flat_occupancy_grid_stateful.dart';
import 'flat_details_modal.dart';

/// Example implementation showing how to handle flat status updates
/// when residents are assigned
class FlatStatusUpdateExample extends StatefulWidget {
  const FlatStatusUpdateExample({super.key});

  @override
  State<FlatStatusUpdateExample> createState() => _FlatStatusUpdateExampleState();
}

class _FlatStatusUpdateExampleState extends State<FlatStatusUpdateExample> {
  // Sample data - in real app, this would come from API/database
  late List<FloorOccupancy> _floorData;

  @override
  void initState() {
    super.initState();
    _initializeFloorData();
  }

  void _initializeFloorData() {
    _floorData = [
      FloorOccupancy(
        floorNumber: 10,
        flats: [
          FlatUnit(
            id: 'A101',
            type: '3BHK',
            status: FlatStatus.vacant,
            floor: 10,
            area: '1500 Sqft',
          ),
          FlatUnit(
            id: 'A102',
            type: '2BHK',
            status: FlatStatus.occupied,
            residentName: 'John Doe',
            floor: 10,
            area: '1200 Sqft',
          ),
          FlatUnit(
            id: 'A103',
            type: '3BHK',
            status: FlatStatus.maintenance,
            floor: 10,
            area: '1500 Sqft',
          ),
          FlatUnit(
            id: 'A104',
            type: '2BHK',
            status: FlatStatus.vacant,
            floor: 10,
            area: '1200 Sqft',
          ),
        ],
      ),
      FloorOccupancy(
        floorNumber: 9,
        flats: [
          FlatUnit(
            id: 'A091',
            type: '3BHK',
            status: FlatStatus.vacant,
            floor: 9,
            area: '1500 Sqft',
          ),
          FlatUnit(
            id: 'A092',
            type: '2BHK',
            status: FlatStatus.vacant,
            floor: 9,
            area: '1200 Sqft',
          ),
          FlatUnit(
            id: 'A093',
            type: '3BHK',
            status: FlatStatus.occupied,
            residentName: 'Jane Smith',
            floor: 9,
            area: '1500 Sqft',
          ),
          FlatUnit(
            id: 'A094',
            type: '2BHK',
            status: FlatStatus.vacant,
            floor: 9,
            area: '1200 Sqft',
          ),
        ],
      ),
    ];
  }

  /// Open occupancy grid with stateful wrapper
  /// This ensures the grid updates colors when status changes
  void _openOccupancyGrid() {
    FlatOccupancyGridStateful.show(
      context,
      towerName: 'Tower A',
      data: _floorData,
    );
  }

  /// Handle flat tap - opens flat details modal
  /// This is the main entry point for all flat interactions
  void _handleFlatTap(FlatUnit unit) {
    FlatDetailsModal.show(
      context,
      unit: unit,
      onStatusChange: (newStatus) {
        // This callback is triggered when:
        // 1. Resident is assigned (Vacant → Occupied)
        // 2. Maintenance status is changed (Maintenance → Vacant/Occupied)
        _updateFlatStatus(unit.id, newStatus);
      },
    );
  }

  /// Update flat status in the data structure
  void _updateFlatStatus(String flatId, FlatStatus newStatus) {
    setState(() {
      // Find and update the flat
      for (var floor in _floorData) {
        for (var flat in floor.flats) {
          if (flat.id == flatId) {
            flat.updateStatus(newStatus);
            
            // TODO: Call API to update status in backend
            // await api.updateFlatStatus(flatId, newStatus);
            
            print('✅ Flat $flatId status updated to: ${_getStatusName(newStatus)}');
            return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tower A - Flat Management'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.apartment,
              size: 80,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tower A',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_getTotalFlats()} Flats | ${_getOccupiedCount()} Occupied | ${_getVacantCount()} Vacant',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Use the stateful version that properly handles status updates
                _openOccupancyGrid();
              },
              icon: const Icon(Icons.grid_view),
              label: const Text('View Flat Occupancy Grid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalFlats() {
    return _floorData.fold(0, (sum, floor) => sum + floor.flats.length);
  }

  int _getOccupiedCount() {
    return _floorData.fold(
      0,
      (sum, floor) => sum + floor.flats.where((f) => f.status == FlatStatus.occupied).length,
    );
  }

  int _getVacantCount() {
    return _floorData.fold(
      0,
      (sum, floor) => sum + floor.flats.where((f) => f.status == FlatStatus.vacant).length,
    );
  }

  void _refreshData() {
    setState(() {
      _initializeFloorData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data refreshed'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Complete flow demonstrations:
/// 
/// FLOW 1: Assign Resident to Vacant Flat
/// 1. User opens Flat Occupancy Grid
/// 2. User clicks on a vacant flat (grey tile, e.g., A101)
/// 3. Flat Details Modal opens showing status: "Vacant"
/// 4. User clicks "Assign Resident" button
/// 5. Assign Resident Modal opens with two tabs
/// 6. User either selects existing resident or adds new one
/// 7. User fills form and clicks "Assign Resident"
/// 8. onStatusChange(FlatStatus.occupied) callback is triggered
/// 9. Flat status updates from "Vacant" to "Occupied"
/// 10. UI refreshes showing updated status
/// 11. Flat tile color changes from grey to green
/// 12. Resident name appears on tile
/// 13. Both modals close
/// 14. Grid shows updated status immediately
/// 
/// FLOW 2: Change Maintenance Status
/// 1. User opens Flat Occupancy Grid
/// 2. User clicks on a maintenance flat (yellow tile, e.g., A103)
/// 3. Flat Details Modal opens showing status: "Maintenance"
/// 4. User clicks "Update Status" button
/// 5. Maintenance Modal opens with warning message
/// 6. User opens dropdown and selects "Mark as Vacant" or "Mark as Occupied"
/// 7. onStatusChange(newStatus) callback is triggered
/// 8. Flat status updates to selected status
/// 9. UI refreshes showing updated status
/// 10. Flat tile color changes (yellow → grey or yellow → green)
/// 11. Both modals close
/// 12. Grid shows updated status immediately
/// 
/// FLOW 3: View Occupied Flat
/// 1. User opens Flat Occupancy Grid
/// 2. User clicks on an occupied flat (green tile, e.g., A102)
/// 3. Flat Details Modal opens showing resident information
/// 4. User clicks "View Resident Details" button
/// 5. Resident Details Modal opens (future feature)
/// 6. User can view/edit resident information
