import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'src/services/visitor_firestore_service.dart';
import 'src/services/resident_visitor_policy_service.dart';
import 'src/models/resident_visitor_authorization.dart';
import 'src/models/resident_visitor_timing.dart';

// Design Constants
const kPrimary = Color(0xFF0E4778);
const kModalBackground = Color(0xFFFFFFFF);
const kInputBorder = Color(0xFFDCE5EF);
const kPlaceholder = Color(0xFF718096);
const kDimOverlay = Color(0x5C000000); // rgba(0,0,0,0.36)
const kRadius = 20.0;
const kInputRadius = 12.0;
const kSpacing = 16.0;
const kLargeSpacing = 24.0;

/// Helper function to show the Add Expected Visitor modal
/// Call this from FAB or any button tap
/// Returns true if visitor was added successfully, false otherwise
Future<bool?> showAddExpectedVisitorModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: kDimOverlay,
    barrierDismissible: true,
    builder: (context) => const AddExpectedVisitorModal(),
  );
}

/// Main modal widget - Add Expected Visitor form
class AddExpectedVisitorModal extends StatefulWidget {
  const AddExpectedVisitorModal({
    super.key,
    this.visitorService,
    this.policyService,
    this.visitor,
  });
  final VisitorFirestoreService? visitorService;
  final ResidentVisitorPolicyService? policyService;
  final Map<String, dynamic>? visitor;

  @override
  State<AddExpectedVisitorModal> createState() =>
      _AddExpectedVisitorModalState();
}

