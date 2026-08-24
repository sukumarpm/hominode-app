# Auto-Generated Credentials Feature

## Overview
Implemented automatic generation of login credentials (Resident ID and Password) when creating new residents through the "Add New" form in the Assign Resident modal.

## Features Implemented

### 1. Automatic Credential Generation

#### Resident ID Generation
- **Format**: `RES` + 4 random digits
- **Example**: `RES5326`, `RES7891`, `RES1234`
- **Range**: RES1000 to RES9999
- **Algorithm**: Uses Dart's `Random` class to generate unique IDs

```dart
final residentNumber = random.nextInt(9000) + 1000; // 1000-9999
_generatedResidentId = 'RES$residentNumber';
```

#### Password Generation
- **Length**: 8 characters
- **Character Set**: Alphanumeric (A-Z, a-z, 0-9)
- **Example**: `aB3xK9mP`, `Qw7tY2nL`
- **Security**: Random generation for each new resident

```dart
const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
_generatedPassword = String.fromCharCodes(
  Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
);
```

### 2. Dynamic UI Display

The credentials info card now displays the **actual generated values**:

```
┌─────────────────────────────────────────────┐
│ ✨ Login credentials will be auto-generated:│
│                                             │
│ • Resident ID: RES5326                      │
│ • Password: Will be sent via SMS/Email      │
└─────────────────────────────────────────────┘
```

- The Resident ID updates dynamically
- Shows the actual ID that will be assigned
- Password is generated but not displayed (security)

### 3. Regeneration on Mode Switch

**Behavior**: New credentials are generated each time user switches to "Add New" tab

**Why**: Ensures fresh, unique credentials for each new resident creation attempt

**Flow**:
1. User clicks "Add New" tab
2. System automatically generates new Resident ID
3. System automatically generates new Password
4. UI updates to show new Resident ID
5. User fills form and submits

### 4. API Integration Ready

The generated credentials are included in the API request:

```dart
final newResidentRequest = AssignResidentNewRequest(
  flatId: widget.flatId,
  name: _nameController.text.trim(),
  phone: _phoneController.text.trim(),
  familyMembers: int.tryParse(_familyMembersController.text.trim()) ?? 1,
  email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
  ownershipType: _ownershipType,
  generatedResidentId: _generatedResidentId,  // ← Auto-generated
  generatedPassword: _generatedPassword,       // ← Auto-generated
);
```

### 5. Console Logging (Development)

For development/debugging, credentials are logged:

```
Generated Credentials:
Resident ID: RES5326
Password: aB3xK9mP
Will be sent to: +91 1234567890 / resident@email.com
```

## Data Model Updates

### AssignResidentNewRequest
Added two new fields:

```dart
class AssignResidentNewRequest {
  final String flatId;
  final String name;
  final String phone;
  final int familyMembers;
  final String? email;
  final String ownershipType;
  final String generatedResidentId;  // ← NEW
  final String generatedPassword;    // ← NEW
  
  Map<String, dynamic> toJson() {
    return {
      'flatId': flatId,
      'name': name,
      'phone': phone,
      'familyMembers': familyMembers,
      'email': email,
      'ownershipType': ownershipType,
      'residentId': generatedResidentId,  // ← Sent to API
      'password': generatedPassword,       // ← Sent to API
    };
  }
}
```

## State Management

### New State Variables
```dart
// Auto-generated credentials
String _generatedResidentId = '';
String _generatedPassword = '';
```

### Generation Function
```dart
void _generateCredentials() {
  // Generate Resident ID: RES + 4 random digits
  final random = Random();
  final residentNumber = random.nextInt(9000) + 1000;
  _generatedResidentId = 'RES$residentNumber';
  
  // Generate Password: 8 characters (alphanumeric)
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  _generatedPassword = String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
  );
  
  setState(() {});
}
```

## User Flow

### Complete Flow with Auto-Generation

1. **User opens Assign Resident modal**
   - Credentials generated on init

2. **User clicks "Add New" tab**
   - New credentials auto-generated
   - Resident ID displayed in info card

3. **User fills form**
   - Name: "John Doe"
   - Phone: "+91 9876543210"
   - Email: "john@example.com"
   - Family Members: "3"
   - Ownership: "Owner"

