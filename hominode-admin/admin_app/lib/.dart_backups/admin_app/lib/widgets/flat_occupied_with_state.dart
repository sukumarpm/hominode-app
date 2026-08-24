import 'package:flutter/material.dart';
import '../models/flat_models.dart';
import '../services/flat_service.dart';

/// Flat Occupied Modal with state management
/// Opens when admin taps an OCCUPIED flat tile
/// 
/// FLOW:
/// - Remove button: Confirms, then calls removeResidentFromFlat + changeFlatStatus(vacant)
/// - Status dropdown:
///   - Occupied: No change
///   - Vacant: removeResidentFromFlat + changeFlatStatus(vacant)
///   - Maintenance: changeFlatStatus(maintenance), keep resident stored
class FlatOccupiedWithState extends StatefulWidget {
  final String flatId;
  final FlatService flatService;

  const FlatOccupiedWithState({
    super.key,
    required this.flatId,
    required this.flatService,
  });

  static Future<void> show(
    BuildContext context, {
    required String flatId,
    required FlatService flatService,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close occupied flat details',
      barrierColor: const Color(0x59000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatOccupiedWithState(
          flatId: flatId,
          flatService: flatService,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
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
  State<FlatOccupiedWithState> createState() => _FlatOccupiedWithStateState();
}

class _FlatOccupiedWithStateState extends State<FlatOccupiedWithState> {
  String _selectedStatus = 'Occupied';
  bool _isUpdating = false;

  final List<String> _statusOptions = [
    'Occupied',
    'Vacant',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    widget.flatService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.flatService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleRemoveResident() async {
    final flat = widget.flatService.getFlatById(widget.flatId);
    if (flat == null || flat.resident == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Resident'),
        content: Text(
          'Remove ${flat.resident!.name} from ${flat.id}? This will mark the flat as Vacant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      // FLOW: Remove resident
      // 1. Call removeResidentFromFlat (sets resident = null)
      // 2. Call changeFlatStatus to vacant
      // Note: removeResidentFromFlat already sets status to vacant
      widget.flatService.removeResidentFromFlat(widget.flatId);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resident removed from ${flat.id}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove resident. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleStatusChange(String selectedStatus) async {
    if (selectedStatus == 'Occupied') {
      return; // No change needed
    }

    final flat = widget.flatService.getFlatById(widget.flatId);
    if (flat == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      if (selectedStatus == 'Vacant') {
        // FLOW: Change to Vacant
        // Remove resident and set status to vacant
        widget.flatService.removeResidentFromFlat(widget.flatId);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flat ${flat.id} marked as Vacant'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (selectedStatus == 'Maintenance') {
        // FLOW: Change to Maintenance
        // Keep resident stored but change status
        widget.flatService.changeFlatStatus(widget.flatId, FlatStatus.maintenance);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flat ${flat.id} marked as Maintenance'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _selectedStatus = 'Occupied';
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

  @override
  Widget build(BuildContext context) {
    final flat = widget.flatService.getFlatById(widget.flatId);

    if (flat == null) {
      return const Center(child: Text('Flat not found'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.92,
          maxHeight: screenHeight * 0.85,
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
                _buildHeader(flat),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailsGrid(flat),
                      const SizedBox(height: 24),
                      if (flat.resident != null) _buildResidentInformation(flat.resident!),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
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

  Widget _buildHeader(FlatUnit flat) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44),
            child: Column(
              children: [
                Text(
                  flat.id,
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
                    fontSize: 14,
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
              label: 'Close occupied flat details',
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

  Widget _buildDetailsGrid(FlatUnit flat) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLabel('Floors')),
            const SizedBox(width: 16),
            Expanded(child: _buildLabel('Flats per Floor')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildValue('Floor ${flat.floor}')),
            const SizedBox(width: 16),
            Expanded(child: _buildValue(flat.config)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildLabel('Area')),
            const SizedBox(width: 16),
            Expanded(child: _buildLabel('Status')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildValue(flat.areaFormatted)),
            const SizedBox(width: 16),
            Expanded(child: _buildOccupiedBadge()),
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

  Widget _buildOccupiedBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF15B34A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Occupied',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildResidentInformation(Resident resident) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resident Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 20),
          _buildResidentRow('Name :', resident.name),
          const SizedBox(height: 16),
          _buildResidentRow('ID :', resident.id),
          const SizedBox(height: 16),
          _buildResidentRowWithBadge('Type :', resident.type),
        ],
      ),
    );
  }

  Widget _buildResidentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildResidentRowWithBadge(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildRemoveButton()),
        const SizedBox(width: 14),
        Expanded(child: _buildStatusDropdown()),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return Semantics(
      label: 'Remove resident from flat',
      button: true,
      child: SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _isUpdating ? null : _handleRemoveResident,
          icon: const Icon(Icons.delete_outline, size: 22),
          label: const Text(
            'Remove',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: _isUpdating
              ? null
              : (value) {
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
}
