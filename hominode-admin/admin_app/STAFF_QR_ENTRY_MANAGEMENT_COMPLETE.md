# Staff QR Entry Management System - Complete Implementation

## Overview
A comprehensive QR code-based staff entry/exit management system for both Admin and Security apps with real-time attendance tracking.

---

## FIRESTORE STRUCTURE

### 1. Staff Collection
```
Collection: staff
Fields:
  - staffId (string): Unique staff identifier
  - name (string): Staff member name
  - phone (string): Contact number
  - role (string): Job role (Security Guard, Cleaner, etc.)
  - buildingId (string): Assigned building
  - gateName (string): Assigned gate (Gate A, Gate B, etc.)
  - shiftTiming (string): Shift details (Morning, Afternoon, Night)
  - photoUrl (string): Staff photo URL
  - qrCodeUrl (string): QR code image URL
  - status (string): Current status (active, inside, outside)
  - lastCheckIn (timestamp): Last entry time
  - lastCheckOut (timestamp): Last exit time
  - adminId (string): Admin who created the staff
  - createdAt (timestamp): Creation timestamp
  - updatedAt (timestamp): Last update timestamp
```

### 2. Staff Attendance Collection
```
Collection: staffAttendance
Fields:
  - staffId (string): Reference to staff member
  - staffName (string): Staff member name
  - buildingId (string): Building reference
  - gateName (string): Gate where entry/exit occurred
  - entryTime (timestamp): Entry timestamp
  - exitTime (timestamp): Exit timestamp (null if still inside)
  - status (string): "inside" or "exited"
  - createdAt (timestamp): Record creation time
```

---

## ADMIN APP FEATURES

### 1. Add Staff with QR Code Generation
**File**: `lib/widgets/add_staff_with_qr_modal.dart`

**Features**:
- Collect staff details (name, phone, role, building, gate, shift)
- Auto-generate unique staffId
- Generate QR code from staffId
- Save to Firestore with QR reference

**Usage**:
```dart
showDialog(
  context: context,
  builder: (context) => AddStaffWithQRModal(
    buildingId: 'building_123',
  ),
);
```

### 2. Staff Profile with QR Display
**File**: `lib/staff_profile_qr_screen.dart`

**Features**:
- Display staff photo and details
- Show QR code
- Share QR code functionality
- Download ID card as PDF

**Usage**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StaffProfileQRScreen(
      staffId: 'staff_123',
    ),
  ),
);
```

### 3. Staff Attendance Tracking
**File**: `lib/staff_attendance_details_screen.dart`

**Features**:
- View all attendance records
- Display entry/exit times
- Calculate duration on-site
- Filter by date and status

**Usage**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StaffAttendanceDetailsScreen(
      staffId: 'staff_123',
      staffName: 'John Doe',
    ),
  ),
);
```

---

## SECURITY APP FEATURES

### 1. QR Code Scanner
**File**: `lib/security_staff_qr_scanner.dart`

**Features**:
- Real-time QR code scanning
- Camera overlay with scanning guides
- Duplicate scan prevention
- Instant staff details display

**Usage**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SecurityStaffQRScanner(),
  ),
);
```

### 2. Staff Details Modal (After Scan)
**Features**:
- Display staff photo and information
- Show assigned gate and shift
- Mark Entry button
- Mark Exit button
- Real-time status updates

---

## SERVICE LAYER

### StaffQRService
**File**: `lib/services/staff_qr_service.dart`

**Key Methods**:

#### QR Code Generation
```dart
// Generate QR code image
Future<Uint8List> generateQRCode(String staffId)

// Save QR code reference to Firestore
Future<void> saveQRCodeReference(String staffId, String qrCodeUrl)
```

#### Staff Management
```dart
// Create staff with QR code
Future<String> createStaffWithQRCode({
  required String name,
  required String phone,
  required String role,
  required String buildingId,
  required String gateName,
  required String shiftTiming,
  String? photoUrl,
})

// Get staff details
Future<Map<String, dynamic>> getStaffDetails(String staffId)

// Get all staff members
Future<List<Map<String, dynamic>>> getAllStaffMembers()

// Update staff details
Future<void> updateStaffDetails(String staffId, Map<String, dynamic> updates)

// Delete staff member
Future<void> deleteStaffMember(String staffId)
```

#### Attendance Tracking
```dart
// Mark entry
Future<void> markStaffEntry(String staffId)

// Mark exit
Future<void> markStaffExit(String staffId)

