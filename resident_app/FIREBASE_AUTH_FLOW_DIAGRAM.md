# Firebase Auth Auto-Creation Flow Diagram

## Complete Authentication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER OPENS LOGIN SCREEN                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              User enters Email/Phone + Password                  │
│                                                                  │
│  Email: preethampriyatharson07@gmail.com                        │
│  Phone: 7010678124                                              │
│  Password: tK7Fo1Ow                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   FIRESTORE AUTHENTICATION                       │
│                                                                  │
│  1. Search Firestore users collection                           │
│  2. Find user by email or phone                                 │
│  3. Verify password matches                                     │
│  4. Check user status is "active"                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ Password Valid? │
                    └─────────────────┘
                       ↓           ↓
                     YES          NO
                       ↓           ↓
                       ↓     ┌──────────────┐
                       ↓     │ Show Error   │
                       ↓     │ Login Failed │
                       ↓     └──────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│              FIREBASE AUTHENTICATION INTEGRATION                 │
│                                                                  │
│  Check if user has authUid in Firestore                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ authUid exists? │
                    └─────────────────┘
                       ↓           ↓
                     YES          NO
                       ↓           ↓
        ┌──────────────────────┐  ┌──────────────────────┐
        │ EXISTING USER PATH   │  │ NEW USER PATH        │
        └──────────────────────┘  └──────────────────────┘
                 ↓                          ↓
┌────────────────────────────┐  ┌────────────────────────────┐
│ Sign in to Firebase Auth   │  │ Create Firebase Auth user  │
│                            │  │                            │
│ _auth.signInWith           │  │ _auth.createUserWith       │
│   EmailAndPassword()       │  │   EmailAndPassword()       │
│                            │  │                            │
│ email: user email          │  │ email: user email          │
│ password: user password    │  │ password: user password    │
└────────────────────────────┘  └────────────────────────────┘
                 ↓                          ↓
                 ↓              ┌────────────────────────────┐
                 ↓              │ Set Firebase Auth profile  │
                 ↓              │                            │
                 ↓              │ - Display Name: user name  │
                 ↓              │ - Photo URL: user photo    │
                 ↓              └────────────────────────────┘
                 ↓                          ↓
                 ↓              ┌────────────────────────────┐
                 ↓              │ Store authUid in Firestore │
                 ↓              │                            │
                 ↓              │ users/{userId}.update({    │
                 ↓              │   authUid: firebaseUid,    │
                 ↓              │   updatedAt: timestamp     │
                 ↓              │ })                         │
                 ↓              └────────────────────────────┘
                 ↓                          ↓
                 └──────────────┬───────────┘
                                ↓
                    ┌───────────────────────┐
                    │ Firebase Auth Success?│
                    └───────────────────────┘
                       ↓               ↓
                     YES              NO
                       ↓               ↓
                       ↓     ┌──────────────────────┐
                       ↓     │ Handle Error         │
                       ↓     │                      │
                       ↓     │ - email-already-in-  │
                       ↓     │   use: Link accounts │
                       ↓     │                      │
                       ↓     │ - Other errors:      │
                       ↓     │   Continue with      │
                       ↓     │   Firestore-only     │
                       ↓     └──────────────────────┘
                       ↓               ↓
                       └───────┬───────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    SAVE LOGIN STATE                              │
│                                                                  │
│  SharedPreferences:                                             │
│  - is_logged_in: true                                           │
│  - user_id: ZsjxqVHSv7OQELHCFee1                               │
│  - user_email: preethampriyatharson07@gmail.com                │
│  - user_phone: 7010678124                                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    LOGIN SUCCESSFUL ✅                           │
│                                                                  │
│  Navigate to Home Screen                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              Firebase Auth Error Occurs                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────┐
                    │  Error Type?    │
                    └─────────────────┘
                       ↓     ↓     ↓
            ┌──────────┼─────┼─────┼──────────┐
            ↓          ↓     ↓     ↓          ↓
    ┌──────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
    │ email-   │ │ wrong- │ │network │ │  other   │
    │ already- │ │password│ │ error  │ │  errors  │
    │ in-use   │ │        │ │        │ │          │
    └──────────┘ └────────┘ └────────┘ └──────────┘
         ↓           ↓          ↓           ↓
         ↓           ↓          ↓           ↓
    ┌────────┐  ┌────────┐ ┌────────┐ ┌────────┐
    │ Link   │  │Continue│ │Continue│ │Continue│
    │accounts│  │Firestore│ │Firestore│ │Firestore│
    │        │  │  only  │ │  only  │ │  only  │
    └────────┘  └────────┘ └────────┘ └────────┘
         ↓           ↓          ↓           ↓
         └───────────┴──────────┴───────────┘
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│              Login Continues Successfully                        │
│                                                                  │
│  App works normally with Firestore-only authentication          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        FIRESTORE                                 │
│                                                                  │
│  users/ZsjxqVHSv7OQELHCFee1                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ name: "Preetham"                                        │    │
│  │ email: "preethampriyatharson07@gmail.com"              │    │
│  │ phone: "7010678124"                                     │    │
│  │ password: "tK7Fo1Ow"                                    │    │
│  │ flatId: "gPy8LvSbQsijXROyhqMp"                         │    │
│  │ role: "resident"                                        │    │
│  │ status: "active"                                        │    │
│  │ authUid: "abc123xyz456" ← Added on first login         │    │
│  │ updatedAt: "2026-02-27T10:30:00Z"                      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    (authUid links to)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                   FIREBASE AUTHENTICATION                        │
│                                                                  │
│  User: abc123xyz456                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ uid: "abc123xyz456"                                     │    │
│  │ email: "preethampriyatharson07@gmail.com"              │    │
│  │ displayName: "Preetham"                                 │    │
│  │ photoURL: [user photo]                                  │    │
│  │ emailVerified: false                                    │    │
│  │ provider: "password"                                    │    │
│  │ createdAt: "2026-02-27T10:30:00Z"                      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    (Used by services)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      APP SERVICES                                │
│                                                                  │
│  - ListingFirestoreService (Marketplace)                        │
│  - PostFirestoreService (Community Wall)                        │
│  - ChatFirestoreService (Messaging)                             │
│  - BookingFirestoreService (Amenities)                          │
│  - All other services                                           │
│                                                                  │
│  All services can now use Firebase Auth ✅                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Timeline Diagram

