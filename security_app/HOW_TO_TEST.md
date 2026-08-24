# How to Test the Security App

## Quick Test Guide

### Step 1: Create Test Visitor (30 seconds)
```
1. Run app: flutter run -d ZA222LQT6V
2. Tap "Profile" tab (bottom right)
3. Tap "Create Test Visitor" button
4. Copy the Document ID shown
```

### Step 2: Generate QR Code (1 minute)
```
1. Go to: https://www.qr-code-generator.com
2. Select "Text" type
3. Paste the Document ID (e.g., abc123xyz456)
4. Click "Create QR Code"
5. Download or display on another device
```

### Step 3: Test Check-In (10 seconds)
```
1. In app, tap "Scan" tab
2. Point camera at QR code
3. Expected Result:
   ✅ Green success dialog appears
   ✅ Shows "Entry Granted ✓"
   ✅ Displays visitor details
   ✅ Shows entry time
4. Tap "Done"
```

### Step 4: Test Check-Out (10 seconds)
```
1. Scan the same QR code again
2. Expected Result:
   ✅ Green success dialog appears
   ✅ Shows "Exit Recorded ✓"
   ✅ Displays visitor details
   ✅ Shows exit time
3. Tap "Done"
```

### Step 5: Test Already Checked Out (10 seconds)
```
1. Scan the same QR code third time
2. Expected Result:
   ❌ Error dialog appears
   ❌ Shows "Already Checked Out"
   ❌ Displays last exit time
3. Tap "OK"
```

---

## What to Check in Firestore

### After Creating Test Visitor
```javascript
visitors/{documentId} {
  visitorName: "Amit Sharma",
  phone: "+91 98765 43210",
  residentName: "Rajesh Kumar",
  flatLabel: "A-301",
  isApproved: true,
  actualArrival: null,  // ← Should be null
  departure: null,      // ← Should be null
}
```

### After Check-In (Scan 1)
```javascript
visitors/{documentId} {
  ...
  actualArrival: Timestamp(2026-03-06 10:30:00),  // ← Now has timestamp
  departure: null,                                 // ← Still null
}
```

### After Check-Out (Scan 2)
```javascript
visitors/{documentId} {
  ...
  actualArrival: Timestamp(2026-03-06 10:30:00),  // ← Check-in time
  departure: Timestamp(2026-03-06 12:45:00),       // ← Now has timestamp
}
```

---

## Expected Console Logs

### Successful Check-In
```
🔍 QR Scanned: abc123xyz456
📡 Fetching visitor from Firestore
   Collection: visitors
   Document ID: abc123xyz456
   Document exists: true
✅ Visitor found: {visitorName: Amit Sharma, ...}
✅ Visitor: Amit Sharma
📊 isApproved: true
📊 actualArrival: null
📊 departure: null
✅ Visitor checked in
```

### Successful Check-Out
```
🔍 QR Scanned: abc123xyz456
📡 Fetching visitor from Firestore
   Document exists: true
✅ Visitor: Amit Sharma
📊 isApproved: true
📊 actualArrival: 2026-03-06 10:30:00
📊 departure: null
✅ Visitor checked out
```

### Already Checked Out Error
```
🔍 QR Scanned: abc123xyz456
📡 Fetching visitor from Firestore
   Document exists: true
✅ Visitor: Amit Sharma
📊 isApproved: true
📊 actualArrival: 2026-03-06 10:30:00
📊 departure: 2026-03-06 12:45:00
❌ Error: Already checked out
```

---

## Troubleshooting

### Issue: "Visitor Not Found"
**Cause:** Document doesn't exist in Firestore  
**Solution:** Create test visitor from Profile tab first

### Issue: "Visitor Not Approved"
**Cause:** isApproved = false in Firestore  
**Solution:** Update document: `isApproved: true`

### Issue: QR Code Not Scanning
**Cause:** Camera permission or lighting  
**Solution:** 
- Grant camera permission
- Ensure good lighting
- Hold QR code steady

### Issue: App Won't Build
**Solution:**
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

---

## Quick Commands

### Run on Device
```bash
flutter run -d ZA222LQT6V
```

### Build APK
```bash
flutter build apk --debug
```

### Check for Errors
```bash
flutter analyze
```

### View Logs
```bash
flutter logs
```

---

## Test Checklist

- [ ] App runs without errors
- [ ] Profile tab opens Test Data screen
- [ ] Test visitor created successfully
- [ ] Document ID copied
- [ ] QR code generated
- [ ] Scan tab opens camera
- [ ] Camera permission granted
- [ ] QR code scanned successfully
- [ ] Check-in success dialog shows
- [ ] Visitor details displayed correctly
- [ ] Entry time shown
- [ ] Check-out success dialog shows
- [ ] Exit time shown
- [ ] Already checked out error shows
- [ ] Firestore timestamps updated correctly

---

## Success Criteria

✅ **Check-In Works:** QR scan → actualArrival timestamp set → Success dialog  
✅ **Check-Out Works:** QR scan → departure timestamp set → Success dialog  
✅ **Error Handling:** Already checked out → Error dialog with exit time  
✅ **UI Matches Spec:** Green checkmark, visitor details, time badge  
✅ **Firestore Updates:** Timestamps set correctly in database

---

**Ready to Test!** 🚀

Follow the steps above to verify the QR scanner flow works as specified.
