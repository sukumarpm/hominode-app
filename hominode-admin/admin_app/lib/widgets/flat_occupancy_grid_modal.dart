import '../models/unit_schema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Data models
enum FlatStatus { occupied, reserved, vacant, maintenance }

class FlatUnit {
  final HousingUnitType unitType;
  final int? unitIndex;
  bool get usesFloors => unitIndex == null;
  final String id; // Sequential ID like "T001", "A101"
  final String docId; // Firestore document ID
  final String type;
  String? residentName;
  final String? residentUserId;
  FlatStatus status;
  final int floor;
  final String? reservedOnboardingId;
  final String? reservedForName;
  final String? reservedResidentType;
  final String area; // e.g., "1500 Sqft"

  FlatUnit({
    this.unitType = HousingUnitType.apartment,
    this.unitIndex,
    required this.id,
    required this.docId,
    required this.type,
    this.residentName,
    this.residentUserId,
    required this.status,
    required this.floor,
    this.reservedOnboardingId,
    this.reservedForName,
    this.reservedResidentType,
    required this.area,
  });

  /// Update flat status (e.g., when resident is assigned)
  void updateStatus(FlatStatus newStatus, {String? newResidentName}) {
    status = newStatus;
    if (newResidentName != null) {
      residentName = newResidentName;
    }
  }
}

class FloorOccupancy {
  final int floorNumber;
  final List<FlatUnit> flats;

  FloorOccupancy({required this.floorNumber, required this.flats});
}

enum ViewMode { grid, list }

class FlatOccupancyGridModal extends StatefulWidget {
  final String towerName;
  final Stream<List<FloorOccupancy>> dataStream;
  final void Function(FlatUnit unit) onFlatTap;

  const FlatOccupancyGridModal({
    super.key,
    required this.towerName,
    required this.dataStream,
    required this.onFlatTap,
  });

