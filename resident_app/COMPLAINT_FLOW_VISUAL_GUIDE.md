# Complaint Flow - Visual Guide

## Status Progression

```
┌──────────┐      ┌──────────────┐      ┌───────────┐
│ PENDING  │  →   │ IN PROGRESS  │  →   │ COMPLETED │
└──────────┘      └──────────────┘      └───────────┘
   🔴 Red            🟠 Orange            🟢 Green
```

## Complaint Detail Modal - By Status

### 1. PENDING Status

```
┌─────────────────────────────────────────┐
│  Complaint Details              🗑️  ✕   │
├─────────────────────────────────────────┤
│                                         │
│  🔧  Leaking Pipe                       │
│      [Pending] 🔴                       │
│      Jan 20, 2024                       │
│                                         │
│  Description                            │
│  Kitchen sink pipe is leaking badly     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Timeline                        │   │
│  │                                 │   │
│  │ ● Complaint Submitted           │   │
│  │   Jan 20, 10:00 AM              │   │
│  │                                 │   │
│  │ ○ Waiting for Staff Assignment  │   │
│  │   Pending                       │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ ℹ️  Waiting for staff assignment │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘

Legend:
● = Done (Green)
○ = Pending (Gray)
```

### 2. IN PROGRESS Status

```
┌─────────────────────────────────────────┐
│  Complaint Details                  ✕   │
├─────────────────────────────────────────┤
│                                         │
│  🔧  Leaking Pipe                       │
│      [In Progress] 🟠                   │
│      Jan 20, 2024                       │
│                                         │
│  Description                            │
│  Kitchen sink pipe is leaking badly     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Assigned Staff                  │   │
│  │                                 │   │
│  │  👤  Ramesh Kumar               │   │
│  │      Plumber                    │   │
│  │                                 │   │
│  │  ┌───────────────────────────┐ │   │
│  │  │ 📞 +91 98765 43210 [Call]→│ │   │
│  │  └───────────────────────────┘ │   │
│  │  ┌───────────────────────────┐ │   │
│  │  │ 💬 Chat with Ramesh [Chat]│ │   │
│  │  └───────────────────────────┘ │   │
│  │  ┌───────────────────────────┐ │   │
│  │  │ ✉️ ramesh@example.com     │ │   │
│  │  └───────────────────────────┘ │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Timeline                        │   │
│  │                                 │   │
│  │ ● Complaint Submitted           │   │
│  │   Jan 20, 10:00 AM              │   │
│  │                                 │   │
│  │ ● Assigned to Ramesh Kumar      │   │
│  │   Jan 20, 11:30 AM              │   │
│  │                                 │   │
│  │ ◐ Work in Progress              │   │
│  │   Jan 20, 2:00 PM               │   │
│  │                                 │   │
│  │ ○ Work Completion               │   │
│  │   In Progress                   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   [Chat With Technician]        │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘

Legend:
● = Done (Green)
◐ = In Progress (Orange)
○ = Pending (Gray)
```

### 3. COMPLETED Status

```
┌─────────────────────────────────────────┐
│  Complaint Details                  ✕   │
├─────────────────────────────────────────┤
│                                         │
│  🔧  Leaking Pipe                       │
│      [Completed] 🟢                     │
│      Jan 20, 2024                       │
│                                         │
│  Description                            │
│  Kitchen sink pipe is leaking badly     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Assigned Staff                  │   │
│  │                                 │   │
│  │  👤  Ramesh Kumar               │   │
│  │      Plumber                    │   │
│  │                                 │   │
│  │  ┌───────────────────────────┐ │   │
│  │  │ 📞 +91 98765 43210 [Call]→│ │   │
│  │  └───────────────────────────┘ │   │
│  │  ┌───────────────────────────┐ │   │
│  │  │ 💬 Chat with Ramesh [Chat]│ │   │
│  │  └───────────────────────────┘ │   │
│  │  ┌───────────────────────────┐ │   │
│  │  │ ✉️ ramesh@example.com     │ │   │
│  │  └───────────────────────────┘ │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Timeline                        │   │
│  │                                 │   │
│  │ ● Complaint Submitted           │   │
│  │   Jan 20, 10:00 AM              │   │
│  │                                 │   │
│  │ ● Assigned to Ramesh Kumar      │   │
│  │   Jan 20, 11:30 AM              │   │
│  │                                 │   │
│  │ ● Work in Progress              │   │
│  │   Jan 20, 2:00 PM               │   │
│  │                                 │   │
│  │ ● Work Completed                │   │
│  │   Jan 21, 10:00 AM              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ ✅ Work completed successfully  │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘

Legend:
● = Done (Green)
```

