import 'package:resident_app/src/services/resident_private_images.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'community_wall_screen.dart';
import 'complaints_screen.dart';
import 'profile_screen.dart';
import 'src/screens/emergency_sos_screen.dart';
import 'src/screens/messages_screen.dart';
import 'src/screens/notifications_screen.dart';
import 'events_announcements_screen.dart';
import 'src/services/apartment_images_service.dart';
import 'src/services/bill_firestore_service.dart';
import 'src/services/recent_activity_flow_function.dart';
import 'src/services/subscription_entitlement_service.dart';
import 'src/services/tenant_resolution_service.dart';
import 'src/services/visitor_firestore_service.dart';
import 'src/widgets/resident_home_quick_actions.dart';
import 'src/widgets/resident_home_identity_actions.dart';
import 'src/widgets/community_image_slideshow.dart';
import 'src/widgets/resident_notification_button.dart';
import 'src/services/notice_firestore_service.dart';
import 'src/widgets/resident_home_due_payment_content.dart';
import 'src/widgets/resident_home_summary_navigation.dart';
import 'src/widgets/resident_home_summary_card.dart';
import 'src/widgets/community_verification_feedback.dart';
import 'src/services/community_wall_entitlement_policy.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  final bool isActive;

  const DashboardScreen({super.key, this.onTabChange, this.isActive = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _navy = Color(0xFF082F73);
  static const Color _ink = Color(0xFF0E2247);
  static const Color _muted = Color(0xFF667792);
  static const Color _pageBg = Color(0xFFF7F9FD);

  StreamSubscription<List<String>>? _imageSubscription;
  String? _imageScope;
  Stream<int>? _unreadCounts;
  late Future<List<dynamic>> _recentActivityFuture;

  final _billService = BillFirestoreService();
  final _visitorService = VisitorFirestoreService();
  final _apartmentImagesService = ApartmentImagesService();

  String _userName = '';
  String _userFlat = '';
  String _organizationName = '';
  bool _isLoading = true;

  Map<String, dynamic>? _upcomingVisitor;
  Map<String, dynamic>? _currentBill;
  String? _profileImageUrl;
  List<String> _bannerImages = [];
  final _communityWallFeedback = CommunityVerificationFeedback();

  @override
  void initState() {
    super.initState();
    _recentActivityFuture = _fetchRecentActivities();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _communityWallFeedback.cancel();
    }
  }

  void _navigateToTab(int index) {
    _communityWallFeedback.cancel();
    widget.onTabChange?.call(index);
  }

  void _prepareForDashboardNavigation() {
    _communityWallFeedback.cancel();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) setState(() => _isLoading = true);
    final tenantName = context.read<TenantResolutionService>().current?.name;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? '';
      final userFlat = userData['flatLabel'] ?? userData['flatId'] ?? '';
      final userOrganization = (userData['organization'] as String?)?.trim();
      var organizationName = tenantName?.isNotEmpty == true
          ? tenantName!
          : userOrganization?.isNotEmpty == true
          ? userOrganization!
          : '';

      final communityId = (userData['communityId'] as String?)?.trim();
      if (communityId?.isNotEmpty == true) {
        try {
          final communityDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .get();
          final communityName = (communityDoc.data()?['name'] as String?)
              ?.trim();
          if (communityDoc.exists && communityName?.isNotEmpty == true) {
            organizationName = communityName!;
          }
        } catch (error) {
          debugPrint(
            'Dashboard community lookup failed for $communityId: $error',
          );
        }
      }

      final bills = await _billService.getBills();
      final payableBills =
          bills.where((bill) {
            if (BillFirestoreService.isV2Bill(bill)) {
              final outstanding = bill['outstandingAmountMinor'];
              return BillFirestoreService.isV2InrBill(bill) &&
                  outstanding is int &&
                  outstanding > 0;
            }
            return (bill['status'] as String?)?.toLowerCase() == 'pending';
          }).toList()..sort((a, b) {
            DateTime dueDate(Map<String, dynamic> bill) {
              final value = bill['dueDate'];
              return value is Timestamp
                  ? value.toDate()
                  : value is DateTime
                  ? value
                  : DateTime(9999);
            }

            return dueDate(a).compareTo(dueDate(b));
          });
      final currentBill = payableBills.isEmpty ? null : payableBills.first;

      final visitors = await _visitorService.getMyVisitors();

      final now = DateTime.now();

      final upcomingVisitor =
          visitors.where((visitor) {
            final status = (visitor['status'] as String? ?? '').toLowerCase();
            final denied =
                visitor['securityDeniedAt'] != null ||
                visitor['entryDeniedAt'] != null ||
                status == 'denied';
            final date = _visitorArrival(visitor['expectedArrival']);
            return status == 'expected' &&
                !denied &&
                date != null &&
                !date.isBefore(now);
          }).toList()..sort((a, b) {
            return _visitorArrival(
              a['expectedArrival'],
            )!.compareTo(_visitorArrival(b['expectedArrival'])!);
          });

      if (mounted) {
        setState(() {
          _userName = userName;
          _userFlat = userFlat;
          _organizationName = organizationName;
          _currentBill = currentBill;
          _upcomingVisitor = upcomingVisitor.isEmpty
              ? null
              : upcomingVisitor.first;
          _profileImageUrl =
              userData['profileImageUrl'] as String? ??
              userData['photoUrl'] as String?;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Dashboard load error: $e');
      debugPrint('$stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tenant = Provider.of<TenantResolutionService>(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final community = tenant.communityId;
    final scope = uid == null || community == null ? null : '$uid/$community';
    if (scope == _imageScope) return;
    _imageScope = scope;
    _bannerImages = [];
    _unreadCounts = scope == null
        ? null
        : NoticeFirestoreService.instance.streamUnreadCount();
    _imageSubscription?.cancel();
    _imageSubscription = scope == null
        ? null
        : _apartmentImagesService
              .streamCommunityImages(community!)
              .listen(
                (images) {
                  if (mounted && _imageScope == scope)
                    setState(() => _bannerImages = images);
                },
                onError: (Object _) {
                  if (mounted && _imageScope == scope)
                    setState(() => _bannerImages = []);
                },
              );
  }

  @override
  void dispose() {
    _imageSubscription?.cancel();
    _communityWallFeedback.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Image.asset(
                'assets/hominode_residential_hero.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.expand(),
              ),
            ),
            const ColoredBox(color: Color(0xB8F7FAFD)),
            RefreshIndicator(
              onRefresh: () async {
                await _loadDashboardData();
                NoticeFirestoreService.instance.refreshUnreadCount();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroAndBanner(),
                    SizedBox(height: 12.h),
                    _buildQuickAccessSection(),
                    SizedBox(height: 18.h),
                    _buildSummaryCards(),
                    SizedBox(height: 16.h),
                    _buildFacilityBanner(),
                    SizedBox(height: 18.h),
                    _buildRecentActivitySection(),
                    SizedBox(height: 110.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroAndBanner() {
    final topInset = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, topInset + 10.h, 18.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ResidentHomeLogo(),
              const Spacer(),
              _notificationButton(),
              SizedBox(width: 10.w),
              InkWell(
                onTap: () {
                  _prepareForDashboardNavigation();
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24.r),
                child: CircleAvatar(
                  radius: 21.r,
                  backgroundColor: Colors.white,
                  backgroundImage: _profileImageUrl?.isNotEmpty == true
                      ? residentImageProvider(_profileImageUrl!)
                      : null,
                  child: _profileImageUrl?.isNotEmpty == true
                      ? null
                      : Icon(Icons.person_outline, color: _navy, size: 24.w),
                ),
              ),
            ],
          ),
          SizedBox(height: 17.h),
          Text(
            'good_morning'.tr(),
            style: TextStyle(color: _muted, fontSize: 13.sp),
          ),
          Text(
            'home_greeting_name'.tr(
              namedArgs: {
                'name': _userName.isEmpty ? 'resident'.tr() : _userName,
              },
            ),
            softWrap: true,
            style: TextStyle(
              color: _ink,
              fontSize: 25.sp,
              height: 1.18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7.h),
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: _navy, size: 19.w),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  _organizationName.isEmpty
                      ? 'your_apartment'.tr()
                      : _organizationName,
                  softWrap: true,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _userFlat.isEmpty ? 'not_set'.tr() : _userFlat,
                style: TextStyle(
                  color: _navy,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const ResidentHomeEmergencySosButton(),
          SizedBox(height: 15.h),
          _communityHeroCard(),
        ],
      ),
    );
  }

  Widget _communityHeroCard() {
    final textScale = MediaQuery.textScalerOf(context).scale(1).toDouble();
    return Container(
      height: 204.h * textScale,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26.r),
        color: const Color(0xFFDCE7F0),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: .12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.r),
        child: CommunityImageSlideshow(
          key: ValueKey(_imageScope),
          images: _bannerImages,
          active: widget.isActive,
          foregroundBuilder: (context, index, count) => Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xEDF7FAFC),
                        Color(0xB8F7FAFC),
                        Color(0x087F8FA6),
                      ],
                      stops: [0, .57, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'your_community'.tr(),
                      style: TextStyle(
                        color: _navy,
                        fontSize: 10.sp,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 7.h),
                    Text(
                      'a_better_tomorrow'.tr(),
                      style: TextStyle(
                        color: _ink,
                        fontSize: 29.sp,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'modern_living_subtitle'.tr(),
                      maxLines: 2,
                      style: TextStyle(
                        color: const Color(0xFF40536B),
                        fontSize: 12.5.sp,
                      ),
                    ),
                    const Spacer(),
                    if (count > 1)
                      Row(
                        children: List.generate(
                          count,
                          (i) => Container(
                            margin: EdgeInsets.only(right: 6.w),
                            width: i == index ? 16.w : 7.w,
                            height: 7.w,
                            decoration: BoxDecoration(
                              color: i == index
                                  ? _navy
                                  : _navy.withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationButton() => ResidentNotificationButton(
    key: ValueKey('notifications/$_imageScope'),
    unreadCounts: widget.isActive
        ? (_unreadCounts ?? const Stream<int>.empty())
        : const Stream<int>.empty(),
    onTap: () async {
      _prepareForDashboardNavigation();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      );
      if (mounted)
        setState(
          () => _unreadCounts = NoticeFirestoreService.instance
              .streamUnreadCount(),
        );
    },
  );

  Widget _buildSummaryCards() {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final visitor = _upcomingVisitor;
    final visitorCard = ResidentHomeSummaryCard(
      icon: Icons.schedule_rounded,
      title: 'upcoming_visitor'.tr(),
      action: 'view_all'.tr(),
      onAction: _openVisitors,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : visitor == null
          ? _informationEmpty(
              Icons.directions_walk_outlined,
              'no_upcoming_visitors'.tr(),
            )
          : _visitorPreview(visitor),
    );
    final bill = _currentBill;
    final due = _billOutstandingLabel(bill);
    final billCard = ResidentHomeSummaryCard(
      icon: Icons.credit_card_outlined,
      title: 'due_payment'.tr(),
      action: 'view_all'.tr(),
      onAction: _openBilling,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ResidentHomeDuePaymentContent(
              amount: due,
              isEmpty: bill == null,
              billTitle: bill == null
                  ? 'no_current_bill'.tr()
                  : (bill['title']?.toString() ?? 'maintenance_charges'.tr()),
              onViewBilling: _openBilling,
              viewBillingLabel: 'view_billing'.tr(),
            ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: width < 376 || textScale > 1.2
          ? Column(
              children: [
                visitorCard,
                SizedBox(height: 12.h),
                billCard,
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: visitorCard),
                  SizedBox(width: 12.w),
                  Expanded(child: billCard),
                ],
              ),
            ),
    );
  }

  String _billOutstandingLabel(Map<String, dynamic>? bill) {
    if (bill == null) return '—';
    if (BillFirestoreService.isV2Bill(bill)) {
      final minor = bill['outstandingAmountMinor'];
      return minor is int
          ? BillFirestoreService.formatV2BillMinorUnits(bill, minor)
          : '—';
    }
    final amount = (bill['amount'] as num?)?.toDouble() ?? 0;
    return '₹${amount.toStringAsFixed(0)}';
  }

  Widget _visitorPreview(Map<String, dynamic> visitor) {
    final name = visitor['visitorName']?.toString().trim();
    final arrival = visitor['expectedArrival'];
    final date = _visitorArrival(arrival);
    return Row(
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: const Color(0xFFE6EFF7),
          child: Icon(Icons.person_outline, color: _navy, size: 23.w),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name?.isNotEmpty == true ? name! : 'visitor'.tr(),
                softWrap: true,
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                date == null
                    ? 'expected_arrival_unavailable'.tr()
                    : _formatArrival(date),
                softWrap: true,
                style: TextStyle(color: _muted, fontSize: 11.5.sp),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatArrival(DateTime date) =>
      '${date.day}/${date.month} · ${TimeOfDay.fromDateTime(date).format(context)}';

  DateTime? _visitorArrival(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Widget _informationEmpty(IconData icon, String label) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: _muted.withValues(alpha: .6), size: 27.w),
        SizedBox(height: 5.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11.5.sp),
        ),
      ],
    ),
  );

  Widget _buildFacilityBanner() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: InkWell(
      onTap: () => _navigateToTab(1),
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        height: 106.h * MediaQuery.textScalerOf(context).scale(1),
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          color: const Color(0xFFDCE8F0),
          image: DecorationImage(
            image: _bannerImages.isEmpty
                ? const AssetImage('assets/hominode_residential_hero.jpg')
                : residentImageProvider(_bannerImages.first),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: .08),
              blurRadius: 13,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'book_a_facility'.tr(),
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'explore_community_amenities'.tr(),
                      softWrap: true,
                      style: TextStyle(color: _muted, fontSize: 11.5.sp),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .86),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: _navy,
                size: 22.w,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openCommunityWallIfAllowed() async {
    final tenantResolution = context.read<TenantResolutionService>();
    final communityId = tenantResolution.communityId;

    if (communityId == null || communityId.trim().isEmpty) {
      if (!mounted) return;

      _communityWallFeedback.showNotice(
        context: context,
        message: 'community_resolution_retry'.tr(),
      );
      return;
    }

    var accessStatus = CommunityWallAccessStatus.featureUnavailable;
    await _communityWallFeedback.run(
      context: context,
      operation: 'home/community-wall-entitlement',
      verify: () async {
        final entitlement = await ResidentSubscriptionEntitlementService()
            .getEntitlement(communityId);
        accessStatus = CommunityWallEntitlementPolicy.evaluate(entitlement);
      },
      onFailure: (error) {
        if (CommunityWallEntitlementPolicy.classifyFailure(error) ==
            CommunityWallVerificationFailure.missingSubscription) {
          _communityWallFeedback.showNotice(
            context: context,
            message: 'community_subscription_not_configured'.tr(),
          );
        } else {
          _communityWallFeedback.showRetryableNotice(
            context: context,
            message: 'community_wall_verification_error'.tr(),
            retryLabel: 'retry'.tr(),
            onRetry: () => unawaited(_openCommunityWallIfAllowed()),
          );
        }
      },
      onSuccess: () {
        if (accessStatus != CommunityWallAccessStatus.allowed) {
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('community_unavailable_title'.tr()),
              content: Text(
                accessStatus == CommunityWallAccessStatus.subscriptionInactive
                    ? 'community_subscription_inactive'.tr()
                    : 'community_wall_restricted'.tr(),
              ),
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

        _prepareForDashboardNavigation();
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CommunityWallScreen(),
            ),
          ),
        );
      },
    );
  }

  void _openVisitors() {
    _prepareForDashboardNavigation();
    openResidentHomeVisitors(context);
  }

  void _openBilling() {
    _prepareForDashboardNavigation();
    openResidentHomeBillingRoute(context);
  }

  Widget _buildQuickAccessSection() {
    final items = <ResidentHomeAction>[
      ResidentHomeAction(
        icon: Icons.groups_2_outlined,
        label: 'visitors'.tr(),
        iconColor: const Color(0xFF1568E9),
        backgroundColor: const Color(0xFFE7F0FF),
        onTap: _openVisitors,
      ),
      ResidentHomeAction(
        icon: Icons.event_available_outlined,
        label: 'amenities'.tr(),
        iconColor: const Color(0xFF08A760),
        backgroundColor: const Color(0xFFE2F8EA),
        onTap: () => _navigateToTab(1),
      ),
      ResidentHomeAction(
        icon: Icons.credit_card_outlined,
        label: 'billing'.tr(),
        iconColor: const Color(0xFF08A760),
        backgroundColor: const Color(0xFFE2F8EA),
        onTap: () => _navigateToTab(3),
      ),
      ResidentHomeAction(
        icon: Icons.campaign_outlined,
        label: 'announcements'.tr(),
        iconColor: const Color(0xFF1568E9),
        backgroundColor: const Color(0xFFE7F0FF),
        onTap: () {
          _prepareForDashboardNavigation();
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const EventsAnnouncementsScreen(announcementsOnly: true),
            ),
          );
        },
      ),
      ResidentHomeAction(
        icon: Icons.groups_rounded,
        label: 'community_wall'.tr(),
        iconColor: const Color(0xFF7848F5),
        backgroundColor: const Color(0xFFEDE5FF),
        onTap: _openCommunityWallIfAllowed,
      ),
      ResidentHomeAction(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'messages'.tr(),
        iconColor: const Color(0xFF1568E9),
        backgroundColor: const Color(0xFFE7F0FF),
        onTap: () {
          _prepareForDashboardNavigation();
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const MessagesScreenEnhanced(),
            ),
          );
        },
      ),
      ResidentHomeAction(
        icon: Icons.support_agent_rounded,
        label: 'complaints'.tr(),
        iconColor: const Color(0xFFF26A21),
        backgroundColor: const Color(0xFFFFEFE4),
        onTap: () {
          _prepareForDashboardNavigation();
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ComplaintsScreen()),
          );
        },
      ),
      ResidentHomeAction(
        icon: Icons.shield_outlined,
        label: 'security'.tr(),
        iconColor: const Color(0xFF1558D6),
        backgroundColor: const Color(0xFFE7F0FF),
        onTap: () {
          _prepareForDashboardNavigation();
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const EmergencySosScreen()),
          );
        },
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ResidentHomeQuickActions(items: items, title: 'quick_access'.tr()),
    );
  }

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(15.w, 14.h, 15.w, 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF193A65).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'recent_activity'.tr(),
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // const Spacer(),
                // TextButton(
                //   onPressed: () {},
                //   style: TextButton.styleFrom(
                //     padding: EdgeInsets.zero,
                //     minimumSize: Size(52.w, 30.h),
                //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                //   ),
                //   child: Text(
                //     'View All',
                //     style: TextStyle(
                //       color: _blue,
                //       fontSize: 13.sp,
                //       fontWeight: FontWeight.w700,
                //     ),
                //   ),
                // ),
              ],
            ),
            FutureBuilder<List<dynamic>>(
              future: _recentActivityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final activities = snapshot.data ?? [];
                if (activities.isEmpty) return _emptyRecentActivity();

                return Column(
                  children: List.generate(
                    activities.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 6.h : 10.h),
                      child: _activityItemFromData(activities[index]),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyRecentActivity() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 2.h),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 58.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.assignment_outlined,
              color: const Color(0xFF75A2F4),
              size: 34.w,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'no_recent_activities'.tr(),
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'you_are_all_caught_up'.tr(),
                  style: TextStyle(color: _muted, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _fetchRecentActivities() async {
    try {
      final result = await RecentActivityFlowFunction.instance
          .fetchRecentActivities(limit: 5);
      return result.success ? result.activities : [];
    } catch (e) {
      debugPrint('Recent activity error: $e');
      return [];
    }
  }

  String _localizedActivityTitle(dynamic activity) {
    final data = activity.data as Map<String, dynamic>? ?? const {};
    switch (activity.activityType) {
      case 'booking':
        return 'activity_booking_title'.tr(
          namedArgs: {'name': (data['amenityName'] ?? 'amenity').toString()},
        );
      case 'visitor':
        return 'activity_visitor_title'.tr(
          namedArgs: {'name': (data['visitorName'] ?? 'unknown').toString()},
        );
      case 'complaint':
        return 'activity_complaint_title'.tr(
          namedArgs: {'category': (data['category'] ?? 'general').toString()},
        );
      default:
        return activity.title as String;
    }
  }

  String _localizedActivitySubtitle(dynamic activity) {
    final data = activity.data as Map<String, dynamic>? ?? const {};
    final date = _localizedRelativeTime(activity.timestamp as DateTime);
    if (activity.activityType == 'visitor') {
      final phone = data['visitorPhone']?.toString() ?? '';
      return phone.isEmpty ? date : '$phone · $date';
    }
    if (activity.activityType == 'complaint') {
      final description = data['description']?.toString() ?? '';
      return description.isEmpty ? date : '$description · $date';
    }
    return date;
  }

  String _localizedRelativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just_now'.tr();
    if (difference.inMinutes < 60)
      return 'minutes_ago'.tr(namedArgs: {'count': '${difference.inMinutes}'});
    if (difference.inHours < 24)
      return 'hours_ago'.tr(namedArgs: {'count': '${difference.inHours}'});
    if (difference.inDays == 1) return 'yesterday'.tr();
    if (difference.inDays < 7)
      return 'days_ago'.tr(namedArgs: {'count': '${difference.inDays}'});
    return '${date.day}/${date.month}/${date.year}';
  }

  String _localizedActivityStatus(String status) {
    final key = switch (status.toLowerCase()) {
      'pending' => 'pending',
      'confirmed' => 'confirmed',
      'approved' => 'approved',
      'received' => 'received',
      'rejected' => 'rejected',
      'cancelled' => 'cancelled',
      'paid' || 'settled' => 'paid',
      'partially_paid' || 'partially paid' => 'partially_paid',
      'overdue' => 'overdue',
      'checked_in' || 'checked in' => 'visitor_status_checked_in',
      'checked_out' || 'checked out' => 'visitor_status_checked_out',
      'entry_denied' || 'entry denied' => 'visitor_status_entry_denied',
      'open' => 'open',
      'in_progress' || 'in progress' => 'in_progress',
      'resolved' => 'resolved',
      'closed' => 'closed',
      _ => null,
    };
    return key == null ? status : key.tr();
  }

  Widget _activityItemFromData(dynamic activity) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    if (activity.activityType == 'booking') {
      icon = Icons.calendar_today;
      iconColor = const Color(0xFF7848F5);
      iconBg = const Color(0xFFEDE5FF);
    } else if (activity.activityType == 'visitor') {
      icon = Icons.shield_outlined;
      iconColor = const Color(0xFFF26A21);
      iconBg = const Color(0xFFFFEFE4);
    } else if (activity.activityType == 'complaint') {
      icon = Icons.warning_amber_rounded;
      iconColor = const Color(0xFFE54848);
      iconBg = const Color(0xFFFFE8E8);
    } else {
      icon = Icons.info_outline_rounded;
      iconColor = const Color(0xFF1568E9);
      iconBg = const Color(0xFFE7F0FF);
    }

    final status = activity.statusText.toLowerCase();
    late Color statusColor;
    late Color statusBg;

    if (status.contains('confirmed') ||
        status.contains('approved') ||
        status.contains('received')) {
      statusColor = const Color(0xFF08A760);
      statusBg = const Color(0xFFE2F8EA);
    } else if (status.contains('pending')) {
      statusColor = const Color(0xFFE39513);
      statusBg = const Color(0xFFFFF2D6);
    } else if (status.contains('rejected') || status.contains('cancelled')) {
      statusColor = const Color(0xFFE54848);
      statusBg = const Color(0xFFFFE8E8);
    } else {
      statusColor = const Color(0xFF1568E9);
      statusBg = const Color(0xFFE7F0FF);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Icon(icon, color: iconColor, size: 22.w),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _localizedActivityTitle(activity),
                softWrap: true,
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _localizedActivitySubtitle(activity),
                softWrap: true,
                style: TextStyle(
                  color: _muted,
                  fontSize: 11.5.sp,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(9.r),
          ),
          child: Text(
            _localizedActivityStatus(activity.statusText),
            style: TextStyle(
              color: statusColor,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
