# Enhanced Staff Management System - Complete Specification

## Overview

This document specifies the complete staff management system with enhanced fields, photo uploads, document management, and full CRUD operations.

---

## 1. STAFF DATA MODEL (Enhanced)

### Firestore Collection: `staff`

```javascript
{
  // Basic Information
  name: String,
  role: String,  // From expanded categories
  phone: String,
  email: String (optional),
  dateOfBirth: Timestamp (optional),
  gender: String (optional),  // "Male", "Female", "Other"
  
  // Address Information
  address: String,
  city: String (optional),
  state: String (optional),
  pincode: String (optional),
  
  // Identity Documents
  aadharNumber: String,  // Encrypted/masked for security
  aadharCardImageUrl: String,  // Firebase Storage URL
  photoUrl: String,  // Profile photo - Firebase Storage URL
  
  // Employment Details
  joiningDate: Timestamp,
  salary: Number,
  shift: String,  // "Morning", "Evening", "Night", "Rotational"
  employmentType: String,  // "Full-time", "Part-time", "Contract"
  
  // Emergency Contact
  emergencyContactName: String,
  emergencyContactPhone: String,
  emergencyContactRelation: String,
  
  // Bank Details (Optional)
  bankAccountNumber: String (optional),
  bankName: String (optional),
  ifscCode: String (optional),
  
  // Attendance Status
  status: String,  // "pending", "present", "absent", "onLeave", "offDuty"
  lastCheckIn: Timestamp | null,
  lastCheckOut: Timestamp | null,
  
  // Performance Tracking
  rating: Number (default: 0.0),
  totalTasks: Number (default: 0),
  completedTasks: Number (default: 0),
  skills: Array<String>,
  
  // System Fields
  isActive: Boolean (default: true),
  createdAt: Timestamp,
  updatedAt: Timestamp,
  createdBy: String (admin user ID),
}
```

---

## 2. EXPANDED ROLE CATEGORIES

### Staff Roles (Comprehensive List)

```dart
final List<String> staffRoles = [
  // Security
  'Security Guard',
  'Security Supervisor',
  'Gate Keeper',
  
  // Maintenance
  'Electrician',
  'Plumber',
  'Carpenter',
  'Painter',
  'AC Technician',
  'Lift Technician',
  'General Maintenance',
  
  // Housekeeping
  'Housekeeping Staff',
  'Housekeeping Supervisor',
  'Sweeper',
  'Cleaner',
  
  // Gardening
  'Gardener',
  'Landscaper',
  
  // Administration
  'Facility Manager',
  'Admin Assistant',
  'Receptionist',
  
  // Specialized
  'Pest Control',
  'Pool Maintenance',
  'Gym Trainer',
  'Yoga Instructor',
  
  // Support
  'Driver',
  'Helper',
  'Delivery Personnel',
  
  // Other
  'Other',
];
```

### Shift Options

```dart
final List<String> shifts = [
  'Morning (6 AM - 2 PM)',
  'Afternoon (2 PM - 10 PM)',
  'Night (10 PM - 6 AM)',
  'Full Day (9 AM - 6 PM)',
  'Rotational',
  'Flexible',
];
```

### Employment Types

```dart
final List<String> employmentTypes = [
  'Full-time',
  'Part-time',
  'Contract',
  'Temporary',
  'Intern',
];
```

---

## 3. ADD STAFF MEMBER DIALOG (Enhanced)

### UI Structure

