# Cloudinary Setup Guide for Poster Management

## Step 1: Create Upload Preset in Cloudinary

1. Go to [Cloudinary Console](https://console.cloudinary.com)
2. Navigate to **Settings** → **Upload**
3. Scroll to **Upload presets** section
4. Click **Add upload preset**
5. Configure:
   - **Name**: `poster_upload`
   - **Unsigned**: Toggle ON (for client-side uploads)
   - **Folder**: `posters`
   - **Resource type**: Image
   - Click **Save**

## Step 2: Verify Configuration

The poster service is configured with:
- **Cloud Name**: `dailyccofb`
- **API Key**: `866472317169594`
- **Upload Preset**: `poster_upload`

## Step 3: Add HTTP Package

Make sure `http` package is in your `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
```

Run: `flutter pub get`

## Step 4: Test Upload

1. Open the Poster Management screen in admin app
2. Select an image
3. Enter poster title
4. Select building
5. Click "Upload Poster"

## Troubleshooting

### 401 Unauthorized
- Verify upload preset name matches `poster_upload`
- Check preset is set to "Unsigned"

### Upload fails silently
- Check console logs for error messages
- Verify image file exists and is readable
- Check internet connection

### Image not appearing
- Verify Cloudinary upload was successful (check console)
- Check Firestore has correct imageUrl
- Verify buildingId is correct

## Security Notes

⚠️ **Important**: The API secret should NOT be exposed in client code. The current setup uses:
- **Unsigned uploads** via upload preset (safe for client)
- **API key** is public (acceptable for unsigned uploads)
- **API secret** is stored in config but NOT used in client uploads

For production, consider:
1. Using backend to sign uploads
2. Restricting upload preset to specific folders
3. Adding upload transformations (resize, format, etc.)
