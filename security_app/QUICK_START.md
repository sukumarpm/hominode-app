# Quick Start Guide - QR Scanner Testing

## 🚀 Quick Steps to Test

### 1️⃣ Create Test Data (30 seconds)
1. Open Lyvo Guard app
2. Tap **Profile** tab (bottom right)
3. Tap **"Create Test Visitor"**
4. Copy the Document ID shown

### 2️⃣ Generate QR Code (1 minute)
1. Go to: https://www.qr-code-generator.com
2. Paste the Document ID
3. Download QR code image

### 3️⃣ Test Scanner (10 seconds)
1. Tap **Scan** tab in app
2. Point camera at QR code
3. View visitor details
4. Test "Mark Entry" button

## ✅ What's Fixed

- Enhanced logging to show exactly what's happening
- Added Test Data Generator screen (accessible from Profile tab)
- Improved error messages with helpful instructions
- Better debugging output in console

## 📱 App Features

**Dashboard (Home Tab)**
- Welcome header with guard info
- Statistics cards
- Quick access buttons
- Pending approvals list

**QR Scanner (Scan Tab)**
- Live camera scanner
- Flashlight toggle
- Auto-detect QR codes
- Fetch visitor from Firestore

**Visitor Details**
- Verification badge
- Visitor information card
- Mark Entry/Exit buttons
- Status-based button enabling

**Test Data (Profile Tab)**
- Create test visitors
- Copy document IDs
- Instructions for QR generation

## 🔍 Debug Logs

Watch the console for these logs:
```
🔍 QR Scanned: [id]
📡 Fetching visitor from Firestore
   Collection: visitors
   Document ID: [id]
   Document exists: true
✅ Visitor found: [data]
```

## 📊 Visitor Status Flow

```
expected → inside → completed
```

- **expected**: Mark Entry enabled ✅
- **inside**: Mark Exit enabled ✅
- **completed**: Both buttons disabled

## 🎯 Next Integration Steps

1. **Resident App**: Generate QR codes with visitor document IDs
2. **Admin App**: Approve visitor requests
3. **SMS Integration**: Send QR codes to visitors
4. **Real-time Updates**: Use Firestore streams for live data

## 🔗 Firebase Details

- **Project**: lyvo-app-9f0ca
- **Collection**: visitors
- **Package**: com.marantrix.lyvo.security

## 💡 Tips

- QR code should contain ONLY the document ID
- No JSON, no extra text, just the ID
- Test data screen creates properly formatted visitors
- Check console logs if something doesn't work
