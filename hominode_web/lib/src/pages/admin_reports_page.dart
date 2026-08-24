import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  String get _communityId => session.activeTenant!.communityId;

  String get _communityName => session.activeTenant!.name;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportSnapshot>(
      future: _loadReportSnapshot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SectionCard(
            title: 'Reports',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SectionCard(
            title: 'Reports',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load reports for this community.',
            ),
          );
        }

        final report = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReportsHero(
              communityName: _communityName,
              residents: report.residents,
              visitors: report.visitors,
              complaints: report.complaints,
              bills: report.bills,
            ),
            const SizedBox(height: 16),
            _QuickNavigation(onNavigate: onNavigate),
            const SizedBox(height: 16),
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Residents',
                  value: report.residents.toString(),
                  icon: Icons.people_outline,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Buildings',
                  value: report.buildings.toString(),
                  icon: Icons.apartment_outlined,
                  color: RolePalette.admin.primary,
                ),
                DashboardStatCard(
                  label: 'Visitors',
                  value: report.visitors.toString(),
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF7A42D8),
                ),
                DashboardStatCard(
                  label: 'Complaints',
                  value: report.complaints.toString(),
                  icon: Icons.report_problem_outlined,
                  color: const Color(0xFFE34A5F),
                ),
                DashboardStatCard(
                  label: 'Amenities',
                  value: report.amenities.toString(),
                  icon: Icons.spa_outlined,
                  color: const Color(0xFF08A579),
                ),
                DashboardStatCard(
                  label: 'Bills',
                  value: report.bills.toString(),
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFFE66A2C),
                ),
                DashboardStatCard(
                  label: 'Events',
                  value: report.events.toString(),
                  icon: Icons.event_outlined,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Notices',
                  value: report.notices.toString(),
                  icon: Icons.campaign_outlined,
                  color: const Color(0xFF7A42D8),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final complaintSection = _ComplaintSummary(
                  report: report,
                  onNavigate: onNavigate,
                );

                final billingSection = _BillingSummary(
                  report: report,
                  onNavigate: onNavigate,
                );

                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: complaintSection),
                      const SizedBox(width: 16),
                      Expanded(child: billingSection),
                    ],
                  );
                }

                return Column(
                  children: [
                    complaintSection,
                    const SizedBox(height: 16),
                    billingSection,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final visitorSection = _VisitorSummary(
                  report: report,
                  onNavigate: onNavigate,
                );

                final communitySection = _CommunitySummary(
                  report: report,
                  onNavigate: onNavigate,
                );

                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: visitorSection),
                      const SizedBox(width: 16),
                      Expanded(child: communitySection),
                    ],
                  );
                }

                return Column(
                  children: [
                    visitorSection,
                    const SizedBox(height: 16),
                    communitySection,
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<_ReportSnapshot> _loadReportSnapshot() async {
    //
    // SECURITY:
    // Every query is explicitly scoped to the already validated
    // active community. There are no broad platform-level queries here.
    //
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db
          .collection('users')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('buildings')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('visitors')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('complaints')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('amenities')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('bills')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('events')
          .where('communityId', isEqualTo: _communityId)
          .get(),
      db
          .collection('notices')
          .where('communityId', isEqualTo: _communityId)
          .get(),
    ]);

    final users = results[0].docs;
    final buildings = results[1].docs;
    final visitors = results[2].docs;
    final complaints = results[3].docs;
    final amenities = results[4].docs;
    final bills = results[5].docs;
    final events = results[6].docs;
    final notices = results[7].docs;

    final residentDocs = users.where((doc) {
      final data = doc.data();

      if (data['communityId']?.toString() != _communityId) {
        return false;
      }

      final role = data['role']?.toString().trim().toLowerCase();

      return role == null || role.isEmpty || role == 'resident';
    }).toList();

    final complaintOpen = complaints.where((doc) {
      final status = _complaintStatus(doc.data());

      return status == 'open' || status == 'pending' || status == 'inprogress';
    }).length;

    final complaintResolved = complaints.where((doc) {
      final status = _complaintStatus(doc.data());

      return status == 'resolved' ||
          status == 'closed' ||
          status == 'completed';
    }).length;

    final visitorPending = visitors
        .where((doc) => _visitorStatus(doc.data()) == 'pending')
        .length;

    final visitorEntered = visitors
        .where((doc) => _visitorStatus(doc.data()) == 'entered')
        .length;

    final visitorExited = visitors
        .where((doc) => _visitorStatus(doc.data()) == 'exited')
        .length;

    final billPending = bills.where((doc) {
      final status = _billStatus(doc.data());

      return status == 'pending' || status == 'due' || status == 'unpaid';
    }).length;

    final billPaid = bills.where((doc) {
      final status = _billStatus(doc.data());

      return status == 'paid' || status == 'settled' || status == 'approved';
    }).length;

    final receiptPending = bills
        .where((doc) => _paymentApprovalStatus(doc.data()) == 'pendingapproval')
        .length;

    final totalBilled = bills.fold<double>(
      0,
      (sum, doc) => sum + _billAmount(doc.data()),
    );

    final totalPaid = bills
        .where((doc) {
          final status = _billStatus(doc.data());

          return status == 'paid' ||
              status == 'settled' ||
              status == 'approved';
        })
        .fold<double>(0, (sum, doc) => sum + _billAmount(doc.data()));

    return _ReportSnapshot(
      residents: residentDocs.length,
      buildings: buildings.length,
      visitors: visitors.length,
      complaints: complaints.length,
      amenities: amenities.length,
      bills: bills.length,
      events: events.length,
      notices: notices.length,
      complaintOpen: complaintOpen,
      complaintResolved: complaintResolved,
      visitorPending: visitorPending,
      visitorEntered: visitorEntered,
      visitorExited: visitorExited,
      billPending: billPending,
      billPaid: billPaid,
      receiptPending: receiptPending,
      totalBilled: totalBilled,
      totalPaid: totalPaid,
    );
  }
}

