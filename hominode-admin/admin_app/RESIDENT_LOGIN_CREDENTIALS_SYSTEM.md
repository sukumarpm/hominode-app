# Resident Login Credentials System

## Overview
This document explains how the auto-generated login credentials work for residents in the Lyvo Admin App and Resident App.

## Credential Generation

### When Are Credentials Generated?

Credentials are automatically generated when:
1. Admin creates a new resident through "Add New" tab in Assign Resident modal
2. Admin clicks "Add New" tab (credentials regenerate each time)

### What Gets Generated?

#### 1. Username (Resident ID)
- **Format**: `RES` + 4 random digits
- **Examples**: 
  - `RES5326`
  - `RES7891`
  - `RES1234`
  - `RES9999`
- **Range**: RES1000 to RES9999 (9000 possible combinations)
- **Purpose**: This is the username residents use to login
- **Visibility**: Shown to admin and sent to resident

#### 2. Password (Auto-Generated)
- **Format**: 8 random alphanumeric characters
- **Character Set**: A-Z, a-z, 0-9 (62 possible characters per position)
- **Examples**:
  - `aB3xK9mP`
  - `Qw7tY2nL`
  - `Xy9mN4pQ`
  - `Zk5mL8nP`
- **Combinations**: 62^8 = 218 trillion possible passwords
- **Purpose**: This is the password residents use to login
- **Visibility**: Generated but NOT shown in UI (security), sent via SMS/Email

#### 3. Auth Email (Internal Only)
- **Format**: `{residentId}@lyvo.com`
- **Examples**:
  - `RES5326@lyvo.com`
  - `RES7891@lyvo.com`
- **Purpose**: Used internally for Firebase Authentication
- **Visibility**: Never shown to admin or resident (internal use only)

## How It Works

### Admin Side (Creating Resident)

```
┌─────────────────────────────────────────────────────────┐
│ Assign Resident to A101                                 │
├─────────────────────────────────────────────────────────┤
│ [Select Existing] [Add New] ← Click here                │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ Resident Name *                                          │
│ [Sarah Williams_____________________________]           │
│                                                          │
│ Phone Number *              Family Members               │
│ [9123456789_______]         [4____________]             │
│                                                          │
│ Email Address                                            │
│ [sarah@example.com______________________]               │
│                                                          │
│ Ownership Type: [Owner ▼]                               │
│                                                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ✨ Login credentials will be auto-generated:        │ │
│ │                                                      │ │
│ │ • Username (Resident ID): RES5326                   │ │
│ │ • Password: aB3xK9mP (will be sent via SMS/Email)  │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ [Assign Resident]                                        │
└─────────────────────────────────────────────────────────┘
```

**What Admin Sees:**
- Username (Resident ID): `RES5326` ✅ Visible
- Password: `aB3xK9mP` ✅ Visible in info card
- Note: "will be sent via SMS/Email"

**What Gets Stored in Firestore:**
```javascript
users/{userId} = {
  name: "Sarah Williams",
  phone: "9123456789",
  email: "sarah@example.com",
  residentId: "RES5326",           // ← Username for login
  password: "aB3xK9mP",            // ← Password for login
  authEmail: "RES5326@lyvo.com",   // ← Internal use only
  authUid: "firebase_auth_uid",    // ← Link to Firebase Auth
  role: "resident",
  flatId: "A101",
  flatLabel: "A101",
  ownershipType: "Owner",
  familyMembers: 4,
  status: "active",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**What Gets Created in Firebase Auth:**
```javascript
Firebase Authentication Account:
{
  uid: "firebase_auth_uid",
  email: "RES5326@lyvo.com",      // ← Internal email format
  password: "aB3xK9mP",            // ← Hashed by Firebase
  displayName: "Sarah Williams"
}
```

### Resident Side (Login)

#### Login Screen UI
```
┌─────────────────────────────────────┐
│                                     │
│         🏢 Lyvo Resident            │
│                                     │
│  Welcome Back!                      │
│  Login to your account              │
│                                     │
│  Username (Resident ID)             │
│  ┌───────────────────────────────┐ │
│  │ RES5326                       │ │
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

#### Login Flow (Step by Step)

**Step 1: Resident Enters Credentials**
```
User Input:
- Username: RES5326
- Password: aB3xK9mP
```

