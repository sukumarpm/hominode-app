# Cloudinary Upload Preset Setup - Visual Guide

## Dashboard Navigation

### Step 1: Open Cloudinary Console
```
https://cloudinary.com/console
         ↓
    [Sign In]
         ↓
    Dashboard opens
```

### Step 2: Navigate to Settings
```
Dashboard
    ↓
[Settings] (gear icon in top right)
    ↓
Settings page opens
```

### Step 3: Go to Upload Tab
```
Settings page
    ↓
[Upload] tab (in left sidebar)
    ↓
Upload settings page
```

### Step 4: Find Upload Presets
```
Upload settings page
    ↓
Scroll down to "Upload presets" section
    ↓
See list of existing presets (if any)
```

### Step 5: Add New Preset
```
Upload presets section
    ↓
[Add upload preset] button
    ↓
Preset creation form opens
```

## Preset Configuration Form

```
┌─────────────────────────────────────────┐
│  Add Upload Preset                      │
├─────────────────────────────────────────┤
│                                         │
│  Name: [lyvo_upload____________]        │
│                                         │
│  Mode: [UNSIGNED ▼]  ← SELECT THIS!    │
│                                         │
│  Signing Mode: [Default ▼]              │
│                                         │
│  [Save] [Cancel]                        │
│                                         │
└─────────────────────────────────────────┘
```

### Key Fields

| Field | Value | Notes |
|-------|-------|-------|
| Name | `lyvo_upload` | Exact name (case-sensitive) |
| Mode | **UNSIGNED** | Critical! Select from dropdown |
| Signing Mode | Default | Leave as is |

## After Saving

```
Upload presets section
    ↓
New preset appears in list:
    ├─ Name: lyvo_upload
    ├─ Mode: UNSIGNED
    ├─ Status: Active ✓
    └─ [Edit] [Delete]
```

## Verification Checklist

```
✓ Preset Name: lyvo_upload
✓ Mode: UNSIGNED (not SIGNED)
✓ Status: Active (not disabled)
✓ Cloud Name: dailyccofb (shown in dashboard)
```

## Testing Upload Flow

```
┌─────────────────────────────────────────┐
│  Flutter App                            │
├─────────────────────────────────────────┤
│                                         │
│  [Apartment Images]                     │
│         ↓                               │
│  [Add Image]                            │
│         ↓                               │
│  Select image from gallery              │
│         ↓                               │
│  [Upload]                               │
│         ↓                               │
│  ┌─────────────────────────────────┐   │
│  │ Uploading...                    │   │
│  │ 50% ████████░░░░░░░░░░░░░░░░░░ │   │
│  └─────────────────────────────────┘   │
│         ↓                               │
│  ✓ Upload Complete!                     │
│         ↓                               │
│  Image appears in list                  │
│                                         │
└─────────────────────────────────────────┘
```

## Console Output During Upload

```
🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Starting image upload...
🔐 STEP 1: Validating admin authentication...
✅ STEP 1 PASSED: Admin authenticated - admin123

📋 STEP 2: Validating input data...
✅ STEP 2 PASSED: Input data validated - File size: 245678 bytes

📤 STEP 3: Uploading image to Cloudinary...
📤 STEP 3.1: Preparing upload request...
📤 STEP 3.2: Sending upload request to Cloudinary...
📤 STEP 3.2b: Response status: 200 ← SUCCESS!
📤 STEP 3.2c: Response received successfully
✅ STEP 3 PASSED: Image uploaded - https://res.cloudinary.com/...

💾 STEP 4: Saving image metadata to Firestore...
✅ STEP 4 PASSED: Image metadata saved - doc123

✅ CLOUDINARY APARTMENT IMAGES SERVICE: Image upload COMPLETE
```

## Error Scenarios

### Scenario 1: 401 Unauthorized

```
Console Output:
❌ STEP 3 FAILED: Upload failed with status 401
   Response body: {"error":{"message":"Invalid upload preset"}}
   Error details: Cloudinary error: Invalid upload preset

Fix: Ensure upload preset is created in Cloudinary dashboard and set to UNSIGNED mode.

Action:
1. Go back to Cloudinary dashboard
2. Check preset exists: lyvo_upload
3. Check Mode is UNSIGNED (not SIGNED)
4. If not, edit preset and change Mode to UNSIGNED
5. Save and retry upload
```

### Scenario 2: 400 Bad Request

