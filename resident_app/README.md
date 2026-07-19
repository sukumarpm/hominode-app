# Lyvo - Your Community, Connected

A comprehensive resident community management app built with Flutter.

## About Lyvo

Lyvo is a modern, feature-rich mobile application designed to enhance community living by connecting residents, simplifying management tasks, and fostering engagement within residential communities.

### Key Features

- **Dashboard** - Quick access to all community features
- **Visitor Management** - Manage guests and deliveries seamlessly
- **Billing & Payments** - View and pay maintenance bills
- **Events & Announcements** - Stay updated with community happenings
- **Community Wall** - Social feed for residents
- **Marketplace** - Buy and sell within your community
- **Amenities Booking** - Reserve community facilities
- **Complaints Management** - Report and track issues
- **Messages** - Chat with neighbors and management

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **Design**: Material Design 3
- **State Management**: StatefulWidget
- **Navigation**: Bottom Navigation with IndexedStack

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode for mobile development

### Installation

```bash
# Clone the repository
git clone <repository-url>

# Navigate to project directory
cd resident_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── main_navigation.dart               # Bottom navigation wrapper
├── dashboard_screen.dart              # Home screen
├── visitor_management_screen.dart     # Visitor management
├── maintenance_billing_screen.dart    # Billing & payments
├── events_announcements_screen.dart   # Events & notices
├── profile_screen.dart                # User profile
├── community_wall_screen.dart         # Social feed
├── messages_screen.dart               # Chat & notifications
└── src/
    ├── components/                    # Reusable UI components
    ├── modals/                        # Modal dialogs
    ├── models/                        # Data models
    ├── screens/                       # Additional screens
    ├── services/                      # Business logic
    └── widgets/                       # Custom widgets
```

## Features Documentation

Detailed documentation for each feature can be found in the respective markdown files:

- [Bottom Navigation](BOTTOM_NAV_IMPLEMENTATION.md)
- [Community Wall](COMMUNITY_WALL_README.md)
- [Events Module](EVENTS_MODULE_README.md)
- [Polls Feature](POLLS_FEATURE_README.md)
- [Visitor Management](VISITOR_MANAGEMENT_README.md)
- [Branding Guide](BRANDING.md)

## Design System

### Colors
- **Primary Blue**: `#2563EB`
- **Dark Blue**: `#1E40AF`
- **Background**: `#F7F7F7`
- **Text Primary**: `#111111`
- **Text Secondary**: `#8C8C8C`

### Typography
- **Font Family**: Inter
- **Weights**: 400, 500, 600, 700

### Spacing
- **Standard**: 16px
- **Small**: 12px
- **Large**: 24px

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is proprietary software. All rights reserved.

## Contact

For questions or support, please contact the development team.

---

**Lyvo** - Making community living better, one connection at a time. 🏘️
