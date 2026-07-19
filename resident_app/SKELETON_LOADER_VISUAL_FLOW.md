# Skeleton Loader - Visual Flow Diagram

## Loading Flow Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER OPENS SCREEN                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              SKELETON LOADER APPEARS                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  │
│  │                                                          │  │
│  │ Shimmer Animation: ════════════════════════════════════ │  │
│  │ Duration: 1500ms (repeating)                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│ Status: Fetching data from Firestore...                        │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
                    (1-3 seconds)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              DATA RECEIVED FROM FIRESTORE                       │
│              SKELETON FADES OUT                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              ACTUAL CONTENT APPEARS                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 👤 John Doe                                              │  │
│  │ Flat 101                                                 │  │
│  │ ─────────────────────────────────────────────────────── │  │
│  │ 👤 Jane Smith                                            │  │
│  │ Flat 102                                                 │  │
│  │ ─────────────────────────────────────────────────────── │  │
│  │ 👤 Mike Johnson                                          │  │
│  │ Flat 103                                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│ Status: Ready to interact                                       │
└─────────────────────────────────────────────────────────────────┘
```

## Admin Dashboard Loading Flow

```
ADMIN DASHBOARD SCREEN
│
├─ Header (Static)
│
├─ Statistics Section
│  ├─ Total Residents Card
│  │  ├─ [SKELETON] → [ACTUAL: 45]
│  │  └─ Duration: 1-2s
│  │
│  ├─ Total Flats Card
│  │  ├─ [SKELETON] → [ACTUAL: 20]
│  │  └─ Duration: 1-2s
│  │
│  ├─ Pending Visitors Card
│  │  ├─ [SKELETON] → [ACTUAL: 3]
│  │  └─ Duration: 1-2s
│  │
│  ├─ Pending Complaints Card
│  │  ├─ [SKELETON] → [ACTUAL: 5]
│  │  └─ Duration: 1-2s
│  │
│  └─ Monthly Collection Card
│     ├─ [SKELETON] → [ACTUAL: ₹45,000]
│     └─ Duration: 1-2s
│
└─ Quick Actions (Static)
```

## Chat Screen Loading Flow

```
CHAT CONVERSATION SCREEN
│
├─ Header (Static)
│
├─ Message List
│  ├─ User ID Loading
│  │  ├─ [SKELETON CHAT LOADER]
│  │  └─ Duration: 0.5-1s
│  │
│  └─ Messages Loading
│     ├─ [SKELETON CHAT LOADER]
│     │  ├─ Header Skeleton
│     │  ├─ Message Bubble Skeletons (5 items)
│     │  └─ Alternating left/right layout
│     │
│     └─ [ACTUAL MESSAGES]
│        ├─ Message 1 (Received)
│        ├─ Message 2 (Sent)
│        ├─ Message 3 (Received)
│        └─ Duration: 1-3s
│
└─ Message Composer (Static)
```

## Messages Screen Loading Flow

```
MESSAGES SCREEN
│
├─ Header (Static)
│
├─ Segmented Control (Static)
│  ├─ Chats Tab
│  └─ Requests Tab
│
├─ CHATS TAB
│  ├─ [SKELETON LIST LOADER]
│  │  ├─ Skeleton Item 1
│  │  ├─ Skeleton Item 2
│  │  ├─ Skeleton Item 3
│  │  ├─ Skeleton Item 4
│  │  └─ Skeleton Item 5
│  │
│  └─ [ACTUAL CHATS]
│     ├─ Admin Chat Card (Green)
│     ├─ Chat 1 (John Doe)
│     ├─ Chat 2 (Jane Smith)
│     └─ Duration: 1-2s
│
└─ REQUESTS TAB
   ├─ [SKELETON LIST LOADER]
   │  ├─ Skeleton Item 1
   │  ├─ Skeleton Item 2
   │  ├─ Skeleton Item 3
   │  ├─ Skeleton Item 4
   │  └─ Skeleton Item 5
   │
   └─ [ACTUAL REQUESTS]
      ├─ Request 1 (Mike Johnson)
      ├─ Request 2 (Sarah Lee)
      └─ Duration: 1-2s
```

## Shimmer Animation Detail

```
Frame 1 (0ms):
┌─────────────────────────────────────────┐
│ ▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────┘

Frame 2 (375ms):
┌─────────────────────────────────────────┐
│ ░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────┘

Frame 3 (750ms):
┌─────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────┘

Frame 4 (1125ms):
┌─────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░ │
└─────────────────────────────────────────┘

Frame 5 (1500ms):
┌─────────────────────────────────────────┐
│ ▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────┘
(Loop repeats)

Legend:
▓ = Dark gray (#E0E0E0)
░ = Light gray (#F5F5F5)
```

## State Transitions

```
┌──────────────┐
│   INITIAL    │
│   STATE      │
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│  LOADING STATE           │
│  ┌────────────────────┐  │
│  │ SKELETON LOADER    │  │
│  │ (Shimmer animates) │  │
│  └────────────────────┘  │
└──────┬───────────────────┘
       │
       ├─ Success ──────────┐
       │                    │
       ├─ Error ────────────┤
       │                    │
       └─ Empty ────────────┤
                            │
                            ▼
                    ┌──────────────────────────┐
                    │  FINAL STATE             │
                    │  ┌────────────────────┐  │
                    │  │ ACTUAL CONTENT     │  │
                    │  │ or ERROR/EMPTY     │  │
                    │  └────────────────────┘  │
                    └──────────────────────────┘
```

## Performance Timeline

```
Time (ms)    Event                          Visual State
─────────────────────────────────────────────────────────
0            Screen opens                   [SKELETON]
100          Firestore query starts         [SKELETON]
500          Network latency                [SKELETON]
1000         Data received                  [SKELETON]
1200         Content rendering              [FADE OUT]
1300         Actual content visible         [ACTUAL]
1500         User can interact              [READY]
```

## Color Scheme

```
Skeleton Colors:
├─ Dark Gray:   #E0E0E0 (RGB: 224, 224, 224)
├─ Light Gray:  #F5F5F5 (RGB: 245, 245, 245)
└─ Gradient:    Dark → Light → Dark

Content Colors:
├─ Primary:     #2563EB (Blue)
├─ Text:        #111827 (Dark)
├─ Secondary:   #6B7280 (Gray)
└─ Background:  #F8F9FA (Light)
```

## User Experience Timeline

```
User Action          App Response              User Perception
─────────────────────────────────────────────────────────────
Tap screen           Skeleton appears         "App is loading"
                     (1-2 seconds)
                     
                     Content appears          "Data loaded fast"
                     
                     User interacts           "Smooth experience"
```

## Summary

The skeleton loader provides a smooth, professional loading experience:

✅ **Immediate Feedback**: Skeleton appears instantly
✅ **Visual Continuity**: Matches content layout
✅ **Smooth Animation**: Shimmer effect is pleasant
✅ **Professional Feel**: Modern loading pattern
✅ **Performance**: Lightweight and efficient
✅ **Accessibility**: Clear loading indication

Total loading time: **1-3 seconds** (depending on network)
Animation smoothness: **60fps** on most devices
