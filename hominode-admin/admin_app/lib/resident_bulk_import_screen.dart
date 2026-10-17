import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hominode_core/hominode_core.dart'
    show
        ResidentBulkImportFile,
        ResidentBulkImportParseException,
        ResidentBulkImportParser;

import 'services/admin_tenant_context.dart';
import 'services/resident_bulk_import_service.dart';

class ResidentBulkImportScreen extends StatefulWidget {
  const ResidentBulkImportScreen({
    super.key,
    this.gateway,
    this.initialFile,
    this.communityId,
  });

  final ResidentBulkImportGateway? gateway;
  final ResidentBulkImportFile? initialFile;
  final String? communityId;

  @override
  State<ResidentBulkImportScreen> createState() =>
      _ResidentBulkImportScreenState();
}

class _ResidentBulkImportScreenState extends State<ResidentBulkImportScreen> {
  late final ResidentBulkImportGateway _gateway;
  ResidentBulkImportFile? _file;
  ResidentBulkImportCallResult? _validation;
  ResidentBulkImportCallResult? _result;
  String? _importJobId;
  String? _message;
  bool _busy = false;

  String get _communityId =>
      widget.communityId ??
      AdminTenantContext.instance.requireTenant().communityId;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ResidentBulkImportService();
    _file = widget.initialFile;
    if (_file != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validate(_file!));
    }
  }

  Future<void> _selectFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;
    final selected = picked.files.single;
    final bytes = selected.bytes;
    if (bytes == null) {
      setState(() => _message = 'bulk_file_read_failed'.tr());
      return;
    }
    try {
      final file = ResidentBulkImportParser.parseBytes(selected.name, bytes);
      await _validate(file);
    } on ResidentBulkImportParseException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'bulk_file_parse_failed'.tr());
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
      _importJobId = null;
    });
    try {
      final validation = await _gateway.validate(
        communityId: _communityId,
        file: file,
      );
      if (!mounted) return;
      setState(() => _validation = validation);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import({ResidentBulkImportFile? retryFile}) async {
    final file = retryFile ?? _file;
    if (file == null ||
        (_validation?.validRows ?? 0) == 0 && retryFile == null) {
      setState(() => _message = 'bulk_no_valid_rows'.tr());
      return;
    }
    final confirmed =
        retryFile != null ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('bulk_import_title_question'.tr()),
                content: Text(
                  (_validation!.validRows == 1
                          ? 'bulk_import_confirmation_one'
                          : 'bulk_import_confirmation_many')
                      .tr(namedArgs: {'count': '${_validation!.validRows}'}),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('cancel'.tr()),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('bulk_import_action'.tr()),
                  ),
                ],
              ),
            ) ==
            true;
    if (!confirmed || !mounted) return;
    final jobId = _importJobId ?? ResidentBulkImportService.newImportJobId();
    setState(() {
      _busy = true;
      _message = null;
      _importJobId = jobId;
    });
    final previousResult = _result;
    try {
      final result = await _gateway.import(
        communityId: _communityId,
        file: file,
        importJobId: jobId,
      );
      if (!mounted) return;
      setState(() {
        _result = retryFile == null || previousResult == null
            ? result
            : _mergeResults(previousResult, result);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
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
    final failedNumbers = (_result?.rows ?? const <Map<String, dynamic>>[])
        .where((row) => row['status'] == 'error')
        .map((row) => row['rowNumber'])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
    final original = _file;
    if (original == null || failedNumbers.isEmpty) return;
    final rows = original.rows
        .where((row) => failedNumbers.contains(row['rowNumber']))
        .toList(growable: false);
    if (rows.isEmpty) return;
    await _import(
      retryFile: ResidentBulkImportFile(
        fileName: original.fileName,
        rows: rows,
      ),
    );
  }

  Future<void> _saveBytes(String fileName, Uint8List bytes) async {
    try {
      await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
      if (mounted) {
        setState(
          () => _message = 'bulk_file_saved'.tr(namedArgs: {'file': fileName}),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'bulk_file_save_failed'.tr());
    }
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'bulk_request_failed'.tr();
    }
    return 'bulk_request_failed_retry'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        _result?.rows ?? _validation?.rows ?? const <Map<String, dynamic>>[];
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text('bulk_resident_import_title'.tr())),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('bulk_resident_import_description'.tr()),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _saveBytes(
                            'hominode_resident_import_template.csv',
                            ResidentBulkImportParser.templateCsvBytes(),
                          ),
                    icon: const Icon(Icons.download_outlined),
                    label: Text('bulk_download_template'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _selectFile,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text('bulk_select_file'.tr()),
                  ),
                ],
              ),
              if (_file != null) ...[
                const SizedBox(height: 16),
                Text(
                  (_file!.rowCount == 1
                          ? 'bulk_file_row_count_one'
                          : 'bulk_file_row_count_many')
                      .tr(
                        namedArgs: {
                          'fileName': _file!.fileName,
                          'count': '${_file!.rowCount}',
                        },
                      ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                MaterialBanner(
                  content: Text(_message!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _message = null),
                      child: Text('dismiss'.tr()),
                    ),
                  ],
                ),
              ],
              if (_validation != null) ...[
                const SizedBox(height: 16),
                _Summary(
                  total: _validation!.totalRows,
                  success: result?.successCount ?? _validation!.validRows,
                  failed: result?.failedCount ?? _validation!.errorRows,
                  imported: result != null,
                ),
                const SizedBox(height: 12),
                if (result == null)
                  FilledButton(
                    key: const Key('bulk-import-confirm'),
                    onPressed: _busy || _validation!.validRows == 0
                        ? null
                        : _import,
                    child: Text(
                      'bulk_import_valid_rows'.tr(
                        namedArgs: {'count': '${_validation!.validRows}'},
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      if (result.failedCount > 0)
                        OutlinedButton.icon(
                          key: const Key('bulk-import-retry'),
                          onPressed: _busy ? null : _retryFailed,
                          icon: const Icon(Icons.refresh),
                          label: Text('bulk_retry_failed_rows'.tr()),
                        ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _saveBytes(
                                'resident_import_results.csv',
                                ResidentBulkImportParser.resultCsvBytes(rows),
                              ),
                        icon: const Icon(Icons.download_outlined),
                        label: Text('bulk_download_results'.tr()),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  result == null
                      ? 'bulk_validation_preview'.tr()
                      : 'bulk_import_results'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...rows.take(100).map(_RowCard.new),
                if (rows.length > 100)
                  Text(
                    'bulk_showing_first_rows'.tr(
                      namedArgs: {'count': '${rows.length}'},
                    ),
                  ),
              ],
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.success,
    required this.failed,
    required this.imported,
  });

  final int total;
  final int success;
  final int failed;
  final bool imported;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      Chip(label: Text('bulk_total_count'.tr(namedArgs: {'count': '$total'}))),
      Chip(
        label: Text(
          (imported ? 'bulk_successful_count' : 'bulk_valid_count').tr(
            namedArgs: {'count': '$success'},
          ),
        ),
      ),
      Chip(
        label: Text('bulk_errors_count'.tr(namedArgs: {'count': '$failed'})),
      ),
    ],
  );
}

