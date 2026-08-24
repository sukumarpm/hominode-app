import 'package:flutter/material.dart';
import 'flat_occupancy_grid_modal.dart';

/// Pixel-perfect "Flat Maintenance Status" overlay modal
/// Opens when admin taps a flat in maintenance status
class FlatMaintenanceModal extends StatefulWidget {
  final FlatUnit unit;
  final Function(FlatStatus newStatus)? onStatusChange;

  const FlatMaintenanceModal({
    super.key,
    required this.unit,
    this.onStatusChange,
  });

  /// Show the modal with fade-in and scale animation
  static Future<void> show(
    BuildContext context, {
    required FlatUnit unit,
    Function(FlatStatus newStatus)? onStatusChange,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close maintenance modal',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatMaintenanceModal(
          unit: unit,
          onStatusChange: onStatusChange,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FlatMaintenanceModal> createState() => _FlatMaintenanceModalState();
}

class _FlatMaintenanceModalState extends State<FlatMaintenanceModal> {
  String _selectedStatus = 'Keep in Maintenance';
  bool _isUpdating = false;

  final List<String> _statusOptions = [
    'Keep in Maintenance',
    'Mark as Vacant',
    'Mark as Occupied',
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.92,
          maxHeight: screenHeight * 0.80,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 8,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailsGrid(),
                      const SizedBox(height: 24),
                      _buildWarningBox(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44),
            child: Column(
              children: [
                Text(
                  widget.unit.id,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'View and manage flat details, resident information, and status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Semantics(
              label: 'Close maintenance modal',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Column(
      children: [
        // Row 1: Labels
        Row(
          children: [
            Expanded(
              child: _buildLabel('Floors'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabel('Flats per Floor'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: Values
        Row(
          children: [
            Expanded(
              child: _buildValue('Floor ${widget.unit.floor}'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildValue(widget.unit.type),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Row 3: Labels
        Row(
          children: [
            Expanded(
              child: _buildLabel('Area'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabel('Status'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 4: Values
        Row(
          children: [
            Expanded(
              child: _buildValue(widget.unit.area),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMaintenanceBadge(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildValue(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildMaintenanceBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2B100),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Maintenance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This flat is under maintenance. Change status when ready.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9A3A2A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusDropdown(),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E2E2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF9CA3AF),
              size: 24,
            ),
          ),
          borderRadius: BorderRadius.circular(14),
          items: _statusOptions.map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: _isUpdating ? null : (value) {
            if (value != null && value != _selectedStatus) {
              setState(() {
                _selectedStatus = value;
              });
              _handleStatusChange(value);
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleStatusChange(String selectedOption) async {
    if (selectedOption == 'Keep in Maintenance') {
      return; // No change needed
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Determine new status
      FlatStatus newStatus;
      if (selectedOption == 'Mark as Vacant') {
        newStatus = FlatStatus.vacant;
      } else if (selectedOption == 'Mark as Occupied') {
        newStatus = FlatStatus.occupied;
      } else {
        return;
      }

      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 800));

      // Update status via callback
      widget.onStatusChange?.call(newStatus);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flat ${widget.unit.id} status updated successfully'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _selectedStatus = 'Keep in Maintenance';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
