import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/parcel_entry.dart';

// ============================================================================
// LOG NEW PARCEL DIALOG
// ============================================================================
// Centered overlay modal for logging new parcel arrivals
// Matches exact UI reference with proper design system

class LogNewParcelDialog extends StatefulWidget {
  final Function(ParcelEntry) onParcelAdded;

  const LogNewParcelDialog({
    super.key,
    required this.onParcelAdded,
  });

  static void show(BuildContext context, {required Function(ParcelEntry) onParcelAdded}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => LogNewParcelDialog(onParcelAdded: onParcelAdded),
    );
  }

  @override
  State<LogNewParcelDialog> createState() => _LogNewParcelDialogState();
}

class _LogNewParcelDialogState extends State<LogNewParcelDialog> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _courierController = TextEditingController();
  final _trackingIdController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedResident;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Mock residents data - TODO: Load from API
  final List<Map<String, String>> _residents = [
    {'name': 'Priya Sharma', 'unit': 'E-305'},
    {'name': 'Rajesh Kumar', 'unit': 'A-204'},
    {'name': 'Amit Patel', 'unit': 'C-102'},
    {'name': 'Sneha Reddy', 'unit': 'D-401'},
    {'name': 'Rohit Gupta', 'unit': 'B-203'},
    {'name': 'Sunita Mehta', 'unit': 'F-106'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _courierController.dispose();
    _trackingIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedResident == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a resident'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.mediumImpact();

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    final selectedResidentData = _residents.firstWhere(
      (resident) => '${resident['name']} - ${resident['unit']}' == _selectedResident,
    );

    final parcel = ParcelEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      residentName: selectedResidentData['name']!,
      unit: selectedResidentData['unit']!,
      courier: _courierController.text.trim(),
      trackingId: _trackingIdController.text.trim(),
      receivedTime: DateTime.now(),
      status: ParcelStatus.pending,
      isResidentNotified: true, // Always notify when logging
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    widget.onParcelAdded(parcel);

    if (mounted) {
      Navigator.of(context).pop();
      
      // TODO: Send SMS/App notification to resident
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Parcel logged & ${selectedResidentData['name']} notified'),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _onClose() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 600,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Log New Parcel',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Record a new parcel delivery',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _onClose,
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF6B7280),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Resident / Unit Dropdown
                        _buildResidentDropdown(),
                        
                        const SizedBox(height: 24),
                        
                        // Courier Service
                        _buildCourierField(),
                        
                        const SizedBox(height: 24),
                        
                        // Tracking Number (Optional)
                        _buildTrackingField(),
                        
                        const SizedBox(height: 24),
                        
                        // Notes
                        _buildNotesField(),
                        
                        const SizedBox(height: 32),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: const Color(0xFFFFFFFF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
                                    'Log & Notify Resident',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResidentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resident / Unit',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedResident,
          decoration: InputDecoration(
            hintText: 'Select resident',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
            ),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF6B7280),
              size: 24,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: _residents.map((resident) {
            final displayText = '${resident['name']} - ${resident['unit']}';
            return DropdownMenuItem<String>(
              value: displayText,
              child: Text(
                displayText,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedResident = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCourierField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Courier Service',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _courierController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter courier service';
            }
            return null;
          },
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: 'e.g., Amazon, Flipkart, Delivery',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tracking Number (Optional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _trackingIdController,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: 'Enter tracking number',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: 'Additional details',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}