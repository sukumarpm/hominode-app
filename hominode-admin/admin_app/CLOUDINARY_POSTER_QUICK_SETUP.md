# Cloudinary Poster Upload - Quick Setup

## What's Done ✅
- Poster service updated with real Cloudinary upload
- Configuration file created with your credentials
- HTTP integration for multipart uploads
- JSON response parsing

## What You Need to Do 🔧

### 1. Create Upload Preset (5 minutes)
```
Cloudinary Console → Settings → Upload → Add upload preset
Name: poster_upload
Unsigned: ON
Folder: posters
Save
```

### 2. Add HTTP Package
```bash
flutter pub add http
```

### 3. Test It
- Open Poster Management screen
- Upload an image
- Check console for success/errors

## Configuration
- **Cloud Name**: dailyccofb
- **Upload Preset**: poster_upload
- **Upload URL**: https://api.cloudinary.com/v1_1/dailyccofb/image/upload

## How It Works
1. User picks image from gallery
2. Image sent to Cloudinary via HTTP multipart
3. Cloudinary returns secure_url
4. URL stored in Firestore posters collection
5. Real-time updates to UI

## Files Modified
- `admin_app/lib/services/poster_service.dart` - Real Cloudinary upload
- `admin_app/lib/config/cloudinary_config.dart` - Configuration

## Next Steps
After setup works:
1. Test with different image sizes
2. Add image transformations (resize, format)
3. Implement progress indicator
4. Add retry logic for failed uploads
