# Resident Management - Quick Start Guide

## 🚀 Quick Access

### Navigate to Residents
```dart
// From anywhere in the app
Navigator.pushNamed(context, '/residents');

// Or use direct navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AdminResidentsPageFirestore(),
  ),
);
```

### Bottom Navigation
- Tap the Residents icon (index 2) in bottom navigation bar

### Dashboard Quick Access
- Tap "Residents" card on dashboard

---

## 📋 Key Features at a Glance

| Feature | How to Access | What It Does |
|---------|---------------|--------------|
| **View All** | Navigate to Residents screen | Shows all residents from Firestore |
| **Search** | Type in search bar | Filters by name, flat, or ID |
| **Filter** | Use dropdown filters | Filter by building or status |
| **Edit** | Click ✏️ icon | Opens edit dialog |
| **View Profile** | Click 👁️ icon | Shows full resident details |
| **Copy Credentials** | Click 📋 in profile | Copies to clipboard |
| **View Password** | Click 👁️ in credentials | Shows password in dialog |
| **Activate/Deactivate** | Click ⋮ → Select option | Changes resident status |
| **Delete** | Click ⋮ → Delete | Removes resident |

---

## 🔥 Firestore Structure

### Collection: `users`

```javascript
{
  // Identity
  "residentId": "RES1234",
  "role": "resident",
  
  // Personal
  "name": "John Doe",
  "phone": "+91 9876543210",
  "email": "john@example.com",
  "familyMembers": 4,
  
  // Flat
  "flatId": "flat_doc_id",
  "flatLabel": "A-101",
  "ownershipType": "owner",
  
  // Status
  "status": "active",
  
  // Auth
  "password": "SecurePass123",
  "authEmail": "john@example.com",
  "authUid": "firebase_uid",
  
  // Timestamps
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

---

## 💻 Code Examples

### Fetch All Residents
```dart
final UserService _userService = UserService();

StreamBuilder<List<UserModel>>(
  stream: _userService.getUsers(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final residents = snapshot.data!;
      // Display residents
    }
    return CircularProgressIndicator();
  },
)
```

### Update Resident
```dart
await _userService.updateUser(
  userId: resident.id,
  name: 'New Name',
  phone: '+91 9999999999',
  email: 'newemail@example.com',
  familyMembers: 5,
  password: 'NewPassword123',
);
```

### Get Single Resident
```dart
final resident = await _userService.getUserById(userId);
if (resident != null) {
  print(resident.name);
}
```

### Change Status
```dart
await _userService.updateUserStatus(
  userId: resident.id,
  status: 'active', // or 'inactive'
);
```

### Delete Resident
```dart
await _userService.deleteUser(resident.id);
```

---

## 🎨 UI Components

### Import Required Widgets
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/edit_resident_dialog.dart';
import 'services/user_service.dart';
```

### Show Edit Dialog
```dart
final result = await showDialog<bool>(
  context: context,
  builder: (context) => EditResidentDialog(resident: resident),
);

if (result == true) {
  // Changes saved
}
```

