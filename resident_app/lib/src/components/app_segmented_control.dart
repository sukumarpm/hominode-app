import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Premium Segmented Control Component
///
/// A high-end, reusable segmented control with smooth animations
/// matching Airbnb/Apple level design standards.
///
/// Design Specifications:
/// - Track background: #F0F1F3 (light grey)
/// - Height: 48px
/// - Corner radius: 30px (pill shape)
/// - Active pill: White with shadow
/// - Shadow: rgba(16, 24, 40, 0.12), blur 12, offset y=3
/// - Animation: 220ms easeOut
/// - Active text: Bold #0F172A
/// - Inactive text: Medium #9AA0A6, 15px
///
/// Usage:
/// ```dart
/// AppSegmentedControl(
///   segments: ['All', 'Furniture', 'Electronics', 'Other'],
///   selectedIndex: _selectedIndex,
///   onChanged: (index) => setState(() => _selectedIndex = index),
/// )
/// ```
class AppSegmentedControl extends StatefulWidget {
  /// List of segment labels (2-5 segments recommended)
  final List<String> segments;

  /// Currently selected segment index
  final int selectedIndex;

  /// Callback when segment is tapped, returns the new index
  final ValueChanged<int> onChanged;

  /// Optional custom height (default: 48px)
  final double? height;

  /// Allows labels to wrap to two lines instead of truncating.
  final bool allowLabelWrap;

  /// Gives labels their natural width and scrolls horizontally when they do
  /// not fit. This is useful for translated tab names that should not break
  /// inside a word.
  final bool scrollable;

  /// Optional horizontal margin (default: 20px)
  final double? horizontalMargin;

  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.height,
    this.horizontalMargin,
    this.allowLabelWrap = false,
    this.scrollable = false,
  }) : assert(
         segments.length >= 2 && segments.length <= 5,
         'Segments must contain 2-5 items',
       );

  @override
  State<AppSegmentedControl> createState() => _AppSegmentedControlState();
}

class _AppSegmentedControlState extends State<AppSegmentedControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(AppSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
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
    final height = widget.height ?? (widget.allowLabelWrap ? 64.0 : 48.0);
    final horizontalMargin = widget.horizontalMargin ?? 20.0;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final availableWidth = outerConstraints.maxWidth.isFinite
            ? outerConstraints.maxWidth - horizontalMargin * 2
            : double.infinity;
        final labelWidths = widget.scrollable
            ? _naturalSegmentWidths(context)
            : null;
        final naturalTrackWidth = labelWidths == null
            ? availableWidth
            : labelWidths.reduce((a, b) => a + b) + 8.w;
        final trackWidth =
            availableWidth.isFinite && naturalTrackWidth < availableWidth
            ? availableWidth
            : naturalTrackWidth;
        final segmentWidths = labelWidths == null
            ? List<double>.filled(
                widget.segments.length,
                (trackWidth - 8.w) / widget.segments.length,
              )
            : labelWidths.map((width) {
                final extraWidth =
                    (trackWidth - 8.w - labelWidths.reduce((a, b) => a + b)) /
                    widget.segments.length;
                return width + extraWidth;
              }).toList();

        final track = Container(
          width: trackWidth.isFinite ? trackWidth : null,
          height: height,
          key: const ValueKey('app-segmented-control-track'),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F3),
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Stack(
              children: [
                // Animated sliding pill
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final startPosition = _segmentStart(
                      segmentWidths,
                      _previousIndex,
                    );
                    final endPosition = _segmentStart(
                      segmentWidths,
                      widget.selectedIndex,
                    );
                    final currentPosition =
                        startPosition +
                        (endPosition - startPosition) * _animation.value;

                    return PositionedDirectional(
                      start: currentPosition,
                      top: 0,
                      bottom: 0,
                      width: segmentWidths[widget.selectedIndex],
                      key: const ValueKey(
                        'app-segmented-control-selected-pill',
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0x10182840,
                              ), // rgba(16, 24, 40, 0.12)
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Segment labels
                Row(
                  children: List.generate(widget.segments.length, (index) {
                    return SizedBox(
                      width: segmentWidths[index],
                      child: _buildSegment(
                        label: widget.segments[index],
                        index: index,
                        isSelected: widget.selectedIndex == index,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );

        return Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(30.r)),
          child: widget.scrollable
              ? SingleChildScrollView(
                  key: const ValueKey('app-segmented-control-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: track,
                )
              : track,
        );
      },
    );
  }

  List<double> _naturalSegmentWidths(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return widget.segments.map((label) {
      double measuredWidth(FontWeight weight) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: weight,
              letterSpacing: -0.2,
            ),
          ),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        return painter.width;
      }

      return measuredWidth(FontWeight.w700) + 24.w;
    }).toList();
  }

  double _segmentStart(List<double> widths, int index) =>
      widths.take(index).fold(4.w, (sum, width) => sum + width);

  Widget _buildSegment({
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        if (widget.selectedIndex != index) {
          widget.onChanged(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: widget.allowLabelWrap ? 4.w : 12.w,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF0F172A) // Active: Dark slate
                : const Color(0xFF9AA0A6), // Inactive: Medium grey
            fontSize: 15.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.2,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: widget.allowLabelWrap && !widget.scrollable ? 2 : 1,
            softWrap: widget.allowLabelWrap && !widget.scrollable,
            overflow: widget.scrollable || widget.allowLabelWrap
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
