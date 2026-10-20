import '../widgets/marketplace_access_gate.dart';
import 'package:resident_app/src/services/resident_private_images.dart';
// lib/src/screens/marketplace_edit_listing_screen.dart
// Edit marketplace listing screen

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/listing_model.dart';
import '../services/listing_firestore_service.dart';
import '../services/resident_image_operations.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class MarketplaceEditListingScreen extends StatelessWidget {
  const MarketplaceEditListingScreen({
    super.key,
    required this.listing,
    this.accessLoader,
  });
  final ListingModel listing;
  final MarketplaceAccessLoader? accessLoader;

  @override
  Widget build(BuildContext context) => MarketplaceAccessGate(
    loader: accessLoader,
    builder: (_) => _MarketplaceEditListingScreenContent(listing: listing),
  );
}

class _MarketplaceEditListingScreenContent extends StatefulWidget {
  final ListingModel listing;

  const _MarketplaceEditListingScreenContent({required this.listing});

  @override
  State<_MarketplaceEditListingScreenContent> createState() =>
      _MarketplaceEditListingScreenState();
}

class _MarketplaceEditListingScreenState
    extends State<_MarketplaceEditListingScreenContent> {
  final ListingFirestoreService _listingService = ListingFirestoreService();
  final _images = ResidentImageOperations();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;

  late String _selectedCategory;
  late String _selectedCondition;
  bool _isUpdating = false;
  List<String> _existingImages = [];
  final List<File> _newImages = [];

  final List<String> _categories = [
    'Furniture',
    'Electronics',
    'Appliances',
    'Books',
    'Clothing',
    'Sports',
    'Toys',
    'Home Decor',
    'Kitchen',
    'Other',
  ];
  final List<String> _conditions = ['Like New', 'Good', 'Fair', 'Poor'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing.title);
    _priceController = TextEditingController(
      text: widget.listing.price.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.listing.description,
    );
    _selectedCategory = widget.listing.category;
    _selectedCondition = widget.listing.condition;
    _existingImages = List.from(widget.listing.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Product',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Images Section
                _buildImagesSection(),
                const SizedBox(height: AppSizes.spaceBetweenSections),

                // Title
                _buildTextField(
                  label: 'Product Title',
                  controller: _titleController,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceBetweenSections),

                // Price
                _buildTextField(
                  label: 'Price (₹)',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a price';
                    }
                    if (int.tryParse(value!) == null) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceBetweenSections),

                // Category
                _buildDropdown(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                  },
                ),
                const SizedBox(height: AppSizes.spaceBetweenSections),

                // Condition
                _buildDropdown(
                  label: 'Condition',
                  value: _selectedCondition,
                  items: _conditions,
                  onChanged: (value) {
                    setState(() => _selectedCondition = value!);
                  },
                ),
                const SizedBox(height: AppSizes.spaceBetweenSections),

                // Description
                _buildTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  maxLines: 5,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceBetweenSections),

                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeightPrimary,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _updateListing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusButton,
                        ),
                      ),
                    ),
                    child: _isUpdating
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
                        : const Text('Update Product'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12.h),
        // Existing images
        if (_existingImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Images (${_existingImages.length})',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                height: 100.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: Image(
                              image: residentImageProvider(
                                _existingImages[index],
                              ),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100.w,
                                  height: 100.h,
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey.shade400,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _existingImages.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                padding: EdgeInsets.all(4.w),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16.w,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        // New images
        if (_newImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Images (${_newImages.length})',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                height: 100.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: Image.file(
                              _newImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _newImages.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                padding: EdgeInsets.all(4.w),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16.w,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        // Add images button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image),
                label: const Text('Add Images'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImages.addAll(
            pickedFiles.map((file) => File(file.path)).toList(),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _newImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final allImages = [..._existingImages];
      for (final image in _newImages) {
        allImages.add(
          await _images.upload(
            feature: 'marketplace',
            resourceId: widget.listing.id!,
            imagePath: image.path,
          ),
        );
      }
      final result = await _listingService.updateListing(
        listingId: widget.listing.id!,
        title: _titleController.text,
        price: int.parse(_priceController.text),
        category: _selectedCategory,
        condition: _selectedCondition,
        description: _descriptionController.text,
        images: allImages,
        expectedImageRevision: widget.listing.imageRevision,
      );

      if (mounted) {
        setState(() => _isUpdating = false);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to update product'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to save images. Please retry.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
