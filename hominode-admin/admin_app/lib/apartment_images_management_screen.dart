import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/standard_header.dart';
import 'services/cloudinary_apartment_images_service.dart';
import 'services/admin_service.dart';
import 'services/admin_tenant_context.dart';
import 'services/firebase_image_upload_service.dart';
import 'widgets/private_apartment_image.dart';

class ApartmentImagesManagementScreen extends StatefulWidget {
  const ApartmentImagesManagementScreen({super.key});

  @override
  State<ApartmentImagesManagementScreen> createState() =>
      _ApartmentImagesManagementScreenState();
}

class _ApartmentImagesManagementScreenState
    extends State<ApartmentImagesManagementScreen> {
  final CloudinaryApartmentImagesService _imagesService =
      CloudinaryApartmentImagesService();
  final AdminService _adminService = AdminService();
  bool _isInitialized = false;
  Stream<List<ApartmentImageModel>>? _images;
  StreamSubscription<User?>? _authSubscription;
  late final ApartmentImageCache _cache = ApartmentImageCache(
    read: FirebaseImageUploadService().read,
    revalidate: FirebaseImageUploadService().authorizeRead,
    scope: () {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final community = AdminTenantContext.instance.communityId;
      return uid == null || community == null ? null : '$uid/$community';
    },
  );
  int _initialization = 0;
  String? _buildingId;

  @override
  void initState() {
    super.initState();
    AdminTenantContext.instance.addListener(_scopeChanged);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (_) => _scopeChanged(),
    );
    _initializeScreen();
  }

  void _scopeChanged() {
    _cache.clear();
    if (!mounted) return;
    setState(() {
      _images = null;
      _buildingId = null;
      _isInitialized = false;
    });
    _initializeScreen();
  }

  @override
  void dispose() {
    AdminTenantContext.instance.removeListener(_scopeChanged);
    _authSubscription?.cancel();
    _cache.clear();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final attempt = ++_initialization;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final community = AdminTenantContext.instance.communityId;
    if (uid == null || community == null) return;
    final buildingIds = await _adminService.getAdminBuildingIds();
    if (!mounted ||
        attempt != _initialization ||
        uid != FirebaseAuth.instance.currentUser?.uid ||
        community != AdminTenantContext.instance.communityId) {
      return;
    }
    setState(() {
      _buildingId = buildingIds.isEmpty ? null : buildingIds.first;
      _images = _imagesService.getImages();
      _isInitialized = true;
    });
  }

  void _showUploadModal([ApartmentImageModel? replacing]) {
    if (_buildingId == null || _buildingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Building ID not found. Please ensure your profile is set up correctly.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => AddApartmentImageModal(
        buildingId: replacing?.buildingId ?? _buildingId!,
        replacing: replacing,
        onImageAdded: (imageId) {
          // UI will update automatically via StreamBuilder
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Apartment Images'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'Manage apartment and common area images',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: ElevatedButton.icon(
                    onPressed: _showUploadModal,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4778),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
          _buildImagesList(),
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }

  Widget _buildImagesList() {
    return StreamBuilder<List<ApartmentImageModel>>(
      stream: _images,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48.w,
                      color: const Color(0xFFEF4444),
                    ),
                    SizedBox(height: 16.h),
                    const Text(
                      'Unable to load images. Please reopen this page.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 56.w,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No images yet',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Upload your first apartment image to get started',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Lazy cards keep off-screen images out of the decoded-image cache.
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                key: ValueKey(images[index].id),
                padding: EdgeInsets.only(bottom: 16.h),
                child: _buildImageCard(images[index]),
              ),
              childCount: images.length,
              addAutomaticKeepAlives: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCard(ApartmentImageModel image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.r),
              topRight: Radius.circular(12.r),
            ),
            child: image.imageAsset != null
                ? PrivateApartmentImage(
                    key: ValueKey(image.imageAsset!.assetId),
                    asset: image.imageAsset!,
                    cache: _cache,
                  )
                : Image.network(
                    image.imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200.h,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
          ),
          // Image Details
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        image.title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Date and Time Display
                if (image.uploadDate.isNotEmpty || image.uploadTime.isNotEmpty)
                  Row(
                    children: [
                      if (image.uploadDate.isNotEmpty) ...[
                        Icon(
                          Icons.calendar_today,
                          size: 14.w,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          image.uploadDate,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if (image.uploadDate.isNotEmpty &&
                          image.uploadTime.isNotEmpty)
                        SizedBox(width: 12.w),
                      if (image.uploadTime.isNotEmpty) ...[
                        Icon(
                          Icons.access_time,
                          size: 14.w,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          image.uploadTime,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        image.type,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF0E4778),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Replace image',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showUploadModal(image),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                      ),
                      onPressed: () => _deleteImage(image),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteImage(ApartmentImageModel image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text('Are you sure you want to delete "${image.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _imagesService.deleteImage(
        image.id,
        expectedRevision: image.revision,
      );
      _cache.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
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
    }
  }
}

// ==================== Add Apartment Image Modal ====================
class AddApartmentImageModal extends StatefulWidget {
  final String buildingId;
  final ApartmentImageModel? replacing;
  final CloudinaryApartmentImagesService? imagesService;
  final Future<File?> Function()? pickImage;
  final Function(String) onImageAdded;

  const AddApartmentImageModal({
    super.key,
    required this.buildingId,
    this.replacing,
    this.imagesService,
    this.pickImage,
    required this.onImageAdded,
  });

  @override
  State<AddApartmentImageModal> createState() => _AddApartmentImageModalState();
}

class _AddApartmentImageModalState extends State<AddApartmentImageModal> {
  late final CloudinaryApartmentImagesService _imagesService =
      widget.imagesService ?? CloudinaryApartmentImagesService();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  bool _isUploading = false;
  bool _isImageSelected = false;
  String? _imageError;

  final DateTime _uploadDateTime = DateTime.now();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateController.text =
        widget.replacing?.uploadDate ??
        '${_uploadDateTime.day.toString().padLeft(2, '0')}-${_uploadDateTime.month.toString().padLeft(2, '0')}-${_uploadDateTime.year}';
    _timeController.text = widget.replacing?.uploadTime ?? '';
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _imageError = null;
      });

      final File? pickedFile;
      if (widget.pickImage != null) {
        pickedFile = await widget.pickImage!();
      } else {
        final selected = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 4096,
          maxHeight: 4096,
        );
        pickedFile = selected == null ? null : File(selected.path);
      }
      if (!mounted) return;

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
          _isImageSelected = true;
          _imageError = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image selected successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imageError = 'Failed to select image. Please try again.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.replacing == null) {
      _timeController.text = TimeOfDay.fromDateTime(
        _uploadDateTime,
      ).format(context);
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      setState(() {
        _imageError = 'Please select an image';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _imageError = null;
    });

    try {
      final imageId = await _imagesService.uploadImage(
        title:
            widget.replacing?.title ??
            'Apartment Image ${DateTime.now().millisecondsSinceEpoch}',
        description: 'Apartment image',
        type: 'Common Area',
        imageFile: _selectedImage!,
        buildingId: widget.buildingId,
        replacing: widget.replacing,
        uploadDate: _dateController.text,
        uploadTime: _timeController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        widget.onImageAdded(imageId);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _imageError = e is ArgumentError
              ? '${e.message}'
              : 'The image could not be saved. Retry to check the result, or reopen this form if the problem continues.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to save image. Please retry.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20.w),
        child: Container(
          constraints: BoxConstraints(maxHeight: 500.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),

              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.h),

                      // Upload Photo
                      _buildFieldLabel('Upload Image'),
                      SizedBox(height: 8.h),
                      _buildUploadButton(),

                      SizedBox(height: 20.h),

                      // Date & Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Date'),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _dateController,
                                  placeholder: 'dd-mm-yyyy',
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Time'),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _timeController,
                                  placeholder: '-- : --',
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),

              // Upload Button
              _buildUploadActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.replacing == null
                      ? 'Add Apartment Image'
                      : 'Replace Apartment Image',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Upload apartment images',
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isUploading ? null : () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8.w),
              child: Icon(Icons.close, size: 20.w, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(fontSize: 14.sp, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
          suffixIcon: readOnly && (onTap != null || widget.replacing == null)
              ? Icon(
                  controller == _dateController
                      ? Icons.calendar_today
                      : Icons.access_time,
                  size: 18.w,
                  color: const Color(0xFF6B7280),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: _imageError != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isImageSelected
                      ? Icons.check_circle_outline
                      : Icons.file_download_outlined,
                  size: 20.w,
                  color: _isImageSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                ),
                SizedBox(width: 8.w),
                Text(
                  _isImageSelected ? 'Image selected' : 'Upload image',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _isImageSelected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Show selected image preview
        if (_isImageSelected && _selectedImage != null) ...[
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.file(
              _selectedImage!,
              cacheWidth: 1024,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, color: Color(0xFF9CA3AF), size: 32.w),
                      SizedBox(height: 4.h),
                      Text(
                        'Image Preview',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Image preview',
                style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
              ),
              GestureDetector(
                onTap: _isUploading
                    ? null
                    : () {
                        setState(() {
                          _isImageSelected = false;
                          _selectedImage = null;
                          _imageError = null;
                        });
                      },
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Show error message
        if (_imageError != null) ...[
          SizedBox(height: 8.h),
          Text(
            _imageError!,
            style: TextStyle(fontSize: 12.sp, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadActionButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: _isUploading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                widget.replacing == null ? 'Upload Image' : 'Replace Image',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
