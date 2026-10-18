import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResidentNotificationButton extends StatelessWidget {
  const ResidentNotificationButton({
    super.key,
    required this.unreadCounts,
    required this.onTap,
  });
  final Stream<int> unreadCounts;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48.w,
          height: 48.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .90),
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            color: const Color(0xFF1558D6),
            size: 23.w,
          ),
        ),
        StreamBuilder<int>(
          stream: unreadCounts,
          initialData: 0,
          builder: (context, snapshot) {
            final count = snapshot.hasError ? 0 : (snapshot.data ?? 0);
            if (count <= 0) return const SizedBox.shrink();
            return Positioned(
              right: 0,
              top: 0,
              child: Container(
                key: const ValueKey('notification-unread-count'),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B3B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
