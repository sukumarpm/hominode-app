# Notification Preferences - Usage Examples

Practical examples of how to use the notification preferences service in your app.

## Setup

Import the service:
```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
```

## Basic Usage

### Check if notifications are enabled

```dart
final notificationService = NotificationPreferencesService();

// Check push notifications
if (await notificationService.isPushEnabled()) {
  // Send push notification
}

// Check email notifications
if (await notificationService.isEmailEnabled()) {
  // Send email
}

// Check SMS notifications
if (await notificationService.isSMSEnabled()) {
  // Send SMS
}
```

### Check Do Not Disturb status

```dart
if (await notificationService.isInDoNotDisturb()) {
  print('User is in Do Not Disturb mode');
  // Don't send notification
  return;
}
```

## Real-World Examples

### Example 1: Sending Event Notification

```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:resident_app/src/models/event.dart';

Future<void> sendEventNotification(Event event) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if we should send this type of notification
  if (!await notificationService.shouldSendNotification(
    NotificationType.event,
  )) {
    print('Event notifications are disabled or in DND');
    return;
  }
  
  // Send push notification
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: 'Upcoming Event',
      body: event.title,
      data: {'event_id': event.id, 'type': 'event'},
    );
  }
  
  // Send email
  if (await notificationService.isEmailEnabled()) {
    await EmailService.send(
      to: user.email,
      subject: 'Event Reminder: ${event.title}',
      body: _buildEventEmailBody(event),
    );
  }
}
```

### Example 2: Visitor Arrival Alert

```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:resident_app/src/models/visitor.dart';

Future<void> notifyVisitorArrival(Visitor visitor) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if visitor alerts are enabled
  if (!await notificationService.areVisitorAlertsEnabled()) {
    print('Visitor alerts are disabled');
    return;
  }
  
  // Check DND
  if (await notificationService.isInDoNotDisturb()) {
    print('User is in Do Not Disturb mode');
    // Maybe queue for later or send anyway if urgent
    return;
  }
  
  // Send push notification
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: 'Visitor Arrived',
      body: '${visitor.name} is at the gate',
      data: {'visitor_id': visitor.id, 'type': 'visitor'},
      priority: 'high', // High priority for visitor alerts
    );
  }
  
  // Send SMS if enabled (for urgent visitor alerts)
  if (await notificationService.isSMSEnabled()) {
    await SMSService.send(
      to: user.phone,
      message: 'Visitor Alert: ${visitor.name} has arrived at the gate.',
    );
  }
}
```

### Example 3: Bill Payment Reminder

```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:resident_app/src/models/bill.dart';

Future<void> sendBillReminder(Bill bill, int daysUntilDue) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if bill reminders are enabled
  if (!await notificationService.areBillRemindersEnabled()) {
    return;
  }
  
  // Don't check DND for bill reminders - they're important
  // Or check and send anyway:
  final inDND = await notificationService.isInDoNotDisturb();
  
  String title = 'Bill Payment Reminder';
  String body = daysUntilDue == 0
      ? 'Your bill of ₹${bill.amount} is due today!'
      : 'Your bill of ₹${bill.amount} is due in $daysUntilDue days';
  
  // Send push notification
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: title,
      body: body,
      data: {'bill_id': bill.id, 'type': 'bill'},
      priority: daysUntilDue <= 1 ? 'high' : 'default',
    );
  }
  
  // Send email with detailed bill
  if (await notificationService.isEmailEnabled()) {
    await EmailService.send(
      to: user.email,
      subject: title,
      body: _buildBillEmailBody(bill, daysUntilDue),
      attachments: [bill.pdfUrl],
    );
  }
  
  // Send SMS for urgent reminders (1 day or less)
  if (daysUntilDue <= 1 && await notificationService.isSMSEnabled()) {
    await SMSService.send(
      to: user.phone,
      message: body,
    );
  }
}
```

### Example 4: Poll Notification

```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:resident_app/src/models/poll.dart';

Future<void> notifyNewPoll(Poll poll) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if poll notifications are enabled
  if (!await notificationService.shouldSendNotification(
    NotificationType.poll,
  )) {
    return;
  }
  
  // Send push notification
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: 'New Poll',
      body: poll.question,
      data: {'poll_id': poll.id, 'type': 'poll'},
    );
  }
  
  // Email notification with poll details
  if (await notificationService.isEmailEnabled()) {
    await EmailService.send(
      to: user.email,
      subject: 'New Community Poll: ${poll.question}',
      body: _buildPollEmailBody(poll),
    );
  }
}
```

