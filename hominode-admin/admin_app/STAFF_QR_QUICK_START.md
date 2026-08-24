# Staff QR Entry Management - Quick Start Guide

## What's New?

A complete QR-based staff entry/exit system with:
- ✅ Automatic QR code generation when adding staff
- ✅ Real-time QR scanning at security gates
- ✅ Instant attendance tracking
- ✅ Staff profile with QR display
- ✅ Share & download ID card functionality

---

## FILES CREATED

### Services
- `lib/services/staff_qr_service.dart` - Core QR and attendance logic

### Screens
- `lib/staff_profile_qr_screen.dart` - Staff profile with QR code
- `lib/security_staff_qr_scanner.dart` - QR scanner for security
- `lib/staff_attendance_details_screen.dart` - Attendance history

### Widgets
- `lib/widgets/add_staff_with_qr_modal.dart` - Add staff with QR generation

### Models
- Updated `lib/models/staff_models.dart` - Added QR-related fields

---

## QUICK SETUP

### 1. Add Dependencies to pubspec.yaml
```yaml
qr_flutter: ^4.1.0
mobile_scanner: ^3.5.0
share_plus: ^7.2.0
pdf: ^3.10.0
printing: ^5.11.0
intl: ^0.19.0
```

### 2. Copy Files
Copy all created files to your project maintaining the directory structure.

### 3. Update Navigation
Add routes in `main.dart`:
```dart
'/staff-profile-qr': (context) => StaffProfileQRScreen(
  staffId: settings.arguments as String,
),
'/security-staff-scanner': (context) => const SecurityStaffQRScanner(),
```

### 4. Update Staff Management Screen
Replace add staff button with:
```dart
void _showAddStaffDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AddStaffWithQRModal(
      buildingId: 'your_building_id',
    ),
  ).then((result) {
    if (result == true) {
      setState(() {}); // Refresh list
    }
  });
}
```

---

## ADMIN APP WORKFLOW

### Adding Staff
1. Click "Add Staff" button
2. Fill in details:
   - Name
   - Phone
   - Role
   - Gate (dropdown)
   - Shift (dropdown)
3. Click "Add Staff & Generate QR"
4. System auto-generates QR code

### Viewing Staff Profile
1. Click on staff member
2. See profile with QR code
3. Options:
   - **Share QR**: Send to staff member
   - **Download ID**: Get PDF ID card

### Checking Attendance
1. Click on staff member
2. Scroll to "Attendance" section
3. View all entry/exit records
4. See duration on-site

---

## SECURITY APP WORKFLOW

### Scanning Staff QR
1. Open "Scan Staff QR" screen
2. Point camera at QR code
3. System auto-scans and shows staff details
4. Choose action:
   - **Mark Entry**: Staff entering
   - **Mark Exit**: Staff leaving

### What Happens
- Entry marked → Status = "inside"
- Exit marked → Status = "exited"
- Duration calculated automatically
- Record saved to Firestore

---

## FIRESTORE STRUCTURE

### Staff Collection
```
staff/
  ├── staffId: "unique_id"
  ├── name: "John Doe"
  ├── phone: "+91 98765 43210"
  ├── role: "Security Guard"
  ├── buildingId: "building_123"
  ├── gateName: "Gate A"
  ├── shiftTiming: "Morning (6 AM - 2 PM)"
  ├── photoUrl: "url_to_photo"
  ├── qrCodeUrl: "url_to_qr"
  ├── status: "active"
  ├── lastCheckIn: timestamp
  ├── lastCheckOut: timestamp
  └── createdAt: timestamp
```

### Staff Attendance Collection
```
staffAttendance/
  ├── staffId: "unique_id"
  ├── staffName: "John Doe"
  ├── buildingId: "building_123"
  ├── gateName: "Gate A"
  ├── entryTime: timestamp
  ├── exitTime: timestamp
  ├── status: "inside" or "exited"
  └── createdAt: timestamp
```

---

## KEY FEATURES

### QR Code Generation
- Automatic when staff is added
- Unique per staff member
- Encoded with staffId
- Can be shared and printed

### Real-time Scanning
- Mobile scanner with camera overlay
- Instant staff details display
- One-tap entry/exit marking
- Duplicate scan prevention

### Attendance Tracking
- Entry time recorded
- Exit time recorded
- Duration calculated
- Status tracked (inside/exited)

### ID Card Download
- PDF generation
- Includes QR code
- Staff details
- Ready to print

---

## COMMON TASKS

### Add New Staff
```dart
// In staff management screen
showDialog(
  context: context,
  builder: (context) => AddStaffWithQRModal(
    buildingId: buildingId,
  ),
);
```

### Get Staff Details
```dart
final staffData = await _qrService.getStaffDetails(staffId);
```

### Mark Entry
```dart
await _qrService.markStaffEntry(staffId);
```

### Mark Exit
```dart
await _qrService.markStaffExit(staffId);
```

### Get Attendance
```dart
final records = await _qrService.getStaffAttendance(staffId);
```

---

## PERMISSIONS NEEDED

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan QR codes</string>
```

---

## TESTING

### Test QR Generation
1. Add a staff member
2. Check Firestore for qrCodeUrl
3. View staff profile to see QR

### Test Scanning
1. Open security app
2. Go to QR scanner
3. Point at generated QR code
4. Should show staff details

### Test Attendance
1. Mark entry
2. Check staffAttendance collection
3. Verify entryTime recorded
4. Mark exit
5. Verify exitTime recorded

---

## TROUBLESHOOTING

| Issue | Solution |
|-------|----------|
| QR not generating | Check qr_flutter installed |
| Scanner not working | Check camera permissions |
| Attendance not saving | Check Firestore rules |
| PDF download fails | Check printing package installed |
| Staff not appearing | Check adminId matches |

---

## NEXT STEPS

1. ✅ Install dependencies
2. ✅ Copy all files
3. ✅ Update navigation
4. ✅ Test QR generation
5. ✅ Test QR scanning
6. ✅ Test attendance marking
7. ✅ Deploy to production

---

## SUPPORT

For detailed information, see:
- `STAFF_QR_ENTRY_MANAGEMENT_COMPLETE.md` - Full documentation
- `lib/services/staff_qr_service.dart` - Service implementation
- `lib/security_staff_qr_scanner.dart` - Scanner implementation
