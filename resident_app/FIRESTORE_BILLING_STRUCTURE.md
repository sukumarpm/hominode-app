# Firestore Billing Structure - Required Setup

## Collections Overview

```
firestore/
├── users/
│   └── {userId}/
├── flats/
│   └── {flatId}/
└── bills/
    └── {billId}/
```

## 1. Users Collection

**Path**: `users/{userId}`

**Required Fields**:
```json
{
  "fullName": "John Doe",
  "email": "john@example.com",
  "phoneNumber": "+1234567890",
  "role": "resident",
  "isActive": true,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

**Note**: The `userId` document ID must match Firebase Auth UID.

## 2. Flats Collection

**Path**: `flats/{flatId}`

**Required Fields**:
```json
{
  "flatNumber": "A-101",
  "buildingId": "building_001",
  "residentIds": ["userId1", "userId2"],  // ← CRITICAL: Array of user IDs
  "floor": 1,
  "bhk": 2,
  "area": 1000,
  "status": "occupied",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

**Critical**: 
- `residentIds` MUST be an array
- `residentIds` MUST contain the user's Firebase Auth UID
- Multiple users can be in the same flat

## 3. Bills Collection

**Path**: `bills/{billId}`

**Required Fields**:
```json
{
  "flatId": "flat_001",  // ← CRITICAL: Must match flat document ID
  "amount": 5000,
  "status": "pending",  // "pending" | "paid" | "overdue"
  "month": "February 2024",
  "dueDate": Timestamp("2024-02-28T00:00:00Z"),
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 1000,
  "serviceCharge": 500,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

**For Paid Bills, Add**:
```json
{
  "paidAt": Timestamp("2024-01-25T10:30:00Z"),
  "paymentMethod": "UPI",  // "UPI" | "Card" | "Net Banking"
  "transactionId": "TXN123456789"
}
```

## Data Relationships

```
User (Firebase Auth UID)
    ↓
    ↓ (residentIds array contains)
    ↓
Flat (flatId)
    ↓
    ↓ (flatId matches)
    ↓
Bills (multiple bills per flat)
```

## Query Flow

### Step 1: Get User's Flat
```dart
flats
  .where('residentIds', arrayContains: currentUserId)
  .limit(1)
  .get()
```

### Step 2: Get Bills for Flat
```dart
bills
  .where('flatId', isEqualTo: flatId)
  .get()
```

### Step 3: Filter by Status
```dart
// For current bill
bills
  .where('flatId', isEqualTo: flatId)
  .where('status', isEqualTo: 'pending')
  .get()

// For payment history
bills
  .where('flatId', isEqualTo: flatId)
  .where('status', isEqualTo: 'paid')
  .get()
```

## Sample Data Setup

### Example 1: Single Resident

**User**:
```
Collection: users
Document ID: user_abc123

{
  "fullName": "John Doe",
  "email": "john@example.com",
  "role": "resident"
}
```

**Flat**:
```
Collection: flats
Document ID: flat_001

{
  "flatNumber": "A-101",
  "buildingId": "building_001",
  "residentIds": ["user_abc123"]  ← User ID here
}
```

**Bill**:
```
Collection: bills
Document ID: bill_001

{
  "flatId": "flat_001",  ← Flat ID here
  "amount": 5000,
  "status": "pending",
  "month": "February 2024",
  "dueDate": Timestamp("2024-02-28"),
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 1000,
  "serviceCharge": 500
}
```

### Example 2: Multiple Residents (Family)

**Users**:
```
users/user_abc123  (Father)
users/user_def456  (Mother)
users/user_ghi789  (Son)
```

**Flat**:
```
Collection: flats
Document ID: flat_002

{
  "flatNumber": "B-205",
  "buildingId": "building_001",
  "residentIds": [
    "user_abc123",  ← Father
    "user_def456",  ← Mother
    "user_ghi789"   ← Son
  ]
}
```

**Bills** (All three users see the same bills):
```
Collection: bills
Document ID: bill_002

{
  "flatId": "flat_002",  ← Same flat for all
  "amount": 6000,
  "status": "pending",
  "month": "February 2024"
}
```

## Field Types Reference

| Field | Type | Example |
|-------|------|---------|
| flatId | string | "flat_001" |
| amount | number | 5000 |
| status | string | "pending" |
| month | string | "February 2024" |
| dueDate | timestamp | 2024-02-28T00:00:00Z |
| residentIds | array | ["user1", "user2"] |
| maintenanceCharge | number | 3000 |
| waterCharge | number | 500 |
| parkingCharge | number | 1000 |
| serviceCharge | number | 500 |
| paidAt | timestamp | 2024-01-25T10:30:00Z |
| paymentMethod | string | "UPI" |
| transactionId | string | "TXN123456789" |

## Indexes Required

Firestore may require these composite indexes:

1. **Bills by Flat and Status**:
   - Collection: `bills`
   - Fields: `flatId` (Ascending), `status` (Ascending)

2. **Bills by Flat and Due Date**:
   - Collection: `bills`
   - Fields: `flatId` (Ascending), `dueDate` (Descending)

Firestore will prompt you to create these when you run queries.

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read their own document
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
    }
    
    // Residents can read flats they're assigned to
    match /flats/{flatId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.residentIds;
    }
    
    // Residents can read bills for their flat
    match /bills/{billId} {
      allow read: if request.auth != null && 
                     exists(/databases/$(database)/documents/flats/$(resource.data.flatId)) &&
                     request.auth.uid in get(/databases/$(database)/documents/flats/$(resource.data.flatId)).data.residentIds;
      
      // Residents can update bill status (for payment)
      allow update: if request.auth != null && 
                       exists(/databases/$(database)/documents/flats/$(resource.data.flatId)) &&
                       request.auth.uid in get(/databases/$(database)/documents/flats/$(resource.data.flatId)).data.residentIds &&
                       request.resource.data.status == 'paid';
    }
  }
}
```

## Validation Checklist

Before testing, verify:

- [ ] User document exists with correct ID
- [ ] Flat document exists
- [ ] Flat has `residentIds` array field
- [ ] User ID is in flat's `residentIds` array
- [ ] Bill documents exist
- [ ] Bills have `flatId` field
- [ ] Bill's `flatId` matches flat document ID (not flatNumber)
- [ ] Bills have required fields (amount, status, month, dueDate)
- [ ] Security rules allow reading
- [ ] User is logged in with Firebase Auth

## Common Mistakes

❌ **Wrong**: Using flatNumber in bills
```json
{
  "flatId": "A-101"  // This is flatNumber, not flatId!
}
```

✅ **Correct**: Using flat document ID
```json
{
  "flatId": "flat_001"  // This is the document ID
}
```

❌ **Wrong**: residentIds as string
```json
{
  "residentIds": "user_abc123"  // Wrong type!
}
```

✅ **Correct**: residentIds as array
```json
{
  "residentIds": ["user_abc123"]  // Correct!
}
```

❌ **Wrong**: Using email or name as ID
```json
{
  "residentIds": ["john@example.com"]  // Wrong!
}
```

✅ **Correct**: Using Firebase Auth UID
```json
{
  "residentIds": ["abc123xyz789"]  // Firebase Auth UID
}
```

---

**Status**: Required Structure
**Purpose**: Billing data fetch
**Last Updated**: 2024
