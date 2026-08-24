# Security App - Quick Reference Guide

## 📱 App Overview
Security Guard module extracted from Admin App for gate security operations.

## 🎯 Core Features
1. **Visitor Management** - Approve/reject, track entry/exit
2. **QR Scanner** - Check-in/check-out visitors
3. **Staff Attendance** - Mark and track attendance
4. **Complaint Tracking** - View and update assigned complaints

---

## 🎨 UI Design (Reused from Admin App)

### Colors
```dart
Primary: Color(0xFF2563EB)
Success: Color(0xFF16A34A)
Warning: Color(0xFFF59E0B)
Error: Color(0xFFEF4444)
Purple: Color(0xFF9333EA)
Background: Color(0xFFF7F7F7)
```

### Spacing
- Screen padding: 16px
- Card padding: 16px
- Section spacing: 20px
- Border radius: 12px

---

## 📊 Firestore Collections

### visitors
```dart
{
  visitorName, phone, residentId, residentName,
  flatId, flatLabel, purpose,
  isApproved, actualArrival, departure,
  adminId, createdAt, updatedAt
}
```

### staff
```dart
{
  name, role, phone, email,
  status, lastCheckIn, lastCheckOut,
  adminId, buildingId, createdAt
}
```

### attendance
```dart
{
  staffId, date, status,
  checkInTime, checkOutTime,
  adminId, markedBy, createdAt
}
```

### complaints
```dart
{
  title, description, category, priority, status,
  residentId, assignedTo,
  adminId, createdAt, resolvedAt
}
```

---

## 🔄 Key Flows

### Visitor Check-In
1. Resident creates request → Pending
2. Security approves → Active
3. Visitor arrives → Scan QR → Set actualArrival
4. Visitor leaves → Scan QR → Set departure → History

### Staff Attendance
1. Open attendance screen
2. Tap "Mark Attendance"
3. Select staff → Mark Present/Absent/On Leave
4. Updates both `attendance` and `staff` collections

---

## 📦 Required Packages
```yaml
firebase_core: ^3.8.1
firebase_auth: ^5.3.3
cloud_firestore: ^5.5.0
mobile_scanner: ^5.2.3
permission_handler: ^11.3.1
intl: ^0.19.0
```

---

## 🔐 Permissions

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS (Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access required to scan visitor QR codes</string>
```

---

## 🚀 Quick Start

1. Copy UI components from Admin App
2. Implement security screens
3. Configure Firebase
4. Add QR scanning
5. Test flows
6. Deploy

---

## 📝 Key Queries

### Get Pending Visitors
```dart
.where('adminId', '==', adminId)
.where('isApproved', '==', false)
```

### Get Active Visitors
```dart
.where('adminId', '==', adminId)
.where('actualArrival', '!=', null)
.where('departure', '==', null)
```

### Mark Attendance
```dart
// Update attendance/{staffId}_{date}
// Update staff/{staffId}.status
```

---

## ✅ Testing Checklist
- [ ] Login with security role
- [ ] Approve visitor
- [ ] Scan QR check-in
- [ ] Scan QR check-out
- [ ] Mark staff attendance
- [ ] View attendance history
- [ ] Update complaint status
- [ ] Search functionality
- [ ] Real-time updates
- [ ] Error handling

---

**For complete details, see**: `SECURITY_APP_COMPLETE_SPECIFICATION.md`
