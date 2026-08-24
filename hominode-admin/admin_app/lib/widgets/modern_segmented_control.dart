import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// MODERN SEGMENTED CONTROL WIDGET
// ============================================================================
// Standard iOS-style segmented control with smooth animations and modern design
// Features: Smooth sliding indicator, haptic feedback, customizable styling

class ModernSegmentedControl extends StatefulWidget {
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
  final bool showCounts;
  final TextStyle? selectedTextStyle;
  final TextStyle? unselectedTextStyle;

  const ModernSegmentedControl({
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
    this.showCounts = true,
    this.selectedTextStyle,
    this.unselectedTextStyle,
  });

  @override
  State<ModernSegmentedControl> createState() => _ModernSegmentedControlState();
}

class _ModernSegmentedControlState extends State<ModernSegmentedControl>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubicEmphasized,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));
    
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onSegmentTap(int index) async {
    if (_isAnimating || index == widget.selectedIndex) return;
    
    setState(() => _isAnimating = true);
    
    // Haptic feedback
    HapticFeedback.selectionClick();
    
    // Scale animation for feedback
    await _scaleController.reverse();
    
    // Trigger callback
    widget.onSegmentChanged(index);
    
    // Scale back up
    await _scaleController.forward();
    
    setState(() => _isAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth - (widget.margin?.horizontal ?? 32);
    final segmentWidth = (containerWidth - 8) / widget.segments.length;
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16),
      height: widget.height ?? 52,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: widget.padding ?? const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Animated sliding indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubicEmphasized,
                left: widget.selectedIndex * segmentWidth + 2,
                top: 2,
                bottom: 2,
                width: segmentWidth - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.indicatorColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
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
        ),
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
            style: isSelected 
                ? (widget.selectedTextStyle ?? TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.selectedColor ?? const Color(0xFF0F172A),
                    letterSpacing: 0.3,
                  ))
                : (widget.unselectedTextStyle ?? TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.unselectedColor ?? const Color(0xFF64748B),
                    letterSpacing: 0.1,
                  )),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.05 : 1.0,
              child: Text(
                widget.showCounts && count != null && count > 0 
                    ? '$segment ($count)' 
                    : segment,
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
// MODERN SEGMENTED CONTROL VARIANTS
// ============================================================================

class StandardModernSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;

  const StandardModernSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return ModernSegmentedControl(
      segments: segments,
      counts: counts,
      selectedIndex: selectedIndex,
      onSegmentChanged: onSegmentChanged,
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFF0F172A),
      unselectedColor: const Color(0xFF64748B),
      indicatorColor: Colors.white,
      height: 52,
    );
  }
}

class CompactModernSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;

  const CompactModernSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return ModernSegmentedControl(
      segments: segments,
      counts: counts,
      selectedIndex: selectedIndex,
      onSegmentChanged: onSegmentChanged,
      backgroundColor: const Color(0xFFF8FAFC),
      selectedColor: const Color(0xFF1E293B),
      unselectedColor: const Color(0xFF94A3B8),
      indicatorColor: Colors.white,
      height: 46,
      selectedTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
        letterSpacing: 0.2,
      ),
      unselectedTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.1,
      ),
    );
  }
}

class AccentModernSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final List<int>? counts;
  final int selectedIndex;
  final Function(int) onSegmentChanged;

  const AccentModernSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return ModernSegmentedControl(
      segments: segments,
      counts: counts,
      selectedIndex: selectedIndex,
      onSegmentChanged: onSegmentChanged,
      backgroundColor: const Color(0xFFEBF8FF),
      selectedColor: const Color(0xFF0369A1),
      unselectedColor: const Color(0xFF64748B),
      indicatorColor: const Color(0xFF0EA5E9),
      height: 50,
    );
  }
}

// ============================================================================
// SMOOTH SCROLL BEHAVIOR
// ============================================================================

class SmoothScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

// ============================================================================
// SMOOTH SCROLL CONTROLLER EXTENSION
// ============================================================================

extension SmoothScrollController on ScrollController {
  Future<void> smoothScrollTo(double offset, {
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    await animateTo(
      offset,
      duration: duration,
      curve: curve,
    );
  }

  Future<void> smoothScrollToTop({
    Duration duration = const Duration(milliseconds: 800),
  }) async {
    await smoothScrollTo(0.0, duration: duration);
  }

  Future<void> smoothScrollToBottom({
    Duration duration = const Duration(milliseconds: 800),
  }) async {
    await smoothScrollTo(position.maxScrollExtent, duration: duration);
  }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

/*
// Standard Usage
StandardModernSegmentedControl(
  segments: ['Pending', 'Active', 'History'],
  counts: [3, 2, 0],
  selectedIndex: _selectedIndex,
  onSegmentChanged: (index) {
    setState(() => _selectedIndex = index);
  },
)

// Compact Version
CompactModernSegmentedControl(
  segments: ['All', 'New', 'Completed'],
  selectedIndex: _selectedIndex,
  onSegmentChanged: _onTabChanged,
)

// Accent Version
AccentModernSegmentedControl(
  segments: ['Overview', 'Details', 'Settings'],
  selectedIndex: _selectedIndex,
  onSegmentChanged: _onTabChanged,
)

// Custom Styling
ModernSegmentedControl(
  segments: ['Tab 1', 'Tab 2', 'Tab 3'],
  selectedIndex: _selectedIndex,
  onSegmentChanged: _onTabChanged,
  backgroundColor: Colors.grey.shade100,
  selectedColor: Colors.blue.shade900,
  unselectedColor: Colors.grey.shade600,
  indicatorColor: Colors.white,
  height: 48,
)

// Smooth Scrolling
final ScrollController _scrollController = ScrollController();

// Smooth scroll to top
_scrollController.smoothScrollToTop();

// Smooth scroll to specific position
_scrollController.smoothScrollTo(200.0);
*/