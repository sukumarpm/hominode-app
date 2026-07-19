# Admin Chat Redesign - Specification 📋

## 🎯 Requirements

### 1. One Building Admin Only
- Each building has exactly ONE admin
- No duplicate admin chats
- Admin identified by `role: 'admin'` in users collection

### 2. Separate Firestore Collection
- Collection: `adminChats` (not `chats`)
- Easier to manage admin-specific queries
- Better security rules
- Separate from resident-to-resident chats

### 3. Pre-built Query System
- Quick query buttons (like chatbot)
- Common queries: Billing, Maintenance, Amenities, Complaints, etc.
- User selects query → Auto-sends message
- Admin responds manually

### 4. Prevent Misuse
- Only query/issue-based chats allowed
- No casual chatting
- Structured conversation flow
- Admin can close/resolve queries

---

## 📊 Firestore Structure

### Collection: `adminChats`

```
adminChats/
  {chatId}/
    chatId: "admin_{buildingId}_{residentId}"
    buildingId: "qhwMQBUqElm6nfhK3Gr"
    adminId: "admin_user_doc_id"
    adminName: "John Admin"
    adminPhoto: "url"
    residentId: "Qy5GmvF8PVhOr9QuJID"
    residentName: "Preetham"
    residentPhoto: "url"
    flatId: "WDxpsEh6DlqdeN9WsYZ"
    flatNumber: "101"
    status: "open" | "resolved" | "closed"
    category: "billing" | "maintenance" | "amenities" | "complaint" | "general"
    lastMessage: "When will maintenance be done?"
    lastMessageTime: Timestamp
    lastMessageBy: "resident" | "admin"
    createdAt: Timestamp
    updatedAt: Timestamp
    
    messages/ (subcollection)
      {messageId}/
        messageId: "auto_generated"
        senderId: "Qy5GmvF8PVhOr9QuJID"
        senderName: "Preetham"
        senderRole: "resident" | "admin"
        text: "When will maintenance be done?"
        isQuery: true | false
        queryType: "billing" | "maintenance" | etc.
        timestamp: Timestamp
        readBy: ["admin_id"]
```

---

## 🎨 UI Design

### Admin Chat Card (Messages Screen)

```
┌─────────────────────────────────────────┐
│ 🛡️  Building Admin                      │
│     Get help and support                │
│                                    →    │
└─────────────────────────────────────────┘
```

### Query Selection Screen

```
┌─────────────────────────────────────────┐
│ ← Chat with Admin                       │
├─────────────────────────────────────────┤
│                                         │
│ Select your query:                      │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 💰 Billing & Payments               ││
│ │ Questions about bills, receipts     ││
│ └─────────────────────────────────────┘│
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 🔧 Maintenance Request              ││
│ │ Report issues, track repairs        ││
│ └─────────────────────────────────────┘│
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 🏊 Amenities & Bookings             ││
│ │ Questions about facilities          ││
│ └─────────────────────────────────────┘│
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 📝 Complaints & Issues              ││
│ │ Report problems, get updates        ││
│ └─────────────────────────────────────┘│
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 🏢 Building & Society               ││
│ │ General building questions          ││
│ └─────────────────────────────────────┘│
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ ❓ Other Query                      ││
│ │ Any other questions                 ││
│ └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

### Pre-built Query Templates

After selecting category, show quick templates:

```
┌─────────────────────────────────────────┐
│ ← Billing & Payments                    │
├─────────────────────────────────────────┤
│                                         │
│ Quick queries:                          │
│                                         │
│ • When is my next bill due?             │
│ • I didn't receive my bill              │
│ • Question about bill amount            │
│ • Payment confirmation needed           │
│ • Request payment receipt               │
│                                         │
│ Or type your own question:              │
│ ┌─────────────────────────────────────┐│
│ │ Type your question...               ││
│ └─────────────────────────────────────┘│
│                                         │
│              [Send Query]               │
│                                         │
└─────────────────────────────────────────┘
```

### Chat Conversation Screen

```
┌─────────────────────────────────────────┐
│ ← Building Admin                        │
│   Billing & Payments                    │
├─────────────────────────────────────────┤
│                                         │
│ [YOU - 10:30 AM]                        │
│ When is my next bill due?               │
│                                         │
│ [ADMIN - 10:45 AM]                      │
│ Your next bill is due on 15th March.    │
│ You can view it in the Billing section. │
│                                         │
│ [YOU - 10:46 AM]                        │
│ Thank you!                              │
│                                         │
│ [ADMIN - 10:47 AM]                      │
│ You're welcome! Query resolved.         │
│ ✅ This chat has been marked as         │
│    resolved by admin.                   │
│                                         │
├─────────────────────────────────────────┤
│ This query is resolved.                 │
│ [Start New Query]                       │
└─────────────────────────────────────────┘
```

---

## 🔄 Flow Function

### Resident Opens Admin Chat

```
Step 1: Get current user data
  ↓ Get buildingId, residentId, flatId
  
Step 2: Find building admin
  ↓ Query: users.where("buildingId", isEqualTo: buildingId)
  ↓         .where("role", isEqualTo: "admin")
  ↓         .limit(1)
  ↓ Result: Admin user document
  
