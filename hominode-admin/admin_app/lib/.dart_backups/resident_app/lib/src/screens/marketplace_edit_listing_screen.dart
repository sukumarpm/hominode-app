// lib/src/screens/marketplace_edit_listing_screen.dart
// Edit marketplace listing screen

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/listing_model.dart';
import '../services/listing_firestore_service.dart';
import '../services/cloudinary_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class MarketplaceEditListingScreen extends StatefulWidget {
  final ListingModel listing;

  const MarketplaceEditListingScreen({
    super.key,
    required this.listing,
  });

  @override
  State<MarketplaceEditListingScreen> createState() =>
      _MarketplaceEditListingScreenState();
}

class _MarketplaceEditListingScreenState
    extends State<MarketplaceEditListingScreen> {
  final ListingFirestoreService _listingService = ListingFirestoreService();
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
    'Other'
  ];
  final List<String> _conditions = ['Like New', 'Good', 'Fair', 'Poor'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing.title);
    _priceController =
        TextEditingController(text: widget.listing.price.toString());
    _descriptionController =
        TextEditingController(text: widget.listing.description);
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
        title: const Text(
          'Edit Product',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
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
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusButton),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
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
        const Text(
          'Product Images',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        // Existing images
        if (_existingImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Images (${_existingImages.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _existingImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100,
                                  height: 100,
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
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
              const SizedBox(height: 12),
            ],
          ),
        // New images
        if (_newImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Images (${_newImages.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
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
              const SizedBox(height: 12),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
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
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
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
      print('❌ Error picking images: $e');
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
      print('❌ Error taking photo: $e');
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
      print('🔵 MARKETPLACE EDIT: Updating listing...');
      
      // Combine existing and new images
      List<String> allImages = [..._existingImages];

      // Upload new images if any
      if (_newImages.isNotEmpty) {
        print('🔐 STEP 1: Uploading ${_newImages.length} new images to Cloudinary...');
        
        for (int i = 0; i < _newImages.length; i++) {
          try {
            final imageUrl = await CloudinaryService.uploadImage(
              imagePath: _newImages[i].path,
              folder: 'marketplace',
              publicId: 'marketplace_${DateTime.now().millisecondsSinceEpoch}_$i',
            );
            
            if (imageUrl.isNotEmpty) {
              allImages.add(imageUrl);
              print('✅ New image ${i + 1} uploaded: $imageUrl');
            }
          } catch (e) {
            print('❌ Error uploading new image ${i + 1}: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error uploading image ${i + 1}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() => _isUpdating = false);
            return;
          }
        }
        
        print('✅ STEP 1 PASSED: All new images uploaded');
      }

      // Step 2: Update listing with all images
      print('🔐 STEP 2: Updating listing in Firestore...');
      
      final result = await _listingService.updateListing(
        listingId: widget.listing.id!,
        title: _titleController.text,
        price: int.parse(_priceController.text),
        category: _selectedCategory,
        condition: _selectedCondition,
        description: _descriptionController.text,
        images: allImages,
      );

      if (mounted) {
        setState(() => _isUpdating = false);
        
        if (result.success) {
          print('✅ STEP 2 PASSED: Listing updated successfully');
          print('✅ MARKETPLACE EDIT: Update complete');
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          print('❌ STEP 2 FAILED: ${result.message}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to update product'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ MARKETPLACE EDIT: Error updating listing: $e');
      print('   Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isUpdating = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
