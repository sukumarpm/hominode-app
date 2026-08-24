import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

/// Clean, Modern Splash Screen
///
/// Features:
/// - Simple gradient background
/// - Logo fade-in with scale animation
/// - App name and tagline
/// - Bottom loading indicator (spinner or progress dots)
/// - Total duration: ~3 seconds
/// - Professional, minimal design
class CleanSplashScreen extends StatefulWidget {
  final String logoAssetPath;
  final String? appName;
  final String? tagline;
  final Duration duration;
  final VoidCallback? onFinish;
  final Color primaryColor;
  final Color secondaryColor;

  const CleanSplashScreen({
    super.key,
    this.logoAssetPath = 'assets/logo1.png',
    this.appName = 'Hominode',
    this.tagline = 'Your Community, Connected',
    this.duration = const Duration(milliseconds: 3000),
    this.onFinish,
    this.primaryColor = const Color(0xFF0E4778),
    this.secondaryColor = const Color(0xFF061C4C),
  });

  @override
  State<CleanSplashScreen> createState() => _CleanSplashScreenState();
}

class _CleanSplashScreenState extends State<CleanSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loaderController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSplashSequence();
  }

  void _initAnimations() {
    // Logo animation (0.8s)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Text animation (0.6s)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Loader animation (continuous)
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _startSplashSequence() async {
    // Start logo animation
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _logoController.forward();
    }

    // Start text animation after logo
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _textController.forward();
    }

    // Wait for total duration
    await Future.delayed(widget.duration);

    // Navigate
    if (mounted && widget.onFinish != null) {
      widget.onFinish!();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.primaryColor, widget.secondaryColor],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Main content (centered)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        AnimatedBuilder(
                          animation: _logoController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _logoOpacity.value,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Container(
                                  width: 140.w,
                                  height: 140.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(28.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(24.w),
                                  child: Image.asset(
                                    widget.logoAssetPath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: 32.h),

                        // App Name
                        AnimatedBuilder(
                          animation: _textController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _textOpacity.value,
                              child: Column(
                                children: [
                                  Text(
                                    widget.appName ?? 'Hominode',
                                    style: TextStyle(
                                      fontSize: 32.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    widget.tagline ??
                                        'Your Community, Connected',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom loading indicator
                Padding(
                  padding: EdgeInsets.only(bottom: 60.h),
                  child: _buildLoadingIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _loaderController,
      builder: (context, child) {
        return Column(
          children: [
            // Animated dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final animValue = (_loaderController.value + delay) % 1.0;
                final scale = (animValue < 0.5)
                    ? 1.0 + (animValue * 0.6)
                    : 1.3 - ((animValue - 0.5) * 0.6);

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
