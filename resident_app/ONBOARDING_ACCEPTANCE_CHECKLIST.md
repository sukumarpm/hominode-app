# Onboarding Flow - Acceptance Checklist

Use this checklist to verify the onboarding implementation matches the design specifications.

## ✅ Visual Elements

### Card Design
- [ ] Large blue rounded square card displayed on each screen
- [ ] Card uses vertical gradient (top: #2563EB → bottom: #1E40AF)
- [ ] Card has soft shadow (blur: 24px, offset: 0,8px, opacity: 0.25)
- [ ] Card border radius is ~20px
- [ ] Card size is approximately 65% of screen width (~254px on iPhone 13)
- [ ] Card has subtle secondary shadow for depth

### Icons
- [ ] White icon centered in card
- [ ] Icon size is ~40% of card size
- [ ] Screen 1: Apartment/building icon
- [ ] Screen 2: People/visitors icon  
- [ ] Screen 3: Notification bell icon
- [ ] Screen 4: Shield/security icon
- [ ] Icons are clearly visible against blue gradient

### Typography
- [ ] Title font is large (34px), bold, italic
- [ ] Title has negative letter spacing (-0.5)
- [ ] Title is centered below card
- [ ] Subtitle is 15px, regular weight
- [ ] Subtitle is centered and spans two lines
- [ ] Subtitle has 1.5 line height
- [ ] Text colors match: title #111111, subtitle #666666

### Content Text
- [ ] Screen 1: "Welcome to Lyvo" + subtitle about apartment management
- [ ] Screen 2: "Visitor Management" + subtitle about pre-approving visitors
- [ ] Screen 3: "Stay Updated" + subtitle about real-time notifications
- [ ] Screen 4: "Safe & Secure" + subtitle about data protection

### Button (CTA)
- [ ] Full-width rounded button at bottom
- [ ] Button height is 56px
- [ ] Button uses same blue gradient as card
- [ ] Button border radius is 12px
- [ ] Button has shadow (blur: 12px, offset: 0,4px, opacity: 0.3)
- [ ] Button text is white, 18px, semibold
- [ ] Screens 1-3: Button says "Next"
- [ ] Screen 4: Button says "Get Started"
- [ ] Button has proper padding from screen edges (16px)

### Skip Link
- [ ] "Skip" text button in top-right corner
- [ ] Skip is within safe area (no status bar overlap)
- [ ] Skip text is 16px, medium weight, dark color
- [ ] Skip has minimum 44px touch target
- [ ] Skip is visible on all screens

### Page Indicators
- [ ] 4 dots displayed above CTA button
- [ ] Active dot is elongated (24px width) and primary blue
- [ ] Inactive dots are circular (8px) and light blue (30% opacity)
- [ ] Dots have 4px horizontal spacing
- [ ] Dots smoothly animate when changing pages

## ✅ Layout & Spacing

- [ ] SafeArea prevents status bar overlap
- [ ] Consistent top spacing across all screens
- [ ] Large vertical gap between card and title (~40px)
- [ ] Medium gap between title and subtitle (~16px)
- [ ] Large gap between content and page indicators
- [ ] Page indicators positioned 24px above button
- [ ] Button positioned 24px from bottom safe area
- [ ] Horizontal padding is 16px throughout
- [ ] Content is vertically centered

## ✅ Animations & Transitions

### Card Entrance
- [ ] Card fades in on screen load
- [ ] Card scales from 0.8 to 1.0
- [ ] Animation uses ease-out-back curve
- [ ] Animation duration is ~600ms
- [ ] Icon animates with card (not separately)

### Page Transitions
- [ ] Smooth slide animation when tapping Next (350ms)
- [ ] Current card slides left while exiting
- [ ] New card slides in from right
- [ ] Title and subtitle cross-fade during transition
- [ ] Slight parallax effect on text (8-12px vertical shift)
- [ ] Transition uses ease-out-cubic curve

### Button Interaction
- [ ] Button scales down slightly on press (0.95x)
- [ ] Scale animation is quick (200ms)
- [ ] Button returns to normal size on release
- [ ] Ripple/press effect is visible

### Background Animation
- [ ] Subtle wave motion visible behind card
- [ ] Wave animation loops continuously (~2s)
- [ ] Wave is very subtle (low opacity ~0.02)
- [ ] Animation doesn't impact performance

### Page Indicators
- [ ] Active dot smoothly expands/contracts (300ms)
- [ ] Color transition is smooth
- [ ] Animation follows page changes

## ✅ Interactions & Behavior

### Navigation
- [ ] Tapping "Next" advances to next screen
- [ ] Tapping "Get Started" navigates to home
- [ ] Swipe left advances to next screen
- [ ] Swipe right goes to previous screen
- [ ] Page changes are smooth and responsive

### Skip Functionality
- [ ] Tapping "Skip" shows confirmation snackbar
- [ ] Snackbar says "Intro skipped"
- [ ] Skip navigates directly to home/main app
- [ ] Skip works from any onboarding screen

### State Persistence
- [ ] Completing onboarding saves flag to SharedPreferences
- [ ] Flag key is 'onboarding_completed'
- [ ] Skipping also saves the flag
- [ ] App can check flag to bypass onboarding on next launch

### Edge Cases
- [ ] Can't swipe past last screen
- [ ] Can't swipe before first screen
- [ ] Animations don't break on rapid taps
- [ ] Works correctly on different screen sizes
- [ ] Handles orientation changes gracefully

## ✅ Accessibility

- [ ] Skip button has semantic label "Skip onboarding"
- [ ] Next button has semantic label "Next page"
- [ ] Get Started button has semantic label "Get Started"
- [ ] All buttons have minimum 44px touch targets
- [ ] Page indicators are semantically labeled
- [ ] Screen reader announces page changes
- [ ] Color contrast meets WCAG standards
- [ ] Focus order is logical

## ✅ Responsive Design

- [ ] Works on iPhone 13 (390px width) - primary target
- [ ] Works on smaller screens (iPhone SE)
- [ ] Works on larger screens (iPhone Pro Max)
- [ ] Works on tablets/iPads
- [ ] Card scales proportionally to screen width
- [ ] Text remains readable on all sizes
- [ ] Button remains full-width with proper padding
- [ ] Spacing adjusts appropriately

## ✅ Technical Requirements

### Code Quality
- [ ] Code is well-commented
- [ ] No hardcoded magic numbers (uses constants)
- [ ] Follows Flutter best practices
- [ ] Null-safety enabled
- [ ] No compiler warnings or errors
- [ ] Clean file structure

### Dependencies
- [ ] Only uses Flutter SDK + shared_preferences
- [ ] No unnecessary heavy packages
- [ ] pubspec.yaml is properly configured
- [ ] All imports are correct

### Performance
- [ ] Animations are smooth (60fps)
- [ ] No jank or stuttering
- [ ] Background wave doesn't impact performance
- [ ] Page transitions are fluid
- [ ] App remains responsive during animations

### Integration
- [ ] Can be easily integrated into existing app
- [ ] Routes are properly configured
- [ ] SharedPreferences integration works
- [ ] Navigation to home screen works
- [ ] Can be run standalone for testing

## ✅ Testing

- [ ] Run standalone demo: `flutter run -t lib/onboarding_main.dart`
- [ ] All 4 screens display correctly
- [ ] Can navigate through all screens
- [ ] Skip functionality works
- [ ] Get Started navigates correctly
- [ ] Swipe gestures work
- [ ] Animations play smoothly
- [ ] State persists after completion
- [ ] Can restart onboarding from home placeholder
- [ ] No console errors or warnings

## 📝 Notes

**Reference Images:**
- Screen 1: Welcome to Lyvo (apartment icon)
- Screen 2: Visitor Management (people icon)
- Screen 3: Stay Updated (bell icon)
- Screen 4: Safe & Secure (shield icon)

**Key Design Values:**
- Primary Blue: #2563EB
- Primary Blue Dark: #1E40AF
- Background: #F7F7F7
- Card size: 65% of screen width
- Card radius: 20px
- Button height: 56px
- Title size: 34px
- Subtitle size: 15px

**Animation Timings:**
- Card entrance: 600ms
- Page transition: 350ms
- Button press: 200ms
- Wave loop: 2000ms

---

## Final Sign-Off

- [ ] All visual elements match reference images
- [ ] All animations are smooth and polished
- [ ] All interactions work as expected
- [ ] Code is production-ready
- [ ] Documentation is complete
- [ ] Ready for integration into main app

**Tested By:** _________________  
**Date:** _________________  
**Status:** ⬜ Approved  ⬜ Needs Revision
