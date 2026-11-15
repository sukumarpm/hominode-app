import 'package:admin_app/widgets/community_location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'models/tenant_config.dart';
import 'services/admin_tenant_context.dart';
import 'services/community_invite_service.dart';
import 'widgets/community_payment_settings_card.dart';
import 'widgets/visitor_policy_settings_card.dart';
import 'widgets/standard_header.dart';

class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({super.key, this.service});
  final CommunityInviteService? service;
  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  late final CommunityInviteService _service =
      widget.service ?? CommunityInviteService();
  late Future<TenantConfig> _community;
  bool _openingLocationDialog = false;

  @override
  void initState() {
    super.initState();
    _community = _service.getSelectedCommunity();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: CustomScrollView(
      slivers: [
        const StandardHeader(title: 'Community Settings'),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: SliverList.list(
            children: [
              FutureBuilder<TenantConfig>(
                future: _community,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    if (snapshot.error is CommunityNotFoundException) {
                      return Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            children: [
                              const Text('Selected community does not exist.'),
                              SizedBox(height: 12.h),
                              FilledButton.icon(
                                onPressed: _showCreateCommunity,
                                icon: const Icon(Icons.add_business),
                                label: const Text('Create Community'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Text('Unable to load community: ${snapshot.error}');
                  }
                  final community = snapshot.data!;
                  return Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28.r,
                                backgroundImage:
                                    community.logoUrl?.isNotEmpty == true
                                    ? NetworkImage(community.logoUrl!)
                                    : null,
                                child: community.logoUrl?.isNotEmpty == true
                                    ? null
                                    : const Icon(Icons.apartment),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      community.name,
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('ID: ${community.communityId}'),
                                    if (community.slug.isNotEmpty)
                                      Text('Slug: ${community.slug}'),
                                    Text(
                                      community.isActive
                                          ? 'Active'
                                          : 'Inactive',
                                      style: TextStyle(
                                        color: community.isActive
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(
                              community.locationConfigured
                                  ? community.location!.formattedAddress
                                  : 'Attendance location not configured',
                            ),
                            subtitle: community.locationConfigured
                                ? Text(
                                    '${community.location!.latitude.toStringAsFixed(6)}, '
                                    '${community.location!.longitude.toStringAsFixed(6)} • '
                                    '${community.location!.attendanceRadiusMeters}m radius',
                                  )
                                : const Text(
                                    'Security check-in is blocked until configured.',
                                  ),
                            trailing: OutlinedButton(
                              onPressed: () => _editLocation(community),
                              child: Text(
                                community.locationConfigured
                                    ? 'Edit'
                                    : 'Configure',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 12.h),
              const CommunityPaymentSettingsCard(),
              const SizedBox(height: 12),
              const VisitorPolicySettingsCard(),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _showCreateCommunity() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateCommunityDialog(service: _service),
    );
    if (!mounted || created != true) return;
    setState(() {
      _community = _service.getSelectedCommunity();
    });
  }

  Future<void> _editLocation(TenantConfig community) async {
    if (_openingLocationDialog) return;
    _openingLocationDialog = true;
    try {
      final freshCommunity = await showDialog<TenantConfig>(
        context: context,
        barrierDismissible: true,
        builder: (context) => CommunityAttendanceLocationDialog(
          service: _service,
          community: community,
        ),
      );
      if (!mounted || freshCommunity == null) return;
      setState(() {
        _community = Future.value(freshCommunity);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community attendance location saved.')),
      );
    } finally {
      _openingLocationDialog = false;
    }
  }
}

typedef CommunityLocationPickerBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<CommunityLocation?> onChanged,
    );

class CommunityAttendanceLocationDialog extends StatefulWidget {
  const CommunityAttendanceLocationDialog({
    super.key,
    required this.service,
    required this.community,
    this.pickerBuilder,
  });
  final CommunityInviteService service;
  final TenantConfig community;
  final CommunityLocationPickerBuilder? pickerBuilder;

  @override
  State<CommunityAttendanceLocationDialog> createState() =>
      _CommunityAttendanceLocationDialogState();
}

class _CommunityAttendanceLocationDialogState
    extends State<CommunityAttendanceLocationDialog> {
  CommunityLocation? _location;
  bool _locationChanged = false;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    final location = _locationChanged ? _location : widget.community.location;
    if (location == null || location.formattedAddress.trim().isEmpty) {
      setState(
        () => _error = 'Choose a map location and enter the property address.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fresh = await widget.service.updateCommunityLocation(
        widget.community,
        location,
      );
      if (mounted) Navigator.pop(context, fresh);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save the attendance location. ${error.toString()}';
        });
      }
    }
  }

  void _setLocation(CommunityLocation? value) {
    _locationChanged = true;
    _location = value;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Community attendance location'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.pickerBuilder?.call(context, _setLocation) ??
                  CommunityLocationPicker(
                    initialLocation: widget.community.location,
                    countryCode: widget.community.countryCode,
                    onChanged: _setLocation,
                  ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('location-dialog-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    ),
  );
}

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog({required this.service});

  final CommunityInviteService service;

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _timeZoneController;
  bool _submitting = false;
  CommunityLocation? _location;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: AdminTenantContext.instance.selectedCommunityId ?? '',
    );

    _nameController = TextEditingController();
    _slugController = TextEditingController();
    _timeZoneController = TextEditingController();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _slugController.dispose();
    _timeZoneController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (_submitting || _formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);
    try {
      await widget.service.createCommunity(
        communityId: _idController.text,
        name: _nameController.text,
        slug: _slugController.text,
        timeZone: _timeZoneController.text,
        location: _location,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Community'),

      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Community ID',
                    hintText: 'GV-0701',
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Community ID is required'
                      : null,
                ),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Green Valley',
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Name is required' : null,
                ),

                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    hintText: 'green-valley',
                  ),
                  validator: (value) =>
                      CommunityInviteService.normalizeSlug(value ?? '').isEmpty
                      ? 'Enter a valid slug'
                      : null,
                ),

                TextFormField(
                  controller: _timeZoneController,
                  decoration: const InputDecoration(
                    labelText: 'Time zone',
                    hintText: 'Asia/Manila',
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Time zone is required'
                      : null,
                ),

                CommunityLocationPicker(
                  initialLocation: null,
                  onChanged: (location) {
                    _location = location;
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _submitting ? null : _createCommunity,
          child: _submitting
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
