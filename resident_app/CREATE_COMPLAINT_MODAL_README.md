# Create New Complaint Modal - Implementation Guide

## Overview
Pixel-perfect centered modal overlay for creating new complaints, matching the design screenshot exactly with full validation, image upload support, and production-ready code.

## File Location
```
lib/src/modals/create_complaint_modal.dart
```

## Features

### ✅ UI Components
- **Centered Modal**: 90% screen width with rounded corners and shadow
- **Header**: "Create New Complaint" title with close button
- **Category Dropdown**: Opens picker dialog with all categories
- **Title Input**: Single-line text field with validation
- **Description Textarea**: Multi-line input (max 1000 chars) with counter
- **Photo Upload**: Optional image attachment with preview and remove
- **Submit Button**: Disabled until form is valid, shows loading state

### ✅ Validation
- Category: Required
- Title: Required, minimum 5 characters
- Description: Required, minimum 10 characters, maximum 1000 characters
- Inline error messages below each field
- Real-time validation on field change

### ✅ User Experience
- Fade + scale entrance animation
- Keyboard-safe scrolling
- Auto-dismiss on successful submission
- Success/error SnackBar feedback
- Loading state during submission
- Accessible tap targets (44×44 px minimum)

## Usage

### Basic Integration
```dart
import 'package:flutter/material.dart';
import 'src/modals/create_complaint_modal.dart';

// From FAB or button
FloatingActionButton(
  onPressed: () {
    showCreateComplaintModal(
      context,
      onCreated: (complaint) {
        // Refresh complaints list
        setState(() {
          complaints.insert(0, complaint);
        });
      },
    );
  },
  child: const Icon(Icons.add),
)
```

### With Custom Callback
```dart
showCreateComplaintModal(
  context,
  onCreated: (complaint) {
    print('New complaint created: ${complaint.id}');
    // Navigate to detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintDetailScreen(complaint: complaint),
      ),
    );
  },
);
```

## Form Fields

### 1. Category (Required)
- Dropdown selector
- Opens modal dialog with all categories
- Shows icon and name for each category
- Categories: Plumbing, Electrical, Maintenance, Cleaning, Security, Other

### 2. Title (Required)
- Single-line text input
- Placeholder: "Brief description"
- Validation: Minimum 5 characters
- Example: "Water Leakage in Bathroom"

### 3. Description (Required)
- Multi-line textarea (6 lines visible)
- Placeholder: "Detailed description"
- Character counter (max 1000)
- Validation: Minimum 10 characters
- Auto-scrolls when content exceeds visible area

### 4. Attach Photo (Optional)
- Large upload box with icon
- Tapping opens image picker (camera/gallery)
- Shows thumbnail preview after selection
- Remove button (X) to clear selection
- **Note**: Requires `image_picker` package (see Integration section)

## Validation Rules

| Field | Rule | Error Message |
|-------|------|---------------|
| Category | Required | "Please select a category" |
| Title | Required | "Title is required" |
| Title | Min 5 chars | "Title must be at least 5 characters" |
| Description | Required | "Description is required" |
| Description | Min 10 chars | "Description must be at least 10 characters" |
| Description | Max 1000 chars | "Description must not exceed 1000 characters" |

## Image Upload Integration

### Add image_picker Package
```yaml
# pubspec.yaml
dependencies:
  image_picker: ^1.0.4
```

### Update Permissions

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to attach photos to complaints</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to attach photos to complaints</string>
```

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### Implement Image Picker
Replace the mock `_pickImage()` method in `create_complaint_modal.dart`:

```dart
import 'package:image_picker/image_picker.dart';

Future<void> _pickImage() async {
  final picker = ImagePicker();
  
  // Show source selection dialog
  final source = await showDialog<ImageSource>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Select Image Source'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  
  if (source != null) {
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _attachedImage = File(image.path);
      });
    }
  }
}
```

## Backend Integration

### Update ComplaintsService
Replace the mock implementation in `complaints_service.dart`:

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ComplaintsService {
  final String baseUrl = 'https://your-api.com/api';
  
  Future<Complaint> createComplaint({
    required String title,
    required String description,
    required ComplaintCategory category,
    File? image,
  }) async {
    // Upload image first if provided
    String? imageUrl;
    if (image != null) {
      imageUrl = await _uploadImage(image);
    }
    
    // Create complaint
    final response = await http.post(
      Uri.parse('$baseUrl/complaints'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_TOKEN',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category.name,
        'imageUrl': imageUrl,
      }),
    );
    
    if (response.statusCode == 201) {
      return Complaint.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create complaint');
    }
  }
  
  Future<String> _uploadImage(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', image.path));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final json = jsonDecode(responseData);
      return json['url'];
    } else {
      throw Exception('Failed to upload image');
    }
  }
}
```

