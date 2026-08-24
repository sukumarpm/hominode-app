import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/user_service.dart';

class EditResidentScreen extends StatefulWidget {
  final UserModel resident;

  const EditResidentScreen({super.key, required this.resident});

  @override
  State<EditResidentScreen> createState() => _EditResidentScreenState();
}

class _EditResidentScreenState extends State<EditResidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _familyMembersController;
  late TextEditingController _passwordController;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.resident.name);
    _phoneController = TextEditingController(text: widget.resident.phone);
    _emailController = TextEditingController(text: widget.resident.email ?? '');
    _familyMembersController = TextEditingController(
      text: widget.resident.familyMembers.toString(),
    );
    _passwordController = TextEditingController(
      text: widget.resident.password ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _familyMembersController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _userService.updateUser(
        userId: widget.resident.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        familyMembers: int.parse(_familyMembersController.text.trim()),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resident updated successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update resident: $e'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0E4778),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Edit Resident',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
                  ),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resident ID Card (Read-only)
                    _buildInfoCard(
                      title: 'Resident ID',
                      value: widget.resident.residentId,
                      icon: Icons.badge,
                      subtitle: 'This ID cannot be changed',
                    ),
                    SizedBox(height: 16.h),

                    // Personal Information Section
                    _buildSectionHeader('Personal Information'),
                    SizedBox(height: 12.h),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email (Optional)',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16.h),

                    _buildTextField(
                      controller: _familyMembersController,
                      label: 'Family Members',
                      icon: Icons.people,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter number of family members';
                        }
                        final number = int.tryParse(value.trim());
                        if (number == null || number < 1) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),

                    // Login Credentials Section
                    _buildSectionHeader('Login Credentials'),
                    SizedBox(height: 12.h),

                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF6B7280),
                          size: 20.w,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),

                    // Flat Information Section (Read-only)
                    if (widget.resident.flatLabel != null) ...[
                      _buildSectionHeader('Flat Information'),
                      SizedBox(height: 12.h),
                      _buildInfoCard(
                        title: 'Assigned Flat',
                        value: widget.resident.flatLabel!,
                        icon: Icons.home,
                        subtitle: 'Manage via Building Management',
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Status Section (Read-only)
                    _buildSectionHeader('Status'),
                    SizedBox(height: 12.h),
                    _buildInfoCard(
                      title: 'Current Status',
                      value: widget.resident.status == 'active'
                          ? 'Active'
                          : 'Inactive',
                      icon: Icons.circle,
                      subtitle: 'Use activate/deactivate option to change',
                      valueColor: widget.resident.status == 'active'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    SizedBox(height: 32.h),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E4778),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20.h,
                                width: 20.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            style: TextStyle(fontSize: 15.sp, color: Color(0xFF111111)),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF6B7280),
                size: 20.w,
              ),
              suffixIcon: suffixIcon,
              filled: false,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: TextStyle(fontSize: 12.sp, color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B7280), size: 20.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}
