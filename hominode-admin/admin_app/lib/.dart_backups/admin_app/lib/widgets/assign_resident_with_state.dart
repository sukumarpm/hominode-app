import 'dart:math';
import 'package:flutter/material.dart';
import '../models/flat_models.dart';
import '../services/flat_service.dart';

enum AssignMode { selectExisting, addNew }

/// Assign Resident Modal with state management
/// Opens from Vacant or Maintenance modals
/// 
/// FLOW:
/// - Select Existing tab: Choose from existing residents (mock data for now)
/// - Add New tab: Create new resident with auto-generated credentials
/// - On assign: calls flatService.assignResidentToFlat()
/// - Flat status automatically updates to Occupied
class AssignResidentWithState extends StatefulWidget {
  final String flatId;
  final FlatService flatService;

  const AssignResidentWithState({
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
      barrierLabel: 'Close assign resident modal',
      barrierColor: const Color(0x59000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AssignResidentWithState(
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
  State<AssignResidentWithState> createState() =>
      _AssignResidentWithStateState();
}

class _AssignResidentWithStateState extends State<AssignResidentWithState> {
  AssignMode _mode = AssignMode.selectExisting;
  bool _isSubmitting = false;
  String? _selectedResidentId;
  String _ownershipType = 'Owner';
  String? _errorMessage;

  // Mock residents for "Select Existing" mode
  final List<Map<String, dynamic>> _mockResidents = [
    {'id': 'RES101', 'name': 'Alice Johnson', 'phone': '+91 9876543210', 'email': 'alice@email.com'},
    {'id': 'RES102', 'name': 'Bob Williams', 'phone': '+91 9876543211', 'email': 'bob@email.com'},
    {'id': 'RES103', 'name': 'Carol Davis', 'phone': '+91 9876543212', 'email': 'carol@email.com'},
    {'id': 'RES104', 'name': 'David Miller', 'phone': '+91 9876543213', 'email': 'david@email.com'},
  ];

  // Add New form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _familyMembersController = TextEditingController(text: '1');
  final TextEditingController _emailController = TextEditingController();

  // Auto-generated credentials
  String _generatedResidentId = '';
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generateCredentials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _familyMembersController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _generateCredentials() {
    final random = Random();
    final residentNumber = random.nextInt(9000) + 1000;
    _generatedResidentId = 'RES$residentNumber';

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    _generatedPassword = String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );

    setState(() {});
  }

  bool get _isFormValid {
    if (_mode == AssignMode.selectExisting) {
      return _selectedResidentId != null && _ownershipType.isNotEmpty;
    } else {
      return _isAddNewFormValid;
    }
  }

  bool get _isAddNewFormValid {
    if (_nameController.text.trim().isEmpty || _nameController.text.trim().length < 2) {
      return false;
    }

    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 10) {
      return false;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        return false;
      }
    }

    return _ownershipType.isNotEmpty;
  }

  Future<void> _handleAssign() async {
    if (!_isFormValid) {
      setState(() {
        _errorMessage = _mode == AssignMode.selectExisting
            ? 'Please select a resident and ownership type.'
            : 'Please fill in all required fields correctly.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 800));

      Resident resident;

      if (_mode == AssignMode.selectExisting) {
        // Find selected resident from mock data
        final selectedData = _mockResidents.firstWhere(
          (r) => r['id'] == _selectedResidentId,
        );

        resident = Resident(
          id: selectedData['id'] as String,
          name: selectedData['name'] as String,
          phone: selectedData['phone'] as String,
          email: selectedData['email'] as String,
          type: _ownershipType,
          familyMembers: 1,
        );
      } else {
        // Create new resident
        resident = Resident(
          id: _generatedResidentId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? 'noemail@example.com'
              : _emailController.text.trim(),
          type: _ownershipType,
          familyMembers: int.tryParse(_familyMembersController.text.trim()) ?? 1,
          generatedPassword: _generatedPassword,
        );

        debugPrint('🔐 Generated Credentials:');
        debugPrint('   Resident ID: $_generatedResidentId');
        debugPrint('   Password: $_generatedPassword');
        debugPrint('   Will be sent to: ${_phoneController.text}');
      }

      // FLOW: Assign resident to flat
      // This function MUST:
      // 1. Set flat.status = FlatStatus.occupied
      // 2. Set flat.resident = resident
      // 3. Trigger UI refresh
      widget.flatService.assignResidentToFlat(
        widget.flatId,
        resident,
        _ownershipType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mode == AssignMode.selectExisting
                  ? 'Resident ${resident.name} assigned to ${widget.flatId}'
                  : 'New resident created and assigned to ${widget.flatId}',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to assign resident. Please try again.';
      });
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
    final keyboardInsets = MediaQuery.of(context).viewInsets;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(flat.id),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: keyboardInsets.bottom > 0 ? keyboardInsets.bottom + 16 : 24,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentedControl(),
                        const SizedBox(height: 24),
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 16),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _mode == AssignMode.selectExisting
                              ? _buildSelectExistingForm()
                              : _buildAddNewForm(),
                        ),
                        const SizedBox(height: 24),
                        _buildPrimaryButton(),
                        const SizedBox(height: 12),
                        _buildCancelButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String flatId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44),
            child: Column(
              children: [
                Text(
                  'Assign Resident to $flatId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select an existing resident or add a new one to this flat.',
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
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              label: 'Select Existing',
              isActive: _mode == AssignMode.selectExisting,
              onTap: () => setState(() => _mode = AssignMode.selectExisting),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              label: 'Add New',
              isActive: _mode == AssignMode.addNew,
              onTap: () {
                setState(() => _mode = AssignMode.addNew);
                _generateCredentials();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [const BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectExistingForm() {
    return Column(
      key: const ValueKey('select_existing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResidentList(),
        const SizedBox(height: 6),
        const Text(
          'Choose from registered residents in the system',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 20),
        _buildLabel('Ownership Type'),
        const SizedBox(height: 8),
        _buildOwnershipDropdown(),
      ],
    );
  }

  Widget _buildResidentList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: _mockResidents.length,
        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (context, index) {
          final resident = _mockResidents[index];
          final isSelected = _selectedResidentId == resident['id'];

          return InkWell(
            onTap: () {
              setState(() {
                _selectedResidentId = resident['id'] as String;
                _errorMessage = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
                borderRadius: index == 0
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : (index == _mockResidents.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(12))
                        : BorderRadius.zero),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getAvatarColor(resident['name'] as String),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(resident['name'] as String),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resident['name'] as String,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${resident['id']}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Widget _buildAddNewForm() {
    return Column(
      key: const ValueKey('add_new'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithAsterisk('Resident Name'),
        const SizedBox(height: 8),
        _buildTextField(controller: _nameController, hintText: 'Enter full name', keyboardType: TextInputType.name),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelWithAsterisk('Phone Number'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _phoneController,
                    hintText: '+91 1234567890',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Family Members'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _familyMembersController,
                    hintText: '1',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          hintText: 'resident@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildLabel('Ownership Type'),
        const SizedBox(height: 8),
        _buildOwnershipDropdown(),
        const SizedBox(height: 20),
        _buildCredentialsInfoCard(),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
    );
  }

  Widget _buildLabelWithAsterisk(String text) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const Text(' *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() => _errorMessage = null),
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ),
    );
  }

  Widget _buildOwnershipDropdown() {
    final ownershipTypes = ['Owner', 'Tenant', 'Lease'];

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _ownershipType,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.keyboard_arrow_down, color: Color(0xFF9CA3AF), size: 24),
          ),
          borderRadius: BorderRadius.circular(12),
          items: ownershipTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(type, style: const TextStyle(fontSize: 15, color: Color(0xFF111827))),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _ownershipType = value;
                _errorMessage = null;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCredentialsInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF1D4ED8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Login credentials will be auto-generated:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Resident ID: $_generatedResidentId',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1D4ED8), height: 1.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Password: Will be sent via SMS/Email',
                  style: TextStyle(fontSize: 14, color: Color(0xFF1D4ED8), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final isEnabled = _isFormValid && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleAssign : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          disabledBackgroundColor: const Color(0x662563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Assign Resident', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Cancel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
