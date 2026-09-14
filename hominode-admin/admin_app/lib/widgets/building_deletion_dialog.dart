import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/building_deletion.dart';

Future<bool> showBuildingDeletionDialog({
  required BuildContext context,
  required String buildingName,
  required Future<BuildingDeletionCheck> Function() validate,
  required Future<void> Function() delete,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BuildingDeletionDialog(
        buildingName: buildingName,
        validate: validate,
        delete: delete,
      ),
    ) ??
    false;

class BuildingDeletionDialog extends StatefulWidget {
  const BuildingDeletionDialog({
    super.key,
    required this.buildingName,
    required this.validate,
    required this.delete,
  });

  final String buildingName;
  final Future<BuildingDeletionCheck> Function() validate;
  final Future<void> Function() delete;

  @override
  State<BuildingDeletionDialog> createState() => _BuildingDeletionDialogState();
}

class _BuildingDeletionDialogState extends State<BuildingDeletionDialog> {
  BuildingDeletionCheck? _check;
  String? _error;
  bool _checking = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  String _message(Object error) {
    if (error is FirebaseFunctionsException &&
        const [
          'failed-precondition',
          'permission-denied',
          'not-found',
          'invalid-argument',
        ].contains(error.code) &&
        error.message?.trim().isNotEmpty == true) {
      return error.message!;
    }
    return 'Unable to complete building deletion. Please refresh and try again.';
  }

  Future<void> _validate() async {
    try {
      final check = await widget.validate();
      if (mounted) setState(() => _check = check);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting || _check?.canDelete != true || _error != null) return;
    setState(() => _deleting = true);
    try {
      await widget.delete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      // An earlier safe preflight is now stale. Close and recheck before retry.
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _check?.buildingName ?? widget.buildingName;
    final safe = _check?.canDelete == true && _error == null;
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: Text(
          _checking
              ? 'Checking $name…'
              : safe
              ? 'Delete $name?'
              : 'Cannot delete $name',
        ),
        content: SingleChildScrollView(
          child: _checking
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) Text(_error!),
                    if (_error == null && safe)
                      Text(
                        'This will permanently delete the building and its ${_check!.unitCount} unused units. Historical resident/security records will not be deleted.',
                      ),
                    if (_error == null && !safe)
                      ..._check!.reasons.map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(reason),
                        ),
                      ),
                    if (_error == null &&
                        !safe &&
                        _check!.conflictCount > _check!.reasons.length)
                      Text(
                        '${_check!.conflictCount} conflicts in total. Resolve these before deleting.',
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(safe || _checking ? 'Cancel' : 'Close'),
          ),
          if (!_checking && safe)
            TextButton(
              onPressed: _deleting ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              child: Text(_deleting ? 'Deleting…' : 'Delete'),
            ),
        ],
      ),
    );
  }
}
