import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'theme/hominode_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Set status bar style to light content
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Start animation
    _animationController.forward();

    // Navigate after delay
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    Future.delayed(const Duration(seconds: 3), () {
      // TODO: Navigate to Login / Onboarding screen after delay
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => const LoginScreen()),
      // );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: HominodeTheme.primaryGradient,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Section
                        _buildLogo(),

                        SizedBox(height: 16.h),

                        // App Name
                        Text(
                          'Hominode',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // Tagline
                        Text(
                          'Your Community, Connected',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100.w,
      height: 100.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: HominodeTheme.navy.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
          child: Stack(
            children: [
              // Main logo shape - abstract "L" design
              Positioned(
                left: 20,
                top: 15,
                child: Container(
                  width: 12.w,
                  height: 55.h,
                  decoration: BoxDecoration(
                    color: HominodeTheme.navy,
                    borderRadius: BorderRadius.circular(6.r),
                    boxShadow: [
                      BoxShadow(
                        color: HominodeTheme.navy.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Secondary shape
              Positioned(
                left: 40,
                top: 25,
                child: Container(
                  width: 8.w,
                  height: 35.h,
                  decoration: BoxDecoration(
                    color: HominodeTheme.blue,
                    borderRadius: BorderRadius.circular(4.r),
                    boxShadow: [
                      BoxShadow(
                        color: HominodeTheme.blue.withValues(alpha: 0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // Accent dot
              Positioned(
                right: 25,
                bottom: 25,
                child: Container(
                  width: 6.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: HominodeTheme.teal,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
