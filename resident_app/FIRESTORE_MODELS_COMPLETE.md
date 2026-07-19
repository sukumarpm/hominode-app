# Firestore Models - Complete Implementation

All Firestore models have been updated with comprehensive JSON serialization support.

## Models Updated

### 1. ResidentModel
**Location:** `lib/src/models/resident_model.dart`

**Fields:**
- `id`, `userId`, `flatId`, `relationship`
- `moveInDate`, `moveOutDate`, `isPrimary`
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications

---

### 2. FlatModel
**Location:** `lib/src/models/flat_model.dart`

**Fields:**
- `id`, `buildingId`, `flatNumber`, `block`, `floor`
- `ownerId`, `residentIds` (List)
- `area`, `bedrooms`, `bathrooms`, `status`
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications

---

### 3. BillModel
**Location:** `lib/src/models/bill_model.dart`

**Fields:**
- `id`, `flatId`, `type`, `amount`
- `dueDate`, `billingPeriodStart`, `billingPeriodEnd`
- `status`, `description`
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications
- `isOverdue` - Computed property to check if bill is overdue

---

### 4. PaymentModel
**Location:** `lib/src/models/payment_model.dart`

**Fields:**
- `id`, `billId`, `flatId`, `userId`
- `amount`, `method`, `status`
- `transactionId`, `receiptUrl`, `paymentDate`
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications
- `isSuccessful`, `isPending`, `isFailed` - Status check properties

---

### 5. NoticeModel
**Location:** `lib/src/models/notice_model.dart`

**Fields:**
- `id`, `title`, `content`, `category`, `priority`
- `authorId`, `authorName`, `attachments` (List)
- `publishDate`, `expiryDate`, `isActive`
- `targetFlats` (List)
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications
- `isExpired` - Computed property to check if notice has expired

---

### 6. VisitorModel
**Location:** `lib/src/models/visitor_model.dart`

**Fields:**
- `id`, `flatId`, `hostUserId`
- `visitorName`, `visitorPhone`, `purpose`
- `expectedArrival`, `actualArrival`, `departure`
- `status`, `vehicleNumber`, `photoUrl`, `approvedBy`
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications
- `hasArrived`, `hasDeparted`, `isActive` - Status check properties

---

### 7. ComplaintModel
**Location:** `lib/src/models/complaint_model.dart`

**Fields:**
- `id`, `flatId`, `userId`
- `title`, `description`, `category`, `priority`
- `status`, `attachments` (List)
- `assignedTo`, `resolution`, `resolvedAt`
- `createdAt`, `updatedAt`

**Methods:**
- `toJson()` / `toMap()` - Serialize to JSON/Map
- `fromJson()` - Deserialize from JSON
- `fromMap()` - Deserialize from Map with document ID
- `fromSnapshot()` - Create from Firestore DocumentSnapshot
- `fromFirestore()` - Alternative Firestore constructor
- `copyWith()` - Immutable copy with modifications
- `isOpen`, `isResolved`, `isInProgress` - Status check properties

---

## Key Features

### Null Safety
All models use proper null-safety with nullable types (`?`) where appropriate and non-null defaults.

### Timestamp Handling
- All DateTime fields are properly converted to/from Firestore Timestamps
- Null timestamps are handled gracefully with fallback to `DateTime.now()`

### Multiple Constructors
Each model provides:
- `fromJson()` - Standard JSON deserialization
- `fromMap()` - Map deserialization with document ID
- `fromSnapshot()` - Direct Firestore DocumentSnapshot conversion
- `fromFirestore()` - Alternative Firestore constructor

### Serialization
- `toJson()` - Converts model to JSON-compatible Map
- `toMap()` - Same as toJson() for backward compatibility

### Immutability
- All fields are `final`
- `copyWith()` method for creating modified copies

### Helper Properties
Models include computed properties for common checks:
- `BillModel.isOverdue`
- `PaymentModel.isSuccessful`, `isPending`, `isFailed`
- `NoticeModel.isExpired`
- `VisitorModel.hasArrived`, `hasDeparted`, `isActive`
- `ComplaintModel.isOpen`, `isResolved`, `isInProgress`

---

## Usage Examples

### Creating a Model
```dart
final bill = BillModel(
  id: 'bill123',
  flatId: 'flat456',
  type: 'maintenance',
  amount: 5000.0,
  dueDate: DateTime.now().add(Duration(days: 30)),
  billingPeriodStart: DateTime.now(),
  billingPeriodEnd: DateTime.now().add(Duration(days: 30)),
  status: 'pending',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### Serializing to JSON
```dart
final json = bill.toJson();
// Upload to Firestore
await FirebaseFirestore.instance
  .collection('bills')
  .doc(bill.id)
  .set(json);
```

### Deserializing from Firestore
```dart
// From DocumentSnapshot
final doc = await FirebaseFirestore.instance
  .collection('bills')
  .doc('bill123')
  .get();
final bill = BillModel.fromFirestore(doc);

// From JSON/Map
final json = {'id': 'bill123', 'flatId': 'flat456', ...};
final bill = BillModel.fromJson(json);
```

### Using copyWith
```dart
final updatedBill = bill.copyWith(
  status: 'paid',
  updatedAt: DateTime.now(),
);
```

### Using Helper Properties
```dart
if (bill.isOverdue) {
  print('Bill is overdue!');
}

if (payment.isSuccessful) {
  print('Payment completed successfully');
}

if (notice.isExpired) {
  print('Notice has expired');
}
```

---

## Testing

All models have been validated with no diagnostics errors. They are ready for use with:
- Firestore database operations
- JSON API communication
- State management (Provider, Riverpod, Bloc, etc.)
- Local storage (SharedPreferences, Hive, etc.)

---

## Next Steps

1. Use these models in your database service layer
2. Implement CRUD operations in `ResidentDatabaseService`
3. Add model validation if needed
4. Consider adding JSON serialization code generation with `json_serializable` for larger projects
