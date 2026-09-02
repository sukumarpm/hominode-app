# Cloudinary 401 Fix - Quick Reference

## The Problem
```
❌ 401 Unauthorized when uploading images to Cloudinary
```

## The Solution (3 Steps)

### Step 1: Create Upload Preset
```
1. Go to https://cloudinary.com/console
2. Settings → Upload → Upload presets
3. Add upload preset
4. Name: lyvo_upload
5. Mode: UNSIGNED ← CRITICAL!
6. Save
```

### Step 2: Verify Configuration
```
✅ Preset Name: lyvo_upload
✅ Mode: UNSIGNED
✅ Cloud Name: dailyccofb
✅ Status: Active
```

### Step 3: Test Upload
```
1. Open app
2. Go to Apartment Images or Posters
3. Upload image
4. Check console:
   ✅ "Response status: 200" = Success!
   ❌ "Response status: 401" = Go back to Step 1
```

## Why It Works

| Component | Purpose |
|-----------|---------|
| UNSIGNED preset | No API key needed in app |
| upload_preset field | Tells Cloudinary which preset to use |
| Multipart request | Sends file + metadata |
| secure_url response | Gets HTTPS image URL |

## Error Messages & Fixes

```
❌ 401 Unauthorized
→ Preset not UNSIGNED or doesn't exist
→ Create/fix preset in dashboard

❌ 400 Bad Request
→ upload_preset field missing
→ Already in code, check file format

❌ 422 Unprocessable
→ File too large or invalid format
→ Use image under 10MB

❌ Timeout
→ Network issue
→ Check connection, retry
```

## Code Flow

```
1. Validate admin authenticated
2. Validate image file
3. Create multipart request
4. Add file + upload_preset
5. Send to Cloudinary
6. Parse response (200 = success)
7. Extract secure_url
8. Save to Firestore
9. Return document ID
```

## Files Updated

✅ `cloudinary_apartment_images_service.dart`
✅ `poster_service.dart`

Both now have:
- Better error parsing
- Specific error guidance
- Proper response handling

## Testing Checklist

- [ ] Preset created in Cloudinary
- [ ] Preset set to UNSIGNED
- [ ] Preset named `lyvo_upload`
- [ ] App opens without errors
- [ ] Can select image
- [ ] Upload returns 200
- [ ] Image appears in list
- [ ] Image displays correctly

## Success = 

✅ Status 200
✅ Image URL extracted
✅ Metadata in Firestore
✅ Image in app
✅ No errors

---

**Time to Fix**: 5 minutes
**Difficulty**: Easy
**Status**: Ready to implement
