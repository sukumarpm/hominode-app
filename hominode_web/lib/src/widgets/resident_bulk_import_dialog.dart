import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hominode_core/hominode_core.dart';

import '../services/resident_bulk_import_service.dart';
import '../theme/web_design_system.dart';

class ResidentBulkImportDialog extends StatefulWidget {
  const ResidentBulkImportDialog({
    super.key,
    required this.communityId,
    this.gateway,
    this.initialFile,
  });

  final String communityId;
  final ResidentBulkImportGateway? gateway;
  final ResidentBulkImportFile? initialFile;

  static Future<void> show(
    BuildContext context, {
    required String communityId,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ResidentBulkImportDialog(communityId: communityId),
  );

  @override
  State<ResidentBulkImportDialog> createState() =>
      _ResidentBulkImportDialogState();
}

class _ResidentBulkImportDialogState extends State<ResidentBulkImportDialog> {
  late final ResidentBulkImportGateway _gateway;
  ResidentBulkImportFile? _file;
  ResidentBulkImportCallResult? _validation;
  ResidentBulkImportCallResult? _result;
  String? _jobId;
  String? _message;
  String _filter = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ResidentBulkImportService();
    _file = widget.initialFile;
    if (_file != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validate(_file!));
    }
  }

  Future<void> _pickFile() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (!mounted || selection == null || selection.files.isEmpty) return;
    final selected = selection.files.single;
    if (selected.bytes == null) {
      setState(() => _message = 'The selected file could not be read.');
      return;
    }
    try {
      await _validate(
        ResidentBulkImportParser.parseBytes(selected.name, selected.bytes!),
      );
    } on ResidentBulkImportParseException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'The selected file could not be parsed.');
      }
    }
  }

  Future<void> _validate(ResidentBulkImportFile file) async {
    setState(() {
      _busy = true;
      _message = null;
      _file = file;
      _validation = null;
      _result = null;
      _jobId = null;
      _filter = 'all';
    });
    try {
      final validation = await _gateway.validate(
        communityId: widget.communityId,
        file: file,
      );
      if (mounted) setState(() => _validation = validation);
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport({ResidentBulkImportFile? retryFile}) async {
    final file = retryFile ?? _file;
    if (file == null) return;
    if (retryFile == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm bulk import'),
          content: Text(
            '${_validation!.count('validRows')} valid row(s) will be created '
            'as pending, unverified onboarding records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final jobId = _jobId ?? ResidentBulkImportService.newImportJobId();
    setState(() {
      _busy = true;
      _message = null;
      _jobId = jobId;
    });
    final previousResult = _result;
    try {
      final result = await _gateway.import(
        communityId: widget.communityId,
        file: file,
        importJobId: jobId,
      );
      if (mounted) {
        setState(() {
          _result = retryFile == null || previousResult == null
              ? result
              : _mergeResults(previousResult, result);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ResidentBulkImportCallResult _mergeResults(
    ResidentBulkImportCallResult previous,
    ResidentBulkImportCallResult retry,
  ) {
    final rows = <int, Map<String, dynamic>>{
      for (final row in previous.rows)
        if (row['rowNumber'] is num) (row['rowNumber'] as num).toInt(): row,
    };
    for (final row in retry.rows) {
      final rowNumber = row['rowNumber'];
      if (rowNumber is num) rows[rowNumber.toInt()] = row;
    }
    final merged = rows.values.toList()
      ..sort(
        (a, b) => (a['rowNumber'] as num).compareTo(b['rowNumber'] as num),
      );
    final success = merged
        .where(
          (row) =>
              row['status'] == 'imported' ||
              row['status'] == 'already_imported',
        )
        .length;
    return ResidentBulkImportCallResult(
      importJobId: retry.importJobId ?? previous.importJobId,
      rows: merged,
      summary: {
        'totalRows': merged.length,
        'successCount': success,
        'failedCount': merged.length - success,
      },
    );
  }

  Future<void> _retryFailed() async {
    final failedRows = (_result?.rows ?? const <Map<String, dynamic>>[])
        .where((row) => row['status'] == 'error')
        .map((row) => row['rowNumber'])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
    final original = _file;
    if (original == null || failedRows.isEmpty) return;
    final rows = original.rows
        .where((row) => failedRows.contains(row['rowNumber']))
        .toList(growable: false);
    if (rows.isEmpty) return;
    await _runImport(
      retryFile: ResidentBulkImportFile(
        fileName: original.fileName,
        rows: rows,
      ),
    );
  }

  Future<void> _download(String fileName, List<int> bytes) async {
    try {
      await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted) {
        setState(() => _message = '$fileName downloaded.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'The download could not be created.');
      }
    }
  }

  String _friendlyError(Object error) => error is FirebaseFunctionsException
      ? error.message ?? 'The import request failed.'
      : 'The import request failed. It is safe to try again.';

  @override
  Widget build(BuildContext context) {
    final active = _result ?? _validation;
    final allRows = active?.rows ?? const <Map<String, dynamic>>[];
    final rows = allRows
        .where((row) {
          if (_filter == 'all') return true;
          final status = row['status'];
          return _filter == 'valid'
              ? status == 'ready' ||
                    status == 'imported' ||
                    status == 'already_imported'
              : status == 'error';
        })
        .toList(growable: false);
    final valid =
        _result?.count('successCount') ?? _validation?.count('validRows') ?? 0;
    final failed =
        _result?.count('failedCount') ?? _validation?.count('errorRows') ?? 0;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1120,
        height: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk Resident Import',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'CSV or XLSX • maximum 500 rows • pending and unverified after import',
                          style: TextStyle(color: WebDesign.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _download(
                            'hominode_resident_import_template.csv',
                            ResidentBulkImportParser.templateCsvBytes(),
                          ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download template'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Select CSV / XLSX'),
                  ),
                  if (_file != null)
                    Text('${_file!.fileName} • ${_file!.rowCount} rows'),
                ],
              ),
            ),
            if (_message != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_message!),
              ),
            if (active != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _Count(label: 'Total', value: allRows.length),
                    const SizedBox(width: 8),
                    _Count(
                      label: _result == null ? 'Valid' : 'Successful',
                      value: valid,
                      color: const Color(0xFF008C72),
                    ),
                    const SizedBox(width: 8),
                    _Count(
                      label: 'Errors',
                      value: failed,
                      color: const Color(0xFFC7394F),
                    ),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'valid', label: Text('Valid')),
                        ButtonSegment(value: 'error', label: Text('Errors')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.single),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: active == null
                  ? const Center(
                      child: Text(
                        'Select a template-based file to preview and validate it.',
                      ),
                    )
                  : Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Row')),
                              DataColumn(label: Text('Resident')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Building / Unit')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Status / Error')),
                            ],
                            rows: rows
                                .map(
                                  (row) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text('${row['rowNumber'] ?? ''}'),
                                      ),
                                      DataCell(
                                        Text(
                                          '${row['residentName'] ?? 'Invalid row'}',
                                        ),
                                      ),
                                      DataCell(
                                        Text('${row['phoneNumber'] ?? ''}'),
                                      ),
                                      DataCell(
                                        Text(
                                          '${row['building'] ?? ''} / ${row['unit'] ?? ''}',
                                        ),
                                      ),
                                      DataCell(
                                        Text('${row['residentType'] ?? ''}'),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 220,
                                          child: Text(
                                            row['message']?.toString() ??
                                                row['status']
                                                    ?.toString()
                                                    .replaceAll('_', ' ') ??
                                                'error',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_result != null)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _download(
                              'resident_import_results.csv',
                              ResidentBulkImportParser.resultCsvBytes(allRows),
                            ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download results'),
                    ),
                  const Spacer(),
                  if (_result != null && failed > 0)
                    OutlinedButton.icon(
                      key: const Key('web-import-retry'),
                      onPressed: _busy ? null : _retryFailed,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry failed rows'),
                    ),
                  if (_result != null && failed > 0) const SizedBox(width: 8),
                  if (_validation != null && _result == null)
                    FilledButton.icon(
                      key: const Key('web-import-confirm'),
                      onPressed: _busy || valid == 0 ? null : _runImport,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text('Import $valid valid row(s)'),
                    ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.label,
    required this.value,
    this.color = WebDesign.text,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$label $value',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
}
