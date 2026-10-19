import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResidentNotificationButton extends StatefulWidget {
  const ResidentNotificationButton({
    super.key,
    required this.createUnreadCounts,
    required this.onTap,
    this.active = true,
  });

  /// Creates a fresh, single-consumer stream for each active subscription.
  final Stream<int> Function() createUnreadCounts;
  final VoidCallback onTap;
  final bool active;

  @override
  State<ResidentNotificationButton> createState() =>
      _ResidentNotificationButtonState();
}

class _ResidentNotificationButtonState
    extends State<ResidentNotificationButton> {
  Stream<int>? _counts;

  @override
  void initState() {
    super.initState();
    _counts = widget.active ? widget.createUnreadCounts() : null;
  }

  @override
  void didUpdateWidget(covariant ResidentNotificationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.createUnreadCounts != widget.createUnreadCounts) {
      _counts = widget.active ? widget.createUnreadCounts() : null;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
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
          // Replacements start at zero, without retaining another tenant's
          // snapshot. StreamBuilder owns cancellation on replacement/disposal.
          key: ObjectKey(_counts),
          stream: _counts,
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