// Get attendance records
Future<List<Map<String, dynamic>>> getStaffAttendance(String staffId)
```

---

## FLOW FUNCTIONS

### Admin Flow: Add Staff with QR

1. Admin opens Staff Management screen
2. Clicks "Add Staff" button
3. Opens `AddStaffWithQRModal`
4. Fills in staff details:
   - Name
   - Phone
   - Role
   - Building
   - Gate
   - Shift Timing
5. Clicks "Add Staff & Generate QR"
6. System:
   - Generates unique staffId
   - Creates staff document in Firestore
   - Generates QR code from staffId
   - Saves QR reference
   - Shows success message
7. Admin can view staff profile with QR code

### Admin Flow: View Staff Profile & QR

1. Admin opens Staff Management screen
2. Clicks on staff member card
3. Opens `StaffProfileQRScreen`
4. Displays:
   - Staff photo
   - Staff details (name, role, phone, building, gate, shift)
   - QR code
5. Admin can:
   - Share QR code (via Share Plus)
   - Download ID card (PDF generation)

### Security Flow: Scan & Mark Attendance

1. Security guard opens Security app
2. Navigates to "Scan Staff QR"
3. Opens `SecurityStaffQRScanner`
4. Points camera at staff QR code
5. System scans and fetches staff details
6. Shows `StaffDetailsModal` with:
   - Staff photo
   - Name, role, phone
   - Building, gate, shift
   - Current status
7. Guard clicks "Mark Entry" or "Mark Exit"
8. System:
   - Creates/updates attendance record
   - Updates staff status
   - Shows confirmation
9. Modal closes, scanner ready for next scan

### Attendance Tracking Flow

1. Admin opens Staff Management
2. Clicks on staff member
3. Opens `StaffAttendanceDetailsScreen`
4. Displays all attendance records with:
   - Entry time
   - Exit time
   - Duration on-site
   - Gate and building
   - Status (inside/exited)
5. Can scroll through historical records

---

## DEPENDENCIES REQUIRED

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^4.13.0
  firebase_auth: ^4.10.0
  qr_flutter: ^4.1.0
  mobile_scanner: ^3.5.0
  share_plus: ^7.2.0
  pdf: ^3.10.0
  printing: ^5.11.0
  intl: ^0.19.0
```

---

## INTEGRATION STEPS

### Step 1: Update pubspec.yaml
Add all required dependencies listed above.

### Step 2: Create Service
- Copy `staff_qr_service.dart` to `lib/services/`

### Step 3: Update Models
- Update `lib/models/staff_models.dart` with new fields

### Step 4: Create UI Screens
- Copy `staff_profile_qr_screen.dart` to `lib/`
- Copy `security_staff_qr_scanner.dart` to `lib/`
- Copy `staff_attendance_details_screen.dart` to `lib/`

### Step 5: Create Widgets
- Copy `add_staff_with_qr_modal.dart` to `lib/widgets/`

### Step 6: Update Existing Screens
- Update `staff_management_screen.dart` to use new modal
- Update `staff_details_screen.dart` to show QR code
- Add scanner navigation in security app

### Step 7: Update Main Navigation
Add routes in `main.dart`:
```dart
'/staff-profile-qr': (context) => StaffProfileQRScreen(
  staffId: settings.arguments as String,
),
'/security-staff-scanner': (context) => const SecurityStaffQRScanner(),
'/staff-attendance': (context) => StaffAttendanceDetailsScreen(
  staffId: settings.arguments as String,
  staffName: 'Staff Member',
),
```

---

## FIRESTORE RULES

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Staff collection
    match /staff/{staffId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                       request.resource.data.adminId == request.auth.uid;
      allow update: if request.auth != null && 
                       resource.data.adminId == request.auth.uid;
      allow delete: if request.auth != null && 
                       resource.data.adminId == request.auth.uid;
    }

    // Staff Attendance collection
    match /staffAttendance/{attendanceId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
  }
}
```

---

## TESTING CHECKLIST

### Admin App
- [ ] Add staff member with all details
- [ ] Verify QR code is generated
- [ ] View staff profile with QR
- [ ] Share QR code
- [ ] Download ID card as PDF
- [ ] View attendance records
- [ ] Filter attendance by date

### Security App
- [ ] Open QR scanner
- [ ] Scan valid QR code
- [ ] View staff details modal
- [ ] Mark entry
- [ ] Verify attendance record created
- [ ] Mark exit
- [ ] Verify exit time recorded
- [ ] Check duration calculation

### Firestore
- [ ] Staff document created with all fields
- [ ] QR code URL saved
- [ ] Attendance records created on entry
- [ ] Attendance records updated on exit
- [ ] Status field updated correctly

---

## TROUBLESHOOTING

### QR Code Not Generating
- Ensure `qr_flutter` package is installed
- Check staffId is not null
- Verify Firestore write permissions

### Scanner Not Working
- Check camera permissions granted
- Ensure `mobile_scanner` package is installed
- Verify QR code is valid

### Attendance Not Recording
- Check Firestore rules allow writes
- Verify staffId exists in staff collection
- Check network connectivity

### PDF Download Fails
- Ensure `pdf` and `printing` packages installed
- Check storage permissions
- Verify staff data is complete

---

## FUTURE ENHANCEMENTS

1. **Biometric Integration**: Add fingerprint/face recognition
2. **Geofencing**: Verify location before marking entry/exit
3. **Notifications**: Send alerts for late arrivals
4. **Reports**: Generate attendance reports and analytics
5. **Mobile Wallet**: Add QR to digital wallet
6. **Multi-language**: Support multiple languages
7. **Offline Mode**: Cache QR codes for offline scanning
8. **Analytics Dashboard**: Real-time attendance analytics

---

## NOTES

- QR codes are generated from staffId for uniqueness
- Attendance records are immutable once created
- Status field tracks current location (inside/outside)
- All timestamps use server time for consistency
- Share functionality uses native share dialog
- PDF generation uses printing package for preview/print

---

## SUPPORT

For issues or questions:
1. Check Firestore rules
2. Verify all dependencies installed
3. Check console logs for errors
4. Ensure camera permissions granted
5. Verify network connectivity
