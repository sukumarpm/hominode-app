import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/parcel_entry.dart';
import 'services/admin_tenant_context.dart';
import 'services/parcel_firestore_service.dart';
import 'widgets/pending_parcel_card.dart';
import 'widgets/collected_parcel_card.dart';
import 'widgets/log_parcel_modal.dart';
import 'widgets/standard_header.dart';

// ============================================================================
// PARCEL DELIVERY TRACKING SCREEN
// ============================================================================
// Pixel-perfect implementation matching the reference design
// Features: Parcel tracking, notifications, collection management

class ParcelDeliveryTrackingScreen extends StatefulWidget {
  const ParcelDeliveryTrackingScreen({super.key});

  @override
  State<ParcelDeliveryTrackingScreen> createState() =>
      _ParcelDeliveryTrackingScreenState();
}

class _ParcelDeliveryTrackingScreenState
    extends State<ParcelDeliveryTrackingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';

  final _service = ParcelFirestoreService();
  final _tenant = AdminTenantContext.instance;
  StreamSubscription<List<ParcelEntry>>? _subscription;
  List<ParcelEntry> _parcels = [];
  final Set<String> _collecting = {};
  bool _loading = true;
  bool _hasCommunity = false;
  String? _loadError;
  int _generation = 0;

  List<ParcelEntry> get _pendingParcels => _parcels
      .where((parcel) => parcel.status == ParcelStatus.pending)
      .toList();
  List<ParcelEntry> get _collectedParcels =>
      _parcels
          .where((parcel) => parcel.status == ParcelStatus.collected)
          .toList()
        ..sort(
          (a, b) => (b.collectedTime ?? b.receivedTime).compareTo(
            a.collectedTime ?? a.receivedTime,
          ),
        );

  @override
  void initState() {
    super.initState();
    _tenant.addListener(_watchParcels);
    _watchParcels();
  }

  void _watchParcels() {
    final generation = ++_generation;
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _parcels = [];
      _collecting.clear();
      _loading = true;
      _hasCommunity = false;
      _loadError = null;
    });
    try {
      final stream = _service.watchParcels();
      _hasCommunity = true;
      _subscription = stream.listen(
        (parcels) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _parcels = parcels;
            _loading = false;
            _loadError = null;
          });
        },
        onError: (Object _) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _parcels = [];
            _loading = false;
            _loadError = 'Unable to load parcels. Please try again.';
          });
        },
      );
    } on StateError {
      setState(() {
        _loading = false;
        _loadError = 'Select an authorized community to view parcels.';
      });
    }
  }

  @override
  void dispose() {
    _tenant.removeListener(_watchParcels);
    _subscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ParcelEntry> get _filteredPendingParcels {
    if (_searchQuery.isEmpty) return _pendingParcels;
    return _pendingParcels.where((parcel) {
      return parcel.residentName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          parcel.unit.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          parcel.trackingId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ParcelEntry> get _filteredCollectedParcels {
    if (_searchQuery.isEmpty) return _collectedParcels;
    return _collectedParcels.where((parcel) {
      return parcel.residentName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          parcel.unit.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          parcel.trackingId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _onLogParcel() {
    HapticFeedback.mediumImpact();
    // The Firestore stream is the source of truth after the dialog saves.
    LogNewParcelDialog.show(context, onParcelAdded: (_) {});
  }

  Future<void> _onMarkAsCollected(ParcelEntry parcel) async {
    if (_collecting.contains(parcel.id)) return;
    final generation = _generation;
    setState(() => _collecting.add(parcel.id));
    HapticFeedback.lightImpact();
    try {
      await _service.markCollected(parcel);
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${parcel.residentName} parcel marked as collected'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Parcel collection failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || generation != _generation) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to mark parcel collected: $e')),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _collecting.remove(parcel.id));
      }
    }
  }

  void _onRemindResident() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Parcel notifications are not available yet. No reminder was sent.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Parcel Delivery Tracking'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Page Header
                _buildPageHeader(),

                const SizedBox(height: 16),

                // Summary Metrics
                _buildSummaryMetrics(),

                const SizedBox(height: 20),

                // Search Bar
                _buildSearchBar(),

                const SizedBox(height: 24),

                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _watchParcels,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _buildPendingSection(),
                  const SizedBox(height: 24),
                  _buildCollectedSection(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Track & manage parcel deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _hasCommunity ? _onLogParcel : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Log Parcel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    int receivedSince(DateTime start) => _parcels
        .where(
          (parcel) =>
              !parcel.receivedTime.isBefore(start) &&
              !parcel.receivedTime.isAfter(now),
        )
        .length;
    String count(int value) => _loading || _loadError != null ? '—' : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              count(receivedSince(today)),
              'Today',
              const Color(0xFF0E4778),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              count(_collectedParcels.length),
              'Collected',
              const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              count(_pendingParcels.length),
              'Pending',
              const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              count(receivedSince(weekStart)),
              'This Week',
              const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Search by resident, unit, or tracking...',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(
                      Icons.clear,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSection() {
    final filteredParcels = _filteredPendingParcels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pending Pickup (${filteredParcels.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filteredParcels.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 56,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pending parcels',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredParcels.map(
            (parcel) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AbsorbPointer(
                absorbing: _collecting.contains(parcel.id),
                child: Opacity(
                  opacity: _collecting.contains(parcel.id) ? 0.6 : 1,
                  child: PendingParcelCard(
                    parcel: parcel,
                    onMarkAsCollected: () => _onMarkAsCollected(parcel),
                    onRemind: _onRemindResident,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCollectedSection() {
    final filteredParcels = _filteredCollectedParcels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recently Collected (${filteredParcels.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filteredParcels.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No collected parcels',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredParcels.map(
            (parcel) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CollectedParcelCard(parcel: parcel),
            ),
          ),
      ],
    );
  }
}
