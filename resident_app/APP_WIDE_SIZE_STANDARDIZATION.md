# App-Wide Size Standardization Guide

## Overview
Standardized spacing, sizing, and typography across all screens for a more compact, consistent UI.

## Standard Spacing Values

### Page/Screen Padding
- **Standard**: 16px (was 20px in many screens)
- **Tight**: 12px (for dense content)
- **Loose**: 20px (for special cases only)

### Component Spacing
- **Between cards**: 10px (was 12px)
- **Between sections**: 16px (was 20-24px)
- **Within cards**: 12px (was 16px)
- **Small gaps**: 8px (was 10-12px)
- **Tiny gaps**: 4px (was 6-8px)

### Card/Container Padding
- **Standard card**: 12px (was 16px)
- **Large card**: 16px (was 20px)
- **Small card**: 10px (was 12px)
- **List item**: 12px (was 14-16px)

## Standard Component Sizes

### Icons
- **Large icon container**: 56x56px (was 64x64px)
- **Medium icon container**: 48x48px (was 56x56px)
- **Small icon container**: 40x40px (was 48x48px)
- **Icon size in container**: 28px (was 32px)
- **Small icon**: 20px (was 24px)

### Buttons
- **Primary button height**: 48px (was 52-56px)
- **Secondary button height**: 44px (was 48-52px)
- **Small button height**: 40px (was 44px)
- **Border radius**: 12px (was 14-16px)

### Cards
- **Border radius**: 14px (was 16px)
- **Large card radius**: 16px (was 18-20px)
- **Small card radius**: 12px (was 14px)

### Modals/Dialogs
- **Padding**: 20px (was 24px)
- **Border radius**: 20px (was 22-24px)
- **Horizontal inset**: 20px (was 24px)

## Standard Typography

### Headers
- **Screen title**: 20pt (was 22-24pt)
- **Section title**: 16pt (was 18pt)
- **Card title**: 16pt (was 17-18pt)
- **Subtitle**: 14pt (was 15-16pt)

### Body Text
- **Primary**: 14pt (was 15pt)
- **Secondary**: 13pt (was 14pt)
- **Small**: 12pt (was 13pt)
- **Tiny**: 11pt (was 12pt)

### Buttons
- **Primary button**: 16pt (was 17pt)
- **Secondary button**: 15pt (was 16pt)
- **Small button**: 14pt (was 15pt)

## Files to Update

### Screens (Priority Order)
1. ✅ Emergency SOS - DONE
2. Dashboard
3. Visitor Management
4. Maintenance & Billing
5. Events & Announcements
6. Community Wall
7. Complaints
8. Messages
9. Marketplace
10. Amenities Booking
11. Domestic Staff
12. Settings screens
13. Profile screens

### Modals/Dialogs
1. ✅ Emergency Call Dialog - DONE
2. Add Visitor Modal
3. Create Complaint Modal
4. Booking Modal
5. Add Staff Modal
6. Product Detail Modal
7. Event Detail Modal
8. All other modals

### Components
1. Primary Header
2. Cards (all types)
3. Buttons
4. Form inputs
5. Segmented controls

## Implementation Strategy

### Phase 1: Core Components (High Impact)
- Update primary_header.dart
- Update standard card components
- Update button components
- Update modal base styles

### Phase 2: Main Screens (User-Facing)
- Dashboard
- Visitor Management
- Billing
- Events
- Community

### Phase 3: Secondary Screens
- Settings
- Profile
- Marketplace
- Amenities

### Phase 4: Modals & Overlays
- All dialogs
- Bottom sheets
- Popups

## Benefits

1. **Consistency** - Same spacing everywhere
2. **Efficiency** - More content visible
3. **Modern** - Tighter, cleaner design
4. **Performance** - Less rendering overhead
5. **Maintainability** - Clear standards

## Migration Checklist

For each screen/component:
- [ ] Update page padding to 16px
- [ ] Update card padding to 12px
- [ ] Update spacing between elements
- [ ] Reduce icon sizes
- [ ] Reduce font sizes by 1-2pt
- [ ] Update button heights to 48px
- [ ] Update border radius values
- [ ] Test on device
- [ ] Verify touch targets (min 44px)
- [ ] Check text readability

---

**Status**: In Progress
**Started**: November 19, 2025