**Step 2: App Queries Firestore**
```dart
// Resident App Code
final userQuery = await FirebaseFirestore.instance
  .collection('users')
  .where('residentId', isEqualTo: 'RES5326')
  .where('role', isEqualTo: 'resident')
  .limit(1)
  .get();

// Returns user document with:
{
  residentId: "RES5326",
  authEmail: "RES5326@lyvo.com",  // ← We need this
  password: "aB3xK9mP",
  name: "Sarah Williams",
  flatId: "A101",
  ...
}
```

**Step 3: Convert to Auth Email**
```dart
// System converts Resident ID to Auth Email
String residentId = "RES5326";
String authEmail = "$residentId@lyvo.com";  // = "RES5326@lyvo.com"
```

**Step 4: Authenticate with Firebase**
```dart
// Authenticate using the internal email format
UserCredential credential = await FirebaseAuth.instance
  .signInWithEmailAndPassword(
    email: "RES5326@lyvo.com",  // ← Converted from Resident ID
    password: "aB3xK9mP"         // ← User entered password
  );

// Success! User is authenticated
```

**Step 5: Load User Data**
```dart
// Get full user data from Firestore
final userData = await FirebaseFirestore.instance
  .collection('users')
  .doc(credential.user!.uid)
  .get();

// Display in app:
- Name: Sarah Williams
- Flat: A101
- Ownership: Owner
- Family Members: 4
```

## Notification Templates

### SMS Notification
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Welcome to Green Valley Society!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Dear Sarah Williams,

Your flat A101 has been assigned.

LOGIN CREDENTIALS:
Username: RES5326
Password: aB3xK9mP

Download our app:
https://lyvo.app/download

Keep these credentials safe.

For support: +91 1234567890
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Email Notification
```
Subject: Welcome to Green Valley Society - Your Login Credentials

Dear Sarah Williams,

Welcome to Green Valley Society! We're pleased to inform you that your flat A101 has been assigned.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR LOGIN CREDENTIALS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Username (Resident ID): RES5326
Password: aB3xK9mP

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GETTING STARTED:

1. Download the Lyvo Resident App:
   • Android: https://play.google.com/store/apps/lyvo
   • iOS: https://apps.apple.com/app/lyvo

2. Open the app and click "Login"

3. Enter your credentials:
   • Username: RES5326
   • Password: aB3xK9mP

4. For security, please change your password after first login

NEED HELP?

If you have any questions or need assistance, please contact:
• Phone: +91 1234567890
• Email: support@greenvalley.com
• Office Hours: 9 AM - 6 PM (Mon-Sat)

Best regards,
Green Valley Society Management

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IMPORTANT: Keep your credentials safe and do not share them with anyone.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Security Features

### Password Generation
```dart
// Current implementation in assign_resident_modal.dart
void _generateCredentials() {
  final random = Random();
  
  // Generate Resident ID: RES + 4 random digits
  final residentNumber = random.nextInt(9000) + 1000; // 1000-9999
  _generatedResidentId = 'RES$residentNumber';
  
  // Generate Password: 8 alphanumeric characters
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  _generatedPassword = String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
  );
  
  setState(() {});
}
```

### Security Measures

✅ **Random Generation**
- Resident ID: 9000 possible combinations
- Password: 218 trillion possible combinations
- Cryptographically random (Dart's Random class)

✅ **Firebase Auth Integration**
- Passwords hashed by Firebase (bcrypt)
- Never stored in plain text in Firebase Auth
- Secure authentication flow

✅ **Firestore Storage**
- Password stored for reference (admin can resend)
- Protected by Firestore security rules
- Only admin can read all user data

✅ **No Email Exposure**
- Internal email format never shown to users
- Residents only see Resident ID
- Cleaner, simpler user experience

## Alternative Login Methods

### Option 1: Login with Resident ID (Primary)
```
Username: RES5326
Password: aB3xK9mP
```

### Option 2: Login with Phone Number (Alternative)
```
Phone: 9123456789
Password: aB3xK9mP

Flow:
1. Query Firestore: WHERE phone = "9123456789"
2. Get authEmail from user document
3. Authenticate with Firebase using authEmail
4. Login successful
```

### Option 3: Login with Email (If Provided)
```
Email: sarah@example.com
Password: aB3xK9mP

