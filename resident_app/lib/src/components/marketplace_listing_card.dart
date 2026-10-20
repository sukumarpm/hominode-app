import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../models/listing_model.dart';

/// Presentation only; the owning screen retains navigation and mutations.
class MarketplaceListingCard extends StatelessWidget {
  const MarketplaceListingCard({
    super.key,
    required this.listing,
    required this.onOpen,
    required this.onEdit,
    required this.onMarkSold,
    required this.onDelete,
  });

  final ListingModel listing;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onMarkSold;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        listing.formattedPrice,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(listing.status),
              ],
            ),

            SizedBox(height: 12.h),

            // Details
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                _buildDetailChip(Icons.category, listing.category),
                _buildDetailChip(Icons.check_circle, listing.condition),
                _buildDetailChip(Icons.calendar_today, listing.formattedDate),
              ],
            ),

            // Phone Requests (Clickable)
            if (listing.phoneRequestCount > 0) ...[
              SizedBox(height: 10.h),
              GestureDetector(
                onTap: onOpen,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 16.w,
                        color: Colors.blue.shade600,
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          '${listing.phoneRequestCount} phone request${listing.phoneRequestCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward,
                        size: 14.w,
                        color: Colors.blue.shade600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: 10.h),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade600;
        label = 'Active';
        break;
      case 'sold':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        label = 'Sold';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        label = 'Inactive';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.w, color: Colors.grey.shade600),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final labels = [
      'Edit',
      listing.status == 'sold' ? 'Sold' : 'Mark Sold',
      'Delete',
    ];
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
    );
    final painters = labels
        .map(
          (label) => TextPainter(
            text: TextSpan(text: label, style: textStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout(),
        )
        .toList();
    final labelWidth = painters
        .map((p) => p.width)
        .reduce((a, b) => a > b ? a : b);
    final labelHeight = painters
        .map((p) => p.height)
        .reduce((a, b) => a > b ? a : b);
    final height = (labelHeight + 24).clamp(48.0, double.infinity);
    for (final painter in painters) {
      painter.dispose();
    }
    final base = OutlinedButton.styleFrom(
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      textStyle: textStyle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      elevation: 0,
    );
    final actions = <Widget>[
      OutlinedButton(
        onPressed: onEdit,
        style: base.copyWith(
          foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.primary),
          ),
        ),
        child: Text(labels[0], maxLines: 1, softWrap: false),
      ),
      ElevatedButton(
        onPressed: onMarkSold,
        style: base.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            listing.status == 'sold'
                ? Colors.grey.shade400
                : Colors.green.shade700,
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
        child: Text(labels[1], maxLines: 1, softWrap: false),
      ),
      OutlinedButton(
        onPressed: onDelete,
        style: base.copyWith(
          foregroundColor: WidgetStatePropertyAll(Colors.red.shade700),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.red.shade700)),
        ),
        child: Text(labels[2], maxLines: 1, softWrap: false),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsRow = (constraints.maxWidth - 16) / 3 >= labelWidth + 26;
        final buttons = actions
            .map((action) => SizedBox(height: height, child: action))
            .toList();
        if (!fitsRow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                buttons[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }
}
