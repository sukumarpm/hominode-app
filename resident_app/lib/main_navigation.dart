import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hominode_notifications/hominode_notifications.dart';
import 'package:provider/provider.dart';

import 'dashboard_screen.dart';
import 'src/screens/visitor_management_screen_new.dart';
import 'maintenance_billing_screen.dart';
import 'events_announcements_screen.dart';
import 'profile_screen.dart';
import 'src/screens/amenities_booking_screen.dart';
import 'src/screens/messages_screen_enhanced.dart';
import 'src/screens/emergency_sos_screen.dart';
import 'complaints_screen.dart';
import 'src/screens/notifications_screen.dart';
import 'src/screens/marketplace_screen.dart';
import 'src/widgets/flat_access_wrapper.dart';
import 'src/widgets/community_verification_feedback.dart';
import 'src/widgets/resident_floating_bottom_navigation.dart';
import 'src/widgets/resident_navigation_loading_overlay.dart';
import 'src/services/subscription_entitlement_service.dart';
import 'src/services/tenant_resolution_service.dart';

/// Main Navigation Screen with Smooth Animated Bottom Navigation Bar
/// Uses IndexedStack to preserve state of all screens while switching tabs
/// Wrapped with FlatAccessWrapper for access control
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isNavigationLoading = false;
  final _communityAccessFeedback = CommunityVerificationFeedback();
  late AnimationController _animationController;

  // All screens - state is preserved with IndexedStack
  List<Widget> get _screens => [
    DashboardScreen(onTabChange: _onTabTapped, isActive: _currentIndex == 0),
    const AmenitiesBookingScreen(),
    const EventsAnnouncementsScreen(announcementsOnly: true),
    const MaintenanceBillingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for smooth transitions
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animationController.forward();
    unawaited(HominodePushNotifications.instance.activate());
  }

  @override
  void dispose() {
    _communityAccessFeedback.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != 2) _communityAccessFeedback.cancel();
    if (index == 4) {
      _openMoreMenu();
      return;
    }
    if (index == 2) {
      unawaited(_openCommunityDestination());
      return;
    }

    _switchTab(index);
  }

  Future<void> _withNavigationLoading(Future<void> Function() operation) async {
    if (_isNavigationLoading) return;
    await runWithNavigationLoading<void>(
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isNavigationLoading = loading);
      },
      operation: operation,
    );
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    _communityAccessFeedback.cancel();

    setState(() {
      _currentIndex = index;
    });

    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _openCommunityDestination() async {
    final tenantResolution = context.read<TenantResolutionService>();
    await _communityAccessFeedback.run(
      context: context,
      operation: 'community-tab/community-membership-resolution',
      verify: () async {
        if (tenantResolution.current == null) {
          await _withNavigationLoading(() async {
            await tenantResolution.resolve();
          });
        }
        if (tenantResolution.communityId?.trim().isNotEmpty != true) {
          throw const TenantResolutionException(
            TenantResolutionFailure.communityMissing,
            'Community membership could not be resolved.',
          );
        }
      },
      onFailure: (error) {
        if (error is TenantResolutionException) {
          _communityAccessFeedback.showNotice(
            context: context,
            message: 'community_resolution_error'.tr(),
          );
          return;
        }
        _communityAccessFeedback.showRetryableNotice(
          context: context,
          message: 'community_access_error'.tr(),
          retryLabel: 'retry'.tr(),
          onRetry: () => unawaited(_openCommunityDestination()),
        );
      },
      onSuccess: () => _switchTab(2),
    );
  }

  void _openMoreMenu() {
    _communityAccessFeedback.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              color: Colors.white.withValues(alpha: .94),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'more'.tr(),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0E2247),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      _moreAction(
                        sheetContext,
                        Icons.groups_outlined,
                        'visitors'.tr(),
                        const VisitorManagementScreenNew(),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.campaign_outlined,
                        'announcements'.tr(),
                        const EventsAnnouncementsScreen(
                          announcementsOnly: true,
                        ),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.calendar_month_outlined,
                        'events'.tr(),
                        null,
                        onTap: () => _openEventsFromMore(sheetContext),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.chat_bubble_outline,
                        'messages'.tr(),
                        const MessagesScreenEnhanced(),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.support_agent_outlined,
                        'complaints'.tr(),
                        const ComplaintsScreen(),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.shield_outlined,
                        'security'.tr(),
                        const EmergencySosScreen(),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.shopping_bag_outlined,
                        'marketplace'.tr(),
                        const MarketplaceScreen(),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.person_outline,
                        'profile'.tr(),
                        const ProfileScreen(),
                      ),
                      _moreAction(
                        sheetContext,
                        Icons.notifications_outlined,
                        'notifications'.tr(),
                        const NotificationsScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _moreAction(
    BuildContext sheetContext,
    IconData icon,
    String label,
    Widget? screen, {
    VoidCallback? onTap,
  }) => SizedBox(
    width: (MediaQuery.sizeOf(sheetContext).width - 60.w) / 3,
    child: InkWell(
      onTap:
          onTap ??
          () {
            Navigator.pop(sheetContext);
            if (screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => screen),
              );
            }
          },
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1F7),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(icon, color: const Color(0xFF173B60), size: 23.w),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF23364D),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openEventsFromMore(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    bool? hasAccess;
    await _withNavigationLoading(() async {
      hasAccess = await _checkEventsEntitlement();
    });
    if (!mounted || hasAccess == null) return;
    if (!hasAccess!) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('events_unavailable_title'.tr()),
          content: Text('events_restricted'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const EventsAnnouncementsScreen(eventsOnly: true),
      ),
    );
  }

  Future<bool?> _checkEventsEntitlement() async {
    final communityId = context.read<TenantResolutionService>().communityId;
    if (communityId == null || communityId.trim().isEmpty) return null;
    try {
      final entitlement = await ResidentSubscriptionEntitlementService()
          .getEntitlement(communityId);
      return entitlement?.canUseFeature('events') == true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('events_verification_error'.tr())),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlatAccessWrapper(
      child: ResidentNavigationLoadingOverlay(
        loading: _isNavigationLoading,
        child: Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: _buildAnimatedBottomNavBar(),
        ),
      ),
    );
  }

  /// Animated Bottom Navigation Bar with smooth transitions
  Widget _buildAnimatedBottomNavBar() {
    return ResidentFloatingBottomNavigation(
      selectedIndex: _currentIndex,
      onSelected: _onTabTapped,
      items: [
        ResidentNavigationItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'nav_home'.tr(),
        ),
        ResidentNavigationItem(
          icon: Icons.event_available_outlined,
          activeIcon: Icons.event_available,
          label: 'nav_facilities'.tr(),
        ),
        ResidentNavigationItem(
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups,
          label: 'nav_community'.tr(),
        ),
        ResidentNavigationItem(
          icon: Icons.credit_card_outlined,
          activeIcon: Icons.credit_card,
          label: 'nav_payments'.tr(),
        ),
        ResidentNavigationItem(
          icon: Icons.apps_outlined,
          activeIcon: Icons.apps,
          label: 'nav_more'.tr(),
        ),
      ],
    );
  }
}
