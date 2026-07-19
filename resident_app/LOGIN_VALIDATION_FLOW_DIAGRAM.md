# Login Validation Flow Diagram

## Complete Login Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER LOGIN SCREEN                             │
│  Email/Phone: user@example.com                                   │
│  Password: ••••••••                                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  Input Validation              │
        │  - Email/Phone format check    │
        │  - Password not empty          │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │  ResidentLoginService          │
        │  .loginAsResident()            │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  STEP 1: Firebase Auth         │
        │  signInWithEmailAndPassword()  │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Firebase Auth Response                        │
        │  ✓ Success: User UID = abc123xyz              │
        │  ✗ Failure: Invalid credentials               │
        └────────────┬───────────────────────────────────┘
                     │
                     ├─ ✗ FAILURE ──────────────────────┐
                     │                                   │
                     │                    ┌──────────────▼──────┐
                     │                    │ Return Error:       │
                     │                    │ "Invalid email or   │
                     │                    │  password"          │
                     │                    └─────────────────────┘
                     │
                     ├─ ✓ SUCCESS
                     │
        ┌────────────▼───────────────────────────────────┐
        │  STEP 2: Query Firestore                       │
        │  collection('users')                           │
        │  .where('authUid', isEqualTo: 'abc123xyz')    │
        │  .limit(1)                                     │
        │  .get()                                        │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Firestore Response                            │
        │  ✓ Found: User document                        │
        │  ✗ Not Found: No document                      │
        └────────────┬───────────────────────────────────┘
                     │
                     ├─ ✗ NOT FOUND ────────────────────┐
                     │                                   │
                     │                    ┌──────────────▼──────┐
                     │                    │ Return Error:       │
                     │                    │ "User account not   │
                     │                    │  found. Please      │
                     │                    │  contact support."  │
                     │                    └─────────────────────┘
                     │
                     ├─ ✓ FOUND
                     │
        ┌────────────▼───────────────────────────────────┐
        │  STEP 3: Validate Role                         │
        │  userData['role'] == 'resident'                │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Role Check Result                             │
        │  ✓ role == 'resident'                          │
        │  ✗ role != 'resident' (e.g., 'admin')         │
        └────────────┬───────────────────────────────────┘
                     │
                     ├─ ✗ INVALID ROLE ─────────────────┐
                     │                                   │
                     │                    ┌──────────────▼──────┐
                     │                    │ Return Error:       │
                     │                    │ "Access denied.     │
                     │                    │  Only residents     │
                     │                    │  can login here."   │
                     │                    └─────────────────────┘
                     │
                     ├─ ✓ VALID ROLE
                     │
        ┌────────────▼───────────────────────────────────┐
        │  STEP 4: Validate Status                       │
        │  userData['status'] == 'active'                │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Status Check Result                           │
        │  ✓ status == 'active'                          │
        │  ✗ status != 'active' (e.g., 'inactive')      │
        └────────────┬───────────────────────────────────┘
                     │
                     ├─ ✗ INACTIVE ─────────────────────┐
                     │                                   │
                     │                    ┌──────────────▼──────┐
                     │                    │ Return Error:       │
                     │                    │ "Your account is    │
                     │                    │  [status]. Please   │
                     │                    │  contact support."  │
                     │                    └─────────────────────┘
                     │
                     ├─ ✓ ACTIVE
                     │
        ┌────────────▼───────────────────────────────────┐
        │  STEP 5: Validate Flat Assignment              │
        │  flatId != null && flatId.trim() != ''         │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Flat Assignment Check Result                  │
        │  ✓ flatId = 'flat_001'                         │
        │  ✗ flatId = null or empty                      │
        └────────────┬───────────────────────────────────┘
                     │
                     ├─ ✗ NO FLAT ──────────────────────┐
                     │                                   │
                     │                    ┌──────────────▼──────┐
                     │                    │ Return Error:       │
                     │                    │ "Access Restricted  │
                     │                    │  – Your account is  │
                     │                    │  not yet assigned   │
                     │                    │  to a flat"         │
                     │                    └─────────────────────┘
                     │
                     ├─ ✓ FLAT ASSIGNED
                     │
        ┌────────────▼───────────────────────────────────┐
        │  ✅ ALL VALIDATIONS PASSED                     │
        │  Return ResidentLoginResult.success()          │
        │  - userData: {...}                             │
        │  - flatId: 'flat_001'                          │
        │  - buildingId: 'building_001'                  │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Clear Access Control Cache                    │
        │  FlatAccessControlService.clearCache()        │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Wait for Data Sync (500ms)                    │
        └────────────┬───────────────────────────────────┘
                     │
        ┌────────────▼───────────────────────────────────┐
        │  Navigate to Home Screen                       │
        │  Navigator.pushReplacementNamed('/home')       │
        └────────────┬───────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │  HOME SCREEN                   │
        │  Welcome, John Doe!            │
        │  Flat: A-101                   │
        │  Building: Main Tower          │
        └────────────────────────────────┘
