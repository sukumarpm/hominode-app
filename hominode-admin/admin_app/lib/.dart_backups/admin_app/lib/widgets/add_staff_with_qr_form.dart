import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/staff_qr_service.dart';

class AddStaffWithQRForm extends StatefulWidget {
  final String buildingId;

  const AddStaffWithQRForm({
    super.key,
    required this.buildingId,
  });

  @override
  State<AddStaffWithQRForm> createState() => _AddStaffWithQRFormState();
}

class _AddStaffWithQRFormState extends State<AddStaffWithQRForm> {
  final StaffQRService _qrService = StaffQRService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();

  bool _isLoading = false;
  String? _selectedGate;
  String? _selectedShift;
  String? _generatedStaffId;
  Uint8List? _generatedQRCode;

  final List<String> _gates = ['Gate A', 'Gate B', 'Gate C', 'Main Gate'];
  final List<String> _shifts = [
    'Morning (6 AM - 2 PM)',
    'Afternoon (2 PM - 10 PM)',
    'Night (10 PM - 6 AM)'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _generateQRCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Generate unique staff ID
      _generatedStaffId = _qrService.generateUniqueStaffId();

      // Generate QR code
      final qrImage = await _qrService.generateQRCode(_generatedStaffId!);

      setState(() {
        _generatedQRCode = qrImage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code generated successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating QR: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (_generatedStaffId == null || _generatedQRCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate QR code first'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _qrService.createStaffWithQRCode(
        staffId: _generatedStaffId!,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _roleController.text.trim(),
        buildingId: widget.buildingId,
        gateName: _selectedGate ?? 'N/A',
        shiftTiming: _selectedShift ?? 'N/A',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member added successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Staff Member',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Staff Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Staff Name',
                  hintText: 'Enter staff name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter staff name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role
              TextFormField(
                controller: _roleController,
                decoration: InputDecoration(
                  labelText: 'Role',
                  hintText: 'e.g., Security Guard, Cleaner',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.work),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Gate Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedGate,
                decoration: InputDecoration(
                  labelText: 'Assigned Gate',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                items: _gates.map((gate) {
                  return DropdownMenuItem(
                    value: gate,
                    child: Text(gate),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGate = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a gate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Shift Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedShift,
                decoration: InputDecoration(
                  labelText: 'Shift Timing',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.schedule),
                ),
                items: _shifts.map((shift) {
                  return DropdownMenuItem(
                    value: shift,
                    child: Text(shift),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedShift = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a shift';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // QR Code Preview
              if (_generatedQRCode != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Generated QR Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      QrImage(
                        data: _generatedStaffId!,
                        version: QrVersions.auto,
                        size: 150,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: $_generatedStaffId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'QR code will appear here',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _generateQRCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Generate QR Code'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isLoading || _generatedQRCode == null)
                          ? null
                          : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Save Staff'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