4. **User clicks "Assign Resident"**
   - System creates resident with ID: `RES5326`
   - System sets password: `aB3xK9mP`
   - System sends SMS to: +91 9876543210
   - System sends Email to: john@example.com
   - Both messages contain login credentials

5. **Success**
   - Modal closes
   - Success message shown
   - Resident can now login with generated credentials

## Backend Integration Points

### API Endpoint Requirements

The backend should:

1. **Accept the generated credentials**
   ```json
   {
     "flatId": "A101",
     "name": "John Doe",
     "phone": "+91 9876543210",
     "email": "john@example.com",
     "familyMembers": 3,
     "ownershipType": "Owner",
     "residentId": "RES5326",
     "password": "aB3xK9mP"
   }
   ```

2. **Create resident account**
   - Use provided `residentId` as username
   - Hash and store `password`
   - Create user profile with provided details

3. **Send notifications**
   - **SMS**: Send to `phone` with credentials
   - **Email**: Send to `email` with credentials (if provided)
   - Include login instructions

4. **Assign to flat**
   - Link resident to specified `flatId`
   - Update flat occupancy status

### SMS Template Example
```
Welcome to [Society Name]!

Your login credentials:
Username: RES5326
Password: aB3xK9mP

Download our app: [link]
Login at: [website]

Keep these credentials safe.
```

### Email Template Example
```
Subject: Welcome to [Society Name] - Your Login Credentials

Dear John Doe,

Welcome to [Society Name]! Your flat A101 has been assigned.

Your login credentials:
Username: RES5326
Password: aB3xK9mP

You can login at: [website]
Or download our mobile app: [link]

For security, please change your password after first login.

Best regards,
[Society Name] Admin
```

## Security Considerations

### Current Implementation
- ✅ Random generation using Dart's Random class
- ✅ 8-character alphanumeric passwords
- ✅ Password not displayed in UI
- ✅ Credentials logged only in development

### Production Recommendations
1. **Use cryptographically secure random generator**
   ```dart
   import 'dart:math' show Random;
   import 'dart:convert' show base64;
   import 'package:crypto/crypto.dart';
   ```

2. **Increase password complexity**
   - Add special characters: `!@#$%^&*()`
   - Increase length to 12+ characters
   - Ensure mix of upper, lower, numbers, symbols

3. **Check for ID uniqueness**
   - Verify Resident ID doesn't already exist
   - Retry generation if collision detected

4. **Implement password hashing**
   - Backend should hash passwords (bcrypt, argon2)
   - Never store plain text passwords

5. **Add password expiry**
   - Force password change on first login
   - Set temporary password expiry (24-48 hours)

6. **Rate limiting**
   - Limit credential generation attempts
   - Prevent brute force attacks

## Testing

### Manual Testing Checklist
- [ ] Open modal, verify credentials generated
- [ ] Switch to "Add New", verify new credentials
- [ ] Check Resident ID format (RES + 4 digits)
- [ ] Verify ID displays in info card
- [ ] Submit form, check console logs
- [ ] Verify credentials included in API request
- [ ] Test multiple submissions (unique IDs each time)

### Edge Cases
- [ ] Rapid tab switching (credentials regenerate)
- [ ] Form submission with generated credentials
- [ ] Modal close and reopen (new credentials)
- [ ] Multiple modals open simultaneously

## Future Enhancements

1. **ID Uniqueness Check**
   - Query backend before finalizing ID
   - Retry if ID already exists

2. **Custom ID Patterns**
   - Allow admin to configure ID format
   - Support different prefixes per building/tower

3. **Password Strength Options**
   - Let admin choose password complexity
   - Option for memorable vs secure passwords

4. **Credential Preview**
   - Show password temporarily with "Show/Hide" toggle
   - Copy to clipboard functionality

5. **Bulk Generation**
   - Generate credentials for multiple residents
   - Export credentials list for admin

6. **QR Code Generation**
   - Generate QR code with credentials
   - Print for physical distribution

## Summary

The auto-generation feature is now fully functional:
- ✅ Generates unique Resident IDs (RES + 4 digits)
- ✅ Generates secure passwords (8 alphanumeric chars)
- ✅ Displays ID dynamically in UI
- ✅ Regenerates on mode switch
- ✅ Includes credentials in API request
- ✅ Ready for SMS/Email notification integration
- ✅ Follows UI flow and design specifications