```
┌─────────────────────────────────────────┐
│  Add Staff Member                    ✕  │
├─────────────────────────────────────────┤
│                                         │
│  📷 Profile Photo                       │
│  [Upload Photo Button]                  │
│  (Shows preview after upload)           │
│                                         │
│  ━━━ Basic Information ━━━              │
│  Full Name *                            │
│  [Text Input]                           │
│                                         │
│  Role *                                 │
│  [Dropdown: Security Guard, etc.]       │
│                                         │
│  Phone Number *                         │
│  [Text Input: +91 XXXXX XXXXX]          │
│                                         │
│  Email                                  │
│  [Text Input]                           │
│                                         │
│  Date of Birth                          │
│  [Date Picker]                          │
│                                         │
│  Gender                                 │
│  [Dropdown: Male/Female/Other]          │
│                                         │
│  ━━━ Address Details ━━━                │
│  Address *                              │
│  [Text Input - Multiline]               │
│                                         │
│  City                                   │
│  [Text Input]                           │
│                                         │
│  State                                  │
│  [Text Input]                           │
│                                         │
│  Pincode                                │
│  [Text Input]                           │
│                                         │
│  ━━━ Identity Documents ━━━             │
│  Aadhar Number *                        │
│  [Text Input: XXXX XXXX XXXX]           │
│                                         │
│  📄 Aadhar Card Image *                 │
│  [Upload Document Button]               │
│  (Shows preview after upload)           │
│                                         │
│  ━━━ Employment Details ━━━             │
│  Joining Date *                         │
│  [Date Picker]                          │
│                                         │
│  Monthly Salary *                       │
│  [Number Input: ₹]                      │
│                                         │
│  Shift *                                │
│  [Dropdown: Morning/Evening/Night]      │
│                                         │
│  Employment Type *                      │
│  [Dropdown: Full-time/Part-time]        │
│                                         │
│  ━━━ Emergency Contact ━━━              │
│  Contact Name *                         │
│  [Text Input]                           │
│                                         │
│  Contact Phone *                        │
│  [Text Input]                           │
│                                         │
│  Relation                               │
│  [Text Input: Father/Mother/Spouse]     │
│                                         │
│  ━━━ Bank Details (Optional) ━━━        │
│  Account Number                         │
│  [Text Input]                           │
│                                         │
│  Bank Name                              │
│  [Text Input]                           │
│                                         │
│  IFSC Code                              │
│  [Text Input]                           │
│                                         │
│  ━━━ Skills & Notes ━━━                 │
│  Skills (comma separated)               │
│  [Text Input]                           │
│                                         │
│  [Cancel]          [Add Staff Member]   │
└─────────────────────────────────────────┘
```

### Image Upload Flow

1. **Profile Photo Upload**
   ```
   User clicks "Upload Photo"
     ↓
   Opens image picker (Camera/Gallery)
     ↓
   User selects/captures image
     ↓
   Image compressed (max 500KB)
     ↓
   Uploaded to Firebase Storage: /staff_photos/{staffId}_profile.jpg
     ↓
   Get download URL
     ↓
   Save URL to Firestore
   ```

2. **Aadhar Card Upload**
   ```
   User clicks "Upload Aadhar Card"
     ↓
   Opens image picker (Camera/Gallery)
     ↓
   User selects/captures image
     ↓
   Image compressed (max 1MB)
     ↓
   Uploaded to Firebase Storage: /staff_documents/{staffId}_aadhar.jpg
     ↓
   Get download URL
     ↓
   Save URL to Firestore
   ```

### Validation Rules

```dart
// Required Fields
- name: Not empty, min 2 characters
- role: Must be selected
- phone: Valid 10-digit number
- address: Not empty
- aadharNumber: Valid 12-digit number
- aadharCardImage: Must be uploaded
- joiningDate: Must be selected
- salary: Must be > 0
- shift: Must be selected
- employmentType: Must be selected
- emergencyContactName: Not empty
- emergencyContactPhone: Valid 10-digit number

// Optional Fields
- email: Valid email format if provided
- dateOfBirth: Must be in past if provided
- city, state, pincode: No validation
- emergencyContactRelation: No validation
- bankAccountNumber: Numeric if provided
- ifscCode: Valid IFSC format if provided
```

---

## 4. STAFF DETAILS SCREEN (Enhanced)

### UI Structure

