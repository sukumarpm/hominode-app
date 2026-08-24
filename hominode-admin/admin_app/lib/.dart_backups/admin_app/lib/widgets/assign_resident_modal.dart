import 'dart:math';
import 'package:flutter/material.dart';

// Data models
enum ResidentStatus { available, assigned, inactive }

class ResidentSummary {
  final String id;
  final String name;
  final String uniqueId; // e.g., "RES-001", "UID-12345"
  final ResidentStatus status;
  final String? flatLabel; // Current flat if assigned

  ResidentSummary({
    required this.id,
    required this.name,
    required this.uniqueId,
    required this.status,
    this.flatLabel,
  });

  String get statusLabel {
    switch (status) {
      case ResidentStatus.available:
        return 'Available';
      case ResidentStatus.assigned:
        return flatLabel != null ? 'Assigned to $flatLabel' : 'Assigned';
      case ResidentStatus.inactive:
        return 'Inactive';
    }
  }

  Color get statusColor {
    switch (status) {
      case ResidentStatus.available:
        return const Color(0xFF10B981); // Green
      case ResidentStatus.assigned:
        return const Color(0xFF2563EB); // Blue
      case ResidentStatus.inactive:
        return const Color(0xFF9CA3AF); // Grey
    }
  }

  // TODO: Add toJson/fromJson for API integration
}

class AssignResidentRequest {
  final String flatId;
  final String residentId;
  final String ownershipType;

  AssignResidentRequest({
    required this.flatId,
    required this.residentId,
    required this.ownershipType,
  });

  // TODO: Add toJson for API submission
}

class AssignResidentNewRequest {
  final String flatId;
  final String name;
  final String phone;
  final int familyMembers;
  final String? email;
  final String ownershipType;
  final String generatedPassword;

  AssignResidentNewRequest({
    required this.flatId,
    required this.name,
    required this.phone,
    required this.familyMembers,
    this.email,
    required this.ownershipType,
    required this.generatedPassword,
  });

  // TODO: Add toJson for API submission
  Map<String, dynamic> toJson() {
    return {
      'flatId': flatId,
      'name': name,
      'phone': phone,
      'familyMembers': familyMembers,
      'email': email,
      'ownershipType': ownershipType,
      'password': generatedPassword,
    };
  }
}

enum AssignMode { selectExisting, addNew }

/// Pixel-perfect "Assign Resident to A101" overlay modal
/// Opens when admin taps "Assign Resident" from Flat Details modal
class AssignResidentModal extends StatefulWidget {
  final String flatId;
  final String flatLabel;
  final Future<List<ResidentSummary>> Function()? loadResidents;
  final Future<void> Function(AssignResidentRequest request)? onAssign;
  final Future<void> Function(AssignResidentNewRequest request)? onAssignNew;

  const AssignResidentModal({
    super.key,
    required this.flatId,
    required this.flatLabel,
    this.loadResidents,
    this.onAssign,
    this.onAssignNew,
  });

