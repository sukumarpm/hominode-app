import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/edit_vendor_modal.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'services/staff_vendor_service.dart';

class VendorDetailsScreen extends StatefulWidget {
  final String vendorId;

  const VendorDetailsScreen({super.key, required this.vendorId});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  final StaffVendorService _service = StaffVendorService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VendorModel?>(
      future: _service.getVendorById(widget.vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Vendor Details',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading vendor details',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final vendor = snapshot.data!;
        return _buildVendorDetails(vendor);
      },
    );
  }

  Widget _buildVendorDetails(VendorModel vendor) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Vendor Details',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF0E4778)),
            onPressed: () => _handleEdit(vendor),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            onPressed: () => _handleDelete(vendor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Profile Image
                  Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(40.r),
                    ),
                    child: Icon(
                      Icons.business,
                      size: 40.w,
                      color: Color(0xFF0E4778),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Business Name
                  Text(
                    vendor.businessName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 8.h),

                  // Category Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      vendor.category,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 20.w, color: Color(0xFFFBBF24)),
                      SizedBox(width: 4.w),
                      Text(
                        vendor.rating.toString(),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '(${vendor.totalServices} services)',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Contact Information
            _buildSection(
              title: 'Contact Information',
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.person_outline,
                    label: 'Contact Person',
                    value: vendor.contactPerson,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: vendor.phone,
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: Color(0xFF0E4778)),
                      onPressed: () => _makePhoneCall(vendor.phone),
                    ),
                  ),
                  if (vendor.email != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: vendor.email!,
                    ),
                  ],
                  if (vendor.address != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: vendor.address!,
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Contract Details
            if (vendor.contractStartDate != null) ...[
              _buildSection(
                title: 'Contract Details',
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Start Date',
                      value: _formatDate(vendor.contractStartDate!),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.event_outlined,
                      label: 'End Date',
                      value: _formatDate(vendor.contractEndDate!),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Status',
                      value: _getContractStatus(vendor),
                      valueColor: _getContractStatusColor(vendor),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],

            // Services Provided
            if (vendor.services.isNotEmpty) ...[
              _buildSection(
                title: 'Services Provided',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vendor.services.map((service) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        service,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 12.h),
            ],

            // Performance Stats
            _buildSection(
              title: 'Performance',
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Total Services',
                      value: vendor.totalServices.toString(),
                      icon: Icons.build_outlined,
                      color: const Color(0xFF0E4778),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Rating',
                      value: vendor.rating.toString(),
                      icon: Icons.star_outline,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 20.w, color: const Color(0xFF6B7280)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24.w, color: color),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getContractStatus(VendorModel vendor) {
    if (vendor.contractEndDate == null) return 'N/A';
    final now = DateTime.now();
    if (now.isAfter(vendor.contractEndDate!)) {
      return 'Expired';
    } else if (now.isBefore(vendor.contractStartDate!)) {
      return 'Upcoming';
    } else {
      return 'Active';
    }
  }

  Color _getContractStatusColor(VendorModel vendor) {
    final status = _getContractStatus(vendor);
    switch (status) {
      case 'Active':
        return const Color(0xFF16A34A);
      case 'Expired':
        return const Color(0xFFDC2626);
      case 'Upcoming':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // TODO: Implement phone dialer using url_launcher package
    // Add url_launcher to pubspec.yaml first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $phoneNumber...'),
        backgroundColor: const Color(0xFF0E4778),
      ),
    );
  }

  Future<void> _handleEdit(VendorModel vendor) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditVendorModal(vendor: vendor),
    );

    if (result == true) {
      // Refresh vendor data by rebuilding the FutureBuilder
      setState(() {});
    }
  }

  Future<void> _handleDelete(VendorModel vendor) async {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Vendor',
        message:
            'Are you sure you want to delete this vendor? This action cannot be undone.',
        itemName: vendor.businessName,
        confirmButtonText: 'Delete Vendor',
        requireReason: true,
        onConfirm: () async {
          try {
            await _service.deleteVendor(vendor.id);
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Go back to vendor list
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vendor deleted successfully'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
          } catch (e) {
            Navigator.of(context).pop(); // Close dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting vendor: $e'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        },
      ),
    );
  }
}
