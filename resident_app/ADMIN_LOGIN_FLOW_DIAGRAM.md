# Admin Login - Flow Diagram

## Complete Login Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN LOGIN FLOW DIAGRAM                      │
└─────────────────────────────────────────────────────────────────┘

                         START
                           │
                           ▼
                  ┌─────────────────┐
                  │  Admin Opens    │
                  │  Admin App      │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │  Splash Screen  │
                  │  Checks Login   │
                  │  Status         │
                  └────────┬────────┘
                           │
                    ┌──────┴──────┐
                    │             │
                    ▼             ▼
            ┌──────────────┐  ┌──────────────┐
            │ Admin Logged │  │ Not Logged   │
            │ In?          │  │ In?          │
            └──────┬───────┘  └──────┬───────┘
                   │                 │
                   │ YES             │ NO
                   │                 │
                   ▼                 ▼
            ┌──────────────┐  ┌──────────────────┐
            │ Navigate to  │  │ Show Admin Login │
            │ Dashboard    │  │ Screen           │
            └──────────────┘  └────────┬─────────┘
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │ User Enters:         │
                            │ - Email/Phone        │
                            │ - Password           │
                            └────────┬─────────────┘
                                     │
                                     ▼
                            ┌──────────────────────┐
                            │ Tap Login Button     │
                            └────────┬─────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │ AdminLoginService.loginAsAdmin │
                    └────────┬───────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────────┐
        │ STEP 1: Validate Input                     │
        │ ├─ Check email/phone not empty            │
        │ ├─ Check password not empty               │
        │ └─ Return error if validation fails       │
        └────────┬───────────────────────────────────┘
                 │
          ┌──────┴──────┐
          │             │
          ▼             ▼
    ┌─────────┐   ┌──────────────┐
    │ VALID   │   │ INVALID      │
    └────┬────┘   └────┬─────────┘
         │             │
         │             ▼
         │        ┌──────────────────┐
         │        │ Show Error:      │
         │        │ "Email and       │
         │        │ password         │
         │        │ required"        │
         │        └──────────────────┘
         │
         ▼
┌────────────────────────────────────────────┐
│ STEP 2: Authenticate with Firebase Auth   │
│ ├─ Convert phone to email if needed       │
│ ├─ Sign in with Firebase Auth             │
│ ├─ Get Firebase Auth UID                  │
│ └─ Return error if auth fails             │
└────────┬───────────────────────────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
┌────────┐  ┌──────────────┐
│ SUCCESS│  │ FAILED       │
└───┬────┘  └────┬─────────┘
    │            │
    │            ▼
    │       ┌──────────────────┐
    │       │ Show Error:      │
    │       │ "Incorrect       │
    │       │ password" or     │
    │       │ "No account      │
    │       │ found"           │
    │       └──────────────────┘
    │
    ▼
┌────────────────────────────────────────────┐
│ STEP 3: Fetch User Document from Firestore│
│ ├─ Query users collection by authUid      │
│ ├─ Get user document                      │
│ ├─ Extract user data                      │
│ └─ Return error if document not found     │
└────────┬───────────────────────────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
┌────────┐  ┌──────────────┐
│ FOUND  │  │ NOT FOUND    │
└───┬────┘  └────┬─────────┘
    │            │
    │            ▼
    │       ┌──────────────────┐
    │       │ Show Error:      │
    │       │ "User profile    │
    │       │ not found"       │
    │       └──────────────────┘
    │
    ▼
┌────────────────────────────────────────────┐
│ STEP 4: Validate Admin Role                │
│ ├─ Check role == "admin"                  │
│ ├─ Check buildingId is assigned           │
│ ├─ Extract admin name and building ID     │
│ └─ Return error if not admin or no bldg   │
└────────┬───────────────────────────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
┌────────┐  ┌──────────────┐
│ VALID  │  │ INVALID      │
└───┬────┘  └────┬─────────┘
    │            │
    │            ▼
    │       ┌──────────────────┐
    │       │ Show Error:      │
    │       │ "Only admins     │
    │       │ can access" or   │
    │       │ "No building     │
    │       │ assigned"        │
    │       └──────────────────┘
    │
    ▼
