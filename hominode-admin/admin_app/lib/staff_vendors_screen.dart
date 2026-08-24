import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'models/vendor_models.dart';
import 'widgets/add_vendor_modal.dart';
import 'widgets/standard_header.dart';
import 'vendor_details_screen.dart';
import 'services/staff_vendor_service.dart';

class StaffVendorsScreen extends StatefulWidget {
  const StaffVendorsScreen({super.key});

  @override
  State<StaffVendorsScreen> createState() => _StaffVendorsScreenState();
}

class _StaffVendorsScreenState extends State<StaffVendorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _service = StaffVendorService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddVendorModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: const Color(
        0x59000000,
      ), // Semi-transparent black (35% opacity)
      builder: (BuildContext context) {
        return const AddVendorModal();
      },
    ).then((result) {
      if (result == true) {
        // No need to manually refresh - StreamBuilder handles it automatically
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor added successfully'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _makePhoneCall(String phoneNumber, String vendorName) {
    // TODO: Implement actual phone dialer using url_launcher
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $vendorName at $phoneNumber...'),
        backgroundColor: const Color(0xFF0E4778),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Cancel',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Widget _buildVendorCard(VendorModel vendor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VendorDetailsScreen(vendorId: vendor.id),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: const Color(0xFF0E4778).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.business, color: Color(0xFF0E4778), size: 24.w),
            ),
            SizedBox(width: 12.w),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.businessName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${vendor.category} • ${vendor.contactPerson}',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            // Call button
            IconButton(
              onPressed: () =>
                  _makePhoneCall(vendor.phone, vendor.businessName),
              icon: Icon(Icons.phone, color: Color(0xFF0E4778), size: 20.w),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(
            title: 'Vendor Management',
            showBackButton: true,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),

                // Header Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E4778).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.business,
                          color: Color(0xFF0E4778),
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vendor Management',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Manage vendor information',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // Add Vendor Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () => _showAddVendorModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E4778),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Add Vendor',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Search Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, category, or phone...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                          size: 20.w,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 20.w),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // Vendor List with StreamBuilder
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: StreamBuilder<List<VendorModel>>(
                    stream: _service.getVendors(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0.w),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0.w),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64.w,
                                  color: Color(0xFFEF4444),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Error loading vendors',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final vendors = snapshot.data ?? [];

                      // Filter vendors based on search
                      final filteredVendors = _searchQuery.isEmpty
                          ? vendors
                          : vendors.where((vendor) {
                              return vendor.businessName.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  vendor.category.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  vendor.contactPerson.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  vendor.phone.contains(_searchQuery);
                            }).toList();

                      if (filteredVendors.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.w),
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.business
                                      : Icons.search_off,
                                  size: 64.w,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No vendors added yet'
                                      : 'No vendors found',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Add your first vendor using the button above'
                                      : 'Try adjusting your search',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: filteredVendors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final vendor = entry.value;
                          return Column(
                            children: [
                              if (index > 0) SizedBox(height: 12.h),
                              _buildVendorCard(vendor),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                SizedBox(height: 80.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Vendor Card Widget
class VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;
  final Function(String, String)? onCallPressed;

  const VendorCard({
    super.key,
    required this.vendor,
    this.onTap,
    this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Avatar
                Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCECFE),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: vendor.profileImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.network(
                            vendor.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.business,
                                color: const Color(0xFF0E4778).withOpacity(0.5),
                                size: 28.w,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.business,
                          color: const Color(0xFF0E4778).withOpacity(0.5),
                          size: 28.w,
                        ),
                ),

                SizedBox(width: 12.w),

                // Name and Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vendor.businessName,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Rating
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Color(0xFFFACC15),
                                size: 16.w,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                vendor.rating.toString(),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Category Chip
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          vendor.category,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Contact Information
            Row(
              children: [
                Icon(Icons.person_outline, size: 16.w, color: Colors.grey[500]),
                SizedBox(width: 6.w),
                Text(
                  'Contact: ${vendor.contactPerson}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            SizedBox(height: 4.h),

            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16.w, color: Colors.grey[500]),
                SizedBox(width: 6.w),
                Text(
                  vendor.phone,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Action Buttons Row
            Row(
              children: [
                // Call Vendor Button
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (onCallPressed != null) {
                          onCallPressed!(vendor.phone, vendor.businessName);
                        }
                      },
                      icon: Icon(
                        Icons.phone,
                        size: 18.w,
                        color: Color(0xFF0E4778),
                      ),
                      label: Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0E4778),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0E4778)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12.w),

                // View Details Button
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 18.w,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E4778),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