## Staff Contact Actions

### Call Staff Flow

```
User taps phone row
        ↓
┌─────────────────────┐
│  Call Staff Member  │
│                     │
│ Do you want to call │
│ +91 98765 43210?    │
│                     │
│ [Cancel]   [Call]   │
└─────────────────────┘
        ↓
   User confirms
        ↓
  Phone dialer opens
```

### Chat Flow

```
User taps chat row
        ↓
   Modal closes
        ↓
Navigate to chat screen
        ↓
┌─────────────────────┐
│ Chat with Ramesh    │
├─────────────────────┤
│                     │
│ [Chat messages]     │
│                     │
│ [Type message...]   │
└─────────────────────┘
```

## Status Badge Colors

```
┌──────────┐
│ Pending  │  Background: #FEE2E2 (Light Red)
└──────────┘  Text: #DC2626 (Red)

┌──────────────┐
│ In Progress  │  Background: #FFF3E8 (Light Orange)
└──────────────┘  Text: #FF7A00 (Orange)

┌───────────┐
│ Completed │  Background: #E8FDEB (Light Green)
└───────────┘  Text: #10B981 (Green)
```

## Timeline Dots

```
●  Done        - #1DB954 (Green)
◐  In Progress - #FF7A00 (Orange)
○  Pending     - #C4C4C4 (Gray)
```

## Quick Reference

### What Users See

| Status | Badge | Staff Details | Actions | Timeline |
|--------|-------|---------------|---------|----------|
| Pending | 🔴 Red | None | Info box | 2 steps |
| In Progress | 🟠 Orange | Full + Call/Chat | Chat button | 4 steps |
| Completed | 🟢 Green | Full + Call/Chat | Success msg | 4 steps (all done) |

### User Actions by Status

#### Pending
- ✅ View details
- ✅ Delete complaint
- ❌ Cannot call staff (not assigned)
- ❌ Cannot chat (not assigned)

#### In Progress
- ✅ View details
- ✅ Call staff
- ✅ Chat with staff
- ✅ View timeline
- ❌ Cannot delete

#### Completed
- ✅ View details
- ✅ Call staff (if needed)
- ✅ Chat with staff (if needed)
- ✅ View full timeline
- ❌ Cannot delete

## Mobile Screen Flow

```
Complaints List
      ↓
Tap complaint
      ↓
┌─────────────────┐
│ Detail Modal    │
│                 │
│ [Status Badge]  │
│ [Description]   │
│ [Staff Details] │ ← Call/Chat buttons
│ [Timeline]      │
│ [CTA Button]    │
└─────────────────┘
      ↓
Tap Call → Confirmation → Phone Dialer
      OR
Tap Chat → Chat Screen
```

## Color Scheme

```
Primary Blue:    #2563EB
Pending Red:     #DC2626
In Progress:     #FF7A00
Completed Green: #10B981
Background:      #F7F7F7
Card White:      #FFFFFF
Text Dark:       #111111
Text Muted:      #7A7A7A
```

## Summary

✅ **3 Status States** - Each with unique UI
✅ **Dynamic Timeline** - Shows progress
✅ **Staff Contact** - Call & Chat buttons
✅ **Status-based CTA** - Appropriate actions
✅ **Color-coded** - Easy to understand
✅ **Professional** - Clean, modern design

Users can now easily track complaint progress and contact staff at any stage!