┌────────────────────────────────────────────┐
│ STEP 5: Save Login State                   │
│ ├─ Save to SharedPreferences               │
│ ├─ Store adminId, email, buildingId       │
│ ├─ Return success with user data          │
│ └─ Ready for admin dashboard              │
└────────┬───────────────────────────────────┘
         │
         ▼
    ┌─────────────────┐
    │ Login Successful│
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────┐
    │ Navigate to Admin    │
    │ Dashboard           │
    └────────┬────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ Admin Dashboard     │
    │ Loads Successfully  │
    └────────┬────────────┘
             │
             ▼
          SUCCESS
```

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING FLOW                           │
└─────────────────────────────────────────────────────────────────┘

                    Login Attempt
                         │
                         ▼
                  ┌──────────────┐
                  │ Validate     │
                  │ Input        │
                  └────┬─────────┘
                       │
                  ┌────┴────┐
                  │          │
                  ▼          ▼
            ┌────────┐  ┌──────────────────┐
            │ VALID  │  │ INVALID          │
            └───┬────┘  └────┬─────────────┘
                │             │
                │             ▼
                │        ┌──────────────────────┐
                │        │ ERROR CODE:          │
                │        │ EMPTY_CREDENTIALS    │
                │        │                      │
                │        │ MESSAGE:             │
                │        │ "Email and password  │
                │        │ are required"        │
                │        └──────────────────────┘
                │
                ▼
        ┌──────────────────┐
        │ Firebase Auth    │
        │ Sign In          │
        └────┬─────────────┘
             │
        ┌────┴────┐
        │          │
        ▼          ▼
    ┌────────┐  ┌──────────────────┐
    │ SUCCESS│  │ FAILED           │
    └───┬────┘  └────┬─────────────┘
        │            │
        │            ▼
        │       ┌──────────────────────┐
        │       │ ERROR CODE:          │
        │       │ user-not-found       │
        │       │ wrong-password       │
        │       │ invalid-email        │
        │       │ etc.                 │
        │       │                      │
        │       │ MESSAGE:             │
        │       │ Specific error msg   │
        │       └──────────────────────┘
        │
        ▼
    ┌──────────────────┐
    │ Fetch Firestore  │
    │ User Document    │
    └────┬─────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
┌────────┐  ┌──────────────────┐
│ FOUND  │  │ NOT FOUND        │
└───┬────┘  └────┬─────────────┘
    │            │
    │            ▼
    │       ┌──────────────────────┐
    │       │ ERROR CODE:          │
    │       │ USER_PROFILE_NOT_FOUND
    │       │                      │
    │       │ MESSAGE:             │
    │       │ "User profile not    │
    │       │ found"               │
    │       └──────────────────────┘
    │
    ▼
┌──────────────────┐
│ Validate Admin   │
│ Role             │
└────┬─────────────┘
     │
  ┌──┴──┐
  │     │
  ▼     ▼
┌────┐ ┌──────────────────┐
│ OK │ │ NOT ADMIN        │
└──┬─┘ └────┬─────────────┘
   │        │
   │        ▼
   │   ┌──────────────────────┐
   │   │ ERROR CODE:          │
   │   │ NOT_ADMIN            │
   │   │                      │
   │   │ MESSAGE:             │
   │   │ "Only administrators │
   │   │ can access this app" │
   │   └──────────────────────┘
   │
   ▼
┌──────────────────┐
│ Check Building   │
│ Assignment       │
└────┬─────────────┘
     │
  ┌──┴──┐
  │     │
  ▼     ▼
┌────┐ ┌──────────────────┐
│ OK │ │ NO BUILDING      │
└──┬─┘ └────┬─────────────┘
   │        │
   │        ▼
   │   ┌──────────────────────┐
   │   │ ERROR CODE:          │
   │   │ NO_BUILDING          │
   │   │                      │
   │   │ MESSAGE:             │
   │   │ "No building         │
   │   │ assigned to this     │
   │   │ admin account"       │
   │   └──────────────────────┘
   │
   ▼
┌──────────────────┐
│ Save Login State │
└────┬─────────────┘
     │
  ┌──┴──┐
  │     │
  ▼     ▼
┌────┐ ┌──────────────────┐
│ OK │ │ FAILED           │
└──┬─┘ └────┬─────────────┘
   │        │
   │        ▼
   │   ┌──────────────────────┐
   │   │ ERROR CODE:          │
   │   │ FIRESTORE_ERROR      │
   │   │                      │
   │   │ MESSAGE:             │
   │   │ "Error saving login  │
   │   │ state"               │
   │   └──────────────────────┘
   │
   ▼
┌──────────────────┐
│ LOGIN SUCCESS    │
│ Navigate to      │
│ Dashboard        │
└──────────────────┘
```

