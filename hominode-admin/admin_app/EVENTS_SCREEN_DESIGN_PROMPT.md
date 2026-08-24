# Events & Announcements Screen - Kiro AI Design Prompt

## 📌 TASK
Generate a Flutter UI screen for an Admin/Management App named:
**EventsAndAnnouncementsScreen**

Use the attached reference image exactly as the UI source. The output must generate Flutter code with the same UI, spacing, colors, and behavior that matches the existing admin app design system.

## 📱 SCREEN PURPOSE
This screen allows admins to:
- View community Events
- Switch between Events and Announcements
- Create new events
- Track RSVP progress
- See event status (Upcoming)

## 🎨 UI STYLE (STRICT REQUIREMENTS)
- Clean, modern Material-style mobile UI
- iOS-like polish with smooth animations
- Rounded corners (12–16px)
- Soft shadows and light borders
- Plenty of white space
- Card-based layout
- Consistent with existing admin app screens

## 🎨 COLOR SYSTEM (MUST MATCH EXISTING APP)

### Primary Colors
```dart
Header Gradient: LinearGradient(
  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
Primary Blue: Color(0xFF2563EB)
Background: Color(0xFFF7F8FA)
Card Background: Color(0xFFFFFFFF)
```

### UI Element Colors
```dart
Border/Divider: Color(0xFFE5E7EB)
Primary Text: Color(0xFF111827)
Secondary Text: Color(0xFF6B7280)
Tag Border (Festival/Health): Color(0xFF2563EB)
Upcoming Badge BG: Color(0xFFE0EBFF)
Upcoming Badge Text: Color(0xFF2563EB)
Progress Bar Active: Color(0xFF2563EB)
Progress Bar Inactive: Color(0xFFE5E7EB)
```

### Status Colors
```dart
Success Green: Color(0xFF10B981)
Warning Orange: Color(0xFFF59E0B)
Error Red: Color(0xFFEF4444)
Purple Accent: Color(0xFF8B5CF6)
```

## ✍️ TYPOGRAPHY (CONSISTENT WITH APP)
```dart
App Bar Title: 18sp, FontWeight.w600, Colors.white
Section Title: 18sp, FontWeight.w700, Color(0xFF111827)
Event Title: 16sp, FontWeight.w600, Color(0xFF111827)
Description: 14sp, FontWeight.w400, Color(0xFF6B7280)
Meta Text (Date/Time/Location): 14sp, FontWeight.w500, Color(0xFF6B7280)
Button Text: 16sp, FontWeight.w600, Colors.white
RSVP Text: 14sp, FontWeight.w500, Color(0xFF6B7280)
Badge Text: 12sp, FontWeight.w600
Tag Text: 12sp, FontWeight.w500
```

## 🧱 LAYOUT STRUCTURE

### 1️⃣ Standard Header (Use Existing Component)
```dart
// Use StandardHeader widget from existing app
StandardHeader(
  title: 'Events & Announcements',
  // Matches existing blue gradient design
)
```

### 2️⃣ Section Header
```dart
Container(
  padding: EdgeInsets.all(16),
  child: Text(
    'Manage community activities',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF6B7280),
    ),
  ),
)
```

### 3️⃣ Tab Switcher (Segmented Control)
```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: 16),
  padding: EdgeInsets.all(4),
  decoration: BoxDecoration(
    color: Color(0xFFF3F4F6),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      // Events Tab (ACTIVE)
      Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text('Events', textAlign: TextAlign.center),
        ),
      ),
      // Announcements Tab (INACTIVE)
      Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Announcements', textAlign: TextAlign.center),
        ),
      ),
    ],
  ),
)
```

### 4️⃣ Primary Action Button
```dart
Container(
  width: double.infinity,
  margin: EdgeInsets.all(16),
  child: ElevatedButton(
    onPressed: () {
      // Navigate to create event screen
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF2563EB),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(vertical: 16),
    ),
    child: Text(
      'Create Event',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
)
```

### 5️⃣ Event Cards (Scrollable List)
Each event card contains:
- **Top Row**: Event Title (Left) + Status Badge (Right): "Upcoming"
- **Category Tag**: Outlined pill (Festival / Health)
- **Description**: Short grey description text
- **Event Details Row**: 📅 Date, ⏰ Time, 📍 Location
- **RSVP Section**: Text "45 / 248 RSVP" + Horizontal progress bar

## 📦 EVENT CARD EXAMPLE DATA (USE EXACTLY)

### Event 1
```dart
EventEntry(
  id: 'evt_001',
  title: 'Diwali Celebration 2025',
  category: 'Festival',
  description: 'Join us for a grand Diwali celebration with cultural programs, dinner, and fireworks.',
  date: DateTime(2025, 11, 12),
  time: '6:00 PM',
  location: 'Community Hall',
  rsvpCount: 45,
  totalCapacity: 248,
  status: 'Upcoming',
)
```

