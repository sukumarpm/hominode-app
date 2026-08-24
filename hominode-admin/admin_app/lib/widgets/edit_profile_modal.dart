import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileModal extends StatefulWidget {
  const EditProfileModal({super.key});

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG: No user logged in');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not logged in'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      _userId = user.uid;
      print('=== DEBUG: Edit Profile Data Fetch ===');
      print('Auth UID: $_userId');
      print('Auth Email: ${user.email}');
      print('Fetching from: admins/$_userId');

      // Fetch admin data from Firestore admins collection
      final userDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(_userId)
          .get();

      print('Document exists: ${userDoc.exists}');

      if (userDoc.exists) {
        final data = userDoc.data()!;
        print('Fetched data: $data');

        setState(() {
          _nameController.text = data['name'] ?? 'Admin User';
          _emailController.text = data['email'] ?? user.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _organizationController.text =
              data['organization'] ?? 'HOMINODE Property Management';
          _isLoading = false;
        });

        print('Name: ${_nameController.text}');
        print('Email: ${_emailController.text}');
        print('Phone: ${_phoneController.text}');
        print('Organization: ${_organizationController.text}');
      } else {
        print('WARNING: Admin document does not exist at admins/$_userId');
        print('Using default values');

        // If no document exists, use default values
        setState(() {
          _nameController.text = 'Admin User';
          _emailController.text = user.email ?? '';
          _phoneController.text = '';
          _organizationController.text = 'HOMINODE Property Management';
          _isLoading = false;
        });
      }
      print('=====================================');
    } catch (e) {
      print('ERROR loading user data: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_userId == null) {
        throw Exception('User ID not found');
      }

      // Update Firestore admins collection (without changing role)
      await FirebaseFirestore.instance.collection('admins').doc(_userId).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'organization': _organizationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfilePicture(),
                          SizedBox(height: 24.h),
                          _buildTextField(
                            'Full Name',
                            _nameController,
                            Icons.person_outline,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            'Email Address',
                            _emailController,
                            Icons.email_outlined,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            'Phone Number',
                            _phoneController,
                            Icons.phone_outlined,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            'Organization',
                            _organizationController,
                            Icons.business_outlined,
                          ),
                          SizedBox(height: 32.h),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.edit, color: Color(0xFF0E4778), size: 24.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'Update your personal information',
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50.r),
            ),
            child: Icon(Icons.person, color: Color(0xFF0E4778), size: 50.w),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo upload - Coming soon')),
                );
              },
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(Icons.camera_alt, color: Colors.white, size: 16.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: EdgeInsets.all(16.w),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
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
        SizedBox(width: 16.w),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
