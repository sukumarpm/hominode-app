import 'src/models/resident_visitor_authorization.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'src/widgets/resident_visitor_page_background.dart';
import 'src/services/resident_visitor_pass_service.dart';
import 'src/models/resident_visitor_lifecycle.dart';
import 'src/services/visitor_qr_contract.dart';
import 'src/services/resident_visitor_policy_service.dart';
import 'src/models/resident_visitor_timing.dart';

/// Visitor QR Pass Screen
/// Displays authenticated, server-issued QR and manual visitor credentials.
class VisitorQRScreen extends StatefulWidget {
  final String visitorId;

  const VisitorQRScreen({
    super.key,
    required this.visitorId,
    this.loadPass,
    this.watchVisitor,
    this.watchCommunity,
    this.loadTimeZone,
  });
  final Future<String?> Function()? loadTimeZone;
  final Future<ResidentVisitorPass> Function(String)? loadPass;
  final Stream<Map<String, dynamic>?> Function(String)? watchVisitor;
  final Stream<Object?> Function(String)? watchCommunity;

  @override
  State<VisitorQRScreen> createState() => _VisitorQRScreenState();
}

class _VisitorQRScreenState extends State<VisitorQRScreen>
    with WidgetsBindingObserver {
  ResidentVisitorPass? _pass;
  Map<String, dynamic>? _visitorData;
  bool _isLoading = true;
  String? _error;
  bool _isAwaitingApproval = false;
  bool _canRetry = false;
  final _service = ResidentVisitorPassService();
  StreamSubscription<Map<String, dynamic>?>? _visitorSubscription;
  StreamSubscription<Object?>? _communitySubscription;
  Timer? _windowTimer;
  String? _community;
  int _request = 0;
  String? _timeZone;
  int _zoneRequest = 0;
  Future<void> _loadTimeZone() async {
    final ticket = ++_zoneRequest;
    try {
      final zone = widget.loadTimeZone != null
          ? await widget.loadTimeZone!()
          : (await ResidentVisitorPolicyService().loadScope()).timeZone;
      final canonical = CommunityTime.canonical(zone);
      if (mounted && ticket == _zoneRequest) {
        setState(() => _timeZone = canonical);
      }
    } catch (_) {
      if (mounted && ticket == _zoneRequest) setState(() => _timeZone = null);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimeZone();
    _start();
  }

  void _start() {
    if (widget.watchVisitor == null && widget.loadPass != null) {
      _loadVisitorData();
      return;
    }
    _visitorSubscription?.cancel();
    _visitorSubscription =
        (widget.watchVisitor ?? _service.watchVisitor)(widget.visitorId).listen(
          (row) {
            final community = row?['communityId'] as String?;
            if (community != null && community != _community) {
              _community = community;
              _communitySubscription?.cancel();
              _communitySubscription =
                  (widget.watchCommunity ?? _service.watchCommunity)(
                    community,
                  ).listen((_) {
                    _loadTimeZone();
                    _loadVisitorData();
                  }, onError: (Object error) => _watchError(error));
            }
            _loadVisitorData();
          },
          onError: (Object error) => _watchError(error),
        );
  }

  void _watchError(Object error) {
    _request++;
    _windowTimer?.cancel();
    if (mounted) {
      setState(() {
        _pass = null;
        _isLoading = false;
        _setError(error);
      });
    }
  }

  // Presentation only: a pending local record never grants or blocks credentials.
  void _setError(Object error) {
    final code = error is FirebaseException
        ? error.code
        : error is ResidentVisitorPassUnavailable
        ? error.code
        : null;
    final message = error is ResidentVisitorPassUnavailable
        ? error.message
        : error is StateError
        ? error.message.toString()
        : error is FirebaseException
        ? residentVisitorError(error)
        : 'visitor_load_error'.tr();
    _isAwaitingApproval =
        code == 'failed-precondition' &&
        const {
          'This invitation requires Admin approval under the current policy.',
          'Admin approval required',
        }.contains(message);
    _canRetry =
        !_isAwaitingApproval &&
        (error is TimeoutException ||
            const {
              'unavailable',
              'deadline-exceeded',
              'network-request-failed',
              'aborted',
            }.contains(code));
    _error = _isAwaitingApproval
        ? 'Your QR pass will be available once your Community Admin approves this invitation.'
        : message;
  }

  void _armRevalidation(ResidentVisitorTiming timing) {
    _windowTimer?.cancel();
    final remaining = timing.remaining;
    if (remaining != null) _windowTimer = Timer(remaining, _loadVisitorData);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTimeZone();
      _loadVisitorData();
    }
  }

  @override
  void didUpdateWidget(covariant VisitorQRScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitorId != widget.visitorId) {
      _request++;
      _community = null;
      _timeZone = null;
      _loadTimeZone();
      _communitySubscription?.cancel();
      _start();
    }
  }

  @override
  void dispose() {
    _request++;
    _windowTimer?.cancel();
    _visitorSubscription?.cancel();
    _communitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadVisitorData() async {
    if (!mounted) return;
    final request = ++_request;
    _windowTimer?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
      _isAwaitingApproval = false;
      _canRetry = false;
      _pass = null;
      _visitorData = null;
    });
    try {
      final pass = await (widget.loadPass ?? _service.load)(widget.visitorId);
      if (!mounted || request != _request) return;
      if (pass.timing.remaining == Duration.zero) {
        throw ResidentVisitorPassUnavailable(
          'Policy availability is being rechecked.',
          pass.timing,
        );
      }
      _armRevalidation(pass.timing);
      setState(() {
        _pass = pass;
        _visitorData = pass.visitor;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      if (error is ResidentVisitorPassUnavailable) {
        _armRevalidation(error.timing);
      }
      setState(() {
        _setError(error);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: ResidentVisitorPageBackground(
        child: Column(
          children: [
            // Status bar spacer
            SizedBox(height: MediaQuery.of(context).padding.top),

            Expanded(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? _buildError()
                        : SingleChildScrollView(
                            padding: EdgeInsets.all(24.w),
                            child: Column(
                              children: [
                                SizedBox(height: 20.h),
                                _buildQRCard(),
                                SizedBox(height: 24.h),
                                Text(
                                  _visitorData!['authorizationState'] ==
                                          'pending_admin'
                                      ? 'Pass availability confirmed under the current community policy'
                                      : 'Authorization: ${ResidentVisitorLifecycle.authorizationLabel(_visitorData!)}',
                                ),
                                _buildVisitorDetails(),
                                SizedBox(height: 32.h),
                                _buildInstructions(),
                                SizedBox(height: 24.h),
                                _buildShareButton(context),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        border: Border(bottom: BorderSide(color: Color(0xFFDFE7F1))),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 12.h),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios,
                color: Color(0xFF0E2247),
                size: 20.w,
              ),
              padding: EdgeInsets.all(8.w),
            ),
            SizedBox(width: 4.w),
            Text(
              'visitor_qr_pass'.tr(),
              style: TextStyle(
                color: const Color(0xFF0E2247),
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isAwaitingApproval
                  ? Icons.schedule_outlined
                  : Icons.error_outline,
              size: 64.w,
              color: _isAwaitingApproval
                  ? const Color(0xFF64748B)
                  : const Color(0xFFDC2626),
            ),
            SizedBox(height: 16.h),
            if (_isAwaitingApproval) ...[
              Text(
                'Awaiting Admin approval',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
            ],
            Text(
              _error ?? 'An error occurred',
              style: TextStyle(
                fontSize: _isAwaitingApproval ? 14.sp : 18.sp,
                fontWeight: _isAwaitingApproval
                    ? FontWeight.w400
                    : FontWeight.w600,
                color: _isAwaitingApproval
                    ? const Color(0xFF64748B)
                    : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            if (_canRetry)
              TextButton(
                onPressed: _loadVisitorData,
                child: const Text('Retry'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E4778),
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text('back'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCard() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082F73).withValues(alpha: .09),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Actual QR Code
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => QrImageView(
                data: _pass!.qrPayload,
                version: QrVersions.auto,
                size: constraints.maxWidth.clamp(0, 240),
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // Pass ID
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: SelectableText(
              'Pass code: ${_pass!.manualCode}',
              style: TextStyle(
                color: const Color(0xFF0E4778),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorDetails() {
    if (_visitorData == null) return const SizedBox();

    final visitorName = _visitorData!['visitorName'] ?? 'N/A';
    final purpose = _visitorData!['purpose'] ?? 'N/A';
    final expectedArrival = ResidentVisitorAuthorization.arrival(_visitorData!);
    final timeString = CommunityTime.format(
      expectedArrival,
      _timeZone,
      dateFormat: DateFormat(
        'd MMM y, h:mm a',
        context.locale.toString(),
      ).format,
    );
    final flatLabel =
        _visitorData!['flatLabel'] ?? _visitorData!['flatId'] ?? 'N/A';
    final vehicleNumber = _visitorData!['vehicleNumber'] ?? 'N/A';

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(23.r),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082F73).withValues(alpha: .06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'visitor_details'.tr(),
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          _buildDetailRow(
            icon: Icons.person_outline,
            label: 'visitor_name'.tr(),
            value: visitorName,
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            icon: Icons.home_outlined,
            label: 'visiting'.tr(),
            value: '${'apartment'.tr()} $flatLabel',
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            icon: Icons.category_outlined,
            label: 'purpose'.tr(),
            value: purpose,
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            icon: Icons.access_time,
            label: 'expected_time'.tr(),
            value: timeString,
          ),
          if (vehicleNumber != 'N/A') ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              icon: Icons.directions_car_outlined,
              label: 'my_vehicles'.tr(),
              value: vehicleNumber,
            ),
          ],
          SizedBox(height: 12.h),
          _buildDetailRow(
            icon: Icons.check_circle_outline,
            label: 'status'.tr(),
            value: ResidentVisitorLifecycle.statusKeyFor(_visitorData!).tr(),
            valueColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: const Color(0xFF64748B)),
        SizedBox(width: 12.w),
        Text(
          '$label: ',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF1E293B),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF0E4778).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0E4778), size: 20.w),
              SizedBox(width: 8.w),
              Text(
                'instructions'.tr(),
                style: TextStyle(
                  color: Color(0xFF0E4778),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInstructionItem('show_qr_at_gate'.tr()),
          _buildInstructionItem('single_entry_only'.tr()),
          _buildInstructionItem('pass_expires_at_time'.tr()),
          _buildInstructionItem('valid_id_proof'.tr()),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6.h),
            width: 6.w,
            height: 6.h,
            decoration: const BoxDecoration(
              color: Color(0xFF0E4778),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Color(0xFF061C4C),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF243143), Color(0xFF0E2247)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082F73).withValues(alpha: .2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSharePass(context),
          borderRadius: BorderRadius.circular(16.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_outlined, color: Colors.white, size: 24.w),
              SizedBox(width: 12.w),
              Text(
                'share_pass'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSharePass(BuildContext context) async {
    if (_pass == null) return;
    final request = _request;
    try {
      final pass = await (widget.loadPass ?? _service.load)(widget.visitorId);
      if (!mounted || !context.mounted || request != _request) return;
      if (!VisitorQrContract.canRequest(pass.visitor)) {
        throw StateError('This pass is no longer available.');
      }
      final box = context.findRenderObject() as RenderBox?;
      final text =
          'Visitor Pass - ${ResidentVisitorLifecycle.statusKeyFor(pass.visitor).tr()}\n\n'
          'Name: ${pass.visitor['visitorName'] ?? 'Visitor'}\n'
          'Visiting: ${pass.visitor['flatLabel'] ?? pass.visitor['flatId'] ?? ''}\n'
          'Pass code: ${pass.manualCode}\n\n'
          'Show the QR code or give this pass code to Security at the gate.';
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        if (error is ResidentVisitorPassUnavailable) {
          _armRevalidation(error.timing);
        }
        setState(() {
          _pass = null;
          _setError(error);
        });
      }
    }
  }
}
