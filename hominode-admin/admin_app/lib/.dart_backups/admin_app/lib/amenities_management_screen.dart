import 'package:flutter/material.dart';
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
  State<AmenitiesManagementScreen> createState() => _AmenitiesManagementScreenState();
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Manage property amenities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SegmentedControlExamples.amenitiesSegmentedControl(
              selectedIndex: selectedTab,
              onChanged: (index) {
                setState(() {
                  selectedTab = index;
                });
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Create Button (Dynamic based on selected tab)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
          
          const SizedBox(height: 20),
          
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
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
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
                Icon(Icons.apartment, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No amenities yet',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first amenity to get started',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          itemCount: amenities.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildAmenityCard(amenities[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildAmenityCard(AmenityModel amenity) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: amenity.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  amenity.icon,
                  color: amenity.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Title and Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amenity.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amenity.buildingName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amenity.priceDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: amenity.isFree ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: amenity.isAvailable
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  amenity.isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: amenity.isAvailable
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Category Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: amenity.color),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              amenity.type,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: amenity.color,
              ),
            ),
          ),
          
          if (amenity.description != null && amenity.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              amenity.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          // Booking Configuration Info
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      amenity.capacityDisplay,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (amenity.allowMultipleBookings) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Multiple bookings',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (amenity.bookingDurations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          amenity.bookingDurations.join(', '),
                          style: const TextStyle(
                            fontSize: 12,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenity.timeSlots!.take(3).map((slot) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        slot,
                        style: const TextStyle(
                          fontSize: 13,
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
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${amenity.timeSlots!.length - 3} more slots',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
          ],
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _toggleAvailability(amenity),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    amenity.isAvailable ? 'Mark Unavailable' : 'Mark Available',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _editAmenity(amenity),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EBFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteAmenity(amenity),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 20,
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
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (booking.buildingName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.apartment, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(
                            booking.buildingName,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: booking.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.statusDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: booking.statusColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Package/Subscription Info (if applicable)
          if (booking.packageType != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_membership, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        booking.packageDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  if (booking.packageDurationDisplay.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Valid: ${booking.packageDurationDisplay}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                  if (booking.packageDurationDays != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${booking.packageDurationDays} days',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Resident Information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.residentName.isNotEmpty ? booking.residentName : 'Resident',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (booking.flatLabel.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.flatLabel,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Total Members Badge
                    if (booking.totalMembers > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              booking.membersDisplay,
                              style: const TextStyle(
                                fontSize: 11,
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Text(booking.phone, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ],
                
                if (booking.email != null && booking.email!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.email!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Family Members List
                if (booking.familyMemberNames != null && booking.familyMemberNames!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text(
                    'Family Members:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 6),
                  ...booking.familyMemberNames!.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Booking Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Text(
                      booking.formattedDate,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                
                if (booking.formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        booking.formattedTime,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ],
                
                // Capacity Info
                if (booking.capacityDisplay.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.groups, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        booking.capacityDisplay,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
                
                if (booking.amount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        '₹${booking.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                      if (booking.paymentStatus != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: booking.paymentStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            booking.paymentStatus!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF4A100).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 14, color: Color(0xFFF4A100)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.notes!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Timestamps
          if (booking.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Booked: ${_formatTimestamp(booking.createdAt!)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
          
          // Action Buttons
          if (booking.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectBooking(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Approve', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
          
          if (booking.status == 'approved' || booking.status == 'confirmed') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel Booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
        await _amenityService.rejectBooking(booking.id, reason.isEmpty ? null : reason);
        
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
        content: Text('Are you sure you want to cancel this booking for ${booking.residentName}?'),
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
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                color: const Color(0xFF2563EB).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markerMargin: const EdgeInsets.symmetric(horizontal: 1),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: Color(0xFF2563EB),
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ),

        // Selected Date Info
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_getBookingsForDay(_selectedDay!).length} bookings',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
            Icon(Icons.event, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Select a date to view bookings',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
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
            Icon(Icons.event_busy, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No bookings on this date',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      itemCount: bookingsBySlot.length,
      itemBuilder: (context, index) {
        final entry = bookingsBySlot.entries.elementAt(index);
        final slotBookings = entry.value;
        final firstBooking = slotBookings.first;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              firstBooking.timeSlot,
                              style: const TextStyle(
                                fontSize: 13,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${slotBookings.length} bookings',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // List of residents
              ...slotBookings.map((booking) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: booking.statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: booking.statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.residentName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            '${booking.flatLabel} • ${booking.phone}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking.statusDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: booking.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