## State Management Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT FLOW                         │
└─────────────────────────────────────────────────────────────────┘

                    Admin Logs In
                         │
                         ▼
            ┌────────────────────────┐
            │ AdminLoginService      │
            │ .loginAsAdmin()        │
            └────────┬───────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │ SharedPreferences          │
        │ (Local Storage)            │
        │                            │
        │ is_admin_logged_in: true   │
        │ admin_id: "FCFwcK..."      │
        │ admin_email: "admin@..."   │
        │ building_id: "FUW27A..."   │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Firebase Auth Session      │
        │ (Firebase)                 │
        │                            │
        │ currentUser: User object   │
        │ uid: "FCFwcK..."           │
        │ email: "admin@..."         │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Admin Dashboard            │
        │ Can Access:                │
        │ - Statistics               │
        │ - Complaints               │
        │ - Amenities                │
        │ - Notifications            │
        │ - Billing                  │
        │ - Visitors                 │
        └────────┬───────────────────┘
                 │
                 ▼
            ┌─────────────┐
            │ Admin Works │
            │ in App      │
            └────────┬────┘
                     │
                     ▼
            ┌─────────────────┐
            │ Admin Logs Out  │
            └────────┬────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │ Clear SharedPreferences    │
        │                            │
        │ is_admin_logged_in: false  │
        │ admin_id: null             │
        │ admin_email: null          │
        │ building_id: null          │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Sign Out from Firebase     │
        │                            │
        │ currentUser: null          │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Navigate to Login Screen   │
        └────────────────────────────┘
```

## Phone to Email Conversion Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHONE TO EMAIL CONVERSION                     │
└─────────────────────────────────────────────────────────────────┘

            User Enters Phone Number
                     │
                     ▼
        ┌────────────────────────────┐
        │ Input: 7201067812          │
        │ or: +917201067812          │
        │ or: 91 7201067812          │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Clean Phone Number         │
        │ Remove: +, spaces, ()      │
        │                            │
        │ Result: 7201067812         │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Remove Country Code        │
        │ If starts with +91: remove │
        │ If starts with 91: remove  │
        │                            │
        │ Result: 7201067812         │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Try Phone Variations       │
        │ 1. 7201067812              │
        │ 2. +917201067812           │
        │ 3. 917201067812            │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Query Firestore            │
        │ WHERE phone == variation   │
        │                            │
        │ Found: User Document       │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Extract Email from Doc     │
        │                            │
        │ Email: admin@lyvo.com      │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │ Use Email for Firebase     │
        │ Auth Sign In               │
        │                            │
        │ Success: Proceed to Step 3 │
        └────────────────────────────┘
```

---

**Status**: READY FOR DEPLOYMENT ✅
