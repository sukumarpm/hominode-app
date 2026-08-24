import 'package:flutter/material.dart';
import 'widgets/standard_header.dart';
import 'widgets/assign_visitor_parking_modal.dart';
import 'parking_management_vehicles_screen.dart';

class ParkingManagementVisitorScreen extends StatefulWidget {
  const ParkingManagementVisitorScreen({super.key});

  @override
  State<ParkingManagementVisitorScreen> createState() => _ParkingManagementVisitorScreenState();
}

class _ParkingManagementVisitorScreenState extends State<ParkingManagementVisitorScreen> {
  final int _selectedTabIndex = 1; // Visitors tab is selected

  // Sample visitor parking data
  final List<VisitorParkingEntry> _visitorParkings = [
    VisitorParkingEntry(
      id: 'V1',
      visitorName: 'Karan Mehta',
      vehicleNumber: 'HR 26 OP 9012',
      slot: 'V2',
      visitingUnit: 'C-102',
      entryTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      isActive: true,
    ),
    VisitorParkingEntry(
      id: 'V2',
      visitorName: 'Rahul Verma',
      vehicleNumber: 'DL 07 MN 5678',
      slot: 'V1',
      visitingUnit: 'A-204',
      entryTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      isActive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Parking Management'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Subtitle
                  const Text(
                    'Manage parking slots & vehicles',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Summary Metrics (4 Cards Grid)
                  const ParkingMetricsGrid(),
                  const SizedBox(height: 20),
                  
                  // Unauthorized Vehicle Alert
                  const UnauthorizedAlertCard(),
                  const SizedBox(height: 20),
                  
                  // Tab Switcher
                  ParkingTabSwitcher(
                    selectedIndex: _selectedTabIndex,
                    onTabChanged: _onTabChanged,
                  ),
                  const SizedBox(height: 20),
                  
                  // Assign Visitor Parking Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onAssignVisitorParking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Assign Visitor Parking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Active Visitor Parking Cards List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final visitor = _visitorParkings[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: VisitorParkingCard(
                      visitor: visitor,
                      onMarkExit: () => _onMarkExit(visitor.id),
                    ),
                  );
                },
                childCount: _visitorParkings.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  void _onTabChanged(int index) {
    if (index != _selectedTabIndex) {
      if (index == 0) {
        // Navigate to Slots (main parking screen)
        Navigator.pop(context, 0);
      } else if (index == 2) {
        // Navigate to Vehicles screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ParkingManagementVehiclesScreen(),
          ),
        );
      }
    }
  }

  void _onAssignVisitorParking() async {
    final result = await showAssignVisitorParkingModal(context);
    
    if (result == true) {
      // TODO: Refresh visitor parking list from API
      // For now, we'll just show that the assignment was successful
      // The success message is already shown by the modal
      
      // Optionally refresh the parking data
      setState(() {
        // Add new visitor parking entry or refresh from API
      });
    }
  }

  void _onMarkExit(String visitorId) {
    setState(() {
      _visitorParkings.removeWhere((visitor) => visitor.id == visitorId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visitor marked as exited'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

// Parking Metrics Grid Widget
class ParkingMetricsGrid extends StatelessWidget {
  const ParkingMetricsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card width to ensure consistent sizing
        final availableWidth = constraints.maxWidth;
        final cardSpacing = 12.0;
        final totalSpacing = cardSpacing * 3; // 3 gaps between 4 cards
        final cardWidth = (availableWidth - totalSpacing) / 4;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: cardWidth,
              child: const ParkingMetricCard(
                value: '120',
                label: 'Total Slots',
                color: Color(0xFF2563EB),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const ParkingMetricCard(
                value: '87',
                label: 'Occupied',
                color: Color(0xFF16A34A),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const ParkingMetricCard(
                value: '33',
                label: 'Vacant',
                color: Color(0xFFF59E0B),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const ParkingMetricCard(
                value: '8',
                label: 'Visitor Slots',
                color: Color(0xFFA855F7),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Individual Parking Metric Card
class ParkingMetricCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const ParkingMetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88, // Fixed height for consistent alignment
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Unauthorized Alert Card Widget
class UnauthorizedAlertCard extends StatelessWidget {
  const UnauthorizedAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unauthorized Vehicle Alert',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vehicle: UP 16 QR 3456',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const Text(
                  'Location: Slot A7 • 10:30 AM',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Handle take action for unauthorized vehicle
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Take Action - Coming soon')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Take Action',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
}

// Tab Switcher Widget
class ParkingTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;

  const ParkingTabSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ['Slots', 'Visitors', 'Vehicles'];
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ] : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Visitor Parking Card Widget
class VisitorParkingCard extends StatelessWidget {
  final VisitorParkingEntry visitor;
  final VoidCallback onMarkExit;

  const VisitorParkingCard({
    super.key,
    required this.visitor,
    required this.onMarkExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Name/Vehicle + Status Badge
            Row(
              children: [
                // Purple Vehicle Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: Color(0xFFA855F7),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Visitor Name and Vehicle Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visitor.vehicleNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Active Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Details Section
            _buildDetailRow('Slot', visitor.slot),
            const SizedBox(height: 8),
            _buildDetailRow('Visiting', visitor.visitingUnit),
            const SizedBox(height: 8),
            _buildDetailRow('Entry', _formatTime(visitor.entryTime)),
            
            const SizedBox(height: 16),
            
            // Mark Exit Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onMarkExit,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Mark Exit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label :',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class VisitorParkingEntry {
  final String id;
  final String visitorName;
  final String vehicleNumber;
  final String slot;
  final String visitingUnit;
  final DateTime entryTime;
  final bool isActive;

  VisitorParkingEntry({
    required this.id,
    required this.visitorName,
    required this.vehicleNumber,
    required this.slot,
    required this.visitingUnit,
    required this.entryTime,
    required this.isActive,
  });
}