# Cloudinary Upload Request Format Reference

## Endpoint
```
POST https://api.cloudinary.com/v1_1/dailyccofb/image/upload
```

## Request Format (Multipart)

### Required Fields
```
file: [binary image data]
upload_preset: lyvo_upload
```

### Optional Fields
```
public_id: apartment_images/admin123/1234567890
tags: admin123,building456,apartment_image
context: adminId=admin123|buildingId=building456|uploadDate=2026-03-26|uploadTime=14:30
```

## Complete Request Example

```dart
var request = http.MultipartRequest('POST', Uri.parse(
  'https://api.cloudinary.com/v1_1/dailyccofb/image/upload'
));

// Add file (REQUIRED)
request.files.add(
  await http.MultipartFile.fromPath('file', imageFile.path),
);

// Add upload preset (REQUIRED)
request.fields['upload_preset'] = 'lyvo_upload';

// Add optional fields
request.fields['public_id'] = 'apartment_images/admin123/1234567890';
request.fields['tags'] = 'admin123,building456,apartment_image';
request.fields['context'] = 'adminId=admin123|buildingId=building456';

// Send request
var response = await request.send();
```

## Success Response (200)

```json
{
  "public_id": "apartment_images/admin123/1234567890",
  "version": 1234567890,
  "signature": "abc123def456",
  "width": 1920,
  "height": 1080,
  "format": "jpg",
  "resource_type": "image",
  "created_at": "2026-03-26T14:30:00Z",
  "tags": ["admin123", "building456", "apartment_image"],
  "bytes": 245678,
  "type": "upload",
  "etag": "abc123def456",
  "placeholder": false,
  "url": "http://res.cloudinary.com/dailyccofb/image/upload/v1234567890/apartment_images/admin123/1234567890.jpg",
  "secure_url": "https://res.cloudinary.com/dailyccofb/image/upload/v1234567890/apartment_images/admin123/1234567890.jpg",
  "folder": "apartment_images/admin123",
  "original_filename": "image"
}
```

### Extract URL
```dart
final jsonResponse = json.decode(responseString);
final imageUrl = jsonResponse['secure_url']; // Use this!
// Result: https://res.cloudinary.com/dailyccofb/image/upload/v1234567890/apartment_images/admin123/1234567890.jpg
```

## Error Response (401)

```json
{
  "error": {
    "message": "Invalid upload preset"
  }
}
```

**Cause**: Preset doesn't exist or not set to UNSIGNED
**Fix**: Create preset in Cloudinary dashboard

## Error Response (400)

```json
{
  "error": {
    "message": "Missing required parameter: upload_preset"
  }
}
```

**Cause**: upload_preset field not included in request
**Fix**: Already included in code, check file format

## Error Response (422)

```json
{
  "error": {
    "message": "File size too large"
  }
}
```

**Cause**: File exceeds 10MB limit
**Fix**: Use smaller image (already validated in code)

## Curl Test Command

Test the endpoint directly:

```bash
curl -X POST https://api.cloudinary.com/v1_1/dailyccofb/image/upload \
  -F "file=@/path/to/image.jpg" \
  -F "upload_preset=lyvo_upload"
```

Expected response:
```json
{
  "secure_url": "https://res.cloudinary.com/dailyccofb/image/upload/...",
  ...
}
```

## Firestore Storage

After successful upload, metadata is stored:

```
Collection: apartmentImages
Document: {auto-generated ID}

Fields:
{
  "title": "Living Room",
  "description": "Main living area",
  "type": "Common Area",
  "imageUrl": "https://res.cloudinary.com/dailyccofb/image/upload/...",
  "adminId": "admin123",
  "adminName": "John Doe",
  "buildingId": "building456",
  "uploadDate": "2026-03-26",
  "uploadTime": "14:30",
  "status": "active",
  "createdAt": {timestamp},
  "updatedAt": {timestamp}
}
```

## Validation Rules

| Field | Rule | Example |
|-------|------|---------|
| file | Required, image format | .jpg, .png, .gif |
| upload_preset | Required, must exist | lyvo_upload |
| file size | Max 10MB | 245KB ✅, 15MB ❌ |
| public_id | Optional, for organization | apartment_images/admin123/1234567890 |
| tags | Optional, for filtering | admin123,building456 |
| context | Optional, for metadata | adminId=admin123\|buildingId=building456 |

## Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Extract secure_url, save to Firestore |
| 400 | Bad Request | Check request format, file type |
| 401 | Unauthorized | Create/fix upload preset |
| 422 | Unprocessable | Check file size, format |
| 500 | Server Error | Retry, check Cloudinary status |
| Timeout | Network issue | Retry, check connection |

## Implementation in Code

The Flutter app implements this correctly:

✅ Uses multipart request
✅ Includes file field
✅ Includes upload_preset field
✅ Extracts secure_url from response
✅ Validates response status (200 = success)
✅ Parses error messages
✅ Saves metadata to Firestore
✅ Handles timeouts

## Debugging

Enable detailed logging:

```dart
print('📤 Request URL: $CLOUDINARY_API_URL');
print('📤 Upload Preset: $CLOUDINARY_UPLOAD_PRESET');
print('📤 File Size: $fileSize bytes');
print('📤 Response Status: ${response.statusCode}');
print('📤 Response Body: $responseString');
```

Check console output for:
- ✅ Status 200 = Success
- ❌ Status 401 = Preset issue
- ❌ Status 400 = Request format issue

---

**Reference**: Cloudinary API Documentation
**Updated**: March 26, 2026
**Status**: Complete