  /// Show the modal with fade-in and scale animation
  static Future<void> show(
    BuildContext context, {
    required String flatId,
    required String flatLabel,
    Future<List<ResidentSummary>> Function()? loadResidents,
    Future<void> Function(AssignResidentRequest request)? onAssign,
    Future<void> Function(AssignResidentNewRequest request)? onAssignNew,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close assign resident modal',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AssignResidentModal(
          flatId: flatId,
          flatLabel: flatLabel,
          loadResidents: loadResidents,
          onAssign: onAssign,
          onAssignNew: onAssignNew,
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
  State<AssignResidentModal> createState() => _AssignResidentModalState();
}

class _AssignResidentModalState extends State<AssignResidentModal> {
  AssignMode _mode = AssignMode.selectExisting;
  bool _isLoadingResidents = false;
  bool _isSubmitting = false;
  List<ResidentSummary> _residents = [];
  String? _selectedResidentId;
  String _ownershipType = 'Owner';
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Add New form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _familyMembersController = TextEditingController(text: '1');
  final TextEditingController _emailController = TextEditingController();
  
  // Auto-generated password
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _loadResidents();
    _generatePassword();
  }
  
  /// Generate random password for new resident
  void _generatePassword() {
    // Generate Password: 8 characters (alphanumeric)
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    _generatedPassword = String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
    
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _familyMembersController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  List<ResidentSummary> get _filteredResidents {
    if (_searchQuery.isEmpty) {
      return _residents;
    }
    
    final query = _searchQuery.toLowerCase();
    return _residents.where((resident) {
      return resident.name.toLowerCase().contains(query) ||
          resident.uniqueId.toLowerCase().contains(query) ||
          (resident.flatLabel?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _loadResidents() async {
    print('\n🟡 AssignResidentModal: _loadResidents() called');
    print('   - widget.loadResidents is null: ${widget.loadResidents == null}');
    
    if (widget.loadResidents == null) {
      print('⚠️  No loadResidents callback provided!');
      print('   Modal will show "No registered residents found"');
      // No residents to load
      setState(() {
        _residents = [];
      });
      return;
    }

    print('🔵 Starting to load residents from Firestore...');
    setState(() {
      _isLoadingResidents = true;
      _errorMessage = null;
    });

    try {
      print('🔵 Calling widget.loadResidents()...');
      final residents = await widget.loadResidents!();
      print('✅ Loaded ${residents.length} residents successfully');
      
      for (var resident in residents) {
        print('   - ${resident.name} (${resident.uniqueId}) - ${resident.statusLabel}');
      }
      
      setState(() {
        _residents = residents;
        _isLoadingResidents = false;
      });
      print('✅ State updated with residents\n');
    } catch (e, stackTrace) {
      print('❌ Error loading residents: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoadingResidents = false;
        _errorMessage = 'Failed to load residents. Please try again.';
      });
    }
  }

  bool get _isFormValid {
    if (_mode == AssignMode.selectExisting) {
      return _selectedResidentId != null && _ownershipType.isNotEmpty;
    } else {
      // Add New mode validation
      return _isAddNewFormValid;
    }
  }

  bool get _isAddNewFormValid {
    // Name validation
    if (_nameController.text.trim().isEmpty || _nameController.text.trim().length < 2) {
      return false;
    }
    
    // Phone validation
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 10) {
      return false;
    }
    
    // Email validation (optional but must be valid if provided)
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        return false;
      }
    }
    
    // Family members validation (optional but must be numeric if provided)
    final familyMembers = _familyMembersController.text.trim();
    if (familyMembers.isNotEmpty) {
      final number = int.tryParse(familyMembers);
      if (number == null || number < 1) {
        return false;
      }
    }
    
    return _ownershipType.isNotEmpty;
  }

  Future<void> _handleAssign() async {
    print('\n🟡 _handleAssign() called');
    print('Mode: $_mode');
    print('Form valid: $_isFormValid');
    
    if (!_isFormValid) {
      print('❌ Form validation failed');
      setState(() {
        if (_mode == AssignMode.selectExisting) {
          _errorMessage = 'Please select a resident and ownership type.';
        } else {
          _errorMessage = 'Please fill in all required fields correctly.';
        }
      });
      return;
    }

    print('✅ Form validation passed');
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_mode == AssignMode.selectExisting) {
        print('🟡 Mode: Select Existing');
        final request = AssignResidentRequest(
          flatId: widget.flatId,
          residentId: _selectedResidentId!,
          ownershipType: _ownershipType,
        );

        if (widget.onAssign != null) {
          print('🟡 Calling widget.onAssign...');
          await widget.onAssign!(request);
        } else {
          print('⚠️  widget.onAssign is null, simulating...');
          // Simulate API call
          await Future.delayed(const Duration(milliseconds: 800));
        }
      } else {
        print('🟡 Mode: Add New');
        // Add New mode
        final newResidentRequest = AssignResidentNewRequest(
          flatId: widget.flatId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          familyMembers: int.tryParse(_familyMembersController.text.trim()) ?? 1,
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          ownershipType: _ownershipType,
          generatedPassword: _generatedPassword,
        );
        
        print('🟡 Request created:');
        print('  - Name: ${newResidentRequest.name}');
        print('  - Phone: ${newResidentRequest.phone}');
        print('  - Email: ${newResidentRequest.email}');
        print('  - Password: ${newResidentRequest.generatedPassword}');
        
        if (widget.onAssignNew != null) {
          print('🟡 Calling widget.onAssignNew...');
          await widget.onAssignNew!(newResidentRequest);
        } else {
          print('⚠️  widget.onAssignNew is null, simulating...');
          // Simulate API call
          await Future.delayed(const Duration(milliseconds: 1000));
        }
        
        final username = _emailController.text.trim().isNotEmpty 
            ? _emailController.text.trim() 
            : _phoneController.text.trim();
        
        print('=== Generated Login Credentials ===');
        print('Username: $username (${_emailController.text.trim().isNotEmpty ? "Email" : "Phone"})');
        print('Password: $_generatedPassword (auto-generated)');
        print('Will be sent to: ${_phoneController.text}${_emailController.text.isNotEmpty ? " / ${_emailController.text}" : ""}');
        print('===================================');
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mode == AssignMode.selectExisting
                  ? 'Resident assigned successfully'
                  : 'Resident created and assigned to ${widget.flatLabel}',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = _mode == AssignMode.selectExisting
            ? 'Failed to assign resident. Please try again.'
            : 'Failed to create resident. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: keyboardInsets.bottom > 0 
                        ? keyboardInsets.bottom + 16 
                        : 24,
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
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
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
                  'Assign Resident to ${widget.flatLabel}',
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
            child: Semantics(
              label: 'Close assign resident modal',
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
                setState(() {
                  _mode = AssignMode.addNew;
                });
                // Regenerate password when switching to Add New mode
                _generatePassword();
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
              ? [
                  const BoxShadow(
                    color: Color(0x0F000000), // rgba(0, 0, 0, 0.06)
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
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
          const Icon(
            Icons.error_outline,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectExistingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(),
        const SizedBox(height: 12),
        _buildResidentCardList(),
        const SizedBox(height: 6),
        const Text(
          'Choose from registered residents in the system',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel('Ownership Type'),
        const SizedBox(height: 8),
        _buildOwnershipDropdown(),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: 'Search by name, ID, or flat...',
        hintStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFF9CA3AF),
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF9CA3AF),
          size: 22,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildResidentCardList() {
    if (_isLoadingResidents) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
        ),
      );
    }

    if (_residents.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 12),
              Text(
                'No registered residents found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredResidents = _filteredResidents;

    if (filteredResidents.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 12),
              Text(
                'No residents match "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: filteredResidents.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE5E7EB),
        ),
        itemBuilder: (context, index) {
          final resident = filteredResidents[index];
          final isSelected = _selectedResidentId == resident.id;
          
          return _buildResidentCard(resident, isSelected, index, filteredResidents.length);
        },
      ),
    );
  }

  Widget _buildResidentCard(ResidentSummary resident, bool isSelected, int index, int totalCount) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedResidentId = resident.id;
          _errorMessage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
          borderRadius: index == 0 
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : (index == totalCount - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero),
        ),
        child: Row(
          children: [
            // Avatar circle with initials
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getAvatarColor(resident.name),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  _getInitials(resident.name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Resident details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resident.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'ID: ${resident.uniqueId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9CA3AF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resident.statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: resident.statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status indicator dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: resident.statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    // Generate consistent color based on name
    final colors = [
      const Color(0xFF2563EB), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
    ];
    
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }



  String _getInitials(String name) {
    if (name.trim().isEmpty) {
      return '?';
    }
    
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Widget _buildOwnershipDropdown() {
    // TODO: Add more ownership types (Tenant, Company, etc.)
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
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF9CA3AF),
              size: 24,
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          items: ownershipTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
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

  Widget _buildAddNewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resident Name *
        _buildLabelWithAsterisk('Resident Name'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _nameController,
          hintText: 'Enter full name',
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 18),
        
        // Phone Number * and Family Members
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
        
        // Email Address
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          hintText: 'resident@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        
        // Ownership Type
        _buildLabel('Ownership Type'),
        const SizedBox(height: 8),
        _buildOwnershipDropdown(),
        const SizedBox(height: 20),
        
        // Info Card
        _buildCredentialsInfoCard(),
      ],
    );
  }

  Widget _buildLabelWithAsterisk(String text) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const Text(
          ' *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFEF4444),
          ),
        ),
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
      onChanged: (_) => setState(() {
        _errorMessage = null;
      }),
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFF9CA3AF),
        ),
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

  Widget _buildCredentialsInfoCard() {
    // Determine what will be used as username
    final username = _emailController.text.trim().isNotEmpty 
        ? _emailController.text.trim() 
        : _phoneController.text.trim();
    
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
          const Icon(
            Icons.auto_awesome,
            color: Color(0xFF1D4ED8),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Login credentials:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  username.isNotEmpty 
                      ? 'Username: $username (Email/Phone)'
                      : 'Username: Email or Phone (enter above)'
                ),
                const SizedBox(height: 4),
                _buildBulletPoint('Password: $_generatedPassword (auto-generated)'),
                const SizedBox(height: 8),
                const Text(
                  'Credentials will be sent via SMS/Email',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1D4ED8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF1D4ED8),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1D4ED8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    final isEnabled = _isFormValid && !_isSubmitting;

    return Semantics(
      label: 'Assign resident to flat ${widget.flatLabel}',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isEnabled ? _handleAssign : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            disabledBackgroundColor: const Color(0x662563EB), // 40% opacity
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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

  Widget _buildCancelButton() {
    return Semantics(
      label: 'Cancel assign resident',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
