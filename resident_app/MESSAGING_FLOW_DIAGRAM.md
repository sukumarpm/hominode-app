# Messaging System - Flow Diagram

## 🔄 Complete User Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      MESSAGES SCREEN                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Segmented Control: [Chats] [Requests]                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  🟢 Building Admin (Always Visible)                       │  │
│  │     Support & Assistance                                  │  │
│  │     [Tap to open admin chat]                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  💬 John Doe                                              │  │
│  │     Hey, how are you?                                     │  │
│  │     [2 unread]                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  💬 Jane Smith                                            │  │
│  │     See you tomorrow!                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  [+] Floating Action Button                                     │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Flow 1: Starting a New Chat

```
User taps [+] button
        ↓
┌─────────────────────────────────────────┐
│  Fetch Flat Members                     │
│  Query: flatId == currentUser.flatId    │
│         uid != currentUser.uid          │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Show Flat Members Bottom Sheet         │
│  ┌───────────────────────────────────┐  │
│  │  👤 John Doe                      │  │
│  │     Same flat member              │  │
│  ├───────────────────────────────────┤  │
│  │  👤 Jane Smith                    │  │
│  │     Same flat member              │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
        ↓
User selects member
        ↓
┌─────────────────────────────────────────┐
│  Check if chat already exists           │
│  Query: participantIds contains both    │
└─────────────────────────────────────────┘
        ↓
   ┌────┴────┐
   │         │
Chat exists  Chat doesn't exist
   │         │
   ↓         ↓
Show msg   Create Chat Request
"Chat      ┌─────────────────────────┐
already    │  chatRequests/          │
exists"    │  {                      │
           │    senderId: uid1       │
           │    receiverId: uid2     │
           │    flatId: flat123      │
           │    status: "pending"    │
           │    createdAt: now       │
           │  }                      │
           └─────────────────────────┘
                    ↓
           Show "Request sent!"
```

## 📨 Flow 2: Receiving & Accepting Request

```
Receiver opens Messages screen
        ↓
Taps [Requests] tab
        ↓
┌─────────────────────────────────────────┐
│  Stream Incoming Requests               │
│  Query: receiverId == currentUser.uid   │
│         status == "pending"             │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Show Request Cards                     │
│  ┌───────────────────────────────────┐  │
│  │  👤 John Doe                      │  │
│  │     Wants to chat with you        │  │
│  │  [Accept] [Reject]                │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
        ↓
User taps [Accept]
        ↓
┌─────────────────────────────────────────┐
│  Update Request                         │
│  status: "accepted"                     │
│  respondedAt: now                       │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Create Chat Document                   │
│  chats/{sorted_uid1_uid2}               │
│  {                                      │
│    chatId: "uid1_uid2"                  │
│    participants: [uid1, uid2]           │
│    participantIds: [uid1, uid2]         │
│    flatId: "flat123"                    │
│    type: "resident"                     │
│    isGroup: false                       │
│    title: "John Doe"                    │
│    lastMessage: null                    │
│    lastMessageTime: null                │
│    unreadCount: 0                       │
│    createdAt: now                       │
│  }                                      │
└─────────────────────────────────────────┘
        ↓
Navigate to Chat Conversation
        ↓
Both users see chat in [Chats] tab
```

## 💬 Flow 3: Sending Messages

```
User opens chat conversation
        ↓
┌─────────────────────────────────────────┐
│  Stream Messages                        │
│  chats/{chatId}/messages                │
│  orderBy: createdAt (ascending)         │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Display Messages                       │
│  ┌───────────────────────────────────┐  │
│  │  John: Hey there!                 │  │
│  │  10:30 AM                         │  │
│  ├───────────────────────────────────┤  │
│  │  You: Hi! How are you?            │  │
│  │  10:31 AM                         │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [Type a message...] [Send]             │
└─────────────────────────────────────────┘
        ↓
User types and taps [Send]
        ↓
┌─────────────────────────────────────────┐
│  Create Message Document                │
│  chats/{chatId}/messages/{messageId}    │
│  {                                      │
│    chatId: chatId                       │
│    senderId: currentUser.uid            │
│    senderName: "You"                    │
│    text: "Hi! How are you?"             │
│    timestamp: now                       │
│    status: "sent"                       │
│    readBy: [currentUser.uid]            │
│  }                                      │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Update Chat Document                   │
│  chats/{chatId}                         │
│  {                                      │
│    lastMessage: "Hi! How are you?"      │
│    lastMessageTime: now                 │
│    updatedAt: now                       │
│  }                                      │
└─────────────────────────────────────────┘
        ↓
Real-time update to both users
        ↓
Message appears instantly
```