### Example 5: Delivery Notification

```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:resident_app/src/models/delivery.dart';

Future<void> notifyDeliveryArrived(Delivery delivery) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if delivery notifications are enabled
  if (!await notificationService.areDeliveryNotificationsEnabled()) {
    return;
  }
  
  // Check DND
  if (await notificationService.isInDoNotDisturb()) {
    // Queue for later or send anyway
    return;
  }
  
  // Send push notification
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: 'Package Delivered',
      body: 'Your ${delivery.type} from ${delivery.courier} has arrived',
      data: {'delivery_id': delivery.id, 'type': 'delivery'},
    );
  }
  
  // Send SMS for important deliveries
  if (delivery.requiresSignature && 
      await notificationService.isSMSEnabled()) {
    await SMSService.send(
      to: user.phone,
      message: 'Package delivered. Signature required at reception.',
    );
  }
}
```

### Example 6: Payment Confirmation

```dart
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:resident_app/src/models/payment.dart';

Future<void> sendPaymentConfirmation(Payment payment) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if payment confirmations are enabled
  if (!await notificationService.arePaymentConfirmationsEnabled()) {
    return;
  }
  
  // Payment confirmations should bypass DND (important)
  
  // Send push notification
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: 'Payment Successful',
      body: 'Your payment of ₹${payment.amount} has been processed',
      data: {'payment_id': payment.id, 'type': 'payment'},
    );
  }
  
  // Always send email receipt
  if (await notificationService.isEmailEnabled()) {
    await EmailService.send(
      to: user.email,
      subject: 'Payment Receipt - ₹${payment.amount}',
      body: _buildPaymentReceiptEmail(payment),
      attachments: [payment.receiptUrl],
    );
  }
  
  // Send SMS confirmation
  if (await notificationService.isSMSEnabled()) {
    await SMSService.send(
      to: user.phone,
      message: 'Payment of ₹${payment.amount} successful. Ref: ${payment.id}',
    );
  }
}
```

## Advanced Usage

### Batch Notification Check

```dart
Future<void> sendMultipleNotifications(List<Notification> notifications) async {
  final notificationService = NotificationPreferencesService();
  
  // Get all preferences once
  final prefs = await notificationService.getAllPreferences();
  final inDND = await notificationService.isInDoNotDisturb();
  
  for (final notification in notifications) {
    // Check based on type
    bool shouldSend = false;
    
    switch (notification.type) {
      case 'event':
        shouldSend = prefs['event_reminders'] as bool;
        break;
      case 'poll':
        shouldSend = prefs['poll_notifications'] as bool;
        break;
      case 'visitor':
        shouldSend = prefs['visitor_alerts'] as bool;
        break;
      // ... other types
    }
    
    if (shouldSend && !inDND) {
      await _sendNotification(notification);
    }
  }
}
```

### Custom Notification Logic

```dart
Future<void> sendSmartNotification({
  required String title,
  required String body,
  required NotificationType type,
  bool bypassDND = false,
  bool urgent = false,
}) async {
  final notificationService = NotificationPreferencesService();
  
  // Check if notification type is enabled
  if (!await notificationService.shouldSendNotification(type)) {
    print('Notification type ${type.channelName} is disabled');
    return;
  }
  
  // Check DND unless bypassed
  if (!bypassDND && await notificationService.isInDoNotDisturb()) {
    if (urgent) {
      print('Urgent notification - sending despite DND');
    } else {
      print('User in DND - queuing notification');
      await _queueNotification(title, body, type);
      return;
    }
  }
  
  // Send via enabled channels
  if (await notificationService.isPushEnabled()) {
    await PushNotificationService.send(
      title: title,
      body: body,
      priority: urgent ? 'high' : 'default',
    );
  }
  
  if (urgent && await notificationService.isSMSEnabled()) {
    await SMSService.send(
      to: user.phone,
      message: '$title: $body',
    );
  }
}
```

### Notification Scheduling

