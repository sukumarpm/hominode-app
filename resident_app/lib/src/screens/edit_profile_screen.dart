// lib/src/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../components/standard_screen.dart';
import '../services/user_data_service.dart';
import '../services/profile_image_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userDataService = UserDataService();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _flatNumberController;

  String? _photoUrl;
  File? _photoFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _flatNumberController = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    print('🔵 EDIT PROFILE LOAD FLOW: Starting...');
    setState(() => _isLoading = true);
    
    try {
      // STEP 1: Fetch user data from Firestore
      print('📥 STEP 1: Fetching user data from Firestore...');
      var userData = await _userDataService.getCurrentUserData(forceRefresh: true);
      
      // If first attempt fails, try getting from SharedPreferences user_id
      if (userData == null) {
        print('⚠️  First attempt failed, trying alternative method...');
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        
        if (userId != null) {
          print('   Trying to fetch with user_id: $userId');
          userData = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get()
              .then((doc) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }
                return null;
              });
        }
      }
      
      if (userData == null) {
        print('❌ STEP 1 FAILED: No user data found');
        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User profile not found. Please contact administrator.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print('✅ STEP 1 PASSED: User data loaded');
      print('   Name: ${userData?['name']}');
      print('   Email: ${userData?['email']}');
      print('   Phone: ${userData?['phone']}');
      print('   Flat: ${userData?['flatLabel'] ?? userData?['flatId']}');
      
      // STEP 2: Populate form fields
      print('🎨 STEP 2: Populating form fields...');
      if (mounted) {
        setState(() {
          _nameController.text = userData?['name'] ?? '';
          _emailController.text = userData?['email'] ?? '';
          _phoneController.text = userData?['phone'] ?? '';
          _flatNumberController.text = userData?['flatLabel'] ?? userData?['flatId'] ?? '';
          _photoUrl = userData?['profileImage'] ?? userData?['photoURL'];
          _isLoading = false;
        });
        
        print('✅ STEP 2 PASSED: Form fields populated');
        print('');
        print('✅ EDIT PROFILE LOAD FLOW: COMPLETE');
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in EDIT PROFILE LOAD FLOW: $e');
      print('   Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _flatNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Edit Profile',
      isScrollable: true,
      padding: const EdgeInsets.all(16),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildPhotoSection(),
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    hint: 'Enter your name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    enabled: false, // Email cannot be changed
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Phone',
                    controller: _phoneController,
                    hint: 'Enter your phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Flat Number',
                    controller: _flatNumberController,
                    hint: 'e.g., A-101',
                    icon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildOldHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 16, 24),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(12),
              ),
              const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0E7FF),
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: ClipOval(
                  child: _photoFile != null
                      ? Image.file(_photoFile!, fit: BoxFit.cover)
                      : _photoUrl != null
                          ? Image.network(_photoUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 50, color: Color(0xFF2563EB)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to change photo',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (!enabled) return null; // Skip validation for disabled fields
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          disabledBackgroundColor: const Color(0xFF93C5FD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Photo Source',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a new photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFF16A34A)),
                  ),
                  title: const Text('Gallery'),
                  subtitle: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _photoFile = File(image.path);
            _photoUrl = image.path;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    print('🔵 EDIT PROFILE SAVE FLOW: Starting...');
    setState(() => _isSaving = true);

    try {
      // STEP 1: Prepare updates
      print('📋 STEP 1: Preparing profile updates...');
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'flatLabel': _flatNumberController.text.trim(),
      };
      print('✅ STEP 1 PASSED: Updates prepared');
      
      // STEP 2: Upload image if selected
      print('📸 STEP 2: Checking for image upload...');
      String? uploadedImageUrl;
      if (_photoFile != null) {
        print('   Image selected, uploading to Cloudinary...');
        final imageResult = await ProfileImageService.instance.uploadProfileImage(
          imagePath: _photoFile!.path,
        );

        if (imageResult.success && imageResult.imageUrl != null) {
          print('✅ STEP 2 PASSED: Image uploaded successfully');
          print('   Image URL: ${imageResult.imageUrl}');
          uploadedImageUrl = imageResult.imageUrl;
          updates['profileImage'] = imageResult.imageUrl;
          _photoUrl = imageResult.imageUrl;
        } else {
          print('⚠️  STEP 2 WARNING: Image upload failed: ${imageResult.message}');
          // Don't fail the entire save if image upload fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: ${imageResult.message}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        print('✅ STEP 2 PASSED: No image to upload');
      }

      // STEP 3: Update Firestore
      print('💾 STEP 3: Updating user data in Firestore...');
      print('   Updates: $updates');
      final success = await _userDataService.updateUserData(updates);

      if (!success) {
        throw Exception('Failed to update profile in Firestore');
      }

      print('✅ STEP 3 PASSED: User data updated in Firestore');
      
      // STEP 4: Force refresh image cache if image was uploaded
      if (uploadedImageUrl != null) {
        print('🔄 STEP 4: Force refreshing image cache...');
        final userId = await _getUserId();
        if (userId != null) {
          await ProfileImageService.instance.forceRefreshProfileImage(userId: userId);
          print('✅ STEP 4 PASSED: Image cache invalidated');
        }
      } else {
        print('✅ STEP 4 PASSED: No image cache refresh needed');
      }
      
      // STEP 5: Return and show success
      print('✅ STEP 5: Returning to profile screen...');
      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      print('');
      print('✅ EDIT PROFILE SAVE FLOW: COMPLETE');
    } catch (e, stackTrace) {
      print('❌ ERROR in EDIT PROFILE SAVE FLOW: $e');
      print('   Stack trace: $stackTrace');
      
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Helper method to get user ID from SharedPreferences or Firebase Auth
  Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getString('user_id');
      
      if (userId == null) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          userId = firebaseUser.uid;
          await prefs.setString('user_id', userId);
        }
      }
      
      return userId;
    } catch (e) {
      print('⚠️  Error getting user ID: $e');
      return null;
    }
  }
}
