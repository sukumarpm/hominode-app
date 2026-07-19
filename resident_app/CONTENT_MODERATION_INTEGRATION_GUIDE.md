# Content Moderation - Integration Guide

## Quick Start

### Step 1: Import the Service
```dart
import 'package:resident_app/src/services/content_moderation_service.dart';
import 'package:resident_app/src/modals/content_moderation_dialog.dart';
```

### Step 2: Check Content Before Saving
```dart
// Check if content is safe
final moderationResult = await ContentModerationService().checkContent(
  text: userContent,
  imageFile: selectedImage, // Optional
);

if (!moderationResult.isSafe) {
  // Show warning dialog
  await ContentModerationDialog.showContentNotAllowedDialog(
    context,
    message: moderationResult.reason,
  );
  return; // Don't save
}

// Content is safe - proceed with saving
```

## Integration in Each Section

### 1. Community Wall - Create Post

**File**: `lib/src/screens/community_wall_screen.dart` (or wherever posts are created)

```dart
Future<void> _createPost() async {
  final content = _contentController.text.trim();
  
  if (content.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter content')),
    );
    return;
  }

  // Show scanning dialog
  ContentModerationDialog.showScanningDialog(context);

  // Check moderation
  final result = await _postService.createPost(content: content);
  
  Navigator.pop(context); // Close scanning dialog

  if (!result.success) {
    if (result.data == 'MODERATION_BLOCKED') {
      // Show moderation warning
      await ContentModerationDialog.showContentNotAllowedDialog(
        context,
        message: result.message ?? 'Content not allowed',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Error')),
      );
    }
    return;
  }

  // Success
  _contentController.clear();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Post created successfully')),
  );
}
```

### 2. Community Wall - Add Comment

**File**: `lib/src/screens/comments_screen.dart` (or wherever comments are added)

```dart
Future<void> _addComment() async {
  final comment = _commentController.text.trim();
  
  if (comment.isEmpty) return;

  // Show scanning dialog
  ContentModerationDialog.showScanningDialog(context);

  // Check moderation
  final result = await _postService.addComment(
    postId: widget.postId,
    comment: comment,
  );
  
  Navigator.pop(context); // Close scanning dialog

  if (!result.success) {
    if (result.data == 'MODERATION_BLOCKED') {
      await ContentModerationDialog.showContentNotAllowedDialog(
        context,
        message: result.message ?? 'Comment not allowed',
      );
    }
    return;
  }

  _commentController.clear();
}
```

### 3. Marketplace - Create Listing

**File**: `lib/src/screens/marketplace_create_listing_screen.dart`

```dart
Future<void> _createListing() async {
  // Validate inputs
  if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all fields')),
    );
    return;
  }

  // Show scanning dialog
  ContentModerationDialog.showScanningDialog(context);

  // Check moderation
  final result = await _listingService.createListing(
    title: _titleController.text,
    price: int.parse(_priceController.text),
    category: _selectedCategory,
    condition: _selectedCondition,
    description: _descriptionController.text,
    images: _selectedImages,
  );
  
  Navigator.pop(context); // Close scanning dialog

  if (!result.success) {
    if (result.data == 'MODERATION_BLOCKED') {
      await ContentModerationDialog.showContentNotAllowedDialog(
        context,
        message: result.message ?? 'Listing content not allowed',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Error')),
      );
    }
    return;
  }

  // Success
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Listing created successfully')),
  );
}
```

### 4. Messages - Send Message

**File**: `lib/src/screens/chat_conversation_screen.dart` (or wherever messages are sent)

```dart
Future<void> _sendMessage() async {
  final message = _messageController.text.trim();
  
  if (message.isEmpty) return;

  // Check moderation
  final moderationResult = await ContentModerationService().checkContent(
    text: message,
  );

  if (!moderationResult.isSafe) {
    await ContentModerationDialog.showContentNotAllowedDialog(
      context,
      message: moderationResult.reason,
    );
    return;
  }

  // Send message (your existing code)
  await _chatService.sendMessage(
    conversationId: widget.conversationId,
    message: message,
  );

  _messageController.clear();
}
```

## Error Handling

### Check for Moderation Block
```dart
if (result.data == 'MODERATION_BLOCKED') {
  // Content was blocked by moderation
  // Show warning dialog
} else if (!result.success) {
  // Other error (network, auth, etc.)
  // Show generic error
}
```

### Custom Error Messages
```dart
// You can customize the warning message
final customMessage = result.message ?? 'Your content violates community guidelines';

await ContentModerationDialog.showContentNotAllowedDialog(
  context,
  message: customMessage,
);
```

## Testing Content

### Test Banned Keywords
```
❌ Blocked: "I want to buy cocaine"
❌ Blocked: "Selling fake IDs"
❌ Blocked: "Let's hack the system"
✅ Allowed: "I want to buy a used phone"
✅ Allowed: "Great apartment for rent"
```

### Test Case Insensitivity
```
❌ Blocked: "COCAINE"
❌ Blocked: "Cocaine"
❌ Blocked: "cocaine"
```

### Test Multiple Keywords
```
❌ Blocked: "Selling drugs and weapons"
✅ Allowed: "Selling books and toys"
```

## Performance Considerations

1. **Text Moderation**: Instant (< 100ms)
2. **Image Moderation**: 1-2 seconds per image
3. **Caching**: Consider caching moderation results for identical content
4. **Batch Processing**: For bulk operations, process in batches

## Customization

### Add More Keywords
Edit `lib/src/services/content_moderation_service.dart`:
```dart
static const List<String> bannedKeywords = [
  // ... existing keywords
  'newkeyword1',
  'newkeyword2',
];
```

### Adjust Image Confidence Threshold
```dart
final imageLabeler = GoogleMlKit.vision.imageLabeler(
  options: ImageLabelerOptions(
    confidenceThreshold: 0.7, // Increase for stricter filtering
  ),
);
```

### Customize Warning Dialog
Edit `lib/src/modals/content_moderation_dialog.dart` to change:
- Dialog title
- Warning message
- Button text
- Colors and styling

## Troubleshooting

### Image Scanning Not Working
- Ensure Google ML Kit is properly configured
- Check that image file exists and is readable
- Verify image format is supported (JPG, PNG, etc.)

### Keywords Not Detected
- Check keyword spelling in banned list
- Ensure text is being converted to lowercase
- Verify keyword is in the list

### Dialog Not Showing
- Ensure BuildContext is valid
- Check that showDialog is awaited
- Verify dialog code has no syntax errors

## Build & Run

```bash
# Ensure dependencies are installed
flutter pub get

# Run the app
flutter run

# Test moderation
# 1. Create a post with banned keyword
# 2. Verify warning dialog appears
# 3. Verify post is not saved
```

## Files Modified

1. ✅ `lib/src/services/content_moderation_service.dart` - Created
2. ✅ `lib/src/modals/content_moderation_dialog.dart` - Created
3. ✅ `lib/src/services/post_firestore_service.dart` - Updated
4. ✅ `lib/src/services/listing_firestore_service.dart` - Updated

## Next Steps

1. Integrate moderation in chat service
2. Add moderation to any other content creation screens
3. Test with real users
4. Monitor for false positives/negatives
5. Adjust banned keywords based on feedback
6. Consider adding admin review system

## Support

For issues or questions:
1. Check the main documentation: `CONTENT_MODERATION_SYSTEM_COMPLETE.md`
2. Review error messages in console
3. Test with simple content first
4. Verify all imports are correct
