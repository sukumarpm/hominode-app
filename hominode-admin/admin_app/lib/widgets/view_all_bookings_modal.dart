import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/amenity_service.dart';

class ViewAllBookingsModal extends StatefulWidget {
  const ViewAllBookingsModal({super.key});

  @override
  State<ViewAllBookingsModal> createState() => _ViewAllBookingsModalState();
}

class _ViewAllBookingsModalState extends State<ViewAllBookingsModal> {
  final AmenityService _amenityService = AmenityService();
  String _selectedFilter = 'all'; // all, pending, approved, rejected, cancelled

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                // Title and Close
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All Bookings',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Pending', 'pending'),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Approved', 'approved'),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Rejected', 'rejected'),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Cancelled', 'cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bookings List
          Expanded(
            child: StreamBuilder<List<AmenityBookingModel>>(
              stream: _amenityService.getBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48.w,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Error loading bookings',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  );
                }

                var bookings = snapshot.data ?? [];

                // Apply filter
                if (_selectedFilter != 'all') {
                  bookings = bookings
                      .where((b) => b.status.toLowerCase() == _selectedFilter)
                      .toList();
                }

                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 56.w,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          _selectedFilter == 'all'
                              ? 'No bookings yet'
                              : 'No $_selectedFilter bookings',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(20.w),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
                      child: _buildFullBookingCard(bookings[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0E4778) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0E4778)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildFullBookingCard(AmenityBookingModel booking) {
    return Container(
      padding: EdgeInsets.all(20.w),
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
          // Header - Amenity Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.amenityName,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (booking.buildingName.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.apartment,
                            size: 14.w,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            booking.buildingName,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: booking.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  booking.statusDisplay,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: booking.statusColor,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),
          const Divider(height: 1),
          SizedBox(height: 16.h),

          // Booking ID
          _buildInfoRow(
            icon: Icons.confirmation_number,
            label: 'Booking ID',
            value: booking.id.substring(0, 8).toUpperCase(),
          ),

          SizedBox(height: 12.h),

          // Date and Time
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Booking Date',
            value: booking.formattedDate,
          ),

          if (booking.formattedTime.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Time Slot',
              value: booking.formattedTime,
            ),
          ],

          // Package/Subscription Information
          if (booking.packageType != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFF0E4778).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.card_membership,
                        size: 18.w,
                        color: Color(0xFF0E4778),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Package Details',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0E4778),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildDetailRow('Type', booking.packageDisplay),
                  if (booking.packageDurationDisplay.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow('Validity', booking.packageDurationDisplay),
                  ],
                  if (booking.packageDurationDays != null) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow(
                      'Duration',
                      '${booking.packageDurationDays} days',
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Resident Information
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10.r),
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
                        color: const Color(0xFF0E4778).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 22.w,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resident Information',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (booking.totalMembers > 1) ...[
                            SizedBox(height: 2.h),
                            Text(
                              booking.membersDisplay,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildDetailRow('Name', booking.residentName),
                SizedBox(height: 6.h),
                _buildDetailRow('Flat', booking.flatLabel),
                SizedBox(height: 6.h),
                _buildDetailRow('Phone', booking.phone),
                if (booking.email != null && booking.email!.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  _buildDetailRow('Email', booking.email!),
                ],

                // Family Members
                if (booking.familyMemberNames != null &&
                    booking.familyMemberNames!.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  const Divider(height: 1),
                  SizedBox(height: 10.h),
                  Text(
                    'Family Members:',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ...booking.familyMemberNames!.map(
                    (name) => Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16.w,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Capacity Information
          if (booking.capacityDisplay.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.groups, size: 18.w, color: Color(0xFF10B981)),
                      SizedBox(width: 8.w),
                      Text(
                        'Capacity Information',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildDetailRow('Slot Status', booking.capacityDisplay),
                  if (booking.slotCapacity != null) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow(
                      'Max Capacity',
                      '${booking.slotCapacity} people',
                    ),
                  ],
                  if (booking.currentBookings != null) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow(
                      'Current Bookings',
                      '${booking.currentBookings}',
                    ),
                  ],
                  if (booking.spotsRemaining != null) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow(
                      'Spots Remaining',
                      '${booking.spotsRemaining}',
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Payment Information
          if (booking.amount > 0) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFF4A100).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.currency_rupee,
                        size: 18.w,
                        color: Color(0xFFF4A100),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Payment Information',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF4A100),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildDetailRow(
                    'Amount',
                    '₹${booking.amount.toStringAsFixed(0)}',
                  ),
                  if (booking.paymentStatus != null) ...[
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status:',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: booking.paymentStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            booking.paymentStatus!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: booking.paymentStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (booking.paymentMethod != null) ...[
                    SizedBox(height: 6.h),
                    _buildDetailRow(
                      'Method',
                      booking.paymentMethod!.toUpperCase(),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Additional Information
          if (booking.bookingType != null || booking.notes != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFF4A100).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18.w,
                        color: Color(0xFFF4A100),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Additional Information',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF4A100),
                        ),
                      ),
                    ],
                  ),
                  if (booking.bookingType != null) ...[
                    SizedBox(height: 10.h),
                    _buildDetailRow(
                      'Booking Type',
                      booking.bookingType!.toUpperCase(),
                    ),
                  ],
                  if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Text(
                      'Notes:',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      booking.notes!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Timestamps
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 10.h),
                if (booking.createdAt != null) ...[
                  _buildTimestampRow('Created', booking.createdAt!),
                ],
                if (booking.bookedAt != null) ...[
                  SizedBox(height: 6.h),
                  _buildTimestampRow('Booked', booking.bookedAt!),
                ],
                if (booking.approvedAt != null) ...[
                  SizedBox(height: 6.h),
                  _buildTimestampRow('Approved', booking.approvedAt!),
                ],
                if (booking.rejectedAt != null) ...[
                  SizedBox(height: 6.h),
                  _buildTimestampRow('Rejected', booking.rejectedAt!),
                ],
                if (booking.cancelledAt != null) ...[
                  SizedBox(height: 6.h),
                  _buildTimestampRow('Cancelled', booking.cancelledAt!),
                ],
                if (booking.updatedAt != null) ...[
                  SizedBox(height: 6.h),
                  _buildTimestampRow('Last Updated', booking.updatedAt!),
                ],
              ],
            ),
          ),

          // Rejection Reason
          if (booking.rejectionReason != null &&
              booking.rejectionReason!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 18.w,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Rejection Reason',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    booking.rejectionReason!,
                    style: TextStyle(fontSize: 13.sp, color: Color(0xFF991B1B)),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons
          if (booking.status == 'pending') ...[
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectBooking(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (booking.status == 'approved' ||
              booking.status == 'confirmed') ...[
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Cancel Booking',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18.w, color: const Color(0xFF6B7280)),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
              ),
              SizedBox(height: 2.h),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTimestampRow(String label, DateTime timestamp) {
    final formatted =
        '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
        ),
        Text(
          formatted,
          style: TextStyle(fontSize: 12.sp, color: Color(0xFF374151)),
        ),
      ],
    );
  }

  Future<void> _approveBooking(AmenityBookingModel booking) async {
    try {
      await _amenityService.approveBooking(booking.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _rejectBooking(AmenityBookingModel booking) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Booking'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Enter rejection reason',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      try {
        await _amenityService.rejectBooking(
          booking.id,
          reason.isEmpty ? null : reason,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking rejected'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelBooking(AmenityBookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel this booking for ${booking.residentName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _amenityService.cancelBooking(booking.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}
