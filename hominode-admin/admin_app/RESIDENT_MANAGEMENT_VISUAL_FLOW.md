# Resident Management - Visual Flow Guide

## Screen Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    RESIDENTS SCREEN                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Search: [Search by name, flat, or ID...]             │ │
│  │  Filters: [Building ▼] [Status ▼]                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  👤 John Doe                          [Active]         │ │
│  │  A-101 • 4 members                                     │ │
│  │  ID: RES1234                                           │ │
│  │  +91 98765 43210                                       │ │
│  │                                    [👁️] [✏️] [⋮]        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  [👁️ View] → Opens Profile View                            │
│  [✏️ Edit] → Opens Edit Dialog                             │
│  [⋮ More] → Activate/Deactivate/Delete                     │
└─────────────────────────────────────────────────────────────┘
```

## Edit Dialog Flow

```
┌─────────────────────────────────────────────────────────────┐
│  ✏️  Edit Resident                                    [✕]   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Resident ID                                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 🎫 RES1234                          (Read-only)        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Full Name *                                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 👤 John Doe                                            │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Phone Number *                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📞 +91 98765 43210                                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Email (Optional)                                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📧 john@example.com                                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Family Members *                                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 👥 4                                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Password                                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 🔒 ••••••••                                      [👁️]  │ │
│  └────────────────────────────────────────────────────────┘ │
│  Leave empty to keep current password                       │
│                                                              │
│  Assigned Flat                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 🏠 A-101                            (Read-only)        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Status                                                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ⚫ Active                           (Read-only)        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────────────────────┐ │
│  │     Cancel       │  │      Save Changes                │ │
│  └──────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Profile View Flow

```
┌─────────────────────────────────────────────────────────────┐
│                                                         [←]  │
│                      John Doe                                │
│                                                              │
│                        👤                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Personal Information                                   │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │  🎫 Resident ID:    RES1234                            │ │
│  │  👤 Full Name:      John Doe                           │ │
│  │  📞 Phone:          +91 98765 43210                    │ │
│  │  📧 Email:          john@example.com                   │ │
│  │  👥 Family Members: 4                                  │ │
│  │  ⚫ Status:         Active                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Login Credentials                    🔒 Confidential  │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │  📧 Auth Email:                                        │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │ john@example.com                    [📋] Copy    │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                                                         │ │
│  │  🔒 Password:                                          │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │ ••••••••                      [📋] Copy [👁️] View│ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                                                         │ │
│  │  🔑 Auth UID:                                          │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │ firebase_auth_uid_here            [📋] Copy      │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Flat Information                                       │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │  🏠 Flat:           A-101                              │ │
│  │  🔑 Ownership:      Owner                              │ │
│  │  🏷️  Flat ID:       flat_doc_id_123                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Billing & Payments                                     │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │  Payment history will be displayed here                │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │  📄 View Payment History                         │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Password View Dialog

```
┌─────────────────────────────────────────┐
│  Password                          [✕]  │
├─────────────────────────────────────────┤
│                                         │
│  SecurePass123                          │
│  (Selectable text)                      │
│                                         │
│                                         │
│                    ┌──────────────────┐ │
│                    │      Close       │ │
│                    └──────────────────┘ │
└─────────────────────────────────────────┘
```

## User Actions & Results

### 1. View Resident Profile
```
Action: Click [👁️] icon on resident card
Result: Opens full profile view with all details
Data: Fetched from Firestore users/{userId}
```

### 2. Edit Resident
```
Action: Click [✏️] icon on resident card
Result: Opens edit dialog with current data
Save: Updates Firestore users/{userId}
Refresh: StreamBuilder auto-updates UI
```

### 3. Copy Credentials
```
Action: Click [📋] icon next to credential field
Result: Copies value to clipboard
Feedback: Shows "Copied to clipboard" snackbar
```

### 4. View Password
```
Action: Click [👁️] icon next to password field
Result: Shows password in dialog (selectable)
Security: Password masked by default
```

### 5. Toggle Password Visibility (Edit)
```
Action: Click [👁️] icon in password field
Result: Toggles between ••••••• and actual text
State: Local to edit dialog
```

### 6. Activate/Deactivate
```
Action: Click [⋮] → Activate/Deactivate
Result: Updates status in Firestore
UI: Status badge updates automatically
```

### 7. Delete Resident
```
Action: Click [⋮] → Delete
Confirm: Shows confirmation dialog
Result: Deletes from Firestore
UI: Removes from list automatically
```

## Data Synchronization

```
┌──────────────┐
│   Firestore  │
│    users/    │
└──────┬───────┘
       │
       │ StreamBuilder (Real-time)
       │
       ▼
┌──────────────┐
│  Residents   │
│    Screen    │
└──────┬───────┘
       │
       ├─────► [View] ──► Profile Page
       │                  (Read-only)
       │
       └─────► [Edit] ──► Edit Dialog
                          (Updates Firestore)
                                │
                                ▼
                          Auto-refresh
                          via StreamBuilder
```

## Field Validation Rules

### Edit Dialog Validation:

| Field          | Required | Validation                    |
|----------------|----------|-------------------------------|
| Name           | Yes      | Not empty                     |
| Phone          | Yes      | Not empty                     |
| Email          | No       | Valid email format (if filled)|
| Family Members | Yes      | Number >= 1                   |
| Password       | No       | Any text (if changing)        |

### Read-Only Fields:
- Resident ID (auto-generated)
- Assigned Flat (via Building Management)
- Status (via activate/deactivate)
- Auth UID (from Firebase Auth)

## Success/Error Messages

### Success Messages:
- ✅ "Resident updated successfully"
- ✅ "Auth Email copied to clipboard"
- ✅ "Password copied to clipboard"
- ✅ "John Doe activated"
- ✅ "John Doe deactivated"
- ✅ "John Doe deleted successfully"

### Error Messages:
- ❌ "Please enter name"
- ❌ "Please enter phone number"
- ❌ "Please enter a valid number"
- ❌ "Failed to update resident: [error]"
- ❌ "Failed to delete resident: [error]"

## Keyboard Shortcuts (Future Enhancement)

| Action         | Shortcut    |
|----------------|-------------|
| Search         | Ctrl/Cmd+F  |
| Edit Selected  | E           |
| View Selected  | V           |
| Delete         | Delete      |
| Close Dialog   | Esc         |

## Mobile Responsiveness

- Edit dialog scrollable on small screens
- Profile view uses SingleChildScrollView
- Cards stack vertically on mobile
- Touch-friendly button sizes
- Responsive padding and margins

## Accessibility Features

- Icon labels for screen readers
- Keyboard navigation support
- High contrast colors
- Clear focus indicators
- Descriptive error messages
- Semantic HTML structure
