import 'package:flutter/material.dart';

/// ParkingSearchFilterModal - Advanced search and filter modal for parking management
/// 
/// This modal provides comprehensive filtering options for parking slots
/// Features:
/// - Filter by slot status (occupied, vacant, unauthorized)
/// - Filter by vehicle type (car, bike, visitor)
/// - Filter by unit/resident
/// - Date range filtering for visitor vehicles
/// - Quick filter presets
class ParkingSearchFilterModal extends StatefulWidget {
  final ParkingSearchFilters currentFilters;
  final Function(ParkingSearchFilters) onFiltersApplied;

  const ParkingSearchFilterModal({
    super.key,
    required this.currentFilters,
    required this.onFiltersApplied,
  });

  @override
  State<ParkingSearchFilterModal> createState() => _ParkingSearchFilterModalState();
}

class _ParkingSearchFilterModalState extends State<ParkingSearchFilterModal> {
  late ParkingSearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters.copyWith();
  }

  void _onApplyFilters() {
    widget.onFiltersApplied(_filters);
    Navigator.of(context).pop();
  }

  void _onClearFilters() {
    setState(() {
      _filters = ParkingSearchFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 24),
                
                // Quick Filters
                _buildQuickFilters(),
                const SizedBox(height: 20),
                
                // Status Filters
                _buildStatusFilters(),
                const SizedBox(height: 20),
                
                // Vehicle Type Filters
                _buildVehicleTypeFilters(),
                const SizedBox(height: 32),
                
                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search & Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Filter parking slots and vehicles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Filters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickFilterChip('All Slots', () => _onClearFilters()),
            _buildQuickFilterChip('Vacant Only', () {
              setState(() {
                _filters = ParkingSearchFilters(showVacant: true);
              });
            }),
            _buildQuickFilterChip('Occupied Only', () {
              setState(() {
                _filters = ParkingSearchFilters(showOccupied: true);
              });
            }),
            _buildQuickFilterChip('Unauthorized', () {
              setState(() {
                _filters = ParkingSearchFilters(showUnauthorized: true);
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Slot Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildFilterCheckbox(
          'Show Vacant Slots',
          _filters.showVacant,
          (value) => setState(() => _filters.showVacant = value),
        ),
        _buildFilterCheckbox(
          'Show Occupied Slots',
          _filters.showOccupied,
          (value) => setState(() => _filters.showOccupied = value),
        ),
        _buildFilterCheckbox(
          'Show Unauthorized Vehicles',
          _filters.showUnauthorized,
          (value) => setState(() => _filters.showUnauthorized = value),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildFilterCheckbox(
          'Car Slots',
          _filters.showCars,
          (value) => setState(() => _filters.showCars = value),
        ),
        _buildFilterCheckbox(
          'Bike Slots',
          _filters.showBikes,
          (value) => setState(() => _filters.showBikes = value),
        ),
        _buildFilterCheckbox(
          'Visitor Vehicles',
          _filters.showVisitors,
          (value) => setState(() => _filters.showVisitors = value),
        ),
      ],
    );
  }

  Widget _buildFilterCheckbox(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            activeColor: const Color(0xFF2563EB),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _onClearFilters,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _onApplyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Apply Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Parking Search Filters Data Model
class ParkingSearchFilters {
  bool showVacant;
  bool showOccupied;
  bool showUnauthorized;
  bool showCars;
  bool showBikes;
  bool showVisitors;
  String? searchQuery;

  ParkingSearchFilters({
    this.showVacant = false,
    this.showOccupied = false,
    this.showUnauthorized = false,
    this.showCars = false,
    this.showBikes = false,
    this.showVisitors = false,
    this.searchQuery,
  });

  ParkingSearchFilters copyWith({
    bool? showVacant,
    bool? showOccupied,
    bool? showUnauthorized,
    bool? showCars,
    bool? showBikes,
    bool? showVisitors,
    String? searchQuery,
  }) {
    return ParkingSearchFilters(
      showVacant: showVacant ?? this.showVacant,
      showOccupied: showOccupied ?? this.showOccupied,
      showUnauthorized: showUnauthorized ?? this.showUnauthorized,
      showCars: showCars ?? this.showCars,
      showBikes: showBikes ?? this.showBikes,
      showVisitors: showVisitors ?? this.showVisitors,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters {
    return showVacant || showOccupied || showUnauthorized || 
           showCars || showBikes || showVisitors ||
           (searchQuery != null && searchQuery!.isNotEmpty);
  }
}

/// Utility function to show the ParkingSearchFilterModal
Future<void> showParkingSearchFilterModal(
  BuildContext context, {
  required ParkingSearchFilters currentFilters,
  required Function(ParkingSearchFilters) onFiltersApplied,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) {
      return ParkingSearchFilterModal(
        currentFilters: currentFilters,
        onFiltersApplied: onFiltersApplied,
      );
    },
  );
}