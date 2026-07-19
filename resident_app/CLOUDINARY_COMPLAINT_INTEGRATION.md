# Cloudinary Image Upload - Complaint Integration

## Problem Fixed
Images were uploading to Cloudinary and saving URLs to Firestore, but not displaying in the complaint detail modal.

## Solution
Added image display in the complaint detail modal that fetches the `imageUrl` from Firestore and displays it.

## How It Works Now

### Flow
1. User creates complaint
2. User uploads image via `ImageUploadWidget`
3. Image uploads to Cloudinary
4. URL saved to Firestore in `complaints/{complaintId}/imageUrl`
5. When viewing complaint details, image displays in modal

### Updated Files

#### 1. complaint_detail_modal.dart
- Added `_buildImageSection()` method
- Fetches `imageUrl` from Firestore
- Displays image with caching and error handling
- Shows in complaint detail modal

#### 2. pubspec.yaml
- Added `cached_network_image: ^3.3.0` for image caching

## Integration Steps

### Step 1: Update Create Complaint Modal
Add image upload widget to your complaint creation modal:

```dart
// In create_complaint_modal.dart or your complaint form

ImageUploadWidget(
  collectionPath: 'complaints',
  documentId: complaintId, // Create complaint first, then upload image
  fieldName: 'imageUrl',
  folder: 'complaints',
  onUploadSuccess: (url) {
    print('Image uploaded: $url');
    // Image is already saved to Firestore
  },
  onUploadError: (error) {
    print('Upload failed: $error');
  },
)
```

### Step 2: Create Complaint First
Before uploading image, create the complaint document:

```dart
// Create complaint in Firestore first
final complaintRef = await FirebaseFirestore.instance
    .collection('complaints')
    .add({
  'title': title,
  'description': description,
  'category': category,
  'createdDate': DateTime.now(),
  'status': 'pending',
  // Don't add imageUrl yet - it will be added by ImageUploadWidget
});

final complaintId = complaintRef.id;

// Now show image upload widget with this complaintId
```

### Step 3: Display Image in Complaint Details
The image will automatically display in the complaint detail modal. No additional code needed - it's already implemented in `_buildImageSection()`.

## Firestore Structure

```
complaints/
  complaint_123/
    title: "Broken window"
    description: "..."
    category: "maintenance"
    status: "pending"
    createdDate: Timestamp
    imageUrl: "https://res.cloudinary.com/de8yccofb/image/upload/..."
    imageUrlMetadata: {
      publicId: "complaints/abc123",
      width: 1920,
      height: 1080,
      size: 245000,
      format: "jpg",
      uploadedAt: "2024-03-14T..."
    }
    updatedAt: Timestamp
```

## Complete Example: Complaint Creation with Image

```dart
class CreateComplaintWithImageScreen extends StatefulWidget {
  @override
  State<CreateComplaintWithImageScreen> createState() =>
      _CreateComplaintWithImageScreenState();
}

class _CreateComplaintWithImageScreenState
    extends State<CreateComplaintWithImageScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _complaintId;
  String? _uploadedImageUrl;
  bool _isCreating = false;

  Future<void> _createComplaint() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create complaint document first
      final complaintRef = await FirebaseFirestore.instance
          .collection('complaints')
          .add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': 'maintenance',
        'status': 'pending',
        'createdDate': DateTime.now(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });

      setState(() {
        _complaintId = complaintRef.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint created. Now upload image.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Complaint Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createComplaint,
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Complaint'),
              ),
            ),
            const SizedBox(height: 24),

            // Image upload section (only after complaint created)
            if (_complaintId != null) ...[
              const Divider(),
              const SizedBox(height: 24),
              const Text(
                'Attach Image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_uploadedImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _uploadedImageUrl!,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('No image selected'),
                  ),
                ),
              const SizedBox(height: 16),
              ImageUploadWidget(
                collectionPath: 'complaints',
                documentId: _complaintId!,
                fieldName: 'imageUrl',
                folder: 'complaints',
                includeMetadata: true,
                onUploadSuccess: (url) {
                  setState(() {
                    _uploadedImageUrl = url;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Image uploaded successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                onUploadError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
```

## Testing the Flow

1. **Create Complaint**
   - Fill title and description
   - Click "Create Complaint"
   - Note the complaint ID

2. **Upload Image**
   - Click "Gallery" or "Camera"
   - Select/take image
   - Wait for upload to complete
   - Image URL appears in Firestore

3. **View Complaint**
   - Go to complaints list
   - Click on complaint
   - Image displays in detail modal

## Troubleshooting

### Image Not Showing
- Check Firestore: `complaints/{id}/imageUrl` should have a URL
- Check URL is valid: Open in browser
- Check internet connection
- Check Cloudinary account is active

### Upload Fails
- Check image file exists
- Check Cloudinary credentials in `cloudinary_service.dart`
- Check Firestore permissions
- Check network connectivity

### Slow Image Loading
- Images are cached locally
- First load may be slower
- Subsequent loads use cache

## Security Notes

- Images are stored in Cloudinary (not Firestore)
- URLs are public (no authentication needed to view)
- For private images, use signed URLs
- Implement rate limiting on backend

## Next Steps

1. Add image upload to marketplace listings
2. Add image upload to profile pictures
3. Add image deletion functionality
4. Add image transformations (thumbnails, resizing)
5. Add multiple image support
