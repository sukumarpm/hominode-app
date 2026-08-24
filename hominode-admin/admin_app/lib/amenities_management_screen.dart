import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';
import 'services/amenity_service.dart';
import 'widgets/standard_header.dart';
import 'widgets/custom_segmented_control.dart';
import 'widgets/add_amenity_modal.dart';
import 'widgets/edit_amenity_modal.dart';
import 'widgets/view_all_bookings_modal.dart';

class AmenitiesManagementScreen extends StatefulWidget {
  const AmenitiesManagementScreen({super.key});

  @override
  State<AmenitiesManagementScreen> createState() =>
      _AmenitiesManagementScreenState();
}

class _AmenitiesManagementScreenState extends State<AmenitiesManagementScreen> {
  final AmenityService _amenityService = AmenityService();
  int selectedTab = 0; // 0 = Amenities, 1 = Bookings

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const StandardAppBar(
        title: 'Amenities Management',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Section Header
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Manage property amenities',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Tab Switcher
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0.w),
            child: SegmentedControlExamples.amenitiesSegmentedControl(
              selectedIndex: selectedTab,
              onChanged: (index) {
                setState(() {
                  selectedTab = index;
                });
              },
            ),
          ),

          SizedBox(height: 20.h),

          // Create Button (Dynamic based on selected tab)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0.w),
            child: PrimaryButton(
              text: selectedTab == 0 ? 'Add Amenity' : 'View All Bookings',
              onPressed: () async {
                if (selectedTab == 0) {
                  _showAddAmenityModal();
                } else {
                  _showAllBookingsModal();
                }
              },
            ),
          ),

          SizedBox(height: 20.h),

          // Content (Expanded to fill remaining space)
          Expanded(
            child: selectedTab == 0
                ? _buildAmenitiesTab()
                : _buildBookingsTab(),
          ),
        ],
      ),
    );
  }

  // Amenities Tab
  Widget _buildAmenitiesTab() {
    return StreamBuilder<List<AmenityModel>>(
      stream: _amenityService.getAmenities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.w, color: Color(0xFFEF4444)),
                SizedBox(height: 16.h),
                Text(
                  'Error loading amenities: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        final amenities = snapshot.data ?? [];

        if (amenities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment, size: 56.w, color: Colors.grey[400]),
                SizedBox(height: 12.h),
                Text(
                  'No amenities yet',
                  style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Add your first amenity to get started',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 80.h),
          itemCount: amenities.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.0.h),
              child: _buildAmenityCard(amenities[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildAmenityCard(AmenityModel amenity) {
    return Container(
      padding: EdgeInsets.all(20.0.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row - Icon, Title and Status
          Row(
            children: [
              // Icon
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: amenity.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(amenity.icon, color: amenity.color, size: 24.w),
              ),
              SizedBox(width: 12.w),
              // Title and Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amenity.name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      amenity.buildingName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      amenity.priceDisplay,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: amenity.isFree
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0E4778),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: amenity.isAvailable
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  amenity.isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: amenity.isAvailable
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Category Tag
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              border: Border.all(color: amenity.color),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              amenity.type,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: amenity.color,
              ),
            ),
          ),

          if (amenity.description != null &&
              amenity.description!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              amenity.description!,
              style: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Booking Configuration Info
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, size: 16.w, color: Color(0xFF6B7280)),
                    SizedBox(width: 6.w),
                    Text(
                      amenity.capacityDisplay,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (amenity.allowMultipleBookings) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'Multiple bookings',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (amenity.bookingDurations.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16.w,
                        color: Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          amenity.bookingDurations.join(', '),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Time Slots (if available)
          if (amenity.timeSlots != null && amenity.timeSlots!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenity.timeSlots!.take(3).map((slot) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16.w,
                        color: Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        slot,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (amenity.timeSlots!.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  '+${amenity.timeSlots!.length - 3} more slots',
                  style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
                ),
              ),
          ],

          SizedBox(height: 16.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _toggleAvailability(amenity),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    amenity.isAvailable ? 'Mark Unavailable' : 'Mark Available',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: () => _editAmenity(amenity),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EBFF),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFF0E4778).withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20.w,
                    color: Color(0xFF0E4778),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _deleteAmenity(amenity),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20.w,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bookings Tab
  Widget _buildBookingsTab() {
    return _BookingsCalendarView(amenityService: _amenityService);
  }

  Widget _buildBookingCard(AmenityBookingModel booking) {
    return Container(
      padding: EdgeInsets.all(20.0.w),
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
                        fontSize: 16.sp,
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
                              fontSize: 12.sp,
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
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: booking.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  booking.statusDisplay,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: booking.statusColor,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Package/Subscription Info (if applicable)
          if (booking.packageType != null) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8.r),
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
                        size: 16.w,
                        color: Color(0xFF0E4778),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        booking.packageDisplay,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0E4778),
                        ),
                      ),
                    ],
                  ),
                  if (booking.packageDurationDisplay.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Text(
                      'Valid: ${booking.packageDurationDisplay}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  if (booking.packageDurationDays != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      '${booking.packageDurationDays} days',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],

          // Resident Information
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E4778).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 20.w,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.residentName.isNotEmpty
                                ? booking.residentName
                                : 'Resident',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (booking.flatLabel.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              booking.flatLabel,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Total Members Badge
                    if (booking.totalMembers > 1)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 12.w,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              booking.membersDisplay,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                if (booking.phone.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16.w, color: Color(0xFF6B7280)),
                      SizedBox(width: 6.w),
                      Text(
                        booking.phone,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],

                if (booking.email != null && booking.email!.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16.w, color: Color(0xFF6B7280)),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          booking.email!,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Family Members List
                if (booking.familyMemberNames != null &&
                    booking.familyMemberNames!.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  const Divider(height: 1),
                  SizedBox(height: 8.h),
                  Text(
                    'Family Members:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  ...booking.familyMemberNames!.map(
                    (name) => Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14.w,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Color(0xFF6B7280),
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

          SizedBox(height: 12.h),

          // Booking Details
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16.w,
                      color: Color(0xFF6B7280),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      booking.formattedDate,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),

                if (booking.formattedTime.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16.w,
                        color: Color(0xFF6B7280),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        booking.formattedTime,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ],

                // Capacity Info
                if (booking.capacityDisplay.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.groups, size: 16.w, color: Color(0xFF6B7280)),
                      SizedBox(width: 8.w),
                      Text(
                        booking.capacityDisplay,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],

                if (booking.amount > 0) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.currency_rupee,
                        size: 16.w,
                        color: Color(0xFF6B7280),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '₹${booking.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0E4778),
                        ),
                      ),
                      if (booking.paymentStatus != null) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: booking.paymentStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            booking.paymentStatus!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: booking.paymentStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Notes
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: const Color(0xFFF4A100).withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14.w, color: Color(0xFFF4A100)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      booking.notes!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Timestamps
          if (booking.createdAt != null) ...[
            SizedBox(height: 8.h),
            Text(
              'Booked: ${_formatTimestamp(booking.createdAt!)}',
              style: TextStyle(fontSize: 11.sp, color: Color(0xFF9CA3AF)),
            ),
          ],

          // Action Buttons
          if (booking.status == 'pending') ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectBooking(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
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
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 14.sp,
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
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Cancel Booking',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddAmenityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddAmenityModal(),
    );
  }

  void _showAllBookingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ViewAllBookingsModal(),
    );
  }

  void _editAmenity(AmenityModel amenity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditAmenityModal(amenity: amenity),
    );
  }

  Future<void> _toggleAvailability(AmenityModel amenity) async {
    try {
      await _amenityService.updateAmenity(amenity.id, {
        'isAvailable': !amenity.isAvailable,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              amenity.isAvailable
                  ? 'Amenity marked as unavailable'
                  : 'Amenity marked as available',
            ),
            backgroundColor: const Color(0xFF10B981),
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

  Future<void> _deleteAmenity(AmenityModel amenity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Amenity'),
        content: Text('Are you sure you want to delete "${amenity.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _amenityService.deleteAmenity(amenity.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Amenity deleted successfully'),
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

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

// Bookings Calendar View Widget
class _BookingsCalendarView extends StatefulWidget {
  final AmenityService amenityService;

  const _BookingsCalendarView({required this.amenityService});

  @override
  State<_BookingsCalendarView> createState() => _BookingsCalendarViewState();
}

class _BookingsCalendarViewState extends State<_BookingsCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<AmenityBookingModel>> _bookingsByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    // Load bookings for the current month
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    final bookings = await widget.amenityService.getBookingsGroupedByDate(
      startDate: firstDay,
      endDate: lastDay,
    );

    setState(() {
      _bookingsByDate = bookings;
      _isLoading = false;
    });
  }

  List<AmenityBookingModel> _getBookingsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _bookingsByDate[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar
        Container(
          margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
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
          child: TableCalendar<AmenityBookingModel>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getBookingsForDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadBookings();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF0E4778).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF0E4778),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markerMargin: EdgeInsets.symmetric(horizontal: 1.w),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: Color(0xFF0E4778),
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: Color(0xFF0E4778),
              ),
            ),
          ),
        ),

        // Selected Date Info
        if (_selectedDay != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16.w,
                  color: Color(0xFF6B7280),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E4778).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${_getBookingsForDay(_selectedDay!).length} bookings',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0E4778),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        // Bookings List for Selected Date
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBookingsList(),
        ),
      ],
    );
  }

  Widget _buildBookingsList() {
    if (_selectedDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event, size: 56.w, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              'Select a date to view bookings',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final bookings = _getBookingsForDay(_selectedDay!);

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 56.w, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              'No bookings on this date',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Group bookings by time slot to show multiple bookings
    final Map<String, List<AmenityBookingModel>> bookingsBySlot = {};
    for (var booking in bookings) {
      final key = '${booking.amenityName}_${booking.timeSlot}';
      if (!bookingsBySlot.containsKey(key)) {
        bookingsBySlot[key] = [];
      }
      bookingsBySlot[key]!.add(booking);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 80.h),
      itemCount: bookingsBySlot.length,
      itemBuilder: (context, index) {
        final entry = bookingsBySlot.entries.elementAt(index);
        final slotBookings = entry.value;
        final firstBooking = slotBookings.first;

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amenity and Time
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstBooking.amenityName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14.w,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              firstBooking.timeSlot,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Multiple bookings indicator
                  if (slotBookings.length > 1)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 14.w,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${slotBookings.length} bookings',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              SizedBox(height: 12.h),
              const Divider(height: 1),
              SizedBox(height: 12.h),

              // List of residents
              ...slotBookings.map(
                (booking) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: booking.statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 16.w,
                          color: booking.statusColor,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.residentName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              '${booking.flatLabel} • ${booking.phone}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: booking.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          booking.statusDisplay,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: booking.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