Step 3: Check existing admin chat
  ↓ Query: adminChats.doc("admin_{buildingId}_{residentId}")
  ↓ If exists: Open existing chat
  ↓ If not: Show query selection screen
  
Step 4: User selects query category
  ↓ Show pre-built query templates
  
Step 5: User selects/types query
  ↓ Create admin chat document
  ↓ Add first message with query
  ↓ Navigate to chat conversation
  
Step 6: Real-time messaging
  ↓ Stream messages from adminChats/{chatId}/messages
  ↓ Admin responds manually
  ↓ Resident can reply
  
Step 7: Admin resolves query
  ↓ Update status to "resolved"
  ↓ Show resolved UI
  ↓ Option to start new query
```

---

## 🛡️ Security Rules

```javascript
// Firestore Security Rules for adminChats

match /adminChats/{chatId} {
  // Read: Resident or Admin in this chat
  allow read: if request.auth != null && (
    resource.data.residentId == request.auth.uid ||
    resource.data.adminId == request.auth.uid
  );
  
  // Create: Only residents can create
  allow create: if request.auth != null &&
    request.resource.data.residentId == request.auth.uid &&
    request.resource.data.status == 'open';
  
  // Update: Resident or Admin can update
  allow update: if request.auth != null && (
    resource.data.residentId == request.auth.uid ||
    resource.data.adminId == request.auth.uid
  );
  
  // Messages subcollection
  match /messages/{messageId} {
    // Read: If can read parent chat
    allow read: if request.auth != null && (
      get(/databases/$(database)/documents/adminChats/$(chatId)).data.residentId == request.auth.uid ||
      get(/databases/$(database)/documents/adminChats/$(chatId)).data.adminId == request.auth.uid
    );
    
    // Create: If can read parent chat
    allow create: if request.auth != null && (
      get(/databases/$(database)/documents/adminChats/$(chatId)).data.residentId == request.auth.uid ||
      get(/databases/$(database)/documents/adminChats/$(chatId)).data.adminId == request.auth.uid
    );
  }
}
```

---

## 📝 Query Categories & Templates

### 1. Billing & Payments
- When is my next bill due?
- I didn't receive my bill
- Question about bill amount
- Payment confirmation needed
- Request payment receipt
- Billing discrepancy

### 2. Maintenance Request
- Plumbing issue in my flat
- Electrical problem
- Lift not working
- Common area maintenance
- Track my maintenance request
- Emergency repair needed

### 3. Amenities & Bookings
- How to book amenity?
- Booking cancellation
- Amenity not available
- Question about amenity rules
- Booking confirmation

### 4. Complaints & Issues
- Noise complaint
- Parking issue
- Security concern
- Cleanliness issue
- Track my complaint status

### 5. Building & Society
- Society rules and regulations
- Upcoming events
- Building announcements
- Visitor policy
- General inquiry

### 6. Other Query
- Custom question (free text)

---

## 🚫 Misuse Prevention

### 1. Query-Based Only
- Must select category first
- Encourages structured queries
- No casual "hi, hello" chats

### 2. Status Tracking
- Open → Admin responding
- Resolved → Query completed
- Closed → No further messages

### 3. Rate Limiting
- Max 5 open queries per resident
- Must resolve before creating new

### 4. Admin Controls
- Can mark as resolved
- Can close inappropriate chats
- Can flag misuse

---

## 📊 Admin Dashboard View

Admins see all queries in organized view:

```
┌─────────────────────────────────────────┐
│ Admin Chat Dashboard                    │
├─────────────────────────────────────────┤
│                                         │
│ Open Queries (12)                       │
│                                         │
│ 💰 Billing (3)                          │
│ 🔧 Maintenance (5)                      │
│ 🏊 Amenities (2)                        │
│ 📝 Complaints (1)                       │
│ 🏢 Building (1)                         │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 💰 Preetham - Flat 101              ││
│ │    When is my next bill due?        ││
│ │    2 min ago                        ││
│ └─────────────────────────────────────┘│
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 🔧 Sibiyon - Flat 102               ││
│ │    Plumbing issue in bathroom       ││
│ │    15 min ago                       ││
│ └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

---

## ✅ Benefits

1. **Organized**: Queries categorized by type
2. **Efficient**: Pre-built templates save time
3. **Professional**: Structured communication
4. **Trackable**: Status tracking (open/resolved)
5. **Scalable**: Easy for admin to manage
6. **Secure**: Separate collection with proper rules
7. **No Misuse**: Query-based system prevents casual chat

---

## 🚀 Implementation Files

1. **Service**: `lib/src/services/admin_chat_service.dart`
2. **Models**: `lib/src/models/admin_chat_model.dart`
3. **Screens**:
   - `lib/src/screens/admin_chat_query_selection_screen.dart`
   - `lib/src/screens/admin_chat_conversation_screen.dart`
4. **Widgets**:
   - `lib/src/widgets/query_category_card.dart`
   - `lib/src/widgets/query_template_button.dart`

---

**Status**: Specification complete  
**Next**: Implement service and UI  
**Expected**: Professional, organized admin chat system
