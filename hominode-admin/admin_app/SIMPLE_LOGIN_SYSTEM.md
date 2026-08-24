# Simple Login System - Email/Phone + Password

## Overview
Residents login using their **Email or Phone** + **Auto-generated Password**. No complex Resident IDs needed!

## How It Works

### Admin Creates Resident

**Step 1: Admin fills form**
```
┌─────────────────────────────────────────────┐
│ Assign Resident to A101                     │
├─────────────────────────────────────────────┤
│ [Select Existing] [Add New] ← Click         │
├─────────────────────────────────────────────┤
│                                             │
│ Resident Name *                             │
│ [Sarah Williams___________________]         │
│                                             │
│ Phone Number *        Family Members        │
│ [9123456789_____]     [4__________]         │
│                                             │
│ Email Address                               │
│ [sarah@example.com________________]         │
│                                             │
│ Ownership Type: [Owner ▼]                  │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ✨ Login credentials:                   │ │
│ │                                          │ │
│ │ • Username: sarah@example.com           │ │
│ │   (Email/Phone)                         │ │
│ │ • Password: aB3xK9mP                    │ │
│ │   (auto-generated)                      │ │
│ │                                          │ │
│ │ Credentials will be sent via SMS/Email  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ [Assign Resident]                           │
└─────────────────────────────────────────────┘
```

**Step 2: System auto-generates password**
- Password: `aB3xK9mP` (8 random alphanumeric characters)
- Username: Uses the email if provided, otherwise phone number

**Step 3: Data stored in Firestore**
```javascript
users/{userId} = {
  name: "Sarah Williams",
  phone: "9123456789",
  email: "sarah@example.com",
  residentId: "RES5326",              // Internal reference only
  authEmail: "sarah@example.com",     // Used for Firebase Auth
  password: "aB3xK9mP",               // Auto-generated
  authUid: "firebase_auth_uid",
  role: "resident",
  flatId: "A101",
  flatLabel: "A101",
  ownershipType: "Owner",
  familyMembers: 4,
  status: "active"
}
```

**Step 4: Firebase Auth account created**
```javascript
Firebase Authentication:
{
  email: "sarah@example.com",        // Actual email
  password: "aB3xK9mP",              // Hashed by Firebase
  displayName: "Sarah Williams"
}
```

### Resident Logs In

**Login Screen:**
```
┌─────────────────────────────────────┐
│                                     │
│         🏢 Lyvo Resident            │
│                                     │
│  Welcome Back!                      │
│  Login to your account              │
│                                     │
│  Email or Phone                     │
│  ┌───────────────────────────────┐ │
│  │ sarah@example.com             │ │
│  └───────────────────────────────┘ │
│                                     │
│  Password                           │
│  ┌───────────────────────────────┐ │
│  │ ••••••••                      │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │         Login                 │ │
│  └───────────────────────────────┘ │
│                                     │
│  Forgot Password?                   │
│                                     │
└─────────────────────────────────────┘
```

**Login Options:**

**Option 1: Login with Email**
```
Email: sarah@example.com
Password: aB3xK9mP
```

**Option 2: Login with Phone**
```
Phone: 9123456789
Password: aB3xK9mP
```

### Login Flow (Behind the Scenes)

**Scenario 1: User enters Email**
```
User enters: sarah@example.com + aB3xK9mP
    ↓
Query Firestore:
WHERE email = "sarah@example.com"
WHERE role = "resident"
    ↓
Get authEmail: "sarah@example.com"
    ↓
Firebase Auth:
signInWithEmailAndPassword(
  email: "sarah@example.com",
  password: "aB3xK9mP"
)
    ↓
✅ Login successful!
```

**Scenario 2: User enters Phone**
```
User enters: 9123456789 + aB3xK9mP
    ↓
Query Firestore:
WHERE phone = "9123456789"
WHERE role = "resident"
    ↓
Get authEmail: "sarah@example.com" OR "9123456789@lyvo.com"
    ↓
Firebase Auth:
signInWithEmailAndPassword(
  email: authEmail,
  password: "aB3xK9mP"
)
    ↓
✅ Login successful!
```

## Two Cases

### Case 1: Resident Has Email
```
Admin enters:
- Name: Sarah Williams
- Phone: 9123456789
- Email: sarah@example.com ✅
- Password: aB3xK9mP (auto-generated)

Firebase Auth uses:
- Email: sarah@example.com
- Password: aB3xK9mP

Resident logs in with:
- Email: sarah@example.com
- Password: aB3xK9mP
```

