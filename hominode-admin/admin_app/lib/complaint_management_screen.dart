import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'desktop/admin_desktop_page_frame.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/complaint_list_card.dart';
import 'widgets/standard_header.dart';
import 'models/complaint_models.dart';
import 'services/complaint_service.dart';

class ComplaintManagementScreen extends StatefulWidget {
  const ComplaintManagementScreen({super.key});

  @override
  State<ComplaintManagementScreen> createState() =>
      _ComplaintManagementScreenState();
}

class _ComplaintManagementScreenState extends State<ComplaintManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ComplaintService _complaintService = ComplaintService();
  String _selectedFilter = 'New'; // New (Pending), In Progress, Resolved

  List<ComplaintEntry> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  void _loadComplaints() {
    print('ComplaintManagementScreen: Loading complaints from Firestore');
    _complaintService.getComplaints().listen(
      (complaints) async {
        print(
          'ComplaintManagementScreen: Received ${complaints.length} complaints',
        );

        // Convert complaints and fetch flat numbers
        List<ComplaintEntry> entries = [];
        for (var complaint in complaints) {
          final entry = await _convertToComplaintEntry(complaint);
          entries.add(entry);
        }

        setState(() {
          _complaints = entries;
          _isLoading = false;
        });
      },
      onError: (error) {
        print('ComplaintManagementScreen ERROR: $error');
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<ComplaintEntry> _convertToComplaintEntry(
    ComplaintModel complaint,
  ) async {
    // Retained complaint history can outlive its canonical unit document.
    String unitNumber = complaint.flatLabel ?? complaint.flatId ?? 'N/A';
    if (complaint.flatLabel?.isNotEmpty != true &&
        complaint.flatId != null &&
        complaint.flatId!.isNotEmpty) {
      try {
        final flatDoc = await FirebaseFirestore.instance
            .collection('flats')
            .doc(complaint.flatId)
            .get();

        if (flatDoc.exists) {
          final flatData = flatDoc.data();
          unitNumber =
              (flatData?['flatLabel'] ??
                      flatData?['flatId'] ??
                      flatData?['flatNumber'] ??
                      unitNumber)
                  .toString();
          print(
            'ComplaintManagementScreen: Fetched flat number: $unitNumber for flatId: ${complaint.flatId}',
          );
        } else {
          unitNumber = complaint.flatId ?? 'N/A';
        }
      } catch (e) {
        print(
          'ComplaintManagementScreen ERROR: Failed to fetch flat number: $e',
        );
        unitNumber = complaint.flatId ?? 'N/A';
      }
    }

    // Fetch resident details from users collection using residentId
    String residentName = 'Unknown';
    if (complaint.residentId.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(complaint.residentId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          residentName =
              userData?['name'] ?? userData?['fullName'] ?? 'Unknown';
          print(
            'ComplaintManagementScreen: Fetched resident name: $residentName for residentId: ${complaint.residentId}',
          );
        } else {
          print(
            'ComplaintManagementScreen: User document not found for residentId: ${complaint.residentId}',
          );
          residentName = complaint.residentName ?? 'Unknown';
        }
      } catch (e) {
        print(
          'ComplaintManagementScreen ERROR: Failed to fetch resident details: $e',
        );
        residentName = complaint.residentName ?? 'Unknown';
      }
    } else {
      // Fallback to stored residentName if residentId is empty
      residentName = complaint.residentName ?? 'Unknown';
    }

    // Convert Firestore complaint to UI complaint model
    return ComplaintEntry(
      id: complaint.id,
      priority: _getPriorityFromString(complaint.priority),
      status: _getStatusFromString(complaint.status),
      title: complaint.title,
      residentName: residentName,
      unit: unitNumber,
      date: complaint.createdAt ?? DateTime.now(),
      category: _getCategoryFromString(complaint.category),
      description: complaint.description,
      assignedTo: complaint.assignedTo, // Use assignedTo from Firestore
    );
  }

  ComplaintPriority _getPriorityFromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return ComplaintPriority.high;
      case 'medium':
        return ComplaintPriority.medium;
      case 'low':
        return ComplaintPriority.low;
      default:
        return ComplaintPriority.medium;
    }
  }

  ComplaintStatus _getStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ComplaintStatus.pending;
      case 'in-progress':
      case 'in progress':
        return ComplaintStatus.inProgress;
      case 'resolved':
        return ComplaintStatus.resolved;
      default:
        return ComplaintStatus.pending;
    }
  }

  ComplaintCategory _getCategoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return ComplaintCategory.plumbing;
      case 'electrical':
        return ComplaintCategory.electrical;
      case 'cleaning':
        return ComplaintCategory.cleaning;
      case 'maintenance':
        return ComplaintCategory.maintenance;
      case 'security':
        return ComplaintCategory.security;
      case 'noise':
      case 'other':
        return ComplaintCategory.other;
      default:
        return ComplaintCategory.maintenance;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onComplaintUpdated(ComplaintEntry updatedComplaint) {
    setState(() {
      final index = _complaints.indexWhere((c) => c.id == updatedComplaint.id);
      if (index != -1) {
        _complaints[index] = updatedComplaint;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Complaints',
        subtitle: 'Track, filter, and update resident complaints.',
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatisticCards(),
                    SizedBox(height: 12.h),
                    _buildFilterTabs(),
                    SizedBox(height: 16.h),
                    _buildSearchAndActions(),
                    SizedBox(height: 16.h),
                    _buildComplaintList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E4778)),
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const StandardHeader(title: 'Complaint Management'),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      _buildStatisticCards(),
                      SizedBox(height: 12.h),
                      _buildFilterTabs(),
                      SizedBox(height: 16.h),
                      _buildSearchAndActions(),
                      SizedBox(height: 16.h),
                      _buildComplaintList(),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
              ],
            ),

      bottomNavigationBar: const StandardBottomNav(
        selectedIndex: 0,
      ), // Home since accessed from dashboard
    );
  }

  // Statistic Cards Row (following dashboard pattern)
  Widget _buildStatisticCards() {
    final activeComplaints = _complaints
        .where(
          (c) =>
              c.status == ComplaintStatus.pending ||
              c.status == ComplaintStatus.inProgress,
        )
        .length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.assignment,
              iconColor: const Color(0xFF0E4778),
              iconBg: const Color(0xFFE0EDFF),
              value: '$activeComplaints',
              label: 'Active Complaints',
              subtitle: 'Pending + In Progress',
              subtitleColor: const Color(0xFF0E4778),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              icon: Icons.pending_actions,
              iconColor: const Color(0xFFF59E0B),
              iconBg: const Color(0xFFFEF3C7),
              value: '${_getPendingComplaints()}',
              label: 'New Complaints',
              subtitle: 'Need attention',
              subtitleColor: const Color(0xFFF59E0B),
              onTap: () => _setFilter('New'),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              icon: Icons.work_outline,
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFEDE9FE),
              value: '${_getInProgressComplaints()}',
              label: 'In Progress',
              subtitle: 'Being resolved',
              subtitleColor: const Color(0xFF8B5CF6),
              onTap: () => _setFilter('In Progress'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
    required Color subtitleColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20.w),
            ),
            SizedBox(height: 6.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6A6A6A),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter Tabs
  Widget _buildFilterTabs() {
    final filters = ['New', 'In Progress', 'Resolved'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Expanded(
              child: GestureDetector(
                onTap: () => _setFilter(filter),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF0E4778)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Search and Actions
  Widget _buildSearchAndActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search complaints...',
                  hintStyle: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFF6B7280),
                    size: 20.w,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    // Real-time search filtering is handled in _getFilteredComplaints()
                  });
                },
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: IconButton(
              onPressed: _showFilterOptions,
              icon: Icon(Icons.tune, color: Colors.white, size: 20.w),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintList() {
    final filteredComplaints = _getFilteredComplaints();

    if (filteredComplaints.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredComplaints.length} Complaint${filteredComplaints.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              if (_selectedFilter != 'New')
                TextButton(
                  onPressed: () => _setFilter('New'),
                  child: Text(
                    'View New',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF0E4778)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          ...filteredComplaints.map(
            (complaint) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ComplaintListCard(
                complaint: complaint,
                onComplaintUpdated: _onComplaintUpdated,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(32.w),
      child: Column(
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(40.r),
            ),
            child: Icon(Icons.search_off, size: 40.w, color: Color(0xFF9CA3AF)),
          ),
          SizedBox(height: 16.h),
          Text(
            'No $_selectedFilter complaints',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'All complaints in this category have been handled',
            style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper Methods
  List<ComplaintEntry> _getFilteredComplaints() {
    List<ComplaintEntry> filtered = List.from(_complaints);

    // Apply status filter
    ComplaintStatus? status;
    switch (_selectedFilter) {
      case 'New':
        status = ComplaintStatus.pending;
        break;
      case 'In Progress':
        status = ComplaintStatus.inProgress;
        break;
      case 'Resolved':
        status = ComplaintStatus.resolved;
        break;
    }

    if (status != null) {
      filtered = filtered.where((c) => c.status == status).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((complaint) {
        return complaint.id.toLowerCase().contains(searchTerm) ||
            complaint.title.toLowerCase().contains(searchTerm) ||
            complaint.residentName.toLowerCase().contains(searchTerm) ||
            complaint.unit.toLowerCase().contains(searchTerm);
      }).toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Options',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 16.h),
            _buildFilterOption('New Complaints', 'New'),
            _buildFilterOption('In Progress', 'In Progress'),
            _buildFilterOption('Resolved', 'Resolved'),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, String filter) {
    final isSelected = _selectedFilter == filter;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFF0E4778) : const Color(0xFF9CA3AF),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: isSelected ? const Color(0xFF0E4778) : const Color(0xFF374151),
        ),
      ),
      onTap: () {
        _setFilter(filter);
        Navigator.pop(context);
      },
    );
  }

  int _getPendingComplaints() {
    return _complaints.where((c) => c.status == ComplaintStatus.pending).length;
  }

  int _getInProgressComplaints() {
    return _complaints
        .where((c) => c.status == ComplaintStatus.inProgress)
        .length;
  }

  int _getResolvedComplaints() {
    return _complaints
        .where((c) => c.status == ComplaintStatus.resolved)
        .length;
  }
}
