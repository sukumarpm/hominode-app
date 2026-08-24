# Firestore Setup Guide for Security App

## Staff Collection Structure

The app expects a `staff` collection in Firestore with the following document structure:

### Required Fields

```json
{
  "uid": "firebase-auth-uid-here",
  "securityId": "SEC-001",
  "name": "Rajesh Kumar",
  "email": "rajesh.kumar@society.com",
  "phone": "+91 98765 43210",
  "password": "BCDEFGHIJKLM",
  "buildingId": "building-001",
  "buildingName": "Main Building",
  "organization": "Security Corp",
  "role": "Security Guard",
  "shift": "Morning Shift (6:00 AM - 2:00 PM)",
  "gate": "Main Gate A",
  "createdAt": "2024-03-13T23:24:00Z",
  "lastCheckIn": null,
  "lastCheckOut": null,
  "lastWorkAssignment": "2024-03-14T00:00:40Z",
  "joiningDate": "2024-03-13T00:00:00Z",
  "emergencyContact": "Not Babu",
  "emergencyPhone": "+91 9234567891"
}
```

## Field Descriptions

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `uid` | String | Firebase Authentication UID | Yes |
| `securityId` | String | Unique security staff ID | Yes |
| `name` | String | Full name of staff member | Yes |
| `email` | String | Email address (used for login) | Yes |
| `phone` | String | Phone number (can be used for login) | Yes |
| `password` | String | Password for login (plain text in Firestore) | Yes |
| `buildingId` | String | Building assignment ID | Yes |
| `buildingName` | String | Name of assigned building | Yes |
| `organization` | String | Organization name | Yes |
| `role` | String | Staff role (e.g., "Security Guard") | Yes |
| `shift` | String | Shift timing details | Yes |
| `gate` | String | Gate assignment | Yes |
| `createdAt` | Timestamp | Account creation date | No |
| `lastCheckIn` | Timestamp | Last check-in time | No |
| `lastCheckOut` | Timestamp | Last check-out time | No |
| `lastWorkAssignment` | Timestamp | Last work assignment date | No |
| `joiningDate` | Timestamp | Staff joining date | No |
| `emergencyContact` | String | Emergency contact name | No |
| `emergencyPhone` | String | Emergency contact phone | No |

## Login Flow

### Step 1: User Input
User enters email/phone and password on login screen

### Step 2: Firestore Query
App queries the `staff` collection to find a document where:
- `email` matches the input, OR
- `phone` matches the input

### Step 3: Password Verification
App compares the entered password with the stored `password` field

### Step 4: Firebase Authentication
- If password matches, app attempts Firebase Auth login
- If Firebase Auth user doesn't exist, app creates one automatically
- Updates the staff document with the Firebase `uid`

### Step 5: Session Management
- User is logged in with Firebase session
- App fetches full staff details from Firestore
- Displays user data throughout the app

## Adding a New Staff Member

### Method 1: Manual Addition via Firebase Console

1. Go to Firebase Console → Firestore Database
2. Click "Add collection" → name it `staff`
3. Click "Add document" → auto-generate ID
4. Add the following fields:

```
Field Name          Type        Value
uid                 string      (leave empty initially, will be auto-filled)
securityId          string      SEC-001
name                string      Rajesh Kumar
email               string      rajesh.kumar@society.com
phone               string      +91 98765 43210
password            string      BCDEFGHIJKLM
buildingId          string      building-001
buildingName        string      Main Building
organization        string      Security Corp
role                string      Security Guard
shift               string      Morning Shift (6:00 AM - 2:00 PM)
gate                string      Main Gate A
createdAt           timestamp   (current date/time)
joiningDate         timestamp   (current date/time)
emergencyContact    string      Contact Name
emergencyPhone      string      +91 XXXXXXXXXX
```

### Method 2: Programmatic Addition

Use Firebase Admin SDK or a backend service to add staff members.

## Testing the Login

### Test Credentials (from Firestore)
```
Email: sibi@gmail.com
Phone: +91 9234567891
Password: BCDEFGHIJKLM
```

### Test Steps
1. Launch the app
2. Enter email or phone: `sibi@gmail.com`
3. Enter password: `BCDEFGHIJKLM`
4. Click Login
5. Should navigate to dashboard with staff details

## Firestore Security Rules

Set these security rules to protect staff data:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Staff collection - authenticated users can read their own data
    match /staff/{staffId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.uid;
      allow create: if request.auth != null;
    }
    
    // Visitors collection - authenticated users can read/write
    match /visitors/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Other collections
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Important Notes

### Password Storage
⚠️ **Security Warning**: Passwords are currently stored in plain text in Firestore. For production:
1. Use Firebase Authentication for password management
2. Never store plain text passwords
3. Implement proper password hashing
4. Use Firebase Security Rules to restrict access

### UID Field
- Initially can be empty or auto-generated
- Will be automatically populated with Firebase Auth UID on first login
- Must match the Firebase Authentication UID for proper session management

### Email Uniqueness
- Ensure each staff member has a unique email
- Email is used for Firebase Authentication
- Phone can also be unique for login purposes

### Data Consistency
- Keep `email` and `phone` fields consistent
- Update staff details through the app when possible
- Maintain referential integrity with building and organization IDs

## Troubleshooting

### Login Fails with "Staff member not found"
- Verify the email/phone exists in Firestore staff collection
- Check for typos in email/phone
- Ensure the document is in the `staff` collection

### Login Fails with "Incorrect password"
- Verify the password matches exactly (case-sensitive)
- Check for extra spaces in password field
- Ensure password field is not empty

### Dashboard Shows "Loading..." Forever
- Check if user is authenticated
- Verify Firestore security rules allow read access
- Check network connectivity
- Verify staff document has all required fields

### Profile Data Not Displaying
- Ensure all required fields are present in staff document
- Check Firestore security rules
- Verify the `uid` field matches Firebase Auth UID
- Check browser console for errors

## Migration from Demo Data

If migrating from demo data:

1. Export existing staff data
2. Add required fields (uid, password, etc.)
3. Create Firestore documents with proper structure
4. Test login with each staff member
5. Update any hardcoded references in code
6. Remove demo data from app

## Best Practices

1. **Regular Backups**: Backup Firestore data regularly
2. **Audit Logging**: Log all login attempts
3. **Password Policy**: Enforce strong password requirements
4. **Access Control**: Implement role-based access control
5. **Data Validation**: Validate all input data
6. **Error Handling**: Provide clear error messages
7. **Session Management**: Implement session timeout
8. **Encryption**: Use HTTPS for all communications

## Support

For issues or questions:
1. Check Firestore console for data structure
2. Review Firebase Authentication logs
3. Check app console for error messages
4. Verify network connectivity
5. Review security rules configuration