## 🔧 Flow 4: Admin Chat (Automatic)

```
User opens Messages screen
        ↓
┌─────────────────────────────────────────┐
│  Check for Admin Chat                   │
│  Query: participantIds contains uid     │
│         type == "admin"                 │
│         buildingId == user.buildingId   │
└─────────────────────────────────────────┘
        ↓
   ┌────┴────┐
   │         │
Exists    Doesn't exist
   │         │
   ↓         ↓
Return    Find Admin User
chatId    ┌─────────────────────────┐
          │  Query: buildingId ==   │
          │         user.buildingId │
          │         role == "admin" │
          └─────────────────────────┘
                    ↓
          ┌─────────────────────────┐
          │  Create Admin Chat      │
          │  chats/admin_{bid}_{uid}│
          │  {                      │
          │    chatId: ...          │
          │    type: "admin"        │
          │    participants: [uid,  │
          │                  adminId]│
          │    buildingId: bid      │
          │    title: "Building     │
          │           Admin"        │
          │    subtitle: "Support & │
          │              Assistance"│
          │    iconName: "support_  │
          │              agent"     │
          │    iconBg: "#10B981"    │
          │  }                      │
          └─────────────────────────┘
                    ↓
          Return chatId
                    ↓
┌─────────────────────────────────────────┐
│  Display Admin Chat (Always at Top)    │
│  🟢 Building Admin                      │
│     Support & Assistance                │
└─────────────────────────────────────────┘
```

## 🔒 Security Flow

```
User attempts action
        ↓
┌─────────────────────────────────────────┐
│  Service Layer Validation               │
│  - Check user is logged in              │
│  - Verify flatId matches                │
│  - Validate participant membership      │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Firestore Security Rules               │
│  - Verify auth.uid in participantIds    │
│  - Check flatId consistency             │
│  - Validate request ownership           │
└─────────────────────────────────────────┘
        ↓
   ┌────┴────┐
   │         │
Allowed   Denied
   │         │
   ↓         ↓
Execute   Return error
action    "Access denied"
```

## 📊 Data Flow

```
┌─────────────────────────────────────────┐
│  Firestore Collections                  │
│                                         │
│  users/                                 │
│    {uid}                                │
│      - flatId                           │
│      - buildingId                       │
│      - name                             │
│      - role                             │
│                                         │
│  chatRequests/                          │
│    {requestId}                          │
│      - senderId                         │
│      - receiverId                       │
│      - flatId                           │
│      - status                           │
│                                         │
│  chats/                                 │
│    {chatId}                             │
│      - participants                     │
│      - flatId                           │
│      - type                             │
│      - lastMessage                      │
│                                         │
│      messages/                          │
│        {messageId}                      │
│          - senderId                     │
│          - text                         │
│          - timestamp                    │
│          - readBy                       │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Real-Time Streams                      │
│  - streamUserChats()                    │
│  - streamChatMessages()                 │
│  - streamIncomingChatRequests()         │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  UI Updates (StreamBuilder)             │
│  - Chats list                           │
│  - Messages list                        │
│  - Requests list                        │
│  - Unread counts                        │
└─────────────────────────────────────────┘
```

## 🎯 Key Decision Points

### 1. Can User Chat?
```
Is user logged in?
  ├─ No → Show login screen
  └─ Yes → Continue
       ↓
Has flatId?
  ├─ No → Show error
  └─ Yes → Show flat members
```

### 2. Create Chat or Request?
```
Does chat exist?
  ├─ Yes → Open existing chat
  └─ No → Create chat request
```

### 3. Admin Chat Type
```
Is admin user found?
  ├─ Yes → Use real admin ID
  └─ No → Use placeholder ID
       ↓
Create chat with type "admin"
```

### 4. Message Delivery
```
Send message
  ↓
Save to Firestore
  ↓
Update chat lastMessage
  ↓
Real-time sync to all participants
  ↓
Update unread counts
```