```
┌─────────────────────────────────────────┐
│  ← Staff Details              ⋮ [Menu]  │
├─────────────────────────────────────────┤
│                                         │
│         [Profile Photo]                 │
│         Ramesh Kumar                    │
│         Security Guard                  │
│         [Present] Badge                 │
│                                         │
│  ━━━ Quick Actions ━━━                  │
│  [Mark Present] [Mark Absent] [Leave]   │
│                                         │
│  ━━━ Basic Information ━━━              │
│  📱 Phone: +91 98765 43210              │
│  📧 Email: ramesh@example.com           │
│  🎂 DOB: 15/08/1990 (33 years)          │
│  👤 Gender: Male                        │
│                                         │
│  ━━━ Address ━━━                        │
│  📍 123, Worker Colony                  │
│      Mumbai, Maharashtra                │
│      Pincode: 400001                    │
│                                         │
│  ━━━ Identity Documents ━━━             │
│  🆔 Aadhar: XXXX XXXX 1234              │
│  [View Aadhar Card Image]               │
│                                         │
│  ━━━ Employment Details ━━━             │
│  📅 Joining: 15/01/2023                 │
│  💰 Salary: ₹15,000/month               │
│  ⏰ Shift: Morning (6 AM - 2 PM)        │
│  📋 Type: Full-time                     │
│  ⭐ Rating: 4.5/5.0                     │
│                                         │
│  ━━━ Attendance Today ━━━               │
│  ✅ Check-in: 06:05 AM                  │
│  ⏱️ Working Hours: 5h 30m               │
│                                         │
│  ━━━ Emergency Contact ━━━              │
│  👤 Name: Sunita Kumar                  │
│  📱 Phone: +91 98765 12345              │
│  🔗 Relation: Wife                      │
│                                         │
│  ━━━ Bank Details ━━━                   │
│  🏦 Bank: HDFC Bank                     │
│  💳 Account: XXXX XXXX 5678             │
│  🔢 IFSC: HDFC0001234                   │
│                                         │
│  ━━━ Skills ━━━                         │
│  [Security] [CCTV] [First Aid]          │
│                                         │
│  ━━━ Performance ━━━                    │
│  Total Tasks: 45                        │
│  Completed: 42                          │
│  Success Rate: 93%                      │
│                                         │
│  [Edit Staff]  [Delete Staff]           │
│                                         │
└─────────────────────────────────────────┘
```

### Menu Options (⋮)

```
┌─────────────────────────┐
│ Edit Staff Details      │
│ Mark Attendance         │
│ View Attendance History │
│ Assign Task             │
│ View Documents          │
│ ─────────────────       │
│ Deactivate Staff        │
│ Delete Staff            │
└─────────────────────────┘
```

---

## 5. STAFF ACTIONS

### 5.1 Edit Staff

**Flow:**
```
Click "Edit Staff"
  ↓
Opens Edit Staff Dialog (similar to Add Staff)
  ↓
Pre-populated with existing data
  ↓
Admin makes changes
  ↓
Click "Save Changes"
  ↓
Validates input
  ↓
Updates Firestore
  ↓
Shows success message
  ↓
Refreshes staff details
```

**Editable Fields:**
- All fields except:
  - Aadhar Number (read-only for security)
  - Created date
  - Staff ID

**Can Update:**
- Profile photo
- Aadhar card image (if needed)
- All other personal/employment details

### 5.2 Delete Staff

**Flow:**
```
Click "Delete Staff"
  ↓
Shows confirmation dialog:
  "Are you sure you want to delete Ramesh Kumar?"
  "This action cannot be undone."
  [Reason for deletion: ___________]
  [Cancel] [Delete]
  ↓
If confirmed:
  ↓
Soft delete: Set isActive = false
  ↓
Add deletedAt timestamp
  ↓
Add deletedBy (admin ID)
  ↓
Add deletionReason
  ↓
Navigate back to staff list
  ↓
Show success message
```

**Note:** Soft delete preserves data for records/audit trail

### 5.3 Mark Attendance

**From Staff Details Screen:**

```
Click "Mark Present"
  ↓
Calls AttendanceService.markPresent(staffId)
  ↓
Updates staff status to "present"
  ↓
Records check-in time
  ↓
Updates UI immediately
  ↓
Shows success message
```

**Quick Actions:**
- Mark Present → Green button
- Mark Absent → Red button
- Mark Leave → Orange button

### 5.4 View Attendance History

**Flow:**
```
Click "View Attendance History"
  ↓
Opens Attendance History Screen
  ↓
Shows calendar view with:
  - Present days (green)
  - Absent days (red)
  - Leave days (orange)
  - Off days (gray)
  ↓
Shows statistics:
  - Total working days
  - Present days
  - Absent days
  - Leave days
  - Attendance percentage
```

---

## 6. FIREBASE STORAGE STRUCTURE

