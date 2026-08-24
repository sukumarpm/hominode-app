# Cloudinary Preset Creation - Visual Guide

## The Exact Steps with Screenshots Description

### Step 1: Open Cloudinary Console
```
URL: https://cloudinary.com/console
```
You should see your dashboard with your cloud name displayed.

### Step 2: Click Settings (Gear Icon)
```
Location: Top right corner of dashboard
Icon: ⚙️ (gear/settings icon)
```
After clicking, you'll see a dropdown menu.

### Step 3: Click "Upload" in Settings
```
In the dropdown menu, look for:
- Account
- Security
- Upload ← CLICK THIS
- Billing
- etc.
```

### Step 4: Scroll to "Upload presets"
```
In the Upload settings page, scroll down.
You'll see a section titled "Upload presets"
```

### Step 5: Click "Add upload preset"
```
In the Upload presets section:
[Add upload preset] button
Click it
```

### Step 6: Fill the Form
```
A form will appear with fields:

┌─────────────────────────────────┐
│ Add Upload Preset               │
├─────────────────────────────────┤
│                                 │
│ Name: [lyvo_upload____________] │
│                                 │
│ Mode: [UNSIGNED ▼]              │
│       ↑ CLICK DROPDOWN          │
│       ↑ SELECT "UNSIGNED"       │
│                                 │
│ Signing Mode: [Default ▼]       │
│ (leave as is)                   │
│                                 │
│ [Save] [Cancel]                 │
│                                 │
└─────────────────────────────────┘
```

### Step 7: Enter Name
```
Field: Name
Value: lyvo_upload

IMPORTANT: 
- Exact spelling
- All lowercase
- No spaces
- No special characters
```

### Step 8: Select Mode
```
Field: Mode
Current: (probably blank or "SIGNED")

Click the dropdown ▼
Select: UNSIGNED

This is CRITICAL!
```

### Step 9: Click Save
```
Button: [Save]
Location: Bottom of form
```

### Step 10: Verify Success
```
After saving, you should see:

✅ Preset appears in list
✅ Name: lyvo_upload
✅ Mode: UNSIGNED
✅ Status: Active
```

## Complete Flow Diagram

```
https://cloudinary.com/console
         ↓
    [⚙️ Settings]
         ↓
    [Upload] tab
         ↓
    Scroll down
         ↓
    [Add upload preset]
         ↓
    Form appears
         ↓
    Name: lyvo_upload
    Mode: UNSIGNED
         ↓
    [Save]
         ↓
    ✅ Preset created!
         ↓
    Go back to app
         ↓
    Try upload again
         ↓
    ✅ Should work!
```

## What Each Field Means

| Field | Value | Why |
|-------|-------|-----|
| Name | `lyvo_upload` | Identifier for preset |
| Mode | UNSIGNED | No API key needed in app |
| Signing Mode | Default | Leave as is |

## Common Mistakes to Avoid

❌ Wrong name: `apartment_images_preset`
✅ Correct name: `lyvo_upload`

❌ Wrong mode: SIGNED
✅ Correct mode: UNSIGNED

❌ Typo: `lyvo_upload ` (with space)
✅ Correct: `lyvo_upload` (no space)

## After Creating Preset

1. **Close Cloudinary tab** (optional)
2. **Go back to Flutter app**
3. **Try uploading image again**
4. **Should see "Response status: 200"** ✅

## If Something Goes Wrong

### Preset not appearing?
- Refresh the page
- Check you clicked Save
- Try creating again

### Still getting "Unknown API key"?
- Verify preset name is exactly `lyvo_upload`
- Verify Mode is UNSIGNED
- Restart the app
- Try uploading again

### Can't find Upload tab?
- Go directly to: https://cloudinary.com/console/settings/upload
- This skips the navigation

## Success Indicators

After creating preset, you should see:

```
Upload presets
├─ lyvo_upload
│  ├─ Mode: UNSIGNED
│  ├─ Status: Active
│  └─ [Edit] [Delete]
```

## Next Steps

1. ✅ Create preset (you are here)
2. Go back to app
3. Try uploading image
4. Should work!

---

**Time**: 5 minutes
**Difficulty**: Very Easy
**Required**: Yes, must do this
