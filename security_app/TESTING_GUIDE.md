# QR Scanner Testing Guide

## Problem Identified

The QR scanner is working correctly, but visitor data doesn't exist in Firestore yet. The app successfully:
- ✅ Scans QR codes
- ✅ Extracts document IDs
- ✅ Queries Firestore
- ❌ But finds no matching documents

## Solution: Create Test Data

### Step 1: Create Test Visitor in Firestore

**Option A: Use the Test Data Screen (Easiest)**

1. Run the app on your device
2. Tap the **Profile** tab in the bottom navigation
3. This opens the **Test Data Generator** screen
4. Tap **"Create Test Visitor"** button
5. A test visitor will be created in Firestore
6. Copy the generated **Document ID**

**Option B: Manual Firestore Entry**

1. Open Firebase Console: https://console.firebase.google.com
2. Go to your project: `lyvo-app-9f0ca`
3. Navigate to **Firestore Database**
4. Create a new collection called `visitors` (if it doesn't exist)
5. Add a new document with these fields:

```
visitorName: "Amit Sharma"
phoneNumber: "+91 98765 43210"
purpose: "Guest Visit"
flatId: "flat_a301"
flatLabel: "A-301"
hostName: "Rajesh Kumar"
hostEmail: "rajesh@example.com"
hostUserId: "user_123"
vehicleNumber: "MH 01 AB 1234"
isApproved: true
status: "expected"
expectedArrival: [current timestamp]
actualArrival: null
departure: null
createdAt: [current timestamp]
updatedAt: [current timestamp]
```

6. Note the auto-generated **Document ID** (e.g., `0Au23BbeJsNqpO6GePJ22`)

### Step 2: Generate QR Code

1. Go to any QR code generator website:
   - https://www.qr-code-generator.com
   - https://www.qrcode-monkey.com
   - https://the-qrcode-generator.com

2. Enter ONLY the Document ID as text (nothing else):
   ```
   0Au23BbeJsNqpO6GePJ22
   ```

3. Generate and download the QR code image

### Step 3: Test the Scanner

1. Open the Lyvo Guard app
2. Tap the **Scan** tab in the bottom navigation
3. Point the camera at the QR code you generated
4. The app will:
   - Scan the QR code
   - Extract the document ID
   - Fetch visitor data from Firestore
   - Display the visitor details screen

### Step 4: Test Entry/Exit Flow

**Mark Entry:**
- When status is `expected`, the "Mark Entry" button is enabled
- Tap "Mark Entry"
- Status changes to `inside`
- `actualArrival` timestamp is recorded

**Mark Exit:**
- When status is `inside`, the "Mark Exit" button is enabled
- Tap "Mark Exit"
- Status changes to `completed`
- `departure` timestamp is recorded

## Visitor Status Flow

```
pending → expected → inside → completed
```

- **pending**: Visitor request created but not approved
- **expected**: Visitor approved by resident, waiting for entry
- **inside**: Visitor entered the premises
- **completed**: Visitor exited the premises

## Debugging Tips

### Check Logs

The app prints detailed logs when scanning:

```
🔍 QR Scanned: [document_id]
📡 Fetching visitor from Firestore
   Collection: visitors
   Document ID: [document_id]
   ID Length: [length]
   ID Trimmed: [trimmed_id]
   Document exists: true/false
✅ Visitor found: [data]
```

### Common Issues

**Issue: "Visitor not found"**
- ✅ Solution: Create test data in Firestore first
- Check that the document ID in QR matches Firestore document ID exactly
- Verify the collection name is `visitors` (lowercase)

**Issue: QR code not scanning**
- Ensure camera permissions are granted
- Make sure QR code is clear and well-lit
- Try adjusting distance from camera

**Issue: Firebase connection error**
- Verify Firebase is initialized in `main.dart`
- Check `google-services.json` is in `android/app/`
- Ensure package name matches: `com.marantrix.lyvo.security`

## Firebase Configuration

**Project ID:** `lyvo-app-9f0ca`
**Package Name:** `com.marantrix.lyvo.security`
**Collection:** `visitors`

## Next Steps

Once you have test data working:

1. Integrate with the resident app to generate QR codes
2. Implement SMS sending for pre-approved visitors
3. Add real-time visitor statistics
4. Implement visitor history and reports
5. Add photo capture for visitor verification

## Support

If you encounter issues:
1. Check the console logs for detailed error messages
2. Verify Firebase connection
3. Ensure test data exists in Firestore
4. Confirm QR code contains only the document ID