class _AddExpectedVisitorModalState extends State<AddExpectedVisitorModal>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  late final _visitorService =
      widget.visitorService ?? VisitorFirestoreService();
  late final _policyService =
      widget.policyService ?? ResidentVisitorPolicyService();
  ResidentVisitorScope? _scope;
  Map<String, dynamic>? _guidance;
  Timer? _guidanceTimer;
  Timer? _policyTimer;
  StreamSubscription<Object?>? _policySubscription;
  int _guidanceVersion = 0;
  bool _bringingPet = false;
  String _feedback = '';
  String? _initialArrival;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isFormValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController.addListener(_validateForm);
    _purposeController.addListener(_validateForm);
    _bringingPet = widget.visitor?['bringingPet'] == true;
    _nameController.text = widget.visitor?['visitorName']?.toString() ?? '';
    _purposeController.text = widget.visitor?['purpose']?.toString() ?? '';
    _loadScope();
  }

  @override
  void dispose() {
    _guidanceTimer?.cancel();
    _policyTimer?.cancel();
    _policySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _guidanceVersion++;
    _nameController.dispose();
    _purposeController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid =
          _nameController.text.isNotEmpty &&
          _purposeController.text.isNotEmpty &&
          _selectedDate != null &&
          _selectedTime != null &&
          _scope != null;
    });
  }

  Future<void> _selectDate() async {
    if (_scope == null) return;
    final localNow = DateTime.parse(
      ResidentVisitTime.local(DateTime.now(), _scope?.timeZone),
    );
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null && _selectedDate!.isAfter(today)
          ? DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
            )
          : today,
      currentDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _validateForm();
      });
      _refreshGuidance();
    }
  }

  Future<void> _selectTime() async {
    if (_scope == null) return;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          _selectedTime ??
          TimeOfDay.fromDateTime(
            CommunityTime.inZone(DateTime.now(), _scope!.timeZone),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
        _validateForm();
      });
      _refreshGuidance();
    }
  }

  Future<void> _loadScope() async {
    try {
      final loaded = await _policyService.loadScope();
      final scope = ResidentVisitorScope(
        uid: loaded.uid,
        communityId: loaded.communityId,
        timeZone: CommunityTime.canonical(loaded.timeZone),
      );
      if (!mounted) return;
      setState(() {
        _scope = scope;
        final existing = widget.visitor == null
            ? null
            : ResidentVisitorAuthorization.arrival(widget.visitor!);
        if (existing != null) {
          _initialArrival = ResidentVisitTime.local(existing, scope.timeZone);
          final wall = DateTime.parse('${_initialArrival!}:00Z');
          _selectedDate = wall;
          _selectedTime = TimeOfDay(hour: wall.hour, minute: wall.minute);
          _isFormValid = true;
        }
      });
      _policySubscription?.cancel();
      try {
        _policySubscription = _policyService
            .watchCommunity(scope.communityId)
            .listen(
              (_) => _refreshGuidance(),
              onError: (_) => _refreshGuidance(),
            );
      } catch (_) {
        // Guidance is advisory. Creation/mutation still authorizes server-side.
      }
      _refreshGuidance();
    } catch (error) {
      if (mounted) setState(() => _feedback = residentVisitorError(error));
    }
  }

  DateTime? get _labelInstant {
    if (_wallArrival == _initialArrival && widget.visitor != null) {
      return ResidentVisitorAuthorization.arrival(widget.visitor!);
    }
    try {
      return ResidentVisitTime.instant(_wallArrival!, _scope!.timeZone);
    } on FormatException {
      return null;
    }
  }

  String? get _wallArrival {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime.utc(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    ).toIso8601String().substring(0, 16);
  }

  void _refreshGuidance() {
    _guidanceTimer?.cancel();
    _policyTimer?.cancel();
    final ticket = ++_guidanceVersion;
    if (_wallArrival == null) return;
    setState(() => _guidance = null);
    _guidanceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final arrival = ResidentVisitTime.instant(
          _wallArrival!,
          _scope?.timeZone,
        );
        final elapsed = Stopwatch()..start();
        final value = await _policyService.contextFor(arrival);
        if (mounted && ticket == _guidanceVersion) {
          setState(() => _guidance = value);
          if (value.containsKey('revalidateAt')) {
            final remaining = ResidentVisitorTiming.fromMap(
              value,
              elapsed: elapsed,
            ).remaining;
            if (remaining != null) {
              _policyTimer = Timer(remaining, _refreshGuidance);
            }
          }
        }
      } catch (_) {
        /* Advisory only: creation always validates on the server. */
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshGuidance();
  }

  Future<void> _handleAddVisitor() async {
    if (!_isFormValid || _isLoading) return;
    setState(() {
      _isLoading = true;
      _feedback = '';
    });
    try {
      final current = await _policyService.loadScope();
      if (_scope == null ||
          current.uid != _scope!.uid ||
          current.communityId != _scope!.communityId ||
          CommunityTime.canonical(current.timeZone) != _scope!.timeZone) {
        throw StateError(
          'Your Resident account or community changed. Reload this form.',
        );
      }
      if (_bringingPet && _guidance?['petPermitted'] == false) {
        throw StateError(residentPetVisitMessage);
      }
      String message;
      if (widget.visitor != null) {
        final changedTime = _wallArrival != _initialArrival;
        await _policyService.mutate(
          widget.visitor!,
          action: 'reschedule',
          arrival: changedTime
              ? ResidentVisitTime.instant(_wallArrival!, current.timeZone)
              : null,
          bringingPet: _bringingPet,
        );
        message =
            'Rescheduling confirmed. Authorization and pass availability will refresh in your visitor list.';
      } else {
        final result = await _visitorService.addExpectedVisitor(
          visitorName: _nameController.text.trim(),
          purpose: _purposeController.text.trim(),
          expectedDate: _selectedDate!,
          expectedTime: DateTime.utc(
            2000,
            1,
            1,
            _selectedTime!.hour,
            _selectedTime!.minute,
          ),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          vehicleNumber: _vehicleController.text.trim().isEmpty
              ? null
              : _vehicleController.text.trim(),
          bringingPet: _bringingPet,
          timeZone: current.timeZone,
        );
        if (!result.success) {
          throw StateError(
            result.message ?? 'The invitation could not be confirmed.',
          );
        }
        message = result.message!;
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) setState(() => _feedback = residentVisitorError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        constraints: const BoxConstraints(maxWidth: 560),
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: kModalBackground.withValues(alpha: .97),
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: Colors.white, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF082F73).withValues(alpha: .12),
                  blurRadius: 26,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(kLargeSpacing),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  _buildHeader(),

                  SizedBox(height: 32),

                  if (widget.visitor == null) ...[
                    // Visitor Name field
                    _buildLabeledTextField(
                      label: 'visitor_name'.tr(),
                      placeholder: 'enter_name'.tr(),
                      controller: _nameController,
                    ),

                    const SizedBox(height: kLargeSpacing),

                    // Purpose field
                    _buildLabeledTextField(
                      label: 'purpose'.tr(),
                      placeholder: 'visitor_purpose_example'.tr(),
                      controller: _purposeController,
                    ),

                    const SizedBox(height: kLargeSpacing),

                    // Phone Number field (Optional)
                    _buildLabeledTextField(
                      label: 'optional_phone'.tr(),
                      placeholder: 'enter_phone'.tr(),
                      controller: _phoneController,
                    ),

                    const SizedBox(height: kLargeSpacing),

                    // Vehicle Number field (Optional)
                    _buildLabeledTextField(
                      label: 'optional_vehicle'.tr(),
                      placeholder: 'e.g., MH 01 AB 1234',
                      controller: _vehicleController,
                    ),

                    const SizedBox(height: kLargeSpacing),
                  ],
                  // Date and Time row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimeField(
                          label: 'date'.tr(),
                          placeholder: 'dd-mm-yyyy',
                          value: _selectedDate != null
                              ? _formatDate(_selectedDate!)
                              : null,
                          onTap: _selectDate,
                        ),
                      ),
                      const SizedBox(width: kSpacing),
                      Expanded(
                        child: _buildDateTimeField(
                          label: 'time'.tr(),
                          placeholder: '-- / --',
                          value: _selectedTime != null
                              ? _formatTime(_selectedTime!)
                              : null,
                          onTap: _selectTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    _scope == null
                        ? 'Community timezone unavailable'
                        : CommunityTime.label(
                            _scope!.timeZone,
                            at: _wallArrival == null ? null : _labelInstant,
                          ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Visitor will bring a pet'),
                    value: _bringingPet,
                    onChanged: _isLoading
                        ? null
                        : (value) => setState(() {
                            _bringingPet = value!;
                            _feedback = '';
                          }),
                  ),
                  if (_bringingPet && _guidance?['petPermitted'] == false)
                    const Text(residentPetVisitMessage),
                  if (_guidance?['authorizationState'] == 'pending_admin')
                    const Text(
                      'This invitation is expected to require Community Admin approval. The server confirms authorization when you submit.',
                    ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : (_scope == null ? _loadScope : _refreshGuidance),
                    child: const Text('Refresh visit guidance'),
                  ),
                  if (widget.visitor != null)
                    const Text(
                      'Rescheduling rechecks authorization and pet entry, and resets any previous Admin authorization.',
                    ),
                  if (_feedback.isNotEmpty)
                    Text(
                      _feedback,
                      key: const ValueKey('visitor-form-feedback'),
                    ),
                  SizedBox(height: 32),

                  // Add Visitor button
                  _buildPrimaryButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header with centered title and close button
  Widget _buildHeader() {
    return Stack(
      children: [
        // Centered title
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.visitor == null
                  ? 'add_expected_visitor'.tr()
                  : 'Reschedule visitor',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0E2247),
              ),
            ),
          ),
        ),

        // Close button (top-right)
        Positioned(
          right: 0,
          top: -8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Icon(Icons.close, size: 28, color: Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Labeled text field component
  Widget _buildLabeledTextField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0E2247),
          ),
        ),

        SizedBox(height: 12),

        // Text field
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: kPlaceholder,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kInputRadius),
              borderSide: const BorderSide(color: kInputBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kInputRadius),
              borderSide: const BorderSide(color: kInputBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kInputRadius),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// Date/Time picker field component
  Widget _buildDateTimeField({
    required String label,
    required String placeholder,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0E2247),
          ),
        ),

        SizedBox(height: 12),

        // Tappable field
        InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(kInputRadius),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kInputRadius),
              border: Border.all(color: kInputBorder, width: 1),
            ),
            child: Text(
              value ?? placeholder,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: value != null ? const Color(0xFF1E293B) : kPlaceholder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Primary CTA button
  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            (_isFormValid &&
                _scope != null &&
                !_isLoading &&
                !(_bringingPet && _guidance?['petPermitted'] == false))
            ? _handleAddVisitor
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          disabledBackgroundColor: kPrimary.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kInputRadius),
          ),
          padding: EdgeInsets.symmetric(vertical: 18),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                widget.visitor == null ? 'add'.tr() : 'Save new visit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
