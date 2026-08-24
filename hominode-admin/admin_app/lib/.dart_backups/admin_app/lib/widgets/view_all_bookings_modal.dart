import 'package:flutter/material.dart';
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
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title and Close
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All Bookings',
                        style: TextStyle(
                          fontSize: 20,
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
                const SizedBox(height: 16),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', 'approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected', 'rejected'),
                      const SizedBox(width: 8),
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
                        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
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
                  bookings = bookings.where((b) => b.status.toLowerCase() == _selectedFilter).toList();
                }

                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'all' 
                              ? 'No bookings yet' 
                              : 'No $_selectedFilter bookings',
                          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildFullBookingCard(AmenityBookingModel booking) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                      style: const TextStyle(
                        fontSize: 18,
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
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: booking.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.statusDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: booking.statusColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Booking ID
          _buildInfoRow(
            icon: Icons.confirmation_number,
            label: 'Booking ID',
            value: booking.id.substring(0, 8).toUpperCase(),
          ),
          
          const SizedBox(height: 12),
          
          // Date and Time
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Booking Date',
            value: booking.formattedDate,
          ),
          
          if (booking.formattedTime.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Time Slot',
              value: booking.formattedTime,
            ),
          ],

          // Package/Subscription Information
          if (booking.packageType != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_membership, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Package Details',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow('Type', booking.packageDisplay),
                  if (booking.packageDurationDisplay.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Validity', booking.packageDurationDisplay),
                  ],
                  if (booking.packageDurationDays != null) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Duration', '${booking.packageDurationDays} days'),
                  ],
                ],
              ),
            ),
          ],
          
          // Resident Information
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 22, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resident Information',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (booking.totalMembers > 1) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.membersDisplay,
                              style: const TextStyle(
                                fontSize: 12,
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
                const SizedBox(height: 12),
                _buildDetailRow('Name', booking.residentName),
                const SizedBox(height: 6),
                _buildDetailRow('Flat', booking.flatLabel),
                const SizedBox(height: 6),
                _buildDetailRow('Phone', booking.phone),
                if (booking.email != null && booking.email!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildDetailRow('Email', booking.email!),
                ],
                
                // Family Members
                if (booking.familyMemberNames != null && booking.familyMemberNames!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Family Members:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...booking.familyMemberNames!.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),

          // Capacity Information
          if (booking.capacityDisplay.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      const Text(
                        'Capacity Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow('Slot Status', booking.capacityDisplay),
                  if (booking.slotCapacity != null) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Max Capacity', '${booking.slotCapacity} people'),
                  ],
                  if (booking.currentBookings != null) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Current Bookings', '${booking.currentBookings}'),
                  ],
                  if (booking.spotsRemaining != null) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Spots Remaining', '${booking.spotsRemaining}'),
                  ],
                ],
              ),
            ),
          ],
          
          // Payment Information
          if (booking.amount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF4A100).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 18, color: Color(0xFFF4A100)),
                      const SizedBox(width: 8),
                      const Text(
                        'Payment Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF4A100),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow('Amount', '₹${booking.amount.toStringAsFixed(0)}'),
                  if (booking.paymentStatus != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: booking.paymentStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            booking.paymentStatus!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: booking.paymentStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (booking.paymentMethod != null) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Method', booking.paymentMethod!.toUpperCase()),
                  ],
                ],
              ),
            ),
          ],
          
          // Additional Information
          if (booking.bookingType != null || booking.notes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF4A100).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFFF4A100)),
                      const SizedBox(width: 8),
                      const Text(
                        'Additional Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF4A100),
                        ),
                      ),
                    ],
                  ),
                  if (booking.bookingType != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow('Booking Type', booking.bookingType!.toUpperCase()),
                  ],
                  if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Notes:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.notes!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Timestamps
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                if (booking.createdAt != null) ...[
                  _buildTimestampRow('Created', booking.createdAt!),
                ],
                if (booking.bookedAt != null) ...[
                  const SizedBox(height: 6),
                  _buildTimestampRow('Booked', booking.bookedAt!),
                ],
                if (booking.approvedAt != null) ...[
                  const SizedBox(height: 6),
                  _buildTimestampRow('Approved', booking.approvedAt!),
                ],
                if (booking.rejectedAt != null) ...[
                  const SizedBox(height: 6),
                  _buildTimestampRow('Rejected', booking.rejectedAt!),
                ],
                if (booking.cancelledAt != null) ...[
                  const SizedBox(height: 6),
                  _buildTimestampRow('Cancelled', booking.cancelledAt!),
                ],
                if (booking.updatedAt != null) ...[
                  const SizedBox(height: 6),
                  _buildTimestampRow('Last Updated', booking.updatedAt!),
                ],
              ],
            ),
          ),
          
          // Rejection Reason
          if (booking.rejectionReason != null && booking.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      const Text(
                        'Rejection Reason',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    booking.rejectionReason!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                  ),
                ],
              ),
            ),
          ],
          
          // Action Buttons
          if (booking.status == 'pending') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectBooking(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Approve', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
          
          if (booking.status == 'approved' || booking.status == 'confirmed') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
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
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
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
    final formatted = '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Text(
          formatted,
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
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
}
