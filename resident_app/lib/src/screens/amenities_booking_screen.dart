import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/amenity.dart';
import '../models/booking.dart';
import '../modals/booking_modal.dart';
import '../components/standard_screen.dart';
import '../services/booking_firestore_service.dart';
import '../widgets/facility_information.dart';

class AmenitiesBookingScreen extends StatefulWidget {
  const AmenitiesBookingScreen({super.key, this.bookingService});
  final BookingFirestoreService? bookingService;

  @override
  State<AmenitiesBookingScreen> createState() => _AmenitiesBookingScreenState();
}

class _AmenitiesBookingScreenState extends State<AmenitiesBookingScreen> {
  late final _bookingService =
      widget.bookingService ?? BookingFirestoreService();
  late final _amenitiesStream = _bookingService.streamAmenitiesRealtime();

  Future<void> _handleCancelBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel the booking for ${booking.amenityName}?',
        ),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Amenities Booking',
      onBackPressed: () => Navigator.maybePop(context),
      isScrollable: true,
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Amenities Section
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Available Amenities',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: _buildAmenitiesStream(),
          ),

          // My Bookings Section
          SizedBox(height: 32.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: _buildBookingsStream(),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildAmenitiesStream() {
    return StreamBuilder<List<AmenityModel>>(
      stream: _amenitiesStream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFFF5757),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading amenities',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
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
              padding: EdgeInsets.all(32.w),
              child: Column(
                children: [
                  Icon(Icons.apartment, size: 64.w, color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Text(
                    'No amenities available',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Check back later for available amenities',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 340.h,
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
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFFF5757),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading bookings',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
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
              padding: EdgeInsets.all(32.w),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 64.w, color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Text(
                    'No bookings yet',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Book an amenity to see it here',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
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
              padding: EdgeInsets.only(bottom: 16.h),
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
      communityId: amenity.communityId,
      name: amenity.name,
      price: amenity.priceDisplay,
      isAvailable: amenity.isAvailable,
      iconName: amenity.iconName ?? 'apartment',
      backgroundColor: '#D6EBFF',
      iconColor: '#0A64FF',
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

  const AmenityCard({super.key, required this.amenity, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
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
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              child: FacilityImage(amenity: amenity),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name and Type
                    Column(
                      children: [
                        Text(
                          amenity.name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          amenity.type,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Color(0xFF9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    if (amenity.buildingName != null)
                      Text(
                        amenity.buildingName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    if (amenity.description != null)
                      Text(
                        amenity.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF6B7280),
                        ),
                      ),

                    // Price, Packages, and Capacity
                    Column(
                      children: [
                        // Price
                        Text(
                          amenity.priceDisplay,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A64FF),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Packages indicator
                        if (amenity.hasPackages) ...[
                          SizedBox(height: 3.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.card_membership,
                                size: 11.w,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'Packages',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Capacity indicator
                        if (amenity.allowMultipleBookings &&
                            amenity.hasConfiguredCapacity) ...[
                          SizedBox(height: 3.h),
                          Text(
                            'Max ${amenity.maxCapacity} users',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Color(0xFF9CA3AF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        SizedBox(height: 6.h),
                        // Status pill
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: amenity.isAvailable
                                ? const Color(0xFFE5F6E9)
                                : const Color(0xFFFFECEC),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            amenity.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: 10.sp,
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

  const BookingCard({super.key, required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              StatusPill(status: booking.status),
            ],
          ),
          SizedBox(height: 8.h),

          // Booking Type & People
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: booking.isPackage
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  booking.isPackage ? booking.packageType! : 'Daily',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: booking.isPackage
                        ? const Color(0xFF0E4778)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              if (booking.numberOfPeople > 1) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 12.w, color: Color(0xFF10B981)),
                      SizedBox(width: 4.w),
                      Text(
                        '${booking.numberOfPeople} people',
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
            ],
          ),
          SizedBox(height: 8.h),

          // Date & Time
          Row(
            children: [
              Icon(Icons.access_time, size: 16.w, color: Color(0xFF8A8A8A)),
              SizedBox(width: 6.w),
              Text(
                '${booking.formattedDate} • ${booking.timeSlot}',
                style: TextStyle(fontSize: 13.sp, color: Color(0xFF8A8A8A)),
              ),
            ],
          ),

          // Package Duration (if applicable)
          if (booking.isPackage && booking.packageDuration.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16.w,
                  color: Color(0xFF8A8A8A),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Valid: ${booking.packageDuration}',
                    style: TextStyle(fontSize: 12.sp, color: Color(0xFF8A8A8A)),
                  ),
                ),
              ],
            ),
          ],

          // Price
          if (booking.price > 0) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 16.w,
                  color: Color(0xFF8A8A8A),
                ),
                SizedBox(width: 6.w),
                Text(
                  '₹${booking.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0E4778),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: OutlinedButton(
              onPressed: booking.status == 'cancelled' ? null : onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF5757), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                disabledForegroundColor: const Color(0xFF9B9B9B),
              ),
              child: Text(
                booking.status == 'cancelled' ? 'Cancelled' : 'Cancel Booking',
                style: TextStyle(
                  fontSize: 15.sp,
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

  const StatusPill({super.key, required this.status});

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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        _displayText,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}
