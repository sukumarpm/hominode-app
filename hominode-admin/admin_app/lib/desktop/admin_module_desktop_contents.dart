import 'package:flutter/material.dart';

import '../admin_residents_page_firestore.dart';
import '../amenities_management_screen.dart';
import '../billing_screen.dart';
import '../complaint_management_screen.dart';
import '../events_announcements_screen.dart';
import '../manage_buildings_page.dart';
import '../parking_management_screen.dart';
import '../profile_screen.dart';
import '../resident_vehicle_management_screen.dart';
import '../settings_screen.dart';
import '../visitor_management_screen.dart';
import 'admin_desktop_page_frame.dart';

class BuildingsDesktopContent extends StatelessWidget {
  const BuildingsDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: ManageBuildingsPage());
}

class ResidentsDesktopContent extends StatelessWidget {
  const ResidentsDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: AdminResidentsPageFirestore());
}

class BillingDesktopContent extends StatelessWidget {
  const BillingDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: BillingScreen());
}

class VisitorsDesktopContent extends StatelessWidget {
  const VisitorsDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: VisitorManagementScreen());
}

class ComplaintsDesktopContent extends StatelessWidget {
  const ComplaintsDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: ComplaintManagementScreen());
}

class EventsDesktopContent extends StatelessWidget {
  const EventsDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: EventsAnnouncementsScreen());
}

class ParkingDesktopContent extends StatelessWidget {
  const ParkingDesktopContent({super.key});
  @override
  Widget build(BuildContext context) => const AdminDesktopPresentationScope(
    child: ParkingManagementScreenEnhanced(),
  );
}

class VehiclesDesktopContent extends StatelessWidget {
  const VehiclesDesktopContent({super.key});
  @override
  Widget build(BuildContext context) => const AdminDesktopPresentationScope(
    child: ResidentVehicleManagementScreen(),
  );
}

class AmenitiesDesktopContent extends StatelessWidget {
  const AmenitiesDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: AmenitiesManagementScreen());
}

class ProfileDesktopContent extends StatelessWidget {
  const ProfileDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: ProfileScreen());
}

class SettingsDesktopContent extends StatelessWidget {
  const SettingsDesktopContent({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminDesktopPresentationScope(child: SettingsScreen());
}
