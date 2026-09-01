import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_page_components.dart';

class ResidentEventsPage extends StatelessWidget {
  const ResidentEventsPage({super.key, required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) => ResidentPageLayout(
    title: 'Events',
    subtitle: 'Upcoming events in your community',
    child: ResidentDashboardDataView(
      session: session,
      builder: (context, data) => SectionCard(
        title: 'Upcoming events',
        subtitle: '${metricValue(data.events?.length)} currently scheduled',
        child: DashboardRecordList(
          records: data.events,
          emptyMessage: 'No upcoming events are scheduled.',
          color: const Color(0xFF08A579),
          icon: Icons.event_outlined,
        ),
      ),
    ),
  );
}
