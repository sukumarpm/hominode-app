import 'package:flutter/material.dart';
import '../models/amenity.dart';
import '../models/booking.dart';
import '../modals/booking_modal.dart';
import '../components/standard_screen.dart';
import '../services/booking_firestore_service.dart';

class AmenitiesBookingScreen extends StatefulWidget {
  const AmenitiesBookingScreen({super.key});

  @override
  State<AmenitiesBookingScreen> createState() => _AmenitiesBookingScreenState();
}

class _AmenitiesBookingScreenState extends State<AmenitiesBookingScreen> {
  final _bookingService = BookingFirestoreService();

  Future<void> _handleCancelBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel the booking for ${booking.amenityName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF5757),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && booking.id != null) {
      try {
        final result = await _bookingService.cancelBooking(booking.id!);
        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to cancel booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Amenities Booking',
      showBackButton: false,
      isScrollable: true,
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Amenities Section
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Available Amenities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildAmenitiesStream(),
          ),
          
          // My Bookings Section
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildBookingsStream(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAmenitiesStream() {
    return StreamBuilder<List<AmenityModel>>(
      stream: _bookingService.streamAmenitiesRealtime(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFFF5757),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading amenities',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.apartment,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No amenities available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check back later for available amenities',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Data state
        final amenities = snapshot.data!;
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: amenities.length,
          itemBuilder: (context, index) {
            final amenity = amenities[index];
            return AmenityCard(
              amenity: amenity,
              onTap: () => _handleAmenityTap(context, amenity),
            );
          },
        );
      },
    );
  }

  Widget _buildBookingsStream() {
    return StreamBuilder<List<BookingModel>>(
      stream: _bookingService.streamMyBookingsRealtime(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFFF5757),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading bookings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No bookings yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Book an amenity to see it here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Data state
        final bookings = snapshot.data!;
        return Column(
          children: bookings.map((booking) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BookingCard(
                booking: booking,
                onCancel: () => _handleCancelBooking(booking),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleAmenityTap(
    BuildContext context,
    AmenityModel amenity,
  ) async {
    final amenityLegacy = Amenity(
      id: amenity.id,
      name: amenity.name,
      price: amenity.priceDisplay,
      isAvailable: amenity.isAvailable,
      iconName: amenity.iconName ?? 'apartment',
      backgroundColor: '#D6EBFF',
      iconColor: '#0A64FF',
      openTime: '6:00 AM',
      closeTime: '8:00 PM',
    );
    
    await BookingModal.show(context, amenityLegacy);
  }
}

// ============================================
// AMENITY CARD WIDGET
// ============================================

class AmenityCard extends StatelessWidget {
  final AmenityModel amenity;
  final VoidCallback? onTap;

  const AmenityCard({
    super.key,
    required this.amenity,
    this.onTap,
  });

  IconData _getIconFromName(String? iconName) {
    if (iconName == null) return Icons.apartment;
    
    switch (iconName.toLowerCase()) {
      case 'pool':
      case 'swimming_pool':
        return Icons.pool;
      case 'gym':
      case 'fitness':
        return Icons.fitness_center;
      case 'hall':
      case 'community_hall':
        return Icons.home_outlined;
      case 'lawn':
      case 'party_lawn':
        return Icons.people_outline;
      case 'tennis':
        return Icons.sports_tennis;
      case 'basketball':
        return Icons.sports_basketball;
      case 'playground':
        return Icons.park;
      case 'parking':
        return Icons.local_parking;
      case 'clubhouse':
        return Icons.house;
      default:
        return Icons.apartment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon container
            Container(
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFD6EBFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  _getIconFromName(amenity.iconName),
                  size: 44,
                  color: const Color(0xFF0A64FF),
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name and Type
                    Column(
                      children: [
                        Text(
                          amenity.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amenity.type,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    
                    // Price, Packages, and Capacity
                    Column(
                      children: [
                        // Price
                        Text(
                          amenity.priceDisplay,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A64FF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Packages indicator
                        if (amenity.hasPackages) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.card_membership,
                                size: 11,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Packages',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        // Capacity indicator
                        if (amenity.allowMultipleBookings) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Max ${amenity.maxCapacity} users',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9CA3AF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        
                        const SizedBox(height: 6),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: amenity.isAvailable
                                ? const Color(0xFFE5F6E9)
                                : const Color(0xFFFFECEC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            amenity.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: amenity.isAvailable
                                  ? const Color(0xFF0AA03C)
                                  : const Color(0xFFFF5757),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// BOOKING CARD WIDGET
// ============================================

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onCancel;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.amenityName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: booking.status),
            ],
          ),
          const SizedBox(height: 8),
          
          // Booking Type & People
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: booking.isPackage ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  booking.isPackage ? booking.packageType! : 'Daily',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: booking.isPackage ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (booking.numberOfPeople > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 12,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${booking.numberOfPeople} people',
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
            ],
          ),
          const SizedBox(height: 8),
          
          // Date & Time
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: Color(0xFF8A8A8A),
              ),
              const SizedBox(width: 6),
              Text(
                '${booking.formattedDate} • ${booking.timeSlot}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8A8A8A),
                ),
              ),
            ],
          ),
          
          // Package Duration (if applicable)
          if (booking.isPackage && booking.packageDuration.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF8A8A8A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Valid: ${booking.packageDuration}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Price
          if (booking.price > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: Color(0xFF8A8A8A),
                ),
                const SizedBox(width: 6),
                Text(
                  '₹${booking.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: booking.status == 'cancelled' ? null : onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF5757), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledForegroundColor: const Color(0xFF9B9B9B),
              ),
              child: Text(
                booking.status == 'cancelled' ? 'Cancelled' : 'Cancel Booking',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: booking.status == 'cancelled' 
                      ? const Color(0xFF9B9B9B)
                      : const Color(0xFFFF5757),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// STATUS PILL WIDGET
// ============================================

class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({
    super.key,
    required this.status,
  });

  Color get _backgroundColor {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return const Color(0xFFE5F6E9);
      case 'pending':
        return const Color(0xFFFFF4E6);
      case 'cancelled':
        return const Color(0xFFFFECEC);
      default:
        return const Color(0xFFE5F6E9);
    }
  }

  Color get _textColor {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return const Color(0xFF0AA03C);
      case 'pending':
        return const Color(0xFFFF9800);
      case 'cancelled':
        return const Color(0xFFFF5757);
      default:
        return const Color(0xFF0AA03C);
    }
  }

  String get _displayText {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}