### API Endpoints

**POST /complaints**
```json
Request:
{
  "title": "Water Leakage in Bathroom",
  "description": "There is water leaking from the bathroom tap continuously",
  "category": "plumbing",
  "imageUrl": "https://cdn.example.com/images/complaint_123.jpg"
}

Response (201 Created):
{
  "id": "complaint_123",
  "title": "Water Leakage in Bathroom",
  "description": "There is water leaking from the bathroom tap continuously",
  "category": "plumbing",
  "status": "pending",
  "createdDate": "2025-11-14T10:30:00Z",
  "assignedTo": null,
  "technicianPhone": null,
  "imageUrl": "https://cdn.example.com/images/complaint_123.jpg"
}
```

**POST /upload**
```
Request: multipart/form-data with 'file' field

Response (200 OK):
{
  "url": "https://cdn.example.com/images/complaint_123.jpg"
}
```

## Customization

### Colors
Edit constants at top of file:
```dart
const Color kPrimary = Color(0xFF2563EB);  // Primary blue
const Color kInputBorder = Color(0xFFE6E6E6);  // Input borders
const Color kPlaceholderText = Color(0xFFBDBDBD);  // Placeholder text
```

### Validation Rules
Modify `validateFields()` method:
```dart
Map<String, String?> validateFields() {
  final errors = <String, String?>{};
  
  // Change minimum title length
  if (_titleController.text.trim().length < 10) {
    errors['title'] = 'Title must be at least 10 characters';
  }
  
  // Add custom validation
  if (_titleController.text.contains('test')) {
    errors['title'] = 'Test complaints are not allowed';
  }
  
  return errors;
}
```

### Add More Fields
```dart
// Add new field in state
String? _selectedPriority;

// Add field in form
_buildPriorityField(),

// Add validation
if (_selectedPriority == null) {
  errors['priority'] = 'Please select priority';
}
```

## Testing

### Manual Test Flow
1. Open complaints screen
2. Tap FAB (+) button
3. Modal appears centered with fade+scale animation
4. Try submitting without filling fields → See validation errors
5. Select category → Error clears
6. Enter title (less than 5 chars) → See error
7. Enter valid title → Error clears
8. Enter description → Character counter updates
9. Tap "Upload photo" → See placeholder message (or picker if implemented)
10. Fill all required fields → Submit button enables
11. Tap submit → Loading spinner shows
12. Success → Modal closes, SnackBar appears, complaint added to list

### Unit Tests
```dart
// test/create_complaint_modal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/modals/create_complaint_modal.dart';

void main() {
  group('Validation Tests', () {
    test('validateFields returns error for empty category', () {
      // Test validation logic
    });
    
    test('validateFields returns error for short title', () {
      // Test validation logic
    });
    
    test('isFormValid returns true when all fields valid', () {
      // Test form validity
    });
  });
}
```

## Accessibility

- All tap targets meet 44×44 px minimum
- Text fields have proper labels and hints
- Error messages announced by screen readers
- Keyboard navigation supported
- Color contrast meets WCAG AA standards

## Assets Required

Uses Material Icons (no external assets needed):
- `Icons.close` - Close button
- `Icons.keyboard_arrow_down` - Dropdown caret
- `Icons.file_upload_outlined` - Upload icon
- Category icons (water_drop, bolt, build, etc.)

## Troubleshooting

### Modal doesn't appear
- Ensure you're calling `showCreateComplaintModal(context, ...)`
- Check that context is valid (from a widget in the tree)

### Validation not working
- Check that `isFormValid()` is being called
- Verify `_errors` map is being updated in `setState()`

### Image picker not working
- Add `image_picker` package to pubspec.yaml
- Configure platform permissions (iOS/Android)
- Replace mock `_pickImage()` with real implementation

### Submit button stays disabled
- Check all validation rules are passing
- Verify `isFormValid()` returns true
- Ensure `setState()` is called after field changes

## Next Steps

1. ✅ Modal is integrated with complaints screen
2. 🔄 Add `image_picker` package for photo uploads
3. 🔄 Configure camera/gallery permissions
4. 🔄 Replace mock `ComplaintsService` with real API
5. 🔄 Add image upload to backend
6. 🔄 (Optional) Add priority field
7. 🔄 (Optional) Add location/unit number field
8. 🔄 (Optional) Add voice note attachment

---

**File**: `lib/src/modals/create_complaint_modal.dart`  
**Assets**: Material Icons (built-in)  
**Usage**: `showCreateComplaintModal(context, onCreated: (complaint) { /* refresh */ });`