```
/staff_photos/
  {staffId}_profile.jpg
  {staffId}_profile_thumb.jpg (thumbnail)

/staff_documents/
  {staffId}_aadhar.jpg
  {staffId}_aadhar_thumb.jpg
  {staffId}_other_doc1.jpg
  {staffId}_other_doc2.jpg
```

### Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Staff photos
    match /staff_photos/{staffId}_{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                     request.resource.size < 5 * 1024 * 1024 && // 5MB max
                     request.resource.contentType.matches('image/.*');
    }
    
    // Staff documents
    match /staff_documents/{staffId}_{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                     request.resource.size < 10 * 1024 * 1024 && // 10MB max
                     request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## 7. IMPLEMENTATION CHECKLIST

### Phase 1: Data Model & Service (Week 1)
- [ ] Update `StaffMember` model in `staff_vendor_service.dart`
- [ ] Add all new fields
- [ ] Update `addStaffMember()` method
- [ ] Update `updateStaffMember()` method
- [ ] Add `deleteStaffMember()` method (soft delete)
- [ ] Add `getStaffMemberById()` method
- [ ] Test Firestore operations

### Phase 2: Image Upload Service (Week 1)
- [ ] Create `ImageUploadService` class
- [ ] Add `uploadProfilePhoto()` method
- [ ] Add `uploadDocument()` method
- [ ] Add image compression
- [ ] Add thumbnail generation
- [ ] Test uploads to Firebase Storage

### Phase 3: Enhanced Add Staff Dialog (Week 2)
- [ ] Update UI with all new fields
- [ ] Add image picker for profile photo
- [ ] Add image picker for Aadhar card
- [ ] Add all dropdowns (role, shift, employment type, gender)
- [ ] Add date pickers (DOB, joining date)
- [ ] Add validation for all fields
- [ ] Implement image upload flow
- [ ] Test complete add staff flow

### Phase 4: Enhanced Staff Details Screen (Week 2)
- [ ] Update UI to show all fields
- [ ] Add profile photo display
- [ ] Add document viewer
- [ ] Add quick action buttons
- [ ] Add menu with all options
- [ ] Implement edit functionality
- [ ] Implement delete functionality
- [ ] Implement mark attendance from details
- [ ] Test all actions

### Phase 5: Edit Staff Dialog (Week 3)
- [ ] Create edit staff dialog
- [ ] Pre-populate all fields
- [ ] Allow photo/document updates
- [ ] Implement save changes
- [ ] Test edit flow

### Phase 6: Attendance Integration (Week 3)
- [ ] Add attendance buttons to details screen
- [ ] Integrate with AttendanceService
- [ ] Show today's attendance status
- [ ] Add attendance history view
- [ ] Test attendance marking

### Phase 7: Testing & Polish (Week 4)
- [ ] End-to-end testing
- [ ] UI/UX improvements
- [ ] Error handling
- [ ] Loading states
- [ ] Success/error messages
- [ ] Performance optimization

---

## 8. SECURITY CONSIDERATIONS

### Data Protection
1. **Aadhar Number**: Store encrypted or masked (show only last 4 digits)
2. **Bank Details**: Encrypt sensitive information
3. **Documents**: Secure Firebase Storage with proper rules
4. **Access Control**: Only admins can view/edit staff data

### Privacy Compliance
1. Get consent for storing personal data
2. Allow staff to request data deletion
3. Implement data retention policies
4. Audit trail for all changes

---

## 9. USER PERMISSIONS

### Admin Can:
- ✅ Add new staff
- ✅ View all staff details
- ✅ Edit staff information
- ✅ Delete/deactivate staff
- ✅ Mark attendance
- ✅ View attendance history
- ✅ Upload/view documents
- ✅ Assign tasks

### Staff Cannot:
- ❌ View other staff details
- ❌ Edit their own details (must request admin)
- ❌ Delete records

---

## 10. FUTURE ENHANCEMENTS

### Phase 2 Features
- [ ] Biometric attendance integration
- [ ] Leave management system
- [ ] Payroll integration
- [ ] Performance review system
- [ ] Training & certification tracking
- [ ] Shift scheduling
- [ ] Task assignment & tracking
- [ ] Staff app for self-service

---

**Document Version:** 1.0  
**Last Updated:** February 20, 2026  
**Status:** Specification Complete - Ready for Implementation
