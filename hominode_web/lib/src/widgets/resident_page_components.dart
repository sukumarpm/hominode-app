import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import '../session/web_session.dart';
import '../tenant/web_host.dart';
import '../theme/web_design_system.dart';
import 'dashboard_components.dart';
import 'community_visuals.dart';

class ResidentPageLayout extends StatelessWidget {
  const ResidentPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        children: [
          CommunityWelcome(
            title: title,
            subtitle: subtitle,
            palette: RolePalette.resident,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: () => _goBack(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      child,
    ],
  );

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      final homePath = WebHostScope.maybeOf(
        context,
      )?.externalPathFor('/resident');
      navigator.pushReplacementNamed(homePath ?? '/resident');
    }
  }
}

class ResidentDashboardDataView extends StatefulWidget {
  const ResidentDashboardDataView({
    super.key,
    required this.session,
    required this.builder,
  });

  final WebSession session;
  final Widget Function(BuildContext context, ResidentDashboardData data)
  builder;

  @override
  State<ResidentDashboardDataView> createState() =>
      _ResidentDashboardDataViewState();
}

class _ResidentDashboardDataViewState extends State<ResidentDashboardDataView> {
  late Future<ResidentDashboardData> _future = _load();

  Future<ResidentDashboardData> _load() =>
      DashboardRepository().residentDashboard(
        communityId: widget.session.activeTenant!.communityId,
        uid: widget.session.uid,
        flatId: widget.session.flatId,
      );

  @override
  void didUpdateWidget(covariant ResidentDashboardDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid ||
        oldWidget.session.activeTenant?.communityId !=
            widget.session.activeTenant?.communityId ||
        oldWidget.session.flatId != widget.session.flatId) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ResidentDashboardData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const SectionCard(
          title: 'Resident information',
          child: EmptyState(
            icon: Icons.error_outline,
            message: 'This resident information is currently unavailable.',
          ),
        );
      }
      return widget.builder(context, snapshot.data!);
    },
  );
}