```

## Error Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOGIN ATTEMPT                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  ResidentLoginService          │
        │  .loginAsResident()            │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Firebase Auth                 │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Success?                      │
        └────────────┬───────────────────┘
                     │
        ┌────────────┴───────────────────┐
        │                                │
        ▼                                ▼
    ✗ FAIL                          ✓ SUCCESS
        │                                │
        │                    ┌───────────▼──────────┐
        │                    │  Firestore Query     │
        │                    │  by authUid          │
        │                    └───────────┬──────────┘
        │                                │
        │                    ┌───────────▼──────────┐
        │                    │  Found?              │
        │                    └───────────┬──────────┘
        │                                │
        │                    ┌───────────┴──────────┐
        │                    │                      │
        │                    ▼                      ▼
        │                ✗ NO                   ✓ YES
        │                    │                      │
        │                    │          ┌───────────▼──────────┐
        │                    │          │  Validate Role       │
        │                    │          │  == 'resident'       │
        │                    │          └───────────┬──────────┘
        │                    │                      │
        │                    │          ┌───────────▼──────────┐
        │                    │          │  Valid?              │
        │                    │          └───────────┬──────────┘
        │                    │                      │
        │                    │          ┌───────────┴──────────┐
        │                    │          │                      │
        │                    │          ▼                      ▼
        │                    │      ✗ NO                   ✓ YES
        │                    │          │                      │
        │                    │          │          ┌───────────▼──────────┐
        │                    │          │          │  Validate Status     │
        │                    │          │          │  == 'active'         │
        │                    │          │          └───────────┬──────────┘
        │                    │          │                      │
        │                    │          │          ┌───────────▼──────────┐
        │                    │          │          │  Active?             │
        │                    │          │          └───────────┬──────────┘
        │                    │          │                      │
        │                    │          │          ┌───────────┴──────────┐
        │                    │          │          │                      │
        │                    │          │          ▼                      ▼
        │                    │          │      ✗ NO                   ✓ YES
        │                    │          │          │                      │
        │                    │          │          │          ┌───────────▼──────────┐
        │                    │          │          │          │  Validate Flat       │
        │                    │          │          │          │  != null && != ''     │
        │                    │          │          │          └───────────┬──────────┘
        │                    │          │          │                      │
        │                    │          │          │          ┌───────────▼──────────┐
        │                    │          │          │          │  Has Flat?           │
        │                    │          │          │          └───────────┬──────────┘
        │                    │          │          │                      │
        │                    │          │          │          ┌───────────┴──────────┐
        │                    │          │          │          │                      │
        │                    │          │          │          ▼                      ▼
        │                    │          │          │      ✗ NO                   ✓ YES
        │                    │          │          │          │                      │
        │                    │          │          │          │                      │
        ▼                    ▼          ▼          ▼          ▼                      ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                    RETURN RESULT                                 │
    ├─────────────────────────────────────────────────────────────────┤
    │  ✗ FAILURE                          │  ✓ SUCCESS                │
    │  - Invalid credentials              │  - userData               │
    │  - User not found                   │  - flatId                 │
    │  - Invalid role                     │  - buildingId             │
    │  - Account inactive                 │  - Navigate to home       │
    │  - No flat assigned                 │                           │
    └─────────────────────────────────────────────────────────────────┘
```

## Firestore Query Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  Firebase Auth User                                              │
│  uid: 'abc123xyz'                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  Query Firestore               │
        │  collection('users')           │
        │  .where('authUid',             │
        │    isEqualTo: 'abc123xyz')     │
        │  .limit(1)                     │
        │  .get()                        │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │  Firestore Document            │
        │  {                             │
        │    authUid: 'abc123xyz',       │
        │    name: 'John Doe',           │
        │    email: 'john@example.com',  │
        │    role: 'resident',           │
        │    flatId: 'flat_001',         │
        │    buildingId: 'building_001', │
        │    status: 'active'            │
        │  }                             │
        └────────────────────────────────┘
```

## Validation Chain

```
┌─────────────────────────────────────────────────────────────────┐
│  VALIDATION CHAIN                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Firebase Auth ✓                                              │
│     └─ User authenticated                                        │
│                                                                   │
│  2. Firestore Query ✓                                            │
│     └─ User document found by authUid                            │
│                                                                   │
│  3. Role Validation ✓                                            │
│     └─ role == 'resident'                                        │
│                                                                   │
│  4. Status Validation ✓                                          │
│     └─ status == 'active'                                        │
│                                                                   │
│  5. Flat Assignment ✓                                            │
│     └─ flatId != null && flatId.trim() != ''                     │
│                                                                   │
│  ✅ ALL VALIDATIONS PASSED                                       │
│     └─ User can access app                                       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│  USER INPUT                                                       │
│  Email: user@example.com                                          │
│  Password: password123                                            │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  ResidentLoginService          │
        │  .loginAsResident()            │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Firebase Auth                 │
        │  .signInWithEmailAndPassword() │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Firebase Auth Response        │
        │  User { uid: 'abc123xyz' }     │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Firestore Query               │
        │  .where('authUid', ...)        │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Firestore Response            │
        │  User Document { ... }         │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  Validation Logic              │
        │  - Check role                  │
        │  - Check status                │
        │  - Check flatId                │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  ResidentLoginResult           │
        │  {                             │
        │    success: true,              │
        │    userData: {...},            │
        │    flatId: 'flat_001',         │
        │    buildingId: 'building_001'  │
        │  }                             │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  LoginScreen                   │
        │  - Clear cache                 │
        │  - Navigate to home            │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │  HOME SCREEN                   │
        │  User logged in successfully   │
        └────────────────────────────────┘
```

---

**Legend**:
- ✓ = Success/Valid
- ✗ = Failure/Invalid
- ✅ = All checks passed
- → = Flow direction
