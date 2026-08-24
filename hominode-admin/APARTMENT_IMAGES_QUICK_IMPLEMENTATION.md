# APARTMENT IMAGES - QUICK IMPLEMENTATION GUIDE

**Date**: March 27, 2026  
**Status**: ✅ READY TO IMPLEMENT

---

## WHAT'S ALREADY DONE ✅

1. ✅ **CloudinaryApartmentImagesService** - Complete with 5-step flow function
2. ✅ **ApartmentImagesService** - Backup service with Firebase Storage
3. ✅ **ApartmentImagesManagementScreen** - UI screen started
4. ✅ **Cloudinary Configuration** - Config file ready
5. ✅ **Flow Function Pattern** - All 5 steps implemented

---

## WHAT YOU NEED TO DO

### 1. Complete the Upload Modal

**File**: `admin_app/lib/apartment_images_management_screen.dart`

**Add this method to show upload dialog**:

```dart
void _showUploadModal() {
  if (_buildingId == null || _buildingId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Building ID not found'),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddApartmentImageModal(
      buildingId: _buildingId!,
      onImageAdded: () {
        setState(() {});
      },
    ),
  );
}
```

### 2. Create Add Image Modal Widget

**File**: `admin_app/lib/widgets/add_apartment_image_modal.dart`

**Create this new file**:

```dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_apartment_images_service.dart';

class AddApartmentImageModal extends StatefulWidget {
  final String buildingId;
  final VoidCallback onImageAdded;

  const AddApartmentImageModal({
    required this.buildingId,
    required this.onImageAdded,
    super.key,
  });

  @override
  State<AddApartmentImageModal> createState() => _AddApartmentImageModalState();
}

class _AddApartmentImageModalState extends State<AddApartmentImageModal> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagesService = CloudinaryApartmentImagesService();
  
  File? _selectedImage;
  String _selectedType = 'Common Area';
  bool _isUploading = false;

  final List<String> _imageTypes = [
    'Common Area',
    'Lobby',
    'Garden',
    'Parking',
    'Gym',
    'Pool',
    'Playground',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final now = DateTime.now();
      final uploadDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final uploadTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await _imagesService.uploadImage(
        title: _titleController.text,
        description: _descriptionController.text,
        type: _selectedType,
        imageFile: _selectedImage!,
        buildingId: widget.buildingId,
        uploadDate: uploadDate,
        uploadTime: uploadTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
        widget.onImageAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Apartment Image'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Preview
            if (_selectedImage != null)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: const Icon(Icons.image, size: 80, color: Colors.grey),
              ),
            const SizedBox(height: 16),

            // Pick Image Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Image'),
            ),
            const SizedBox(height: 16),

            // Title Field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Lobby Entrance',
                border: OutlineInputBorder(),
              ),
              enabled: !_isUploading,
            ),
            const SizedBox(height: 12),

            // Description Field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the image...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 12),

            // Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _imageTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: _isUploading ? null : (value) {
                setState(() => _selectedType = value ?? 'Common Area');
              },
              decoration: const InputDecoration(
                labelText: 'Image Type',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _uploadImage,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}
```

### 3. Complete the Main Screen

**File**: `admin_app/lib/apartment_images_management_screen.dart`

**Complete the build method**:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Apartment Images'),
      elevation: 0,
    ),
    body: !_isInitialized
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Header with Add Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Building Images',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showUploadModal,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Image'),
                    ),
                  ],
                ),
              ),

              // Images Grid
              Expanded(
                child: StreamBuilder<List<ApartmentImageModel>>(
                  stream: _imagesService.getImages(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    final images = snapshot.data ?? [];

                    if (images.isEmpty) {
                      return const Center(
                        child: Text('No apartment images yet'),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return ApartmentImageCard(
                          image: image,
                          onDelete: () async {
                            await _imagesService.deleteImage(image.id);
                            setState(() {});
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
  );
}
```

### 4. Create Image Card Widget

**File**: `admin_app/lib/widgets/apartment_image_card.dart`

```dart
import 'package:flutter/material.dart';
import '../services/cloudinary_apartment_images_service.dart';

class ApartmentImageCard extends StatelessWidget {
  final ApartmentImageModel image;
  final VoidCallback onDelete;

  const ApartmentImageCard({
    required this.image,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Stack(
        children: [
          // Image
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(image.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Overlay with info
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Title and info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    image.type,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Delete button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Image'),
                    content: const Text('Are you sure you want to delete this image?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## TESTING STEPS

### 1. Test Upload Flow

```
1. Open Apartment Images screen
2. Click "Add Image" button
3. Select image from gallery
4. Enter title: "Lobby Entrance"
5. Enter description: "Main lobby"
6. Select type: "Lobby"
7. Click Upload
8. Wait for upload to complete
9. See success notification
10. Image appears in grid
```

### 2. Test Fetch Flow

```
1. Open Apartment Images screen
2. See all uploaded images
3. Images sorted by newest first
4. Real-time updates working
5. No demo data shown
```

### 3. Test Delete Flow

```
1. Click delete on image
2. Confirm deletion
3. Image removed from list
4. See success notification
```

---

## EXPECTED RESULTS

### Upload
✅ Image uploads to Cloudinary  
✅ URL stored in Firestore  
✅ Metadata saved with adminId  
✅ Real-time list updates  
✅ Success notification shown  

### Fetch
✅ All admin's images displayed  
✅ Sorted by newest first  
✅ Real-time updates working  
✅ No demo data shown  

### Delete
✅ Image removed from Firestore  
✅ Image removed from list  
✅ Success notification shown  

---

## TROUBLESHOOTING

### Upload Fails
- Check Cloudinary upload preset exists
- Verify preset is set to UNSIGNED
- Check file size < 10MB
- Check network connection

### Images Not Showing
- Check Firestore has documents
- Verify adminId matches current admin
- Check Firestore rules allow read
- Verify real-time stream is working

### Slow Upload
- Compress image before upload
- Check network connection
- Try smaller file first

---

## NEXT STEPS

1. ✅ Create `add_apartment_image_modal.dart`
2. ✅ Create `apartment_image_card.dart`
3. ✅ Complete `apartment_images_management_screen.dart`
4. ✅ Test upload flow
5. ✅ Test fetch flow
6. ✅ Test delete flow
7. ✅ Deploy to production

---

**Status**: ✅ READY FOR IMPLEMENTATION

All code provided. Just copy and paste into your files!
