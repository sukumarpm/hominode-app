import 'package:flutter/material.dart';
import '../services/gate_service.dart';

class AddGateModal extends StatefulWidget {
  const AddGateModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AddGateModal();
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
  State<AddGateModal> createState() => _AddGateModalState();
}

class _AddGateModalState extends State<AddGateModal> {
  final _formKey = GlobalKey<FormState>();
  final GateService _gateService = GateService();

  String _location = ''; // Changed from gateName to location
  String _workingStatus = 'Active';
  String _shiftTime = 'Full Day (24 Hours)';

  bool _isLoading = false;

  final List<String> _workingStatuses = [
    'Active',
    'Inactive',
    'Maintenance',
    'Under Repair',
  ];

  final List<String> _shiftTimes = [
    'Full Day (24 Hours)',
    'Morning (6 AM - 2 PM)',
    'Afternoon (2 PM - 10 PM)',
    'Night (10 PM - 6 AM)',
    'Day Shift (6 AM - 6 PM)',
    'Night Shift (6 PM - 6 AM)',
  ];

  Future<void> _handleAddGate() async {
    if (_location.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter place name'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _gateService.addGate(
        gateName: _location.trim(), // Using location as gateName in backend
        gateType: 'Security Post', // Default type
        workingStatus: _workingStatus,
        shiftTime: _shiftTime,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security place added successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add place'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92 > 600
              ? 600
              : MediaQuery.of(context).size.width * 0.92,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildLocationField(),
                    const SizedBox(height: 20),
                    _buildWorkingStatusField(),
                    const SizedBox(height: 20),
                    _buildShiftTimeField(),
                    const SizedBox(height: 24),
                    _buildAddButton(),
                    const SizedBox(height: 12),
                    _buildCancelButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Column(
          children: const [
            Text(
              'Add Security Place',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add places where security staff is needed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
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
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Place Name',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'e.g., Gate 1, Near Lift, Parking Area',
            hintStyle: const TextStyle(
              color: Color(0xFFB9BDC1),
              fontSize: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE6E9EC),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE6E9EC),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1,
              ),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _location = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildWorkingStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Working Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _workingStatus,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE6E9EC),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE6E9EC),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _workingStatuses.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(status),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _workingStatus = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildShiftTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shift Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _shiftTime,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE6E9EC),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE6E9EC),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _shiftTimes.map((time) {
            return DropdownMenuItem(
              value: time,
              child: Text(time),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _shiftTime = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleAddGate,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.4),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 54),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Add Place',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6B7280),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