```dart
Future<void> scheduleNotification({
  required DateTime scheduledTime,
  required String title,
  required String body,
  required NotificationType type,
}) async {
  final notificationService = NotificationPreferencesService();
  
  // Check preferences at schedule time
  if (!await notificationService.shouldSendNotification(type)) {
    print('Notification type disabled - not scheduling');
    return;
  }
  
  // Schedule the notification
  await NotificationScheduler.schedule(
    id: DateTime.now().millisecondsSinceEpoch,
    scheduledTime: scheduledTime,
    title: title,
    body: body,
    payload: type.channelId,
    // Re-check preferences when notification fires
    onFire: () async {
      if (await notificationService.shouldSendNotification(type)) {
        // Send notification
      }
    },
  );
}
```

## Integration with Firebase Cloud Messaging

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  static Future<void> handleMessage(RemoteMessage message) async {
    final notificationService = NotificationPreferencesService();
    
    // Get notification type from message data
    final typeString = message.data['type'] as String?;
    final type = _parseNotificationType(typeString);
    
    // Check if we should show this notification
    if (!await notificationService.shouldSendNotification(type)) {
      print('Notification filtered by user preferences');
      return;
    }
    
    // Check DND
    if (await notificationService.isInDoNotDisturb()) {
      print('User in DND - storing notification');
      await _storeNotification(message);
      return;
    }
    
    // Show notification
    await _showLocalNotification(message);
  }
  
  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'event':
        return NotificationType.event;
      case 'poll':
        return NotificationType.poll;
      case 'visitor':
        return NotificationType.visitor;
      case 'delivery':
        return NotificationType.delivery;
      case 'bill':
        return NotificationType.bill;
      case 'payment':
        return NotificationType.payment;
      default:
        return NotificationType.general;
    }
  }
}
```

## Testing

### Test Notification Preferences

```dart
void testNotificationPreferences() async {
  final service = NotificationPreferencesService();
  
  print('=== Notification Preferences Test ===');
  
  // Test all getters
  print('Push: ${await service.isPushEnabled()}');
  print('Email: ${await service.isEmailEnabled()}');
  print('SMS: ${await service.isSMSEnabled()}');
  print('Events: ${await service.areEventRemindersEnabled()}');
  print('Polls: ${await service.arePollNotificationsEnabled()}');
  print('Visitors: ${await service.areVisitorAlertsEnabled()}');
  print('Deliveries: ${await service.areDeliveryNotificationsEnabled()}');
  print('Bills: ${await service.areBillRemindersEnabled()}');
  print('Payments: ${await service.arePaymentConfirmationsEnabled()}');
  print('In DND: ${await service.isInDoNotDisturb()}');
  
  // Test notification type checks
  for (final type in NotificationType.values) {
    final shouldSend = await service.shouldSendNotification(type);
    print('Should send ${type.channelName}: $shouldSend');
  }
}
```

## Best Practices

1. **Always check DND** - Unless the notification is critical
2. **Respect user preferences** - Don't bypass settings without good reason
3. **Use appropriate channels** - Push for immediate, email for detailed
4. **Handle errors gracefully** - Notification failures shouldn't crash the app
5. **Log notification attempts** - For debugging and analytics
6. **Test thoroughly** - Verify all notification types and preferences
7. **Provide feedback** - Let users know when notifications are sent

## Common Patterns

### Pattern 1: Critical Notifications (Always Send)

```dart
// For emergency or critical notifications
await sendCriticalNotification(
  title: 'Emergency Alert',
  body: 'Important community announcement',
  bypassDND: true,
  bypassPreferences: true,
);
```

### Pattern 2: Queued Notifications (Send After DND)

```dart
if (await notificationService.isInDoNotDisturb()) {
  await queueNotification(notification);
} else {
  await sendNotification(notification);
}
```

### Pattern 3: Multi-Channel Notifications

```dart
final channels = <String>[];
if (await notificationService.isPushEnabled()) channels.add('push');
if (await notificationService.isEmailEnabled()) channels.add('email');
if (await notificationService.isSMSEnabled()) channels.add('sms');

await sendMultiChannelNotification(notification, channels);
```

---

**Need more examples?** Check the service implementation in `notification_preferences_service.dart`
