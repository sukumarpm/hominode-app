import 'admin_module_destinations.dart';

const String adminDashboardRoute = '/dashboard';
const String adminBuildingsRoute = '/buildings';
const String adminResidentsRoute = '/residents';
const String adminBillingRoute = '/billing';
const String adminVisitorsRoute = '/visitors';
const String adminComplaintsRoute = '/complaints';
const String adminEventsRoute = '/events';
const String adminParkingRoute = '/parking';
const String adminResidentVehiclesRoute = '/resident-vehicles';
const String adminAmenitiesRoute = '/amenities';
const String adminProfileRoute = '/profile';
const String adminSettingsRoute = '/settings';

// Legacy aliases kept for backward compatibility with existing navigation calls.
const String adminVisitorsLegacyRoute = '/visitor_management';
const String adminParkingLegacyRoute = '/parking_management';
const String adminResidentVehiclesLegacyRoute = '/resident_vehicles';

String adminRoutePathForModule(AdminModuleId module) {
  switch (module) {
    case AdminModuleId.dashboard:
      return adminDashboardRoute;
    case AdminModuleId.buildings:
      return adminBuildingsRoute;
    case AdminModuleId.residents:
      return adminResidentsRoute;
    case AdminModuleId.billing:
      return adminBillingRoute;
    case AdminModuleId.visitors:
      return adminVisitorsRoute;
    case AdminModuleId.complaints:
      return adminComplaintsRoute;
    case AdminModuleId.events:
      return adminEventsRoute;
    case AdminModuleId.parking:
      return adminParkingRoute;
    case AdminModuleId.residentVehicles:
      return adminResidentVehiclesRoute;
    case AdminModuleId.amenities:
      return adminAmenitiesRoute;
    case AdminModuleId.profile:
      return adminProfileRoute;
    case AdminModuleId.settings:
      return adminSettingsRoute;
  }
}

AdminModuleId? adminModuleFromRoutePath(String? routePath) {
  switch (routePath) {
    case adminDashboardRoute:
      return AdminModuleId.dashboard;
    case adminBuildingsRoute:
      return AdminModuleId.buildings;
    case adminResidentsRoute:
      return AdminModuleId.residents;
    case adminBillingRoute:
      return AdminModuleId.billing;
    case adminVisitorsRoute:
    case adminVisitorsLegacyRoute:
      return AdminModuleId.visitors;
    case adminComplaintsRoute:
      return AdminModuleId.complaints;
    case adminEventsRoute:
      return AdminModuleId.events;
    case adminParkingRoute:
    case adminParkingLegacyRoute:
      return AdminModuleId.parking;
    case adminResidentVehiclesRoute:
    case adminResidentVehiclesLegacyRoute:
      return AdminModuleId.residentVehicles;
    case adminAmenitiesRoute:
      return AdminModuleId.amenities;
    case adminProfileRoute:
      return AdminModuleId.profile;
    case adminSettingsRoute:
      return AdminModuleId.settings;
    default:
      return null;
  }
}
