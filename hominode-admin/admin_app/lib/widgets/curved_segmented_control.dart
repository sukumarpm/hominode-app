import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// CURVED SEGMENTED CONTROL WIDGET
// ============================================================================
// Reusable curved segmented control with smooth animations
// Consistent design across all screens

class CurvedSegmentedControl extends StatefulWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? indicatorColor;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const CurvedSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    this.indicatorColor,
    this.height,
    this.padding,
    this.margin,
  });

  @override
  State<CurvedSegmentedControl> createState() => _CurvedSegmentedControlState();
}

class _CurvedSegmentedControlState extends State<CurvedSegmentedControl>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubicEmphasized,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onSegmentTap(int index) async {
    if (_isAnimating || index == widget.selectedIndex) return;
    
    setState(() => _isAnimating = true);
    
    // Haptic feedback
    HapticFeedback.selectionClick();
    
    // Animate the transition
    await _animationController.reverse();
    widget.onSegmentChanged(index);
    await _animationController.forward();
    
    setState(() => _isAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final segmentWidth = (screenWidth - (widget.margin?.horizontal ?? 32) - 8) / widget.segments.length;
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16),
      padding: widget.padding ?? const EdgeInsets.all(4),
      height: widget.height ?? 48,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated sliding indicator
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubicEmphasized,
                left: widget.selectedIndex * segmentWidth + 2,
                top: 2,
                bottom: 2,
                width: segmentWidth - 4,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.indicatorColor ?? Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Segment buttons
          Row(
            children: List.generate(
              widget.segments.length,
              (index) => _buildSegmentButton(index, segmentWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, double width) {
    final isSelected = widget.selectedIndex == index;
    final segment = widget.segments[index];
    final count = widget.counts != null && index < widget.counts!.length 
        ? widget.counts![index] 
        : null;
    
    return GestureDetector(
      onTap: () => _onSegmentTap(index),
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected 
                  ? (widget.selectedColor ?? const Color(0xFF0F172A))
                  : (widget.unselectedColor ?? const Color(0xFF64748B)),
              letterSpacing: isSelected ? 0.2 : 0.0,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.02 : 1.0,
              child: Text(
                count != null && count > 0 ? '$segment ($count)' : segment,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CURVED SEGMENTED CONTROL VARIANTS
// ============================================================================

class PrimaryCurvedSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;

  const PrimaryCurvedSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return CurvedSegmentedControl(
      segments: segments,
      counts: counts,
      selectedIndex: selectedIndex,
      onSegmentChanged: onSegmentChanged,
      backgroundColor: const Color(0xFFE2E8F0),
      selectedColor: const Color(0xFF0F172A),
      unselectedColor: const Color(0xFF64748B),
      indicatorColor: Colors.white,
    );
  }
}

class AccentCurvedSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;

  const AccentCurvedSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return CurvedSegmentedControl(
      segments: segments,
      counts: counts,
      selectedIndex: selectedIndex,
      onSegmentChanged: onSegmentChanged,
      backgroundColor: const Color(0xFFDCFDF7),
      selectedColor: const Color(0xFF065F46),
      unselectedColor: const Color(0xFF6B7280),
      indicatorColor: const Color(0xFF10B981),
    );
  }
}

class CompactCurvedSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;

  const CompactCurvedSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return CurvedSegmentedControl(
      segments: segments,
      counts: counts,
      selectedIndex: selectedIndex,
      onSegmentChanged: onSegmentChanged,
      backgroundColor: const Color(0xFFF8FAFC),
      selectedColor: const Color(0xFF1E293B),
      unselectedColor: const Color(0xFF94A3B8),
      indicatorColor: Colors.white,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

// ============================================================================
// CURVED TAB INDICATOR (Alternative Style)
// ============================================================================

class CurvedTabIndicator extends Decoration {
  final Color color;
  final double radius;
  @override
  final EdgeInsets padding;

  const CurvedTabIndicator({
    this.color = Colors.white,
    this.radius = 20.0,
    this.padding = const EdgeInsets.all(4.0),
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CurvedTabIndicatorPainter(
      color: color,
      radius: radius,
      padding: padding,
    );
  }
}

class _CurvedTabIndicatorPainter extends BoxPainter {
  final Color color;
  final double radius;
  final EdgeInsets padding;

  _CurvedTabIndicatorPainter({
    required this.color,
    required this.radius,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = Rect.fromLTWH(
      offset.dx + padding.left,
      offset.dy + padding.top,
      configuration.size!.width - padding.horizontal,
      configuration.size!.height - padding.vertical,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, paint);

    // Add subtle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      shadowPaint,
    );
  }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

/*
// Basic Usage
PrimaryCurvedSegmentedControl(
  segments: ['Pending', 'Active', 'History'],
  counts: [3, 2, 0],
  selectedIndex: 0,
  onSegmentChanged: (index) {
    setState(() => _selectedIndex = index);
  },
)

// Custom Styling
CurvedSegmentedControl(
  segments: ['Tab 1', 'Tab 2', 'Tab 3'],
  selectedIndex: _selectedIndex,
  onSegmentChanged: (index) => _onTabChanged(index),
  backgroundColor: Colors.blue.shade50,
  selectedColor: Colors.blue.shade900,
  unselectedColor: Colors.blue.shade400,
  indicatorColor: Colors.white,
  height: 50,
)

// Compact Version
CompactCurvedSegmentedControl(
  segments: ['All', 'Active', 'Completed'],
  selectedIndex: _selectedIndex,
  onSegmentChanged: (index) => _onTabChanged(index),
)
*/