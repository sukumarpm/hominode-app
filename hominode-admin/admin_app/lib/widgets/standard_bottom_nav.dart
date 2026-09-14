import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../admin_dashboard_page.dart';
import '../admin_residents_page_firestore.dart';
import '../billing_screen.dart';
import '../manage_buildings_page.dart';
import '../profile_screen.dart';
import '../theme/hominode_theme.dart';

class StandardBottomNav extends StatefulWidget {
  final int selectedIndex;

  const StandardBottomNav({super.key, required this.selectedIndex});

  @override
  State<StandardBottomNav> createState() => _StandardBottomNavState();
}

class _StandardBottomNavState extends State<StandardBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  int _tappedIndex = -1;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Desktop navigation is owned by AdminDesktopShell's fixed sidebar.
    if (MediaQuery.sizeOf(context).width >= 1024) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, -8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(minHeight: 60.h, maxHeight: 80.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                index: 0,
              ),
              _buildBottomNavItem(
                context,
                icon: Icons.apartment_outlined,
                activeIcon: Icons.apartment_rounded,
                label: 'Buildings',
                index: 1,
              ),
              _buildBottomNavItem(
                context,
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Residents',
                index: 2,
              ),
              _buildBottomNavItem(
                context,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Billing',
                index: 3,
              ),
              _buildBottomNavItem(
                context,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = widget.selectedIndex == index;
    final isTapped = _tappedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _tappedIndex = index;
          });
          _scaleController.forward();
          _rippleController.forward();
          HapticFeedback.lightImpact();
        },
        onTapUp: (_) {
          _scaleController.reverse();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _tappedIndex = -1;
              });
              _rippleController.reset();
            }
          });
        },
        onTapCancel: () {
          _scaleController.reverse();
          setState(() {
            _tappedIndex = -1;
          });
          _rippleController.reset();
        },
        onTap: () => _handleNavigation(context, index),
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _rippleAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: isTapped ? _scaleAnimation.value : 1.0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.w),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ripple effect
                    if (isTapped)
                      Container(
                        width: 45 * _rippleAnimation.value,
                        height: 45 * _rippleAnimation.value,
                        decoration: BoxDecoration(
                          color: HominodeTheme.teal.withValues(
                            alpha: 0.1 * (1 - _rippleAnimation.value),
                          ),
                          borderRadius: BorderRadius.circular(22.5.r),
                        ),
                      ),

                    // Main content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon container with smooth background
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 32 : 28,
                          height: isSelected ? 32 : 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? HominodeTheme.teal.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              isSelected ? 10 : 8,
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              isSelected ? activeIcon : icon,
                              key: ValueKey('${index}_$isSelected'),
                              color: isSelected
                                  ? HominodeTheme.blue
                                  : const Color(0xFF6B7280),
                              size: isSelected ? 22 : 20,
                            ),
                          ),
                        ),

                        SizedBox(height: 3.h),

                        // Label with smooth animation
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? HominodeTheme.blue
                                  : const Color(0xFF6B7280),
                              letterSpacing: isSelected ? 0.1 : 0.05,
                              height: 1.0,
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Active indicator with smooth animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: EdgeInsets.only(top: 2.h),
                          width: isSelected ? 4 : 0,
                          height: isSelected ? 4 : 0,
                          decoration: BoxDecoration(
                            color: HominodeTheme.teal,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // If already on the selected tab, do nothing
    if (index == widget.selectedIndex) return;

    // Add haptic feedback for better UX
    HapticFeedback.selectionClick();

    // Smooth page transition
    Widget? targetPage;

    try {
      switch (index) {
        case 0: // Home
          targetPage = const AdminDashboardPage();
          break;
        case 1: // Buildings
          targetPage = const ManageBuildingsPage();
          break;
        case 2: // Residents
          targetPage = const AdminResidentsPageFirestore();
          break;
        case 3: // Billing
          targetPage = const BillingScreen();
          break;
        case 4: // Profile
          targetPage = const ProfileScreen();
          break;
        default:
          // Handle unexpected index
          return;
      }

      _navigateWithTransition(context, targetPage, index);
    } catch (e) {
      // Handle navigation errors gracefully
      debugPrint('Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Navigation error occurred'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateWithTransition(BuildContext context, Widget page, int index) {
    try {
      // Use different navigation strategies based on the target
      if (index == 0) {
        // Home - return to the root AuthWrapper route.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (widget.selectedIndex == 0) {
        // From home to other screens - push
        Navigator.push(context, _createSmoothRoute(page));
      } else {
        // Between non-home screens - replace
        Navigator.pushReplacement(context, _createSmoothRoute(page));
      }
    } catch (e) {
      // Fallback navigation if smooth transition fails
      debugPrint('Smooth navigation failed, using fallback: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  PageRouteBuilder _createSmoothRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Enhanced smooth transition with multiple effects

        // Primary slide animation
        const slideBegin = Offset(0.0, 0.03);
        const slideEnd = Offset.zero;
        final slideTween = Tween(begin: slideBegin, end: slideEnd);
        final slideAnimation = animation.drive(
          slideTween.chain(CurveTween(curve: Curves.easeOutCubic)),
        );

        // Fade animation with custom curve
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuart),
          ),
        );

        // Scale animation for subtle zoom effect
        final scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

        // Secondary animation for exit transition
        final secondarySlideAnimation =
            Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.02, 0.0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeInCubic,
              ),
            );

        final secondaryFadeAnimation = Tween<double>(begin: 1.0, end: 0.8)
            .animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeInCubic,
              ),
            );

        return SlideTransition(
          position: secondarySlideAnimation,
          child: FadeTransition(
            opacity: secondaryFadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: ScaleTransition(scale: scaleAnimation, child: child),
              ),
            ),
          ),
        );
      },
    );
  }

  // Retained for the existing mobile interaction design.
  // ignore: unused_element
  void _showProfileComingSoon(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20.w),
              SizedBox(width: 12.w),
              Text(
                'Profile page coming soon',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: HominodeTheme.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          margin: EdgeInsets.all(16.w),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error showing profile notification: $e');
    }
  }
}