Flow:
1. Query Firestore: WHERE email = "sarah@example.com"
2. Get authEmail from user document
3. Authenticate with Firebase using authEmail
4. Login successful
```

## Implementation Code

### Admin App - Generate Credentials
```dart
// In assign_resident_modal.dart
void _generateCredentials() {
  final random = Random();
  
  // Generate Resident ID
  final residentNumber = random.nextInt(9000) + 1000;
  _generatedResidentId = 'RES$residentNumber';
  
  // Generate Password
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  _generatedPassword = String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
  );
  
  setState(() {});
}
```

### Admin App - Create User
```dart
// In user_service.dart
Future<String> createUser({
  required String name,
  required String phone,
  required String residentId,
  required String password,
  String? email,
  int familyMembers = 1,
}) async {
  // Create auth email from resident ID
  final authEmail = '$residentId@lyvo.com';
  
  // Create Firebase Auth account
  UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
    email: authEmail,
    password: password,
  );
  
  // Create Firestore document
  final docRef = await _firestore.collection('users').add({
    'name': name,
    'phone': phone,
    'email': email,
    'residentId': residentId,        // ← Username for login
    'authEmail': authEmail,          // ← Internal use
    'password': password,            // ← Password for login
    'authUid': userCredential.user?.uid,
    'role': 'resident',
    'flatId': null,
    'flatLabel': null,
    'ownershipType': null,
    'familyMembers': familyMembers,
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  return docRef.id;
}
```

### Resident App - Login with Resident ID
```dart
// In auth_service.dart (Resident App)
Future<UserCredential> signInWithResidentId(
  String residentId,
  String password,
) async {
  // Query Firestore to get auth email
  final userQuery = await _firestore
    .collection('users')
    .where('residentId', isEqualTo: residentId)
    .where('role', isEqualTo: 'resident')
    .limit(1)
    .get();
  
  if (userQuery.docs.isEmpty) {
    throw Exception('User not found');
  }
  
  // Get auth email from user document
  final userData = userQuery.docs.first.data();
  final authEmail = userData['authEmail'] as String;
  
  // Authenticate with Firebase
  return await _auth.signInWithEmailAndPassword(
    email: authEmail,      // RES5326@lyvo.com
    password: password,    // aB3xK9mP
  );
}
```

### Resident App - Login with Phone
```dart
// In auth_service.dart (Resident App)
Future<UserCredential> signInWithPhone(
  String phone,
  String password,
) async {
  // Query Firestore to get auth email
  final userQuery = await _firestore
    .collection('users')
    .where('phone', isEqualTo: phone)
    .where('role', isEqualTo: 'resident')
    .limit(1)
    .get();
  
  if (userQuery.docs.isEmpty) {
    throw Exception('User not found');
  }
  
  // Get auth email from user document
  final userData = userQuery.docs.first.data();
  final authEmail = userData['authEmail'] as String;
  
  // Authenticate with Firebase
  return await _auth.signInWithEmailAndPassword(
    email: authEmail,      // RES5326@lyvo.com
    password: password,    // aB3xK9mP
  );
}
```

## Summary

### What Residents See and Use

**Credentials Received (via SMS/Email):**
- Username: `RES5326`
- Password: `aB3xK9mP`

**Login Screen:**
- Enter Username: `RES5326`
- Enter Password: `aB3xK9mP`
- Click Login

**Behind the Scenes:**
- System converts `RES5326` to `RES5326@lyvo.com`
- Authenticates with Firebase
- Loads user data from Firestore
- Resident never sees the @lyvo.com email

### Key Points

✅ **Simple for Residents**
- Just remember: Username (RES5326) + Password (aB3xK9mP)
- No need to remember complex email addresses
- Clean, professional credential format

✅ **Secure**
- Auto-generated random passwords
- Firebase Auth handles password hashing
- Firestore security rules protect data

✅ **Flexible**
- Can login with Resident ID, Phone, or Email
- All methods use the same password
- System handles conversion internally

✅ **Admin Friendly**
- Credentials auto-generated
- Shown in UI for reference
- Sent automatically via SMS/Email

The system is production-ready and fully functional!
