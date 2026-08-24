# Bulk Upload Flats Feature

## Overview
The Bulk Upload Flats modal allows admins to upload multiple flats at once using CSV or Excel files, streamlining the data entry process.

## Features

### ✅ Visual Design
- Centered overlay with semi-transparent dark scrim (35% opacity)
- White modal card with 20px rounded corners
- Smooth fade-in + scale animation (220ms)
- Responsive: max 92% width or 720px, max 80% height
- Keyboard-safe with automatic scrolling

### ✅ Components

#### 1. Header
- **Title**: "Bulk Upload Flats" (24sp, bold)
- **Subtitle**: "Upload multiple flats using Excel or CSV file." (14sp, grey)
- **Close Button**: X icon in top-right corner

#### 2. Template Download Panel
- Light grey background (#F8F9FB)
- Upload icon on the left
- Instruction text: "Download the template, fill in flat details, and upload back."
- Fully tappable - downloads template on tap
- Shows success SnackBar when tapped

#### 3. File Upload Section
- **Label**: "Drop your file here" (17sp, bold)
- **Upload Row**: 
  - White background with grey border
  - Download icon + "Upload photo" text
  - Changes to filename when file selected
  - Shows "Change" link when file is selected
  - Fully tappable - opens file picker

#### 4. Upload Button
- Full-width blue button (#2563EB)
- Text: "Upload File"
- Disabled until file is selected (40% opacity)
- Shows loading spinner during upload
- 54px height with 12px border radius

### ✅ Validation
- Only CSV and Excel files (.csv, .xlsx) allowed
- Shows error message for invalid file types
- Red error banner below upload row
- Button disabled until valid file selected

### ✅ File Selection Flow
1. User clicks "Upload photo" row
2. Bottom sheet appears with file options:
   - flats_data.csv (CSV File • 2.4 KB)
   - flats_data.xlsx (Excel File • 5.1 KB)
3. User selects a file
4. Filename appears in upload row
5. "Change" link appears for re-selection
6. Upload button becomes enabled

### ✅ Upload Flow
1. User selects valid file
2. Clicks "Upload File" button
3. Button shows loading spinner (1 second)
4. Modal closes on success
5. Success SnackBar appears: "Flats uploaded successfully from {filename}"

## Usage

### Basic Implementation

```dart
import 'widgets/bulk_upload_modal.dart';

// Show the modal
ElevatedButton(
  onPressed: () {
    BulkUploadFlatsModal.show(
      context,
      onUploadSuccess: (file) {
        print('File uploaded: ${file.name}');
        print('File size: ${file.size} bytes');
        print('File path: ${file.path}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flats uploaded from ${file.name}'),
          ),
        );
      },
    );
  },
  child: const Text('Bulk Upload'),
);
```

### PlatformFile Structure

```dart
// From file_picker package
class PlatformFile {
  final String name;      // e.g., "flats_data.csv"
  final int size;         // File size in bytes
  final String? path;     // File path (may be null on web)
  final List<int>? bytes; // File bytes (for web)
  final String? extension; // File extension
}
```

## Integration Points

### Current Implementation ✅
- Uses `file_picker` package (v10.3.7)
- Opens native file picker on device
- Supports CSV and Excel files (.csv, .xlsx, .xls)
- Returns PlatformFile object with file details
- 1-second delay to simulate upload
- Full error handling for file selection

### File Picker Integration ✅ COMPLETE

The modal now uses the real `file_picker` package:

```dart
import 'package:file_picker/file_picker.dart';

Future<void> _pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx', 'xls'],
    allowMultiple: false,
  );
  
  if (result != null && result.files.isNotEmpty) {
    setState(() {
      _selectedFile = result.files.first;
    });
  }
}
```

#### 2. Real Template Download
Replace mock download with actual API call:

```dart
import 'package:url_launcher/url_launcher.dart';

void _downloadTemplate() async {
  final url = Uri.parse('https://your-api.com/download-template');
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  }
}
```

#### 3. Real File Upload
Replace mock upload with actual API call:

```dart
import 'package:http/http.dart' as http;

Future<bool> _uploadFile(MockFile file) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://your-api.com/upload-flats'),
    );
    
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );
    
    var response = await request.send();
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

## Error Handling

### File Type Validation
```dart
if (!fileName.endsWith('.csv') && !fileName.endsWith('.xlsx')) {
  setState(() {
    _errorMessage = 'Only CSV and Excel files are allowed';
    _selectedFile = null;
  });
  return;
}
```

### Upload Failure
```dart
try {
  await uploadFileToServer(_selectedFile!);
  // Success
} catch (e) {
  setState(() {
    _errorMessage = 'Upload failed. Please try again.';
    _isLoading = false;
  });
}
```

## Colors

| Element | Color | Hex |
|---------|-------|-----|
| Primary Blue | Button background | #2563EB |
| Dark Text | Title | #111111 |
| Grey Text | Subtitle | #6B7280 |
| Light Grey | Template panel text | #9CA3AF |
| Border Grey | Upload row border | #E5E7EB |
| Panel BG | Template panel | #F8F9FB |
| Error Red | Error messages | #EF4444 |
| Success Green | Success SnackBar | #10B981 |

## Accessibility

- ✅ Semantic labels for all interactive elements
- ✅ Minimum 44×44px touch targets
- ✅ High contrast text
- ✅ Screen reader support
- ✅ Keyboard navigation

## Testing Checklist

- [ ] Modal opens with smooth animation
- [ ] Close button closes modal
- [ ] Tap outside closes modal
- [ ] Template panel shows download message
- [ ] File picker opens on upload row tap
- [ ] Selected filename appears in upload row
- [ ] "Change" link appears after selection
- [ ] Invalid file types show error
- [ ] Upload button disabled without file
- [ ] Upload button shows loading state
- [ ] Success callback receives file data
- [ ] Success SnackBar appears
- [ ] Works on small screens
- [ ] Keyboard doesn't cover content

## Future Enhancements

- [ ] Drag and drop file support
- [ ] File preview before upload
- [ ] Progress bar during upload
- [ ] Batch upload multiple files
- [ ] Upload history/logs
- [ ] Validation of file contents
- [ ] Error reporting for invalid data
- [ ] Undo uploaded data
