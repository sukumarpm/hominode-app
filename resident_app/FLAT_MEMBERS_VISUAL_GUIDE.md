# Flat Members - Visual Guide

## Messages Screen Flow

```
┌─────────────────────────────────────────┐
│         MESSAGES SCREEN                 │
│                                         │
│  [Chats]  [Requests]                   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Admin Chat (Green)              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Chat 1: Jane Smith              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Chat 2: Mike Johnson            │   │
│  └─────────────────────────────────┘   │
│                                         │
│                              [+] Button │
└─────────────────────────────────────────┘
```

## Add Member Flow

```
User Taps [+] Button
        ↓
┌─────────────────────────────────────────┐
│    FLAT MEMBERS BOTTOM SHEET            │
│                                         │
│  Building Members                       │
│  2 members in your flat                 │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 👤 Jane Smith                   │   │
│  │    Flat 101                     │   │
│  │                            [💬] │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 👤 Mike Johnson                 │   │
│  │    Flat 101                     │   │
│  │                            [💬] │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
        ↓
User Taps Member
        ↓
Chat Request Sent
```

## Data Flow

```
┌──────────────────────────────────────────────────┐
│ STEP 1: Get Current User                         │
│ ├─ Firebase Auth or Firestore Auth              │
│ └─ Get user document                            │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│ STEP 2: Get User's Flat ID                       │
│ ├─ Read flatId from user document               │
│ └─ Validate exists                              │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│ STEP 3: Query Flat Members                       │
│ ├─ Query: users.where("flatId", isEqualTo: id) │
│ └─ Get all users in same flat                   │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│ STEP 4: Filter Results                           │
│ ├─ Loop through results                         │
│ ├─ Exclude current user (doc.id == userId)     │
│ └─ Keep other flat members                      │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│ STEP 5: Display Members                          │
│ ├─ Show flat members only                       │
│ ├─ Exclude current user                         │
│ └─ Allow chat requests                          │
└──────────────────────────────────────────────────┘
```

## Member Display Rules

```
┌─────────────────────────────────────────┐
│ MEMBER DISPLAY RULES                    │
├─────────────────────────────────────────┤
│                                         │
│ ✅ SHOW:                                │
│ • Other residents in same flat          │
│ • Their name and flat number            │
│ • Chat request button                   │
│                                         │
│ ❌ DON'T SHOW:                          │
│ • Current user (yourself)               │
│ • Residents from other flats            │
│ • Residents from other buildings        │
│                                         │
└─────────────────────────────────────────┘
```

## Example: Building A

```
┌─────────────────────────────────────────┐
│ BUILDING A                              │
├─────────────────────────────────────────┤
│                                         │
│ FLAT 101:                               │
│ • John Doe (current user) ❌ NOT SHOWN │
│ • Jane Smith ✅ SHOWN                  │
│ • Mike Johnson ✅ SHOWN                │
│                                         │
│ FLAT 102:                               │
│ • Sarah Lee ❌ NOT SHOWN                │
│ • Tom Wilson ❌ NOT SHOWN               │
│                                         │
│ FLAT 103:                               │
│ • Lisa Anderson ❌ NOT SHOWN            │
│                                         │
└─────────────────────────────────────────┘
```

## Query Comparison

```
┌─────────────────────────────────────────┐
│ BEFORE: Building Members Query          │
├─────────────────────────────────────────┤
│                                         │
│ Query: users.where("buildingId", ...)  │
│                                         │
│ Results:                                │
│ • John Doe (Flat 101) ❌ WRONG         │
│ • Jane Smith (Flat 101) ✅             │
│ • Mike Johnson (Flat 101) ✅           │
│ • Sarah Lee (Flat 102) ❌ WRONG        │
│ • Tom Wilson (Flat 102) ❌ WRONG       │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ AFTER: Flat Members Query               │
├─────────────────────────────────────────┤
│                                         │
│ Query: users.where("flatId", ...)      │
│                                         │
│ Results:                                │
│ • John Doe (Flat 101) ❌ FILTERED OUT  │
│ • Jane Smith (Flat 101) ✅ SHOWN       │
│ • Mike Johnson (Flat 101) ✅ SHOWN     │
│                                         │
└─────────────────────────────────────────┘
```

## Status

✅ COMPLETE - Flat members only, current user excluded
