import 'dart:async';

import 'package:flutter/material.dart';
import '../services/security_visitor_summary_service.dart';
import '../utils/app_colors.dart';

/// Counts are a server snapshot, never permission for a visitor to enter.
class SecurityVisitorCounters extends StatefulWidget {
  const SecurityVisitorCounters({
    super.key,
    required this.communityId,
    this.load,
    this.refreshVersion = 0,
  });
  final String communityId;
  final Future<SecurityVisitorSummary> Function()? load;
  final int refreshVersion;

  @override
  State<SecurityVisitorCounters> createState() =>
      _SecurityVisitorCountersState();
}

class _SecurityVisitorCountersState extends State<SecurityVisitorCounters>
    with WidgetsBindingObserver {
  SecurityVisitorSummary? _summary;
  bool _loading = true;
  int _generation = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (!_loading &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        _reload();
      }
    });
  }

  @override
  void didUpdateWidget(SecurityVisitorCounters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.communityId != widget.communityId ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      _reload();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _summary = null;
    });
    try {
      final summary =
          await (widget.load ?? SecurityVisitorSummaryService().load)().timeout(
            const Duration(seconds: 20),
          );
      if (!mounted || generation != _generation) return;
      if (summary.communityId != widget.communityId) {
        throw const FormatException('Visitor summary community mismatch.');
      }
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _summary = null;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final placeholder = _loading ? '…' : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  summary?.totalToday.toString() ?? placeholder,
                  Icons.people,
                  AppColors.primaryTeal,
                  'Today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  summary?.activeInside.toString() ?? placeholder,
                  Icons.login,
                  AppColors.successGreen,
                  'Inside',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  summary?.pendingRequests.toString() ?? placeholder,
                  Icons.pending,
                  AppColors.warningOrange,
                  'Requests',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Exits',
                  summary?.exitsToday.toString() ?? placeholder,
                  Icons.logout,
                  AppColors.errorRed,
                  'Today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _loading
                      ? 'Loading visitor counts…'
                      : summary == null
                      ? 'Visitor counts unavailable'
                      : 'Today: ${summary.localDate} (${summary.timeZone})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                  ),
                ),
              ),
              if (!_loading)
                TextButton(
                  onPressed: _reload,
                  child: Text(summary == null ? 'Retry' : 'Refresh'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}
