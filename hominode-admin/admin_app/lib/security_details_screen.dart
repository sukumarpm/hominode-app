import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/security_service.dart';
import 'widgets/assign_security_work_modal.dart';

class SecurityDetailsScreen extends StatelessWidget {
  final SecurityStaff staff;

  const SecurityDetailsScreen({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Security Details',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF0E4778)),
            onPressed: () {
              _showAssignWorkModal(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            _buildProfileSection(),
            SizedBox(height: 20.h),
            _buildInfoCards(),
            SizedBox(height: 20.h),
            _buildPersonalInfo(),
            SizedBox(height: 20.h),
            if (staff.specialInstructions != null) _buildSpecialInstructions(),
            if (staff.specialInstructions != null) SizedBox(height: 20.h),
            _buildEmergencyContact(),
            SizedBox(height: 20.h),
            _buildActionButtons(context),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      width: double.infinity, // Full width
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center align
        children: [
          // Profile Picture
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE0EDFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0E4778), width: 3),
            ),
            child: staff.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      staff.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Color(0xFF0E4778),
                          size: 50.w,
                        );
                      },
                    ),
                  )
                : Icon(Icons.person, color: Color(0xFF0E4778), size: 50.w),
          ),
          SizedBox(height: 16.h),
          // Name
          Text(
            staff.name,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          // Role
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE0EDFF),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              staff.role,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0E4778),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Status Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: staff.getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: staff.getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  staff.getStatusDisplay(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: staff.getStatusColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              icon: Icons.access_time,
              iconColor: const Color(0xFF0E4778),
              iconBg: const Color(0xFFE0EDFF),
              label: 'Shift',
              value: staff.shiftTiming ?? 'Not assigned',
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.location_on,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFD1FAE5),
              label: 'Gate',
              value: staff.gateAssignment ?? 'Not assigned',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24.w),
          ),
          SizedBox(height: 12.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 16.h),
          _buildDetailRow(
            icon: Icons.phone,
            label: 'Phone',
            value: staff.phone,
          ),
          if (staff.email != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.email,
              label: 'Email',
              value: staff.email!,
            ),
          ],
          if (staff.address != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.home,
              label: 'Address',
              value: staff.address!,
            ),
          ],
          if (staff.aadharNumber != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.credit_card,
              label: 'Aadhar Number',
              value: staff.aadharNumber!,
            ),
          ],
          if (staff.joiningDate != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Joining Date',
              value: _formatDate(staff.joiningDate!),
            ),
          ],
          if (staff.salary != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.currency_rupee,
              label: 'Salary',
              value: '₹${staff.salary!.toStringAsFixed(0)}/month',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecialInstructions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Color(0xFFF59E0B),
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Special Instructions',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              staff.specialInstructions!,
              style: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF111827),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact() {
    if (staff.emergencyContact == null && staff.emergencyPhone == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.emergency,
                  color: Color(0xFFEF4444),
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Emergency Contact',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (staff.emergencyContact != null)
            _buildDetailRow(
              icon: Icons.person,
              label: 'Contact Name',
              value: staff.emergencyContact!,
            ),
          if (staff.emergencyPhone != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.phone,
              label: 'Contact Phone',
              value: staff.emergencyPhone!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36.w,
          height: 36.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 18.w, color: const Color(0xFF6B7280)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showAssignWorkModal(context);
              },
              icon: Icon(Icons.assignment, size: 20.w),
              label: const Text('Assign Work'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E4778),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement call functionality
                  },
                  icon: Icon(Icons.phone, size: 18.w),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0E4778),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    side: const BorderSide(color: Color(0xFF0E4778)),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement message functionality
                  },
                  icon: Icon(Icons.message, size: 18.w),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    side: const BorderSide(color: Color(0xFF10B981)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignWorkModal(BuildContext context) {
    AssignSecurityWorkModal.show(context, staff);
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final date = _formatDate(dateTime);
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$date at $hour:$minute $period';
  }
}