```
Console Output:
❌ STEP 3 FAILED: Upload failed with status 400
   Response body: {"error":{"message":"Missing required parameter: upload_preset"}}
   Error details: Cloudinary error: Missing required parameter: upload_preset

Fix: Check request format - upload_preset field may be missing or incorrect.

Action:
1. Verify file is valid image format (.jpg, .png, .gif)
2. Check file size is under 10MB
3. Check internet connection
4. Retry upload
```

### Scenario 3: Timeout

```
Console Output:
❌ STEP 3 FAILED: Cloudinary upload error
   Error type: TimeoutException
   Error message: Upload timeout - please try again

Fix: Network issue or slow connection

Action:
1. Check internet connection
2. Try with smaller image
3. Retry upload
4. Check Cloudinary status page
```

## Firestore Verification

After successful upload, check Firestore:

```
Firestore Console
    ↓
Collections
    ↓
[apartmentImages]
    ↓
New document appears:
    ├─ title: "Living Room"
    ├─ description: "Main living area"
    ├─ type: "Common Area"
    ├─ imageUrl: "https://res.cloudinary.com/..."
    ├─ adminId: "admin123"
    ├─ buildingId: "building456"
    ├─ uploadDate: "2026-03-26"
    ├─ uploadTime: "14:30"
    ├─ status: "active"
    ├─ createdAt: {timestamp}
    └─ updatedAt: {timestamp}
```

## Image Display Flow

```
Firestore Document
    ↓
App fetches imageUrl
    ↓
Display image from Cloudinary URL
    ↓
Image appears in list
    ↓
User can view/delete image
```

## Complete Setup Timeline

```
Time    Action                          Status
────────────────────────────────────────────────
0:00    Open Cloudinary console         ⏱️
0:30    Navigate to Upload settings     ⏱️
1:00    Click "Add upload preset"       ⏱️
1:30    Fill in form:                   ⏱️
        - Name: lyvo_upload
        - Mode: UNSIGNED
2:00    Click Save                      ⏱️
2:30    Preset created                  ✅
3:00    Open Flutter app                ⏱️
3:30    Navigate to Apartment Images    ⏱️
4:00    Select image                    ⏱️
4:30    Click Upload                    ⏱️
5:00    Check console: Status 200       ✅
5:30    Verify Firestore document       ✅
6:00    Image appears in app            ✅
────────────────────────────────────────────────
Total time: ~6 minutes
```

## Troubleshooting Decision Tree

```
Upload fails?
    ↓
Check console for status code
    ├─ 401 Unauthorized
    │   ├─ Preset doesn't exist?
    │   │   └─ Create preset in dashboard
    │   └─ Preset not UNSIGNED?
    │       └─ Edit preset, change Mode to UNSIGNED
    │
    ├─ 400 Bad Request
    │   ├─ File format invalid?
    │   │   └─ Use .jpg, .png, or .gif
    │   └─ File too large?
    │       └─ Use image under 10MB
    │
    ├─ 422 Unprocessable
    │   └─ File too large or invalid
    │       └─ Use smaller image
    │
    ├─ Timeout
    │   ├─ Internet connection?
    │   │   └─ Check connection
    │   └─ Cloudinary down?
    │       └─ Check status page
    │
    └─ Other error
        └─ Check error message in console
```

## Success Indicators

```
✅ Console shows "Response status: 200"
✅ Console shows "Image uploaded - https://..."
✅ Console shows "Image metadata saved"
✅ Firestore has new document
✅ Image appears in app list
✅ Image displays correctly
✅ No error messages
```

## Quick Reference Card

```
┌──────────────────────────────────────────┐
│  CLOUDINARY SETUP QUICK REFERENCE        │
├──────────────────────────────────────────┤
│                                          │
│  Dashboard: https://cloudinary.com/...   │
│  Settings → Upload → Upload presets      │
│                                          │
│  Preset Name: lyvo_upload                │
│  Mode: UNSIGNED ← CRITICAL!              │
│                                          │
│  Cloud Name: dailyccofb                  │
│  Endpoint: https://api.cloudinary.com... │
│                                          │
│  Test: Upload image → Check console      │
│  Success: Status 200 + Image in app      │
│                                          │
└──────────────────────────────────────────┘
```

---

**Visual Guide**: Complete
**Status**: Ready to use
**Time**: 5-6 minutes
