import 'package:flutter/material.dart';
import 'widgets/standard_header.dart';

class OccupancyManagementScreen extends StatefulWidget {
  const OccupancyManagementScreen({super.key});

  @override
  State<OccupancyManagementScreen> createState() =>
      _OccupancyManagementScreenState();
}

class _OccupancyManagementScreenState extends State<OccupancyManagementScreen> {
  String selectedBuilding = 'All Buildings';
  String selectedFilter = 'All';

  final List<String> buildings = [
    'All Buildings',
    'Tower A',
    'Tower B',
    'Tower C',
  ];

  final List<String> filters = ['All', 'Occupied', 'Vacant', 'Maintenance'];

  final List<OccupancyUnit> units = [
    OccupancyUnit(
      unitNumber: 'A-101',
      building: 'Tower A',
      floor: 1,
      status: OccupancyStatus.occupied,
      residentName: 'Rajesh Kumar',
      residentPhone: '+91 98765 11111',
      occupiedSince: DateTime(2023, 6, 15),
      rentAmount: 25000,
    ),
    OccupancyUnit(
      unitNumber: 'A-102',
      building: 'Tower A',
      floor: 1,
      status: OccupancyStatus.vacant,
      vacantSince: DateTime(2024, 11, 1),
      expectedRent: 24000,
    ),
    OccupancyUnit(
      unitNumber: 'B-205',
      building: 'Tower B',
      floor: 2,
      status: OccupancyStatus.occupied,
      residentName: 'Priya Sharma',
      residentPhone: '+91 98765 22222',
      occupiedSince: DateTime(2024, 1, 10),
      rentAmount: 28000,
    ),
    OccupancyUnit(
      unitNumber: 'C-304',
      building: 'Tower C',
      floor: 3,
      status: OccupancyStatus.maintenance,
      maintenanceReason: 'Plumbing repair',
      maintenanceSince: DateTime(2024, 12, 10),
    ),
  ];

  List<OccupancyUnit> get filteredUnits {
    var filtered = units;

    if (selectedBuilding != 'All Buildings') {
      filtered = filtered
          .where((unit) => unit.building == selectedBuilding)
          .toList();
    }

    if (selectedFilter != 'All') {
      filtered = filtered.where((unit) {
        switch (selectedFilter) {
          case 'Occupied':
            return unit.status == OccupancyStatus.occupied;
          case 'Vacant':
            return unit.status == OccupancyStatus.vacant;
          case 'Maintenance':
            return unit.status == OccupancyStatus.maintenance;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Occupancy Management'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildFilters(),
                const SizedBox(height: 16),
                _buildSearchAndActions(),
                _buildSummaryCards(),
                _buildUnitsList(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.home_work, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit Occupancy',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track and manage residential unit occupancy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search units, residents...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _showAddUnitModal,
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E4778).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _exportData,
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedBuilding,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedBuilding = newValue;
                      });
                    }
                  },
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF6B7280),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  items: buildings.map<DropdownMenuItem<String>>((
                    String value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.apartment,
                              size: 18,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedFilter,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedFilter = newValue;
                      });
                    }
                  },
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF6B7280),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  items: filters.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getFilterColor(value).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getFilterIcon(value),
                              size: 18,
                              color: _getFilterColor(value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalUnits = units.length;
    final occupiedUnits = units
        .where((u) => u.status == OccupancyStatus.occupied)
        .length;
    final vacantUnits = units
        .where((u) => u.status == OccupancyStatus.vacant)
        .length;
    final maintenanceUnits = units
        .where((u) => u.status == OccupancyStatus.maintenance)
        .length;
    final occupancyRate = ((occupiedUnits / totalUnits) * 100).round();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OccupancySummaryCard(
                  title: 'Total Units',
                  value: totalUnits.toString(),
                  color: const Color(0xFF0E4778),
                  icon: Icons.home,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OccupancySummaryCard(
                  title: 'Occupied',
                  value: occupiedUnits.toString(),
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OccupancySummaryCard(
                  title: 'Vacant',
                  value: vacantUnits.toString(),
                  color: const Color(0xFFF59E0B),
                  icon: Icons.home_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OccupancySummaryCard(
                  title: 'Occupancy Rate',
                  value: '$occupancyRate%',
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Units (${filteredUnits.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          ...filteredUnits.map(
            (unit) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OccupancyUnitCard(unit: unit),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Occupied':
        return Icons.check_circle;
      case 'Vacant':
        return Icons.home_outlined;
      case 'Maintenance':
        return Icons.build;
      default:
        return Icons.filter_list;
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Occupied':
        return const Color(0xFF10B981);
      case 'Vacant':
        return const Color(0xFFF59E0B);
      case 'Maintenance':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showAddUnitModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Unit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This feature will allow you to add new residential units to the system.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Coming Soon',
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
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Occupancy data exported successfully'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Data Models
enum OccupancyStatus { occupied, vacant, maintenance }

class OccupancyUnit {
  final String unitNumber;
  final String building;
  final int floor;
  final OccupancyStatus status;
  final String? residentName;
  final String? residentPhone;
  final DateTime? occupiedSince;
  final DateTime? vacantSince;
  final DateTime? maintenanceSince;
  final String? maintenanceReason;
  final double? rentAmount;
  final double? expectedRent;

  OccupancyUnit({
    required this.unitNumber,
    required this.building,
    required this.floor,
    required this.status,
    this.residentName,
    this.residentPhone,
    this.occupiedSince,
    this.vacantSince,
    this.maintenanceSince,
    this.maintenanceReason,
    this.rentAmount,
    this.expectedRent,
  });
}

// Summary Card Widget
class OccupancySummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const OccupancySummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// Unit Card Widget
class OccupancyUnitCard extends StatelessWidget {
  final OccupancyUnit unit;

  const OccupancyUnitCard({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit.unitNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(), size: 14, color: _getStatusColor()),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.apartment, size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                '${unit.building} • Floor ${unit.floor}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          if (unit.status == OccupancyStatus.occupied) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  unit.residentName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  unit.residentPhone ?? 'No phone',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            if (unit.rentAmount != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.currency_rupee,
                    size: 16,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${unit.rentAmount!.toInt()}/month',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (unit.status == OccupancyStatus.maintenance &&
              unit.maintenanceReason != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.build, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  unit.maintenanceReason!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ],
          if (unit.status == OccupancyStatus.vacant &&
              unit.expectedRent != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.currency_rupee,
                  size: 16,
                  color: const Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  'Expected: ₹${unit.expectedRent!.toInt()}/month',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (unit.status) {
      case OccupancyStatus.occupied:
        return const Color(0xFF10B981);
      case OccupancyStatus.vacant:
        return const Color(0xFFF59E0B);
      case OccupancyStatus.maintenance:
        return const Color(0xFFDC2626);
    }
  }

  IconData _getStatusIcon() {
    switch (unit.status) {
      case OccupancyStatus.occupied:
        return Icons.check_circle;
      case OccupancyStatus.vacant:
        return Icons.home_outlined;
      case OccupancyStatus.maintenance:
        return Icons.build;
    }
  }

  String _getStatusText() {
    switch (unit.status) {
      case OccupancyStatus.occupied:
        return 'Occupied';
      case OccupancyStatus.vacant:
        return 'Vacant';
      case OccupancyStatus.maintenance:
        return 'Maintenance';
    }
  }
}
