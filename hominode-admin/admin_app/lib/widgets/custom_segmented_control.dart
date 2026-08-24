import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Premium Segmented Control Component
///
/// A reusable, animated segmented control with smooth pill animation
/// that follows Apple + Material 3 hybrid design principles.
///
/// Features:
/// - Smooth sliding animation (220-260ms)
/// - Premium visual design with subtle shadows
/// - Supports 2-4 tabs with automatic width distribution
/// - Consistent across all screens in the app
/// - Touch targets ≥ 44px for accessibility
class CustomSegmentedControl extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double? height;

  const CustomSegmentedControl({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44.0,
  }) : assert(
         tabs.length >= 2 && tabs.length <= 4,
         'Tabs must be between 2-4 items',
       );

  @override
  State<CustomSegmentedControl> createState() => _CustomSegmentedControlState();
}

class _CustomSegmentedControlState extends State<CustomSegmentedControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _textColorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _textColorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(CustomSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light grey background
        borderRadius: BorderRadius.circular(22.r),
      ),
      padding: EdgeInsets.all(4.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth =
              (constraints.maxWidth - (4 * 2)) / widget.tabs.length;

          return Stack(
            children: [
              // Animated Active Pill
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return AnimatedAlign(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(
                      -1.0 +
                          (2.0 *
                              widget.selectedIndex /
                              (widget.tabs.length - 1)),
                      0.0,
                    ),
                    child: Container(
                      width: segmentWidth,
                      height: widget.height! - 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Tab Buttons
              Row(
                children: widget.tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final title = entry.value;
                  final isSelected = index == widget.selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: widget.height! - 8,
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF0E4778) // Primary Blue
                                : const Color(0xFF6B7280), // Grey
                          ),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact Segmented Control for smaller spaces
///
/// A smaller variant of the segmented control for use in tight spaces
/// like modals, cards, or secondary navigation areas.
class CompactSegmentedControl extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const CompactSegmentedControl({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSegmentedControl(
      tabs: tabs,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      height: 36.0, // Smaller height for compact version
    );
  }
}

/// Segmented Control with Icons
///
/// An enhanced version that supports icons alongside text labels
/// for better visual hierarchy and user experience.
class IconSegmentedControl extends StatefulWidget {
  final List<SegmentItem> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double? height;

  const IconSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44.0,
  });

  @override
  State<IconSegmentedControl> createState() => _IconSegmentedControlState();
}

class _IconSegmentedControlState extends State<IconSegmentedControl> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22.r),
      ),
      padding: EdgeInsets.all(4.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth =
              (constraints.maxWidth - 8) / widget.segments.length;

          return Stack(
            children: [
              // Animated Active Pill
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  -1.0 +
                      (2.0 *
                          widget.selectedIndex /
                          (widget.segments.length - 1)),
                  0.0,
                ),
                child: Container(
                  width: segmentWidth,
                  height: widget.height! - 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Segment Buttons
              Row(
                children: widget.segments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final segment = entry.value;
                  final isSelected = index == widget.selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: widget.height! - 8,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (segment.icon != null) ...[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                child: Icon(
                                  segment.icon,
                                  size: 16.w,
                                  color: isSelected
                                      ? const Color(0xFF0E4778)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF0E4778)
                                      : const Color(0xFF6B7280),
                                ),
                                child: Text(
                                  segment.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Segment Item for Icon Segmented Control
class SegmentItem {
  final String title;
  final IconData? icon;

  const SegmentItem({required this.title, this.icon});
}

/// Usage Examples and Helper Methods
class SegmentedControlExamples {
  // Buildings Screen: Grid / List
  static Widget buildingsSegmentedControl({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return IconSegmentedControl(
      segments: const [
        SegmentItem(title: 'Grid View', icon: Icons.grid_view),
        SegmentItem(title: 'List View', icon: Icons.list),
      ],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }

  // Residents Screen: All / Pending
  static Widget residentsSegmentedControl({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return CustomSegmentedControl(
      tabs: const ['All Residents', 'Pending Requests'],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }

  // Billing Screen: Bills / History
  static Widget billingSegmentedControl({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return CustomSegmentedControl(
      tabs: const ['Bills', 'Payment History'],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }

  // Visitor Management: Pending / Active / History
  static Widget visitorSegmentedControl({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return CustomSegmentedControl(
      tabs: const ['Pending', 'Active', 'History'],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }

  // Events & Announcements: Events / Announcements
  static Widget eventsSegmentedControl({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return CustomSegmentedControl(
      tabs: const ['Events', 'Announcements'],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }

  // Amenities Management: Amenities / Bookings
  static Widget amenitiesSegmentedControl({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return CustomSegmentedControl(
      tabs: const ['Amenities', 'Bookings'],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }
}
