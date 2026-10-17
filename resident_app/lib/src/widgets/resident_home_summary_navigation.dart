import 'package:flutter/material.dart';

import '../../maintenance_billing_screen.dart';
import '../screens/visitor_management_screen_new.dart';

void openResidentHomeVisitors(
  BuildContext context, {
  WidgetBuilder? destinationBuilder,
}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: destinationBuilder ?? (_) => const VisitorManagementScreenNew(),
    ),
  );
}

void openResidentHomeBilling(
  BuildContext context, {
  ValueChanged<int>? onTabChange,
  WidgetBuilder? destinationBuilder,
}) {
  if (onTabChange != null) {
    onTabChange(3);
    return;
  }

  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder:
          destinationBuilder ??
          (_) => const MaintenanceBillingScreen(showBackButton: true),
    ),
  );
}

/// Opens Billing above Home so a summary-card action has a direct return path.
void openResidentHomeBillingRoute(
  BuildContext context, {
  WidgetBuilder? destinationBuilder,
}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder:
          destinationBuilder ??
          (_) => const MaintenanceBillingScreen(showBackButton: true),
    ),
  );
}
