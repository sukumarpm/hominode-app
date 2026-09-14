import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/booking_firestore_service.dart';

IconData facilityIcon(String? name) {
  switch (name?.toLowerCase()) {
    case 'pool':
    case 'swimming_pool':
      return Icons.pool;
    case 'gym':
    case 'fitness':
    case 'fitness_center':
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

/// Shared image presentation for cards and details; only HTTP(S) is loaded.
class FacilityImage extends StatelessWidget {
  const FacilityImage({super.key, required this.amenity, this.height = 90});
  final AmenityModel amenity;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = AmenityModel.safeImageUrl(amenity.imageUrl);
    Widget fallback() => Center(
      child: Icon(
        facilityIcon(amenity.iconName),
        size: 44.w,
        color: const Color(0xFF0A64FF),
        semanticLabel: 'Facility image unavailable',
      ),
    );
    return SizedBox(
      height: height.h,
      width: double.infinity,
      child: ColoredBox(
        color: const Color(0xFFD6EBFF),
        child: url == null
            ? fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => fallback(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback(),
              ),
      ),
    );
  }
}

/// Document-backed information only; contains no booking actions or defaults
/// for opening hours, durations, or missing prices.
class FacilityInformation extends StatelessWidget {
  const FacilityInformation({super.key, required this.amenity});
  final AmenityModel amenity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: FacilityImage(amenity: amenity, height: 120),
        ),
        SizedBox(height: 12.h),
        Text(
          amenity.name,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
        Text(amenity.type),
        if (amenity.buildingName != null)
          Text('Building: ${amenity.buildingName}'),
        if (amenity.description != null) ...[
          SizedBox(height: 8.h),
          Text(amenity.description!),
        ],
        SizedBox(height: 8.h),
        Text('Price: ${amenity.priceDisplay}'),
        SizedBox(height: 8.h),
        if (amenity.timeSlots.isNotEmpty) ...[
          const Text('Time slots'),
          for (final slot in amenity.timeSlots) Text(slot),
        ] else
          const Text('No time slots available'),
        if (amenity.bookingDurations.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text('Booking durations: ${amenity.bookingDurations.join(', ')}'),
        ],
        if (amenity.hasConfiguredCapacity) ...[
          SizedBox(height: 8.h),
          Text(
            'Capacity: ${amenity.maxCapacity} ${amenity.maxCapacity == 1 ? 'person' : 'people'}',
          ),
        ],
      ],
    );
  }
}
