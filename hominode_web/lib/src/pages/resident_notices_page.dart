import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_page_components.dart';

class ResidentNoticesPage extends StatelessWidget {
  const ResidentNoticesPage({super.key, required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) => ResidentPageLayout(
    title: 'Notices',
    subtitle: 'Published notices visible to your unit',
    child: ResidentDashboardDataView(
      session: session,
      builder: (context, data) => SectionCard(
        title: 'Active notices',
        subtitle: '${metricValue(data.activeNotices)} currently available',
        child: DashboardRecordList(
          records: data.notices,
          emptyMessage: 'No active notices are available.',
          color: RolePalette.resident.primary,
          icon: Icons.campaign_outlined,
        ),
      ),
    ),
  );
}