### Case 2: Resident Has NO Email
```
Admin enters:
- Name: John Doe
- Phone: 9876543210
- Email: (empty) ❌
- Password: Xy9mN4pQ (auto-generated)

Firebase Auth uses:
- Email: 9876543210@lyvo.com (auto-generated)
- Password: Xy9mN4pQ

Resident logs in with:
- Phone: 9876543210
- Password: Xy9mN4pQ
```

## SMS/Email Notifications

### SMS Template (With Email)
```
Welcome to Green Valley Society!

Your login credentials:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Email: sarah@example.com
Password: aB3xK9mP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Download app: https://lyvo.app

Keep these credentials safe.
```

### SMS Template (Without Email)
```
Welcome to Green Valley Society!

Your login credentials:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phone: 9876543210
Password: Xy9mN4pQ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Download app: https://lyvo.app

Keep these credentials safe.
```

### Email Template
```
Subject: Welcome to Green Valley Society - Your Login Credentials

Dear Sarah Williams,

Welcome to Green Valley Society! Your flat A101 has been assigned.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR LOGIN CREDENTIALS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Email: sarah@example.com
Password: aB3xK9mP

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GETTING STARTED:

1. Download the Lyvo Resident App
2. Open the app and click "Login"
3. Enter your email and password
4. For security, please change your password after first login

Need help? Contact us at support@greenvalley.com

Best regards,
Green Valley Society Management
```

## Implementation

### Password Generation
```dart
// In assign_resident_modal.dart
void _generatePassword() {
  final random = Random();
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  _generatedPassword = String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
  );
  setState(() {});
}
```

### Create User
```dart
// In user_service.dart
Future<String> createUser({
  required String name,
  required String phone,
  required String password,
  String? email,
  int familyMembers = 1,
}) async {
  // Use email if provided, otherwise use phone@lyvo.com
  final authEmail = email?.isNotEmpty == true 
      ? email! 
      : '$phone@lyvo.com';
  
  // Create Firebase Auth account
  UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
    email: authEmail,
    password: password,
  );
  
  // Generate internal resident ID
  final residentId = await generateResidentId();
  
  // Create Firestore document
  await _firestore.collection('users').add({
    'name': name,
    'phone': phone,
    'email': email,
    'residentId': residentId,      // Internal reference
    'authEmail': authEmail,        // For Firebase Auth
    'password': password,          // Auto-generated
    'authUid': userCredential.user?.uid,
    'role': 'resident',
    'status': 'active',
    // ... other fields
  });
}
```

### Resident App Login
```dart
// In auth_service.dart (Resident App)
Future<UserCredential> signIn(String emailOrPhone, String password) async {
  // Check if input is email or phone
  final isEmail = emailOrPhone.contains('@');
  
  String authEmail;
  
  if (isEmail) {
    // Direct email login
    authEmail = emailOrPhone;
  } else {
    // Phone login - query Firestore to get authEmail
    final userQuery = await _firestore
      .collection('users')
      .where('phone', isEqualTo: emailOrPhone)
      .where('role', isEqualTo: 'resident')
      .limit(1)
      .get();
    
    if (userQuery.docs.isEmpty) {
      throw Exception('User not found');
    }
    
    authEmail = userQuery.docs.first.data()['authEmail'];
  }
  
  // Authenticate with Firebase
  return await _auth.signInWithEmailAndPassword(
    email: authEmail,
    password: password,
  );
}
```

## Key Benefits

✅ **Simple for Residents**
- Use their own email or phone
- No need to remember complex IDs
- Natural and intuitive

✅ **Secure**
- Auto-generated random passwords
- Firebase Auth handles security
- Password hashing by Firebase

✅ **Flexible**
- Can login with email OR phone
- Same password for both methods
- System handles conversion

✅ **Admin Friendly**
- Password auto-generated
- Shown in UI for reference
- Sent automatically via SMS/Email

## Summary

**What Admin Does:**
1. Enters resident details (name, phone, email)
2. System auto-generates password
3. Clicks "Assign Resident"

**What Resident Gets:**
- Email: sarah@example.com (or Phone: 9123456789)
- Password: aB3xK9mP

**What Resident Does:**
1. Opens Lyvo Resident App
2. Enters email/phone + password
3. Logs in successfully

**Simple, secure, and user-friendly!** 🎉
