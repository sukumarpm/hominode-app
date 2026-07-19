# Firebase Setup Guide for Events & Announcements

## Overview
The Events & Announcements screen is now fully integrated with Firestore. To see data in the app, you need to add documents to Firebase.

---

## Required Firestore Collections

### 1. Collection: `announcements`
### 2. Collection: `events`

---

## How to Add Data

### Option 1: Firebase Console (Manual)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database**
4. Click **Start collection**

#### Add Announcements Collection:

**Collection ID:** `announcements`

**Sample Document 1:**
```
Document ID: (auto-generated)

Fields:
- title (string): "Water Supply Maintenance"
- description (string): "Water supply will be interrupted on March 3rd from 10 AM to 2 PM for maintenance work."
- category (string): "Maintenance"
- priority (string): "high"
- status (string): "active"
- createdAt (timestamp): (click "Add field" → select "timestamp" → click "Set to current time")
- updatedAt (timestamp): (same as createdAt)
```

**Sample Document 2:**
```
Document ID: (auto-generated)

Fields:
- title (string): "New Parking Rules"
- description (string): "Updated parking guidelines have been implemented. Please check the notice board."
- category (string): "Rules"
- priority (string): "medium"
- status (string): "active"
- createdAt (timestamp): (current time)
- updatedAt (timestamp): (current time)
```

#### Add Events Collection:

**Collection ID:** `events`

**Sample Document 1:**
```
Document ID: (auto-generated)

Fields:
- title (string): "Holi Celebration 2026"
- description (string): "Join us for a colorful Holi celebration with your neighbors!"
- category (string): "Festival"
- priority (string): "high"
- status (string): "active"
- eventDate (timestamp): March 25, 2026 10:00 AM
- location (string): "Community Ground"
- createdAt (timestamp): (current time)
- updatedAt (timestamp): (current time)
```

**Sample Document 2:**
```
Document ID: (auto-generated)

Fields:
- title (string): "Morning Yoga Session"
- description (string): "Start your day with a refreshing yoga session on the terrace."
- category (string): "Wellness"
- priority (string): "low"
- status (string): "active"
- eventDate (timestamp): March 5, 2026 6:00 AM
- location (string): "Terrace Garden"
- createdAt (timestamp): (current time)
- updatedAt (timestamp): (current time)
```

---

### Option 2: Using Firebase Admin SDK (Programmatic)

If you have an Admin App or backend, use this code:

```javascript
// Add announcement
await db.collection('announcements').add({
  title: "Pool Maintenance",
  description: "Swimming pool will be closed for cleaning on March 1st",
  category: "Maintenance",
  priority: "medium",
  status: "active",
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp()
});

// Add event
await db.collection('events').add({
  title: "Community BBQ Night",
  description: "Join us for a fun evening with food and music",
  category: "Social",
  priority: "medium",
  status: "active",
  eventDate: admin.firestore.Timestamp.fromDate(new Date('2026-03-20T18:00:00')),
  location: "Community Garden",
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp()
});
```

---

## Field Specifications

### Announcements Fields

| Field | Type | Required | Values | Description |
|-------|------|----------|--------|-------------|
| title | string | Yes | Any text | Announcement title |
| description | string | Yes | Any text | Full description |
| category | string | Yes | Any text | Category label (e.g., "Maintenance", "Rules") |
| priority | string | Yes | "high", "medium", "low" | Priority level |
| status | string | Yes | "active", "inactive" | Only "active" shown in app |
| createdAt | timestamp | Yes | Server timestamp | Creation date |
| updatedAt | timestamp | Yes | Server timestamp | Last update date |

### Events Fields

| Field | Type | Required | Values | Description |
|-------|------|----------|--------|-------------|
| title | string | Yes | Any text | Event title |
| description | string | Yes | Any text | Full description |
| category | string | Yes | Any text | Category label (e.g., "Festival", "Wellness") |
| priority | string | Yes | "high", "medium", "low" | Priority level |
| status | string | Yes | "active", "inactive" | Only "active" shown in app |
| eventDate | timestamp | No | Future date/time | When event occurs |
| location | string | No | Any text | Event location |
| createdAt | timestamp | Yes | Server timestamp | Creation date |
| updatedAt | timestamp | Yes | Server timestamp | Last update date |

---

## Priority Colors

The app displays priority badges with these colors:

- **High**: Red background (#FEE2E2), Red text (#EF4444)
- **Medium**: Blue background (#DBEAFE), Blue text (#2563EB)
- **Low**: Green background (#D1FAE5), Green text (#10B981)

---

## Firestore Security Rules

Make sure your Firestore rules allow reading these collections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Announcements - read by all authenticated users
    match /announcements/{announcementId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Events - read by all authenticated users
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## Testing

### 1. Add Test Data
- Add at least 2 announcements and 2 events using Firebase Console

### 2. Run the App
```bash
flutter run
```

### 3. Navigate to Events & Announcements
- Tap on the Events & Announcements icon in bottom navigation
- Switch between "Announcements" and "Events" tabs
- Verify data appears correctly

### 4. Test Real-Time Updates
- Keep the app open
- Add a new announcement in Firebase Console
- Watch it appear in the app automatically (no refresh needed)

### 5. Test Empty State
- Set all documents' status to "inactive"
- Verify "No Announcements/Events" message appears

---

## Troubleshooting

### No Data Showing?

1. **Check Firestore Rules**
   - Ensure read permission is granted
   - User must be authenticated

2. **Check Document Fields**
   - Verify `status` field is set to "active"
   - Check field names match exactly (case-sensitive)

3. **Check Console for Errors**
   ```bash
   flutter run
   ```
   Look for Firestore permission errors

4. **Verify Collection Names**
   - Must be exactly: `announcements` and `events`
   - Case-sensitive

### Real-Time Updates Not Working?

- Check internet connection
- Verify Firestore is not in offline mode
- Restart the app

---

## Admin App Integration

For a complete solution, create an Admin App that allows:

1. **Create** announcements and events
2. **Edit** existing announcements and events
3. **Delete** announcements and events
4. **Change status** (active/inactive)
5. **Set priority** (high/medium/low)

The Resident App is read-only and will automatically display any changes made by the Admin App in real-time.

---

**Setup Complete!** 🎉

Once you add data to Firestore, the Events & Announcements screen will display it automatically with real-time updates.
