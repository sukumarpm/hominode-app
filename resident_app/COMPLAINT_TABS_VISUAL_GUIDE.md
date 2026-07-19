# Complaint Tabs - Visual Guide

## Tab Interface

### Active Tab (Selected)
```
┌─────────────────────────────────────────┐
│ ┌─────────────────┬─────────────────┐   │
│ │  📋 Active  (3) │  ⟲ History  (5)│   │
│ │   [BLUE BG]     │   [GRAY TEXT]   │   │
│ └─────────────────┴─────────────────┘   │
│                                         │
│  ┌──────┐  ┌──────────┐  ┌──────────┐  │
│  │  1   │  │    2     │  │    0     │  │
│  │Pending│ │In Progress│ │Completed │  │
│  └──────┘  └──────────┘  └──────────┘  │
│                                         │
│  Active Complaints                      │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🔧 Leaking Pipe    [Pending] 🔴│   │
│  │ Kitchen sink...                 │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ ⚡ Power Issue  [In Progress] 🟠│   │
│  │ Bedroom lights...               │   │
│  │ 👤 Ramesh • +91 123...          │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🚰 Water Problem   [Pending] 🔴│   │
│  │ Bathroom tap...                 │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### History Tab (Selected)
```
┌─────────────────────────────────────────┐
│ ┌─────────────────┬─────────────────┐   │
│ │  📋 Active  (3) │  ⟲ History  (5)│   │
│ │   [GRAY TEXT]   │   [BLUE BG]     │   │
│ └─────────────────┴─────────────────┘   │
│                                         │
│  Complaint History                      │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🔧 Fixed Pipe   [Completed] 🟢 │   │
│  │ Kitchen sink fixed              │   │
│  │ 👤 Ramesh • Feb 19, 2026        │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ ⚡ Light Fixed  [Completed] 🟢 │   │
│  │ Bedroom lights working          │   │
│  │ 👤 Suresh • Feb 18, 2026        │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🚰 Tap Repaired [Completed] 🟢 │   │
│  │ Bathroom tap fixed              │   │
│  │ 👤 Vijay • Feb 17, 2026         │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Status Flow Diagram

```
┌──────────────────────────────────────────┐
│         CREATE COMPLAINT                 │
└────────────┬─────────────────────────────┘
             ↓
┌──────────────────────────────────────────┐
│  STATUS: PENDING (Red)                   │
│  TAB: Active                             │
│  ACTIONS: View, Delete                   │
└────────────┬─────────────────────────────┘
             ↓
      Admin Assigns Staff
             ↓
┌──────────────────────────────────────────┐
│  STATUS: IN PROGRESS (Orange)            │
│  TAB: Active                             │
│  ACTIONS: View, Call, Chat               │
└────────────┬─────────────────────────────┘
             ↓
      Admin Marks Resolved
             ↓
┌──────────────────────────────────────────┐
│  STATUS: COMPLETED (Green)               │
│  TAB: History                            │
│  ACTIONS: View Only                      │
└──────────────────────────────────────────┘
```

## Tab Switching Animation

```
User taps History tab
        ↓
┌─────────────────────┐
│ Active → History    │
│ [Fade transition]   │
└─────────────────────┘
        ↓
Content updates
        ↓
Shows completed complaints
```

## Empty States

### Active Tab - No Complaints
```
┌─────────────────────────────────┐
│                                 │
│                                 │
│         ✓                       │
│      (64px icon)                │
│                                 │
│   No active complaints          │
│   (18px, bold, gray)            │
│                                 │
│   Create a new complaint to     │
│   get started                   │
│   (14px, gray)                  │
│                                 │
│                                 │
└─────────────────────────────────┘
```

### History Tab - No History
```
┌─────────────────────────────────┐
│                                 │
│                                 │
│         ⟲                       │
│      (64px icon)                │
│                                 │
│   No complaint history          │
│   (18px, bold, gray)            │
│                                 │
│   Completed complaints will     │
│   appear here                   │
│   (14px, gray)                  │
│                                 │
│                                 │
└─────────────────────────────────┘
```

