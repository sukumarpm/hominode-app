import 'package:flutter/material.dart';
import '../models/flat_models.dart';
import '../services/flat_service.dart';
import 'assign_resident_with_state.dart';

/// Flat Details Modal (Vacant) with state management integration
/// Opens when admin taps a VACANT flat tile
/// 
/// FLOW:
/// - Shows flat details
/// - "Assign Resident" button opens AssignResidentModal
/// - After assignment, flat status updates to Occupied automatically
class FlatDetailsWithState extends StatefulWidget {
  final String flatId;
  final FlatService flatService;

  const FlatDetailsWithState({
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
      barrierLabel: 'Close flat details',
      barrierColor: const Color(0x59000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatDetailsWithState(
          flatId: flatId,
          flatService: flatService,
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
  State<FlatDetailsWithState> createState() => _FlatDetailsWithStateState();
}

class _FlatDetailsWithStateState extends State<FlatDetailsWithState> {
  final bool _isLoading = false;

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

  Future<void> _handleAssignResident() async {
    final flat = widget.flatService.getFlatById(widget.flatId);
    if (flat == null) return;

    // Open Assign Resident modal
    await AssignResidentWithState.show(
      context,
      flatId: flat.id,
      flatService: widget.flatService,
    );

    // After assignment, check if flat is now occupied
    final updatedFlat = widget.flatService.getFlatById(widget.flatId);
    if (updatedFlat != null && updatedFlat.status == FlatStatus.occupied) {
      // Close this modal since flat is now occupied
      if (mounted) {
        Navigator.of(context).pop();
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
          maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
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
                      _buildInfoBanner(),
                      const SizedBox(height: 20),
                      _buildPrimaryButton(),
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
                    fontWeight: FontWeight.w700,
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
              label: 'Close flat details',
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
            Expanded(child: _buildStatusPill(flat.status)),
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

  Widget _buildStatusPill(FlatStatus status) {
    final statusText = _getStatusText(status);
    final backgroundColor = _getStatusBackgroundColor(status);
    final textColor = _getStatusTextColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  String _getStatusText(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return 'Vacant';
      case FlatStatus.occupied:
        return 'Occupied';
      case FlatStatus.maintenance:
        return 'Maintenance';
    }
  }

  Color _getStatusBackgroundColor(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return const Color(0xFFD1D5DB);
      case FlatStatus.occupied:
        return const Color(0xFF10B981);
      case FlatStatus.maintenance:
        return const Color(0xFFFBBF24);
    }
  }

  Color _getStatusTextColor(FlatStatus status) {
    switch (status) {
      case FlatStatus.vacant:
        return const Color(0xFF374151);
      case FlatStatus.occupied:
        return Colors.white;
      case FlatStatus.maintenance:
        return const Color(0xFF78350F);
    }
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'This flat is currently vacant. You can assign a resident or change its status.',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2563EB),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Semantics(
      label: 'Assign resident to flat',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleAssignResident,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            disabledBackgroundColor: const Color(0x662563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Assign Resident',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