class _ReportSnapshot {
  const _ReportSnapshot({
    required this.residents,
    required this.buildings,
    required this.visitors,
    required this.complaints,
    required this.amenities,
    required this.bills,
    required this.events,
    required this.notices,
    required this.complaintOpen,
    required this.complaintResolved,
    required this.visitorPending,
    required this.visitorEntered,
    required this.visitorExited,
    required this.billPending,
    required this.billPaid,
    required this.receiptPending,
    required this.totalBilled,
    required this.totalPaid,
  });

  final int residents;
  final int buildings;
  final int visitors;
  final int complaints;
  final int amenities;
  final int bills;
  final int events;
  final int notices;

  final int complaintOpen;
  final int complaintResolved;

  final int visitorPending;
  final int visitorEntered;
  final int visitorExited;

  final int billPending;
  final int billPaid;
  final int receiptPending;

  final double totalBilled;
  final double totalPaid;

  double get outstanding {
    final value = totalBilled - totalPaid;

    return value < 0 ? 0 : value;
  }
}

//
// ============================================================
// HERO
// ============================================================
//

class _ReportsHero extends StatelessWidget {
  const _ReportsHero({
    required this.communityName,
    required this.residents,
    required this.visitors,
    required this.complaints,
    required this.bills,
  });

  final String communityName;
  final int residents;
  final int visitors;
  final int complaints;
  final int bills;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: RolePalette.admin.gradient,
        borderRadius: BorderRadius.circular(WebDesign.radius + 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      communityName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(label: 'Residents', value: '$residents'),
              _HeroMetric(label: 'Visitors', value: '$visitors'),
              _HeroMetric(label: 'Complaints', value: '$complaints'),
              _HeroMetric(label: 'Bills', value: '$bills'),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), metrics],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 20),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// QUICK ACCESS
// ============================================================
//