```
TIME: 0s
┌─────────────────────────────────────────────────────────────────┐
│ User opens app                                                   │
└─────────────────────────────────────────────────────────────────┘

TIME: 1s
┌─────────────────────────────────────────────────────────────────┐
│ User enters credentials and taps Login                           │
└─────────────────────────────────────────────────────────────────┘

TIME: 1.5s
┌─────────────────────────────────────────────────────────────────┐
│ Firestore query: Search for user by email/phone                 │
│ Result: User found ✅                                            │
└─────────────────────────────────────────────────────────────────┘

TIME: 2s
┌─────────────────────────────────────────────────────────────────┐
│ Password verification: Compare passwords                         │
│ Result: Password matches ✅                                      │
└─────────────────────────────────────────────────────────────────┘

TIME: 2.5s
┌─────────────────────────────────────────────────────────────────┐
│ Check authUid in Firestore                                       │
│ Result: No authUid found (first login)                          │
└─────────────────────────────────────────────────────────────────┘

TIME: 3s
┌─────────────────────────────────────────────────────────────────┐
│ Firebase Auth: Create new user                                   │
│ _auth.createUserWithEmailAndPassword()                          │
└─────────────────────────────────────────────────────────────────┘

TIME: 3.5s
┌─────────────────────────────────────────────────────────────────┐
│ Firebase Auth: User created ✅                                   │
│ UID: abc123xyz456                                               │
└─────────────────────────────────────────────────────────────────┘

TIME: 4s
┌─────────────────────────────────────────────────────────────────┐
│ Firebase Auth: Set profile data                                  │
│ - Display Name: Preetham                                        │
│ - Photo URL: [user photo]                                       │
└─────────────────────────────────────────────────────────────────┘

TIME: 4.5s
┌─────────────────────────────────────────────────────────────────┐
│ Firestore: Store authUid                                         │
│ users/ZsjxqVHSv7OQELHCFee1.update({                            │
│   authUid: "abc123xyz456"                                       │
│ })                                                              │
└─────────────────────────────────────────────────────────────────┘

TIME: 5s
┌─────────────────────────────────────────────────────────────────┐
│ Save login state to SharedPreferences                            │
│ Navigate to Home Screen                                         │
│ Login Complete ✅                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Console Log Flow

```
🔐 Starting Firestore-only authentication...
   Identifier: preethampriyatharson07@gmail.com
   ↓
📧 Detected email, searching in Firestore...
   Searching for email: preethampriyatharson07@gmail.com
   ↓
   ✅ Found user with email: preethampriyatharson07@gmail.com
   User ID: ZsjxqVHSv7OQELHCFee1
   User Name: Preetham
   ↓
   Verifying password...
   Stored password: tK7Fo1Ow
   Entered password: tK7Fo1Ow
   ↓
✅ Password verified successfully
   ↓
🔐 Creating/Signing in with Firebase Authentication...
   ↓
   No authUid found, creating new Firebase Auth user...
   ↓
✅ Firebase Auth account created
   ↓
✅ Firebase Auth profile set and authUid stored in Firestore
   Auth UID: abc123xyz456
   Email: preethampriyatharson07@gmail.com
   ↓
💾 Login state saved
   ↓
✅ Login successful!
   Welcome: Preetham
```

---

## Service Integration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER LOGGED IN                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              User navigates to Marketplace                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│           ListingFirestoreService.getAllListings()              │
│                                                                  │
│  1. Check Firebase Auth: _auth.currentUser                      │
│     Result: User signed in ✅                                    │
│                                                                  │
│  2. Get current user ID: _auth.currentUser.uid                  │
│     Result: abc123xyz456                                        │
│                                                                  │
│  3. Fetch listings from Firestore                               │
│     Result: Listings loaded ✅                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              Marketplace displays listings ✅                    │
│                                                                  │
│  No "User not authenticated" error!                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary

This flow diagram shows:

1. ✅ **User Login**: Email/Phone + Password
2. ✅ **Firestore Validation**: Credentials checked
3. ✅ **authUid Check**: Determines if Firebase Auth user exists
4. ✅ **Firebase Auth Creation**: New user created if needed
5. ✅ **Profile Sync**: Name and photo synced
6. ✅ **authUid Storage**: Link stored in Firestore
7. ✅ **Service Integration**: All services work with Firebase Auth
8. ✅ **Error Handling**: Graceful fallback to Firestore-only

**Total Time**: ~5 seconds for first login  
**Subsequent Logins**: ~2 seconds (sign in only, no creation)

