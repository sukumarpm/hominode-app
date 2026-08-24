import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/gate_service.dart';

class AssignSecurityWorkModal extends StatefulWidget {
  final SecurityStaff staff;

  const AssignSecurityWorkModal({
    super.key,
    required this.staff,
  });

  static Future<void> show(BuildContext context, SecurityStaff staff) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AssignSecurityWorkModal(staff: staff);
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
  State<AssignSecurityWorkModal> createState() => _AssignSecurityWorkModalState();
}

class _AssignSecurityWorkModalState extends State<AssignSecurityWorkModal> {
  final SecurityService _securityService = SecurityService();
  final GateService _gateService = GateService();
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedShift;
  String? _selectedGate;
  String? _selectedWorkStatus;
  final TextEditingController _instructionsController = TextEditingController();
  
  bool _isLoading = false;
  List<GateModel> _availableGates = [];
  bool _loadingGates = true;

  final List<String> _shifts = [
    'Morning Shift (6 AM - 2 PM)',
    'Evening Shift (2 PM - 10 PM)',
    'Night Shift (10 PM - 6 AM)',
  ];

  final List<String> _workStatuses = [
    'On Duty',
    'Off Duty',
    'Break',
  ];

  @override
  void initState() {
    super.initState();
    _selectedShift = widget.staff.shiftTiming;
    _selectedGate = widget.staff.gateAssignment;
    _selectedWorkStatus = widget.staff.workStatus;
    _instructionsController.text = widget.staff.specialInstructions ?? '';
    _loadGates();
  }

  Future<void> _loadGates() async {
    print('Loading gates...');
    try {
      final gatesStream = _gateService.getGates();
      gatesStream.listen((gates) {
        print('Gates loaded: ${gates.length}');
        for (var gate in gates) {
          print('Gate: ${gate.gateName} - ${gate.workingStatus}');
        }
        if (mounted) {
          setState(() {
            _availableGates = gates;
            _loadingGates = false;
          });
        }
      });
    } catch (e) {
      print('Error loading gates: $e');
      if (mounted) {
        setState(() {
          _loadingGates = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
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
                    _buildShiftTimingField(),
                    const SizedBox(height: 20),
                    _buildSecurityPlaceField(),
                    const SizedBox(height: 20),
                    _buildWorkStatusField(),
                    const SizedBox(height: 20),
                    _buildInstructionsField(),
                    const SizedBox(height: 24),
                    _buildAssignButton(),
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
          children: [
            const Text(
              'Assign Work',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.staff.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

  Widget _buildShiftTimingField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shift Timing',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedShift,
          decoration: InputDecoration(
            hintText: 'Select shift timing',
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
          items: _shifts.map((shift) {
            return DropdownMenuItem(
              value: shift,
              child: Text(shift),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedShift = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select shift timing';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSecurityPlaceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security Place',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingGates)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E9EC)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading places...'),
              ],
            ),
          )
        else
          InkWell(
            onTap: _availableGates.isEmpty ? null : _showGateSelectionModal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE6E9EC),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: _selectedGate != null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedGate ?? (_availableGates.isEmpty
                          ? 'No places available'
                          : 'Select security place'),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedGate != null
                            ? const Color(0xFF111111)
                            : const Color(0xFFB9BDC1),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: _availableGates.isEmpty
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        if (_availableGates.isEmpty && !_loadingGates) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFEF3C7),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.location_off,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No places available. Add places from Security Management screen.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showGateSelectionModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.92 > 500
                  ? 500
                  : MediaQuery.of(context).size.width * 0.92,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0EDFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Select Security Place',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.close,
                              color: Color(0xFF9CA3AF),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Gate List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: _availableGates.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final gate = _availableGates[index];
                        final isSelected = _selectedGate == gate.gateName;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGate = gate.gateName;
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEFF6FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gate.gateName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF111111),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: gate.workingStatus == 'Active'
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFFFE5E5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              gate.workingStatus,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: gate.workingStatus == 'Active'
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            gate.shiftTime ?? 'No shift',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF2563EB),
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildWorkStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedWorkStatus,
          decoration: InputDecoration(
            hintText: 'Select work status',
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
          items: _workStatuses.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(status),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedWorkStatus = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select work status';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInstructionsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Special Instructions (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter any special instructions...',
            hintStyle: const TextStyle(
              color: Color(0xFFB9BDC1),
              fontSize: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
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
          ),
        ),
      ],
    );
  }

  Widget _buildAssignButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _assignWork,
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
              'Assign Work',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 54),
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

  Future<void> _assignWork() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that a gate is selected
    if (_selectedGate == null || _selectedGate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a security place'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Assign work to security staff (updates staff collection and status)
      await _securityService.assignWork(
        staffId: widget.staff.id,
        shiftTiming: _selectedShift!,
        gateAssignment: _selectedGate!,
        workStatus: _selectedWorkStatus!,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      );

      // Step 2: Find the gate by name and update it with assignment details
      final gates = await _gateService.getGates().first;
      final selectedGate = gates.firstWhere(
        (gate) => gate.gateName == _selectedGate,
        orElse: () => throw Exception('Gate not found'),
      );

      // Step 3: Update gate collection with security assignment details
      await _gateService.assignSecurityToGate(
        gateId: selectedGate.id,
        securityId: widget.staff.id,
        securityName: widget.staff.name,
        shiftTiming: _selectedShift!,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work assigned to ${widget.staff.name}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign work: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
