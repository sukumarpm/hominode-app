# Cloudinary Unsigned Upload Preset Setup

## Quick Setup (5 minutes)

### Step 1: Log in to Cloudinary
1. Go to https://cloudinary.com/console
2. Sign in with your account

### Step 2: Create Upload Preset
1. Click **Settings** (gear icon)
2. Go to **Upload** tab
3. Scroll down to **Upload presets** section
4. Click **Add upload preset**

### Step 3: Configure Preset
Fill in the form:
- **Name**: `lyvo_upload`
- **Mode**: Select **UNSIGNED** (this is critical!)
- Leave other settings as default
- Click **Save**

### Step 4: Verify
You should see:
```
✅ Preset Name: lyvo_upload
✅ Mode: UNSIGNED
✅ Status: Active
```

## Why UNSIGNED?

- No API key or secret needed in Flutter code
- Safer for mobile apps (credentials not exposed)
- Preset handles authentication on Cloudinary side
- Perfect for user-generated content

## Flutter Code Configuration

The app is already configured to use:
- **Cloud Name**: `dailyccofb`
- **Upload Preset**: `lyvo_upload`
- **Endpoint**: `https://api.cloudinary.com/v1_1/dailyccofb/image/upload`

## Testing Upload

1. Open admin app
2. Go to Apartment Images or Posters section
3. Click "Add Image" or "Upload Poster"
4. Select an image
5. Click Upload
6. Check console for:
   - ✅ "Response status: 200" = Success!
   - ❌ "Response status: 401" = Preset issue (go back to Step 3)
   - ❌ "Response status: 400" = Request format issue

## Troubleshooting

### Still Getting 401?
- [ ] Preset name is exactly `lyvo_upload`
- [ ] Mode is set to UNSIGNED (not SIGNED)
- [ ] Preset is Active (not disabled)
- [ ] Cloud name is `dailyccofb`

### Getting 400 Bad Request?
- [ ] Check that upload_preset field is included
- [ ] Verify file is valid image format
- [ ] Check file size is under 10MB

### Upload Timeout?
- [ ] Check internet connection
- [ ] Try with smaller image
- [ ] Check Cloudinary status page

## What Happens After Upload

1. Image uploaded to Cloudinary
2. Secure URL extracted from response
3. Metadata saved to Firestore:
   - Image URL
   - Title, description, type
   - Admin ID, building ID
   - Upload date/time
4. Image appears in app immediately

## Security

✅ No API keys in Flutter code
✅ UNSIGNED preset only allows uploads (no deletions)
✅ Admin authentication required in app
✅ Firestore rules validate admin ownership
✅ All uploads tagged with admin/building IDs

## Next Steps

1. Create the upload preset (5 minutes)
2. Test upload in app
3. Verify image appears in Firestore
4. Check image displays in apartment images/posters section

Done! Your Cloudinary integration is ready.