## Tab Button States

### Selected (Active)
```
┌─────────────────┐
│   📋 (white)    │
│   Active        │
│   (white, bold) │
│      3          │
│   (white, 12px) │
└─────────────────┘
Background: #2563EB (Blue)
```

### Unselected (History)
```
┌─────────────────┐
│   ⟲ (gray)      │
│   History       │
│   (gray, bold)  │
│      5          │
│   (gray, 12px)  │
└─────────────────┘
Background: Transparent
```

## Complaint Card Variations

### Active - Pending
```
┌─────────────────────────────────┐
│ 🔧  Leaking Pipe   [Pending] 🔴│
│     Kitchen sink is leaking     │
│     Plumbing • Feb 20, 2026     │
│                                 │
│     (No staff assigned)         │
└─────────────────────────────────┘
```

### Active - In Progress
```
┌─────────────────────────────────┐
│ 🔧  Leaking Pipe [In Progress]🟠│
│     Kitchen sink is leaking     │
│     Plumbing • Feb 20, 2026     │
│                                 │
│ ┌─────────────────────────────┐│
│ │ 👤 Ramesh Kumar             ││
│ │    Plumber • +91 98765...   ││
│ └─────────────────────────────┘│
└─────────────────────────────────┘
```

### History - Completed
```
┌─────────────────────────────────┐
│ 🔧  Leaking Pipe  [Completed] 🟢│
│     Kitchen sink fixed          │
│     Plumbing • Feb 20, 2026     │
│                                 │
│ ┌─────────────────────────────┐│
│ │ 👤 Ramesh Kumar             ││
│ │    Plumber • +91 98765...   ││
│ └─────────────────────────────┘│
└─────────────────────────────────┘
```

## User Journey

### Journey 1: New Complaint
```
1. User opens app
   ↓
2. Taps "+" button
   ↓
3. Creates complaint
   ↓
4. Appears in Active tab
   ↓
5. Shows "Pending" status
```

### Journey 2: Track Progress
```
1. User opens Active tab
   ↓
2. Sees "In Progress" complaint
   ↓
3. Taps to view details
   ↓
4. Sees staff info
   ↓
5. Can call or chat
```

### Journey 3: View History
```
1. User taps History tab
   ↓
2. Sees completed complaints
   ↓
3. Taps to view details
   ↓
4. Sees resolution info
   ↓
5. Reviews past work
```

## Color Scheme

### Tab Colors
```
Selected:
- Background: #2563EB (Blue)
- Text: #FFFFFF (White)
- Icon: #FFFFFF (White)

Unselected:
- Background: Transparent
- Text: #9CA3AF (Gray)
- Icon: #9CA3AF (Gray)
```

### Status Colors
```
Pending:
- Badge: #FEE2E2 (Light Red)
- Text: #DC2626 (Red)

In Progress:
- Badge: #FFF3E8 (Light Orange)
- Text: #FF7A00 (Orange)

Completed:
- Badge: #E8FDEB (Light Green)
- Text: #10B981 (Green)
```

## Quick Reference

| Tab | Shows | Status Summary | Can Create | Can Delete |
|-----|-------|----------------|------------|------------|
| Active | Pending + In Progress | ✅ Yes | ✅ Yes | ✅ Pending only |
| History | Completed | ❌ No | ✅ Yes | ❌ No |

| Status | Tab | Badge | Staff Details | Actions |
|--------|-----|-------|---------------|---------|
| Pending | Active | 🔴 Red | ❌ No | View, Delete |
| In Progress | Active | 🟠 Orange | ✅ Yes | View, Call, Chat |
| Completed | History | 🟢 Green | ✅ Yes | View only |

## Summary

✅ **Two tabs** - Active and History
✅ **Auto-organization** - Complaints move based on status
✅ **Real-time updates** - Automatic refresh
✅ **Clear visual design** - Easy to understand
✅ **Proper workflow** - From creation to completion

Users can now easily manage active complaints and review their history!
