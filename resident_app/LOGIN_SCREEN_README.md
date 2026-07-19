# Login Screen - Pixel Perfect Implementation

## Overview
A pixel-perfect Flutter implementation of the login screen matching the provided design specifications for iPhone 13 (390px width).

## Features

### Design Specifications
- ✅ Gradient blue background (#2F80ED → #2563EB)
- ✅ Centered welcome text with proper typography
- ✅ Large rounded white container card (28px radius)
- ✅ Mobile number input field with light grey background
- ✅ Primary "Send OTP" button
- ✅ "Don't have an account? Register" link
- ✅ Pixel-perfect spacing and padding
- ✅ iOS Cupertino feel

### Color Palette
```dart
Background Gradient Top:    #2F80ED
Background Gradient Bottom:  #2563EB
White Card:                 #FFFFFF
Input Field Background:     #F5F5F5
Input Border:               #E5E7EB
Primary Button Blue:        #2563EB
Primary Text:               #FFFFFF
Title Text:                 #FFFFFF
Subtitle Text:              #F0F0F0
Card Label Text:            #111111
Hint Text:                  #A3A3A3
Link Blue:                  #2563EB
```

### Typography
```dart
Title ("Welcome Back"):     28pt, Bold, White
Subtitle:                   16pt, Regular, White
Form Heading ("Login"):     22pt, Semibold, Black
Label ("Mobile Number"):    16pt, Medium, Black
Hint Text:                  15pt, Regular, Grey
Button Text:                17pt, Semibold, White
Footer Link:                15pt, Medium, Blue
```

### Layout Specifications
- Card corner radius: 28px
- Card horizontal padding: 28px
- Card vertical padding: 32px
- Input field corner radius: 12px
- Button height: 54px
- Button corner radius: 12px

## File Structure

```
lib/
├── login_demo.dart                          # Demo app entry point
└── src/
    ├── screens/
    │   └── login_screen.dart                # Main login screen
    └── components/
        ├── auth_text_field.dart             # Reusable text field
        └── auth_primary_button.dart         # Reusable button
```

## Components

### 1. LoginScreen
Main screen with gradient background and login card.

**Features:**
- Gradient background
- Centered content
- Responsive layout
- Keyboard handling
- Form validation ready

### 2. AuthTextField
Reusable text input component.

**Props:**
- `controller`: TextEditingController
- `hintText`: String
- `keyboardType`: TextInputType
- `obscureText`: bool (for passwords)
- `suffixIcon`: Widget (optional)
- `validator`: Function (optional)

**Styling:**
- Light grey background (#F5F5F5)
- Border: #E5E7EB
- Corner radius: 12px
- Padding: 16px horizontal

### 3. AuthPrimaryButton
Reusable primary action button.

**Props:**
- `text`: String
- `onPressed`: VoidCallback
- `isLoading`: bool
- `isEnabled`: bool

**Styling:**
- Background: #2563EB
- Height: 54px
- Corner radius: 12px
- White text, 17pt, Semibold

## Usage

### Run Demo
```bash
# Navigate to project directory
cd resident_app

# Run the login demo
flutter run -t lib/login_demo.dart
```

### Integration into Main App
```dart
import 'package:resident_app/src/screens/login_screen.dart';

// In your router or navigation
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const LoginScreen()),
);
```

### Customize Components
```dart
// Custom text field
AuthTextField(
  controller: _controller,
  hintText: 'Enter email',
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    if (value?.isEmpty ?? true) {
      return 'Email is required';
    }
    return null;
  },
)

// Custom button
AuthPrimaryButton(
  text: 'Login',
  onPressed: () => _handleLogin(),
  isLoading: _isLoading,
)
```

## Responsive Design

The screen is optimized for iPhone 13 (390px width) but adapts to different screen sizes:

- Uses `SafeArea` for notch handling
- `SingleChildScrollView` for keyboard overflow
- Percentage-based spacing
- Flexible padding

## Animations (Optional Enhancement)

Add subtle animations for better UX:

```dart
// Card fade-in animation
AnimatedOpacity(
  opacity: _visible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 400),
  child: _buildLoginCard(),
)

// Slide-up animation
AnimatedSlide(
  offset: _visible ? Offset.zero : const Offset(0, 0.1),
  duration: const Duration(milliseconds: 400),
  curve: Curves.easeOut,
  child: _buildLoginCard(),
)
```

## Testing

### Manual Testing Checklist
- [ ] Screen displays correctly on iPhone 13
- [ ] Gradient background renders properly
- [ ] Text is readable and properly sized
- [ ] Input field accepts text input
- [ ] Button responds to taps
- [ ] Register link is tappable
- [ ] Keyboard doesn't overlap content
- [ ] Status bar is light colored

### Test on Multiple Devices
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id> -t lib/login_demo.dart
```

## Next Steps

### 1. Add OTP Screen
Create a matching OTP verification screen:
- 6-digit OTP input
- Resend OTP functionality
- Timer countdown
- Auto-submit on completion

### 2. Add Registration Screen
Create registration flow:
- Name input
- Email input
- Mobile number
- Password fields
- Terms & conditions checkbox

### 3. Add Form Validation
Implement proper validation:
- Mobile number format (10 digits)
- Email format validation
- Required field checks
- Error message display

### 4. Add Backend Integration
Connect to authentication API:
- Send OTP endpoint
- Verify OTP endpoint
- Error handling
- Loading states

### 5. Add State Management
Implement state management (Provider/Riverpod/Bloc):
- Authentication state
- Form state
- Loading states
- Error states

## Design Notes

### Matching iOS Feel
- Uses SF Pro Display font (iOS system font)
- Bouncing scroll physics
- Light status bar
- Smooth animations
- Clean, minimal design

### Accessibility
- Proper contrast ratios
- Readable font sizes
- Touch target sizes (44x44 minimum)
- Screen reader support ready

### Performance
- Minimal widget rebuilds
- Efficient text controllers
- Optimized gradient rendering
- Fast initial load

## Troubleshooting

### Issue: Keyboard overlaps content
**Solution:** Wrapped in `SingleChildScrollView` with proper padding

### Issue: Status bar icons not visible
**Solution:** Using `SystemUiOverlayStyle.light` for light icons

### Issue: Card shadow not visible
**Solution:** Subtle shadow with low opacity (0.08)

### Issue: Text looks different from design
**Solution:** Exact font sizes and weights specified

## Credits

Design specifications provided by client.
Implementation follows Flutter best practices and Material Design guidelines.

---

**Status**: ✅ Pixel-perfect implementation complete
**Device Target**: iPhone 13 (390px width)
**Flutter Version**: 3.35.3+
**Last Updated**: 2025-01-20