class _QuickNavigation extends StatelessWidget {
  const _QuickNavigation({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Access',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          QuickActionCard(
            label: 'Residents',
            icon: Icons.people_outline,
            color: const Color(0xFF246BFD),
            onTap: () => onNavigate('/admin/residents'),
          ),
          QuickActionCard(
            label: 'Visitors',
            icon: Icons.badge_outlined,
            color: const Color(0xFF7A42D8),
            onTap: () => onNavigate('/admin/visitors'),
          ),
          QuickActionCard(
            label: 'Complaints',
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFE34A5F),
            onTap: () => onNavigate('/admin/complaints'),
          ),
          QuickActionCard(
            label: 'Billing',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF08A579),
            onTap: () => onNavigate('/admin/billing'),
          ),
          QuickActionCard(
            label: 'Events & Notices',
            icon: Icons.campaign_outlined,
            color: const Color(0xFFE66A2C),
            onTap: () => onNavigate('/admin/events'),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// COMPLAINT REPORT
// ============================================================
//

class _ComplaintSummary extends StatelessWidget {
  const _ComplaintSummary({required this.report, required this.onNavigate});

  final _ReportSnapshot report;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Complaint Summary',
      action: TextButton(
        onPressed: () => onNavigate('/admin/complaints'),
        child: const Text('View Complaints'),
      ),
      child: Column(
        children: [
          _ReportRow(
            icon: Icons.report_problem_outlined,
            label: 'Total complaints',
            value: '${report.complaints}',
            color: const Color(0xFFE34A5F),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.pending_actions_outlined,
            label: 'Open / pending',
            value: '${report.complaintOpen}',
            color: const Color(0xFFE66A2C),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.check_circle_outline,
            label: 'Resolved',
            value: '${report.complaintResolved}',
            color: const Color(0xFF08A579),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// BILLING REPORT
// ============================================================
//

class _BillingSummary extends StatelessWidget {
  const _BillingSummary({required this.report, required this.onNavigate});

  final _ReportSnapshot report;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Billing Summary',
      action: TextButton(
        onPressed: () => onNavigate('/admin/billing'),
        child: const Text('View Billing'),
      ),
      child: Column(
        children: [
          _ReportRow(
            icon: Icons.receipt_long_outlined,
            label: 'Total billed',
            value: _money(report.totalBilled),
            color: const Color(0xFF246BFD),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.check_circle_outline,
            label: 'Paid amount',
            value: _money(report.totalPaid),
            color: const Color(0xFF08A579),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Outstanding',
            value: _money(report.outstanding),
            color: const Color(0xFFE66A2C),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.fact_check_outlined,
            label: 'Receipt approvals',
            value: '${report.receiptPending}',
            color: const Color(0xFF7A42D8),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// VISITOR REPORT
// ============================================================
//

class _VisitorSummary extends StatelessWidget {
  const _VisitorSummary({required this.report, required this.onNavigate});

  final _ReportSnapshot report;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Visitor Summary',
      action: TextButton(
        onPressed: () => onNavigate('/admin/visitors'),
        child: const Text('View Visitors'),
      ),
      child: Column(
        children: [
          _ReportRow(
            icon: Icons.badge_outlined,
            label: 'Total visitors',
            value: '${report.visitors}',
            color: const Color(0xFF7A42D8),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.schedule_outlined,
            label: 'Pending',
            value: '${report.visitorPending}',
            color: const Color(0xFFE66A2C),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.login_outlined,
            label: 'Entered',
            value: '${report.visitorEntered}',
            color: const Color(0xFF246BFD),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.logout_outlined,
            label: 'Exited',
            value: '${report.visitorExited}',
            color: const Color(0xFF08A579),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// COMMUNITY REPORT
// ============================================================
//

class _CommunitySummary extends StatelessWidget {
  const _CommunitySummary({required this.report, required this.onNavigate});

  final _ReportSnapshot report;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Community Summary',
      action: TextButton(
        onPressed: () => onNavigate('/admin/community'),
        child: const Text('My Community'),
      ),
      child: Column(
        children: [
          _ReportRow(
            icon: Icons.people_outline,
            label: 'Residents',
            value: '${report.residents}',
            color: const Color(0xFF246BFD),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.apartment_outlined,
            label: 'Buildings',
            value: '${report.buildings}',
            color: RolePalette.admin.primary,
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.spa_outlined,
            label: 'Amenities',
            value: '${report.amenities}',
            color: const Color(0xFF08A579),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.event_outlined,
            label: 'Events',
            value: '${report.events}',
            color: const Color(0xFFE66A2C),
          ),
          const Divider(height: 24),
          _ReportRow(
            icon: Icons.campaign_outlined,
            label: 'Notices',
            value: '${report.notices}',
            color: const Color(0xFF7A42D8),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: WebDesign.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

//
// ============================================================
// DATA HELPERS
// ============================================================
//

String _complaintStatus(Map<String, dynamic> data) {
  for (final key in const ['status', 'complaintStatus', 'resolutionStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      final normalized = value.replaceAll(' ', '').replaceAll('_', '');

      if (normalized == 'inprogress') {
        return 'inprogress';
      }

      return normalized;
    }
  }

  return 'open';
}

String _visitorStatus(Map<String, dynamic> data) {
  for (final key in const ['status', 'visitStatus', 'approvalStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      final normalized = value.replaceAll(' ', '').replaceAll('_', '');

      if (normalized == 'pendingapproval') {
        return 'pending';
      }

      return normalized;
    }
  }

  return 'pending';
}

String _billStatus(Map<String, dynamic> data) {
  for (final key in const ['status', 'billStatus', 'paymentStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      return value.replaceAll(' ', '').replaceAll('_', '');
    }
  }

  return 'pending';
}

String _paymentApprovalStatus(Map<String, dynamic> data) {
  final value = data['paymentStatus']?.toString().trim().toLowerCase();

  if (value == null || value.isEmpty) {
    return '';
  }

  return value.replaceAll(' ', '').replaceAll('_', '');
}

double _billAmount(Map<String, dynamic> data) {
  for (final key in const [
    'amount',
    'totalAmount',
    'billAmount',
    'total',
    'dueAmount',
  ]) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', ''));

      if (parsed != null) {
        return parsed;
      }
    }
  }

  return 0;
}

String _money(num amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}