  static Future<void> show(
    BuildContext context, {
    required String towerName,
    required Stream<List<FloorOccupancy>> dataStream,
    required void Function(FlatUnit unit) onFlatTap,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatOccupancyGridModal(
          towerName: towerName,
          dataStream: dataStream,
          onFlatTap: onFlatTap,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FlatOccupancyGridModal> createState() => _FlatOccupancyGridModalState();
}

class _FlatOccupancyGridModalState extends State<FlatOccupancyGridModal> {
  ViewMode _viewMode = ViewMode.grid;
  String _searchQuery = '';
  FlatStatus? _statusFilter;

  List<FloorOccupancy> _filterData(List<FloorOccupancy> source) {
    return source
        .map((floor) {
          final filteredFlats = floor.flats.where((flat) {
            final query = _searchQuery.toLowerCase();

            final matchesSearch =
                _searchQuery.isEmpty ||
                flat.id.toLowerCase().contains(query) ||
                (flat.residentName?.toLowerCase().contains(query) ?? false) ||
                (flat.reservedForName?.toLowerCase().contains(query) ?? false);

            final matchesStatus =
                _statusFilter == null || flat.status == _statusFilter;

            return matchesSearch && matchesStatus;
          }).toList();

          return FloorOccupancy(
            floorNumber: floor.floorNumber,
            flats: filteredFlats,
          );
        })
        .where((floor) => floor.flats.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 500
              ? 460
              : MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          elevation: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Expanded(
                child: StreamBuilder<List<FloorOccupancy>>(
                  stream: widget.dataStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFEF4444),
                                size: 40,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Unable to load units.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data ?? const <FloorOccupancy>[];

                    if (data.isEmpty) {
                      return Center(
                        child: Text(
                          'No units found in this building.',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildViewToggle(),
                          SizedBox(height: 14.h),
                          _buildLegend(),
                          SizedBox(height: 14.h),
                          _buildSearchAndFilter(),
                          SizedBox(height: 16.h),

                          _viewMode == ViewMode.grid
                              ? _buildGridView(data)
                              : _buildListView(data),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 32.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.towerName} - Unit Occupancy',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Visual representation of all units. Click on any unit to view or edit details.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Semantics(
              label: 'Close occupancy grid',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  width: 36.w,
                  height: 36.h,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 20.w,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(26.r),
      ),
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Grid View',
              isActive: _viewMode == ViewMode.grid,
              onTap: () => setState(() => _viewMode = ViewMode.grid),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              label: 'List View',
              isActive: _viewMode == ViewMode.list,
              onTap: () => setState(() => _viewMode = ViewMode.list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 9.h),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(23.r),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _buildLegendItem('Occupied', const Color(0xFF10B981)),
        _buildLegendItem('Reserved', const Color(0xFF3B82F6)),
        _buildLegendItem('Vacant', const Color(0xFFD1D5DB)),
        _buildLegendItem('Maintenance', const Color(0xFFFBBF24)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: 'Search by unit or resident',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.sp),
              prefixIcon: Icon(
                Icons.search,
                color: Color(0xFF9CA3AF),
                size: 20.w,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFF0E4778)),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(flex: 3, child: _buildStatusFilter()),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return PopupMenuButton<FlatStatus?>(
      initialValue: _statusFilter,
      onSelected: (value) => setState(() => _statusFilter = value),
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _statusFilter == null ? 'All' : _getStatusLabel(_statusFilter!),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16.w,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All')),
        const PopupMenuItem(
          value: FlatStatus.occupied,
          child: Text('Occupied'),
        ),
        const PopupMenuItem(value: FlatStatus.vacant, child: Text('Vacant')),
        const PopupMenuItem(
          value: FlatStatus.maintenance,
          child: Text('Maintenance'),
        ),
        const PopupMenuItem(
          value: FlatStatus.reserved,
          child: Text('Reserved'),
        ),
      ],
    );
  }

  String _getStatusLabel(FlatStatus status) {
    switch (status) {
      case FlatStatus.occupied:
        return 'Occupied';
      case FlatStatus.reserved:
        return 'Reserved';
      case FlatStatus.vacant:
        return 'Vacant';
      case FlatStatus.maintenance:
        return 'Maintenance';
    }
  }

  Widget _buildGridView(List<FloorOccupancy> source) {
    final filteredData = _filterData(source);

    if (filteredData.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Text(
            'No units found',
            style: TextStyle(fontSize: 16.sp, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filteredData.map((floor) {
        return Padding(
          padding: EdgeInsets.only(bottom: 18.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  floor.floorNumber == 0
                      ? 'Units'
                      : 'Floor ${floor.floorNumber}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: floor.flats.length,
                itemBuilder: (context, index) {
                  return _buildFlatTile(floor.flats[index]);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlatTile(FlatUnit flat) {
    final color = _getFlatColor(flat.status);
    final textColor = flat.status == FlatStatus.vacant
        ? const Color(0xFF6B7280)
        : Colors.white;

    return Semantics(
      label: 'Flat ${flat.id} ${_getStatusLabel(flat.status)} ${flat.type}',
      button: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: () => widget.onFlatTap(flat),
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  flat.id,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  flat.type,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  flat.residentName ?? 'Vacant',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w400,
                    color: textColor.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<FloorOccupancy> source) {
    final filteredData = _filterData(source);

    if (filteredData.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Text(
            'No units found',
            style: TextStyle(fontSize: 16.sp, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filteredData.map((floor) {
        return Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  floor.floorNumber == 0
                      ? 'Units'
                      : 'Floor ${floor.floorNumber}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              ...floor.flats.map(
                (flat) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _buildFlatListItem(flat),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlatListItem(FlatUnit flat) {
    final color = _getFlatColor(flat.status);
    final textColor = flat.status == FlatStatus.vacant
        ? const Color(0xFF6B7280)
        : Colors.white;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: () => widget.onFlatTap(flat),
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flat.id,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${flat.type} • ${_getStatusLabel(flat.status)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (flat.residentName != null)
                Text(
                  flat.residentName!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFlatColor(FlatStatus status) {
    switch (status) {
      case FlatStatus.occupied:
        return const Color(0xFF10B981);
      case FlatStatus.vacant:
        return const Color(0xFFE5E7EB);
      case FlatStatus.maintenance:
        return const Color(0xFFFBBF24);
      case FlatStatus.reserved:
        return const Color(0xFF3B82F6); // Blue color for reserved flats
    }
  }
}