class _RowCard extends StatelessWidget {
  const _RowCard(this.row);

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'error';
    final isGood =
        status == 'ready' ||
        status == 'imported' ||
        status == 'already_imported';
    return Card(
      child: ListTile(
        leading: Icon(
          isGood ? Icons.check_circle_outline : Icons.error_outline,
          color: isGood ? Colors.green : Colors.red,
        ),
        title: Text(
          'bulk_row_title'.tr(
            namedArgs: {
              'row': '${row['rowNumber']}',
              'resident': '${row['residentName'] ?? 'bulk_invalid_row'.tr()}',
            },
          ),
        ),
        subtitle: Text(
          [
                row['phoneNumber'],
                if (row['building'] != null || row['unit'] != null)
                  '${row['building'] ?? ''} / ${row['unit'] ?? ''}',
                row['message'],
              ]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join('\n'),
        ),
        trailing: Text(_bulkStatusLabel(status)),
      ),
    );
  }
}

String _bulkStatusLabel(String status) => switch (status) {
  'ready' => 'bulk_status_ready'.tr(),
  'imported' => 'bulk_status_imported'.tr(),
  'already_imported' => 'bulk_status_already_imported'.tr(),
  'error' => 'bulk_status_error'.tr(),
  _ => status.replaceAll('_', ' '),
};