### Event 2
```dart
EventEntry(
  id: 'evt_002',
  title: 'Yoga & Wellness Workshop',
  category: 'Health',
  description: 'Free yoga and meditation session for all residents.',
  date: DateTime(2025, 11, 12),
  time: '6:00 PM',
  location: 'Rooftop Garden',
  rsvpCount: 50,
  totalCapacity: 248,
  status: 'Upcoming',
)
```

### Event 3 (Additional)
```dart
EventEntry(
  id: 'evt_003',
  title: 'Yoga & Wellness Workshop',
  category: 'Health',
  description: 'Free yoga and meditation session for all residents.',
  date: DateTime(2025, 11, 12),
  time: '6:00 PM',
  location: 'Rooftop Garden',
  rsvpCount: 50,
  totalCapacity: 248,
  status: 'Upcoming',
)
```

## 🔄 INTERACTIONS (LOGIC NOTES)
```dart
// Tab switch toggles content (Events / Announcements)
void _switchTab(String tab) {
  setState(() {
    _selectedTab = tab;
  });
}

// Create Event button navigates to event creation screen
void _createEvent() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CreateEventScreen(),
    ),
  );
}

// Cards are tappable (future detail screen)
void _viewEventDetails(EventEntry event) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EventDetailScreen(event: event),
    ),
  );
}

// RSVP progress dynamically fills based on percentage
double _getRsvpProgress(int current, int total) {
  return current / total;
}
```

## 🧩 COMPONENTS TO CREATE

### EventCardWidget
```dart
class EventCardWidget extends StatelessWidget {
  final EventEntry event;
  final VoidCallback? onTap;
  
  const EventCardWidget({
    Key? key,
    required this.event,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event title and status badge
          // Category tag
          // Description
          // Event details (date, time, location)
          // RSVP progress
        ],
      ),
    );
  }
}
```

### SegmentedTabSwitcher
```dart
class SegmentedTabSwitcher extends StatelessWidget {
  final String selectedTab;
  final Function(String) onTabChanged;
  
  const SegmentedTabSwitcher({
    Key? key,
    required this.selectedTab,
    required this.onTabChanged,
  }) : super(key: key);
}
```

### RsvpProgressBar
```dart
class RsvpProgressBar extends StatelessWidget {
  final int current;
  final int total;
  
  const RsvpProgressBar({
    Key? key,
    required this.current,
    required this.total,
  }) : super(key: key);
}
```

### StatusBadge
```dart
class StatusBadge extends StatelessWidget {
  final String status;
  
  const StatusBadge({
    Key? key,
    required this.status,
  }) : super(key: key);
}
```

## 🛠 FLUTTER REQUIREMENTS
- Use Scaffold, AppBar, Container, ListView
- No external packages
- Clean widget separation
- Responsive for mobile
- Comment logic placeholders clearly
- Follow existing app architecture patterns
- Use consistent naming conventions
- Implement proper state management

## 📱 NAVIGATION INTEGRATION
```dart
// Add to existing bottom navigation
bottomNavigationBar: StandardBottomNav(
  selectedIndex: 4, // Events tab index
),

// Add to dashboard quick access
QuickAccessCard(
  icon: Icons.event,
  title: 'Events',
  subtitle: 'Community activities',
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EventsAndAnnouncementsScreen(),
    ),
  ),
),
```

## ✅ OUTPUT EXPECTATION
✔ Pixel-perfect Flutter UI matching the reference image
✔ Same spacing, colors, and hierarchy as existing app
✔ Consistent with admin app design system
✔ Ready for backend integration
✔ Matches provided image exactly
✔ Uses existing StandardHeader component
✔ Follows established UI patterns
✔ Professional admin app appearance

## 🎯 DESIGN CONSISTENCY NOTES
- Must use the same blue gradient header as other admin screens
- Follow the same card design patterns as complaint management
- Use consistent spacing (16px containers, 12px elements, 8px gaps)
- Match the typography hierarchy of existing screens
- Implement the same shadow and border styles
- Use the established color palette throughout
- Maintain the same professional admin app aesthetic

## 📋 FINAL CHECKLIST
- [ ] Header matches StandardHeader component
- [ ] Colors match existing admin app palette
- [ ] Typography follows established hierarchy
- [ ] Spacing matches existing screens (16px, 12px, 8px)
- [ ] Cards use same shadow and border styles
- [ ] Navigation integrates with existing bottom nav
- [ ] Components are reusable and well-structured
- [ ] Code follows existing app architecture
- [ ] All interactions have proper placeholder logic
- [ ] Ready for integration with existing admin app