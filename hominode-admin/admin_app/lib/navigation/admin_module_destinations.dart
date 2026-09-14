import 'package:flutter/material.dart';

import '../admin_dashboard_desktop_content.dart';
import '../desktop/admin_module_desktop_contents.dart';

enum AdminModuleId {
  dashboard,
  buildings,
  residents,
  billing,
  visitors,
  complaints,
  events,
  parking,
  residentVehicles,
  amenities,
  profile,
  settings,
}

class AdminModuleDestination {
  const AdminModuleDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final AdminModuleId id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Desktop navigation backed exclusively by the existing admin modules.
final List<AdminModuleDestination> adminModuleDestinations =
    List.unmodifiable(<AdminModuleDestination>[
      AdminModuleDestination(
        id: AdminModuleId.dashboard,
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        builder: (_) => const AdminDashboardDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.buildings,
        label: 'Buildings',
        icon: Icons.apartment_outlined,
        builder: (_) => const BuildingsDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.residents,
        label: 'Residents',
        icon: Icons.people_outline,
        builder: (_) => const ResidentsDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.billing,
        label: 'Billing',
        icon: Icons.receipt_long_outlined,
        builder: (_) => const BillingDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.visitors,
        label: 'Visitors',
        icon: Icons.badge_outlined,
        builder: (_) => const VisitorsDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.complaints,
        label: 'Complaints',
        icon: Icons.report_problem_outlined,
        builder: (_) => const ComplaintsDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.events,
        label: 'Events',
        icon: Icons.event_outlined,
        builder: (_) => const EventsDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.parking,
        label: 'Parking',
        icon: Icons.local_parking_outlined,
        builder: (_) => const ParkingDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.residentVehicles,
        label: 'Resident Vehicles',
        icon: Icons.directions_car_outlined,
        builder: (_) => const VehiclesDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.amenities,
        label: 'Amenities',
        icon: Icons.pool_outlined,
        builder: (_) => const AmenitiesDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.profile,
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        builder: (_) => const ProfileDesktopContent(),
      ),
      AdminModuleDestination(
        id: AdminModuleId.settings,
        label: 'Settings',
        icon: Icons.settings_outlined,
        builder: (_) => const SettingsDesktopContent(),
      ),
    ]);