### Navigate to Profile
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ResidentProfilePage(resident: resident),
  ),
);
```

### Copy to Clipboard
```dart
Clipboard.setData(ClipboardData(text: value));
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Copied to clipboard')),
);
```

---

## 🔍 Search & Filter

### Search Implementation
```dart
List<UserModel> _filterResidents(List<UserModel> residents) {
  return residents.where((resident) {
    final matchesSearch = _searchQuery.isEmpty ||
        resident.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (resident.flatLabel?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        resident.residentId.toLowerCase().contains(_searchQuery.toLowerCase());
    
    return matchesSearch;
  }).toList();
}
```

### Filter by Building
```dart
final matchesBuilding = _selectedBuilding == null ||
    _selectedBuilding == 'all' ||
    (resident.flatLabel?.startsWith(_selectedBuilding!) ?? false);
```

### Filter by Status
```dart
final matchesStatus = _selectedStatus == null ||
    _selectedStatus == 'all' ||
    resident.status == _selectedStatus;
```

---

## 🛡️ Security Best Practices

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Only authenticated admins can read/write
      allow read, write: if request.auth != null && 
                           request.auth.token.role == 'admin';
    }
  }
}
```

### Password Handling
```dart
// Always mask password in UI
Text(isPassword ? '••••••••' : value)

// Show in secure dialog only
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Password'),
    content: SelectableText(password),
  ),
);
```

---

## ⚡ Common Tasks

### 1. Add New Resident
```dart
// Use Building Management → Assign Resident
// This creates the user and assigns to flat
```

### 2. Edit Resident Details
```dart
// Click edit icon → Modify fields → Save
```

### 3. View Credentials
```dart
// Click view icon → Scroll to credentials section
```

### 4. Copy Password
```dart
// Profile → Credentials → Click copy icon
```

### 5. Change Status
```dart
// Click ⋮ → Activate or Deactivate
```

---

## 🐛 Troubleshooting

### Residents Not Loading
```
1. Check Firestore rules
2. Verify internet connection
3. Check console for errors
4. Verify collection name is 'users'
5. Verify role field is 'resident'
```

### Edit Not Saving
```
1. Check form validation
2. Verify Firestore write permissions
3. Check console for errors
4. Verify userId is correct
```

### Password Not Showing
```
1. Verify password field exists in Firestore
2. Check if password is null
3. Verify field name is 'password'
```

### Copy Not Working
```
1. Verify Clipboard permission
2. Check if value is not null
3. Test on different device/browser
```

---

## 📱 Mobile Considerations

### Responsive Design
- Edit dialog scrollable on small screens
- Touch-friendly button sizes (min 44x44)
- Readable text sizes
- Proper padding and margins

### Performance
- StreamBuilder for real-time updates
- Efficient Firestore queries
- Minimal rebuilds
- Lazy loading

---

## 🔗 Related Modules

### Building Management
- Assign residents to flats
- Manage flat occupancy
- View flat details

### Billing Module
- View payment history
- Generate bills
- Track dues

### Visitor Management
- Link visitors to residents
- Approve visitor requests
- View visitor history

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `RESIDENT_MANAGEMENT_FIRESTORE_INTEGRATION.md` | Integration details |
| `RESIDENT_EDIT_AND_PROFILE_COMPLETE.md` | Feature documentation |
| `RESIDENT_MANAGEMENT_VISUAL_FLOW.md` | Visual flow guide |
| `RESIDENT_MANAGEMENT_COMPLETE_SUMMARY.md` | Complete summary |
| `RESIDENT_MANAGEMENT_TESTING_GUIDE.md` | Testing guide |
| `RESIDENT_MANAGEMENT_QUICK_START.md` | This file |

---

## 🎯 Key Files

```
lib/
├── admin_residents_page_firestore.dart    # Main screen
├── widgets/
│   └── edit_resident_dialog.dart          # Edit dialog
└── services/
    └── user_service.dart                  # Firestore service
```

---

## ⚙️ Configuration

### Required Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^4.13.0
  firebase_auth: ^4.15.0
  firebase_core: ^2.24.0
```

### Firebase Setup
1. Add Firebase to your Flutter app
2. Enable Firestore Database
3. Configure Firestore rules
4. Enable Authentication

---

## 🚦 Status Indicators

### Status Badge Colors
- **Active**: Green (#10B981)
- **Inactive**: Red (#EF4444)

### Status Values
- `"active"` - Resident is active
- `"inactive"` - Resident is inactive

---

## 💡 Tips & Tricks

1. **Real-time Updates**: Use StreamBuilder for automatic UI updates
2. **Search Performance**: Filter at Firestore level when possible
3. **Password Security**: Always mask passwords in UI
4. **Error Handling**: Always wrap Firestore calls in try-catch
5. **Validation**: Validate all inputs before saving
6. **User Feedback**: Show loading states and notifications
7. **Navigation**: Use named routes for consistency
8. **Testing**: Test with real Firestore data

---

## 🎓 Learning Resources

### Flutter Firestore
- [Official Firestore Docs](https://firebase.google.com/docs/firestore)
- [FlutterFire Documentation](https://firebase.flutter.dev/)

### StreamBuilder
- [Flutter StreamBuilder Guide](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html)

### Form Validation
- [Flutter Form Validation](https://docs.flutter.dev/cookbook/forms/validation)

---

## ✅ Quick Checklist

Before deploying:
- [ ] Firestore rules configured
- [ ] All features tested
- [ ] Error handling implemented
- [ ] Loading states added
- [ ] Validation working
- [ ] Navigation tested
- [ ] Mobile responsive
- [ ] Security verified
- [ ] Documentation complete

---

## 🆘 Need Help?

1. Check documentation files
2. Review code comments
3. Check console logs
4. Verify Firestore data structure
5. Test with sample data
6. Check Firebase console for errors

---

## 🎉 You're Ready!

The Resident Management module is fully functional and ready to use. Start by navigating to the Residents screen and exploring the features!
