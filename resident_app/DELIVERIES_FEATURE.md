# Deliveries Tab Feature

## Overview
The Deliveries tab in the Visitor Management screen displays package deliveries with a simplified card layout, showing delivery status and timing information.

## Features Implemented
✅ Purple-tinted delivery icon (shopping bag)
✅ Delivery name and subtitle (time or expected time)
✅ Status chips (Received = green, Pending = pink)
✅ Simplified card layout (no action buttons)
✅ Clean, minimal design
✅ Exact color matching from reference design

## Delivery Card Components

### 1. Icon Container
- **Size:** 48x48px
- **Background:** #F6EDFF (light purple tint)
- **Icon:** Shopping bag outline
- **Icon Color:** #8B5CF6 (purple)
- **Border Radius:** 12px

### 2. Delivery Details
- **Title:** Delivery name (e.g., "Amazon Delivery", "Swiggy Delivery")
  - Font: 16pt SemiBold
  - Color: #1E293B (dark text)
- **Subtitle:** Time information
  - Font: 13pt Regular
  - Color: #94A3B8 (gray text)
  - Examples: "2 hours ago", "Expected 6:00 PM"

### 3. Status Chip
Two variants:

**Received Status:**
- Background: #E6FBEE (light green)
- Text: "Received"
- Text Color: #0DA85E (green)
- Font: 12pt SemiBold

**Pending Status:**
- Background: #FFDCE6 (light pink)
- Text: "Pending"
- Text Color: #D2002F (red)
- Font: 12pt SemiBold

## Card Styling
- **Background:** White (#FFFFFF)
- **Border:** 1px solid #F1F5F9 (light gray)
- **Border Radius:** 16px
- **Padding:** 16px all around
- **Shadow:** rgba(0,0,0,0.05) with 10px blur, 2px offset
- **Spacing between cards:** 16px

## Sample Data

### Delivery 1 - Received
```dart
_buildDeliveryCard(
  title: 'Amazon Delivery',
  subtitle: '2 hours ago',
  isReceived: true,
)
```

### Delivery 2 - Pending
```dart
_buildDeliveryCard(
  title: 'Swiggy Delivery',
  subtitle: 'Expected 6:00 PM',
  isReceived: false,
)
```

## Color Constants

```dart
// Delivery icon background
const kDeliveryIconBg = Color(0xFFF6EDFF);

// Delivery icon color
const kDeliveryIconColor = Color(0xFF8B5CF6);

// Received status
const kReceivedBg = Color(0xFFE6FBEE);
const kReceivedText = Color(0xFF0DA85E);

// Pending status
const kPendingBg = Color(0xFFFFDCE6);
const kPendingText = Color(0xFFD2002F);

// Card border
const kCardBorder = Color(0xFFF1F5F9);
```

## Layout Structure

```
DeliveryCard
├── Row
    ├── Icon Container (48x48)
    │   └── Shopping Bag Icon
    ├── SizedBox (12px spacing)
    ├── Expanded Column
    │   ├── Title Text
    │   ├── SizedBox (4px spacing)
    │   └── Subtitle Text
    └── Status Chip
        └── Status Text
```

## Differences from Visitor Cards

### Visitor Cards (Pending/Approved tabs)
- Circular avatar with initial
- Visitor name and visit type
- Time with clock icon
- Action buttons (Approve/Reject or View QR Pass)
- More detailed information

### Delivery Cards (Deliveries tab)
- Square icon container with delivery icon
- Delivery service name
- Simple time/expected time text
- Status chip only (no action buttons)
- Simplified, minimal design

## Integration Notes

### Adding New Deliveries
To add more delivery items, simply add more `_buildDeliveryCard()` calls in the Deliveries tab content:

```dart
Column(
  children: [
    _buildDeliveryCard(
      title: 'Amazon Delivery',
      subtitle: '2 hours ago',
      isReceived: true,
    ),
    const SizedBox(height: 16),
    _buildDeliveryCard(
      title: 'Swiggy Delivery',
      subtitle: 'Expected 6:00 PM',
      isReceived: false,
    ),
    const SizedBox(height: 16),
    _buildDeliveryCard(
      title: 'Flipkart Delivery',
      subtitle: 'Expected Tomorrow 10:00 AM',
      isReceived: false,
    ),
  ],
)
```

### Dynamic Data Integration
For backend integration, map delivery data to the card:

```dart
// Example with dynamic data
ListView.separated(
  itemCount: deliveries.length,
  separatorBuilder: (context, index) => const SizedBox(height: 16),
  itemBuilder: (context, index) {
    final delivery = deliveries[index];
    return _buildDeliveryCard(
      title: delivery.serviceName,
      subtitle: delivery.isReceived 
          ? delivery.receivedTime 
          : 'Expected ${delivery.expectedTime}',
      isReceived: delivery.status == 'received',
    );
  },
)
```

## Future Enhancements
- Add delivery tracking number
- Add delivery person details
- Add photo of delivered package
- Add signature capture
- Add delivery instructions
- Add notification when delivery arrives
- Add delivery history filter
- Add search functionality
- Add delivery details screen on tap
- Add OTP verification for delivery

## Accessibility
- Icon container has sufficient size (48x48px)
- Text contrast meets WCAG standards
- Status chips are clearly distinguishable
- Card tap area is large enough (minimum 44x44px)

## Testing Checklist
- [ ] Deliveries tab displays correctly
- [ ] Delivery cards show proper icon and colors
- [ ] Received status shows green chip
- [ ] Pending status shows pink chip
- [ ] Card spacing is consistent
- [ ] Text is readable and properly sized
- [ ] Icons display correctly
- [ ] Card shadows render properly
- [ ] Layout is responsive
- [ ] Tab switching works smoothly
