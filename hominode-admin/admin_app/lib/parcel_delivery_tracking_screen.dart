import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/parcel_entry.dart';
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

  // Mock data for parcels
  final List<ParcelEntry> _pendingParcels = [
    ParcelEntry(
      id: '1',
      residentName: 'Priya Sharma',
      unit: 'E-305',
      courier: 'Flipkart',
      trackingId: 'FLP987654321O',
      receivedTime: DateTime(2025, 11, 2, 11, 45),
      status: ParcelStatus.pending,
      isResidentNotified: true,
    ),
    ParcelEntry(
      id: '2',
      residentName: 'Rajesh Kumar',
      unit: 'A-204',
      courier: 'Amazon',
      trackingId: 'AMZ123456789O',
      receivedTime: DateTime(2025, 11, 2, 14, 30),
      status: ParcelStatus.pending,
      isResidentNotified: true,
    ),
  ];

  final List<ParcelEntry> _collectedParcels = [
    ParcelEntry(
      id: '3',
      residentName: 'Amit Patel',
      unit: 'C-102',
      courier: 'Delivery',
      trackingId: '',
      receivedTime: DateTime(2025, 11, 1, 9, 15),
      collectedTime: DateTime(2025, 11, 1, 18, 30),
      status: ParcelStatus.collected,
      isResidentNotified: false,
    ),
    ParcelEntry(
      id: '4',
      residentName: 'Sneha Reddy',
      unit: 'D-401',
      courier: 'Bluedart',
      trackingId: '',
      receivedTime: DateTime(2025, 11, 1, 9, 15),
      collectedTime: DateTime(2025, 11, 1, 18, 30),
      status: ParcelStatus.collected,
      isResidentNotified: false,
    ),
  ];

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
          parcel.unit.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _onLogParcel() {
    HapticFeedback.mediumImpact();
    LogNewParcelDialog.show(
      context,
      onParcelAdded: (parcel) {
        setState(() {
          _pendingParcels.insert(0, parcel);
        });
      },
    );
  }

  void _onMarkAsCollected(String parcelId) {
    HapticFeedback.lightImpact();

    final parcel = _pendingParcels.firstWhere((p) => p.id == parcelId);
    setState(() {
      _pendingParcels.removeWhere((p) => p.id == parcelId);
      parcel.status = ParcelStatus.collected;
      parcel.collectedTime = DateTime.now();
      _collectedParcels.insert(0, parcel);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('${parcel.residentName} parcel marked as collected'),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onRemindResident(String parcelId) {
    HapticFeedback.lightImpact();

    final parcel = _pendingParcels.firstWhere((p) => p.id == parcelId);

    // TODO: Send SMS / App notification to resident
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Reminder sent to ${parcel.residentName}'),
          ],
        ),
        backgroundColor: const Color(0xFF0E4778),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                // Pending Pickup Section
                _buildPendingSection(),

                const SizedBox(height: 24),

                // Recently Collected Section
                _buildCollectedSection(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Parcel Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
            onPressed: _onLogParcel,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard('8', 'Today', const Color(0xFF0E4778)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard('5', 'Inside Now', const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              '${_pendingParcels.length}',
              'Pending',
              const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard('42', 'This Week', const Color(0xFF7C3AED)),
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
              child: PendingParcelCard(
                parcel: parcel,
                onMarkAsCollected: () => _onMarkAsCollected(parcel.id),
                onRemind: () => _onRemindResident(parcel.id),
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
