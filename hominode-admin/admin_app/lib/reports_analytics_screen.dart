import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/standard_header.dart';
import 'services/reports_service.dart';
import 'services/admin_tenant_context.dart';
import 'widgets/reports_charts.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key, ReportsService? reportsService})
    : _reportsService = reportsService;

  final ReportsService? _reportsService;

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  late final ReportsService _reportsService;

  DateTime selectedDate = DateTime.now();
  int selectedTabIndex = 0; // 0: Financial, 1: Occupancy, 2: Complaints

  // Data holders
  FinancialSummary? _financialSummary;
  OccupancySummary? _occupancySummary;
  List<BuildingOccupancy> _buildingOccupancies = [];
  ComplaintsSummary? _complaintsSummary;
  List<MonthlyComplaints> _complaintsTrends = [];
  int? _deliveriesCount;
  String? _financialLoadError;
  bool _occupancyLoading = true;
  String? _occupancyLoadError;
  bool _complaintsLoading = true;
  String? _complaintsLoadError;

  bool _isLoading = true;
  String _detailMode = 'all';
  DateTimeRange? _detailRange;
  List<Map<String, dynamic>> _residentOptions = [];
  int _residentListRequest = 0;
  bool _detailLoading = false;
  Map<String, dynamic>? _detailedReport;
  String? _detailError;
  String? _selectedResidentId;
  final TextEditingController _residentSearch = TextEditingController();

  final List<String> tabs = ['Financial', 'Occupancy', 'Complaints'];

  @override
  void initState() {
    super.initState();
    _reportsService = widget._reportsService ?? ReportsService();
    _residentSearch.addListener(_onResidentSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _residentSearch.removeListener(_onResidentSearchChanged);
    _residentSearch.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all data in parallel
      await Future.wait([
        _loadFinancialData(),
        _loadOccupancyData(),
        _loadComplaintsData(),
        _loadDeliveriesData(),
      ]);
    } catch (e) {
      print('Error loading reports data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFinancialData() async {
    try {
      final summary = await _reportsService.getFinancialSummary(
        year: selectedDate.year,
        month: selectedDate.month,
      );

      if (mounted) {
        setState(() {
          _financialSummary = summary;
          _financialLoadError = null;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _financialSummary = null;
          _financialLoadError = error.userMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _financialSummary = null;
          _financialLoadError =
              'Financial report is unavailable right now. Please try again shortly.';
        });
      }
      print('ReportsAnalyticsScreen: Financial load error: $error');
    }
  }

  String _residentLabel(Map<String, dynamic> row) {
    final identity = Map<String, dynamic>.from(row['identity'] as Map);
    return '${identity['name'] ?? 'Resident'} · ${identity['phone'] ?? ''} · ${identity['unit'] ?? ''} · ${identity['deleted'] == true ? 'Deleted' : 'Active'}';
  }

  void _onResidentSearchChanged() {
    if (_selectedResidentId == null) return;
    final selected = _residentOptions.where(
      (row) => row['residentId'] == _selectedResidentId,
    );
    if (selected.isEmpty ||
        _residentSearch.text != _residentLabel(selected.first)) {
      setState(() {
        _selectedResidentId = null;
        _detailedReport = null;
      });
    }
  }

  Future<void> _changeDetailMode(String mode) async {
    final request = ++_residentListRequest;
    setState(() {
      _detailMode = mode;
      _selectedResidentId = null;
      _residentSearch.clear();
      _residentOptions = [];
      _detailedReport = null;
      _detailError = null;
      _detailLoading = mode == 'individual';
    });
    if (mode != 'individual') return;
    try {
      final residents = await _reportsService.getFinancialReportResidents();
      if (mounted && request == _residentListRequest) {
        setState(() {
          _residentOptions = residents;
          _detailLoading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _residentListRequest) {
        setState(() {
          _detailError = 'Resident list is unavailable. Please try again.';
          _detailLoading = false;
        });
      }
    }
  }

  Future<void> _generateDetailedReport() async {
    if (_detailMode == 'individual' && _selectedResidentId == null) return;
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final result = await _reportsService.getDetailedFinancialReport(
        from: _detailRange?.start,
        to: _detailRange?.end,
        residentId: _detailMode == 'individual' ? _selectedResidentId : null,
      );
      if (mounted) {
        setState(() {
          _detailedReport = result;
          _detailLoading = false;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _detailError = error.userMessage;
          _detailLoading = false;
          _detailedReport = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detailError = 'Financial report is unavailable. Please try again.';
          _detailLoading = false;
          _detailedReport = null;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibleDetailedRows {
    final rows = (_detailedReport?['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (_detailMode == 'all') return rows;
    return rows
        .where((row) => row['residentId'] == _selectedResidentId)
        .toList();
  }

  Future<void> _exportDetailedPdf() async {
    final rows = _visibleDetailedRows;
    if (rows.isEmpty) return;
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'HOMINODE FINANCIAL REPORT',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Community: ${AdminTenantContext.instance.requireCommunityId()}',
          ),
          for (final warning
              in (_detailedReport?['coverageWarnings'] as List? ?? const []))
            pw.Text('Coverage warning: $warning'),
          pw.Text(
            'Period: ${_detailRange == null ? 'All history' : '${_detailRange!.start.toIso8601String().substring(0, 10)} – ${_detailRange!.end.toIso8601String().substring(0, 10)}'}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Resident',
              'Billed',
              'Paid',
              'Credit applied',
              'Available credit',
              'Outstanding',
            ],
            data: rows
                .map(
                  (row) => [
                    '${(row['identity'] as Map)['name'] ?? 'Resident'}${(row['identity'] as Map)['deleted'] == true ? ' (Deleted)' : ''}',
                    _minor(row['billedMinor']),
                    _minor(row['paidMinor']),
                    _minor(row['creditAppliedMinor']),
                    _minor(row['availableCreditMinor']),
                    _minor(row['outstandingMinor']),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Resident',
              'Phone',
              'Unit',
              'Description / Period',
              'Billed',
              'Paid',
              'Outstanding',
              'Status',
            ],
            data: rows.expand((row) {
              final identity = Map<String, dynamic>.from(
                row['identity'] as Map? ?? {},
              );
              final bills = (row['bills'] as List? ?? const [])
                  .whereType<Map>();
              if (bills.isEmpty) {
                return [
                  [
                    identity['name'] ?? 'Resident',
                    identity['phone'] ?? '',
                    identity['unit'] ?? '',
                    '—',
                    _minor(row['billedMinor']),
                    _minor(row['paidMinor']),
                    _minor(row['outstandingMinor']),
                    row['paymentStatus'] ?? '',
                  ],
                ];
              }
              return bills.map(
                (bill) => [
                  identity['name'] ?? 'Resident',
                  identity['phone'] ?? '',
                  identity['unit'] ?? '',
                  '${bill['description']} / ${bill['billingPeriod']}',
                  _minor(bill['amountMinor']),
                  _minor(bill['paidMinor']),
                  _minor(bill['outstandingMinor']),
                  bill['status'] ?? '',
                ],
              );
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Receipts in reporting period (separate from bill allocations)',
          ),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Resident',
              'Transaction',
              'Received',
              'Method / Reference',
              'Received at',
              'Created at',
            ],
            data: rows
                .expand(
                  (row) => (row['payments'] as List? ?? const [])
                      .whereType<Map>()
                      .map(
                        (payment) => [
                          (row['identity'] as Map)['name'] ?? 'Resident',
                          payment['transactionId'],
                          _minor(payment['receivedAmountMinor']),
                          '${payment['method']} / ${payment['reference'] ?? ''}',
                          _reportTimestamp(payment['receivedAtMs']),
                          _reportTimestamp(payment['createdAtMs']),
                        ],
                      ),
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static xls.CellValue? _excelValue(Object? value) => switch (value) {
    null => null,
    bool value => xls.BoolCellValue(value),
    int value => xls.IntCellValue(value),
    num value => xls.DoubleCellValue(value.toDouble()),
    _ => xls.TextCellValue(value.toString()),
  };

  Future<void> _exportDetailedExcel() async {
    final rows = _visibleDetailedRows;
    if (rows.isEmpty) return;
    final book = xls.Excel.createExcel();
    final coverage = book['Coverage'];
    for (final warning
        in (_detailedReport?['coverageWarnings'] as List? ?? const [])) {
      coverage.appendRow(
        ['Coverage warning', warning].map(_excelValue).toList(),
      );
    }
    final summary = book['Resident totals'];
    summary.appendRow(
      [
        'Resident',
        'Phone',
        'Unit',
        'Deleted',
        'Billed minor',
        'Paid minor',
        'Credit applied minor',
        'Available credit minor',
        'Outstanding minor',
      ].map(_excelValue).toList(),
    );
    final receipts = book['Receipts'];
    receipts.appendRow(
      [
        'Resident',
        'Transaction',
        'Received amount minor',
        'Method',
        'Reference',
        'Received at',
        'Created at',
      ].map(_excelValue).toList(),
    );
    final sheet = book['Financial Report'];
    sheet.appendRow(
      [
        'Resident',
        'Phone',
        'Unit',
        'Deleted',
        'Description',
        'Billing period',
        'Bill amount minor',
        'Paid minor',
        'Outstanding minor',
        'Bill status',
        'Payment amount minor',
        'Method',
        'Reference',
        'Payment timestamp',
        'Transaction created at',
      ].map(_excelValue).toList(),
    );
    for (final row in rows) {
      final identity = Map<String, dynamic>.from(row['identity'] as Map? ?? {});
      summary.appendRow(
        [
          identity['name'],
          identity['phone'],
          identity['unit'],
          identity['deleted'],
          row['billedMinor'],
          row['paidMinor'],
          row['creditAppliedMinor'],
          row['availableCreditMinor'],
          row['outstandingMinor'],
        ].map(_excelValue).toList(),
      );
      for (final payment
          in (row['payments'] as List? ?? const []).whereType<Map>()) {
        receipts.appendRow(
          [
            identity['name'],
            payment['transactionId'],
            payment['receivedAmountMinor'],
            payment['method'],
            payment['reference'],
            _reportTimestamp(payment['receivedAtMs']),
            _reportTimestamp(payment['createdAtMs']),
          ].map(_excelValue).toList(),
        );
      }
      for (final bill in (row['bills'] as List? ?? const []).whereType<Map>()) {
        final settlements = (bill['settlements'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        if (settlements.isEmpty) {
          sheet.appendRow(
            [
              identity['name'],
              identity['phone'],
              identity['unit'],
              identity['deleted'],
              bill['description'],
              bill['billingPeriod'],
              bill['amountMinor'],
              bill['paidMinor'],
              bill['outstandingMinor'],
              bill['status'],
            ].map(_excelValue).toList(),
          );
        }
        for (final payment in settlements) {
          sheet.appendRow(
            [
              identity['name'],
              identity['phone'],
              identity['unit'],
              identity['deleted'],
              bill['description'],
              bill['billingPeriod'],
              bill['amountMinor'],
              bill['paidMinor'],
              bill['outstandingMinor'],
              bill['status'],
              payment['amountMinor'],
              payment['method'],
              payment['reference'],
              _reportTimestamp(payment['receivedAtMs']),
              _reportTimestamp(payment['createdAtMs']),
            ].map(_excelValue).toList(),
          );
        }
      }
    }
    final bytes = book.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hominode_financial_report.xlsx')
      ..writeAsBytesSync(bytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Hominode Financial Report');
  }

  Future<void> _loadOccupancyData() async {
    if (mounted) {
      setState(() {
        _occupancyLoading = true;
        _occupancyLoadError = null;
      });
    }

    try {
      final summary = await _reportsService.getOccupancySummary();
      final buildings = await _reportsService.getBuildingOccupancy();

      if (mounted) {
        setState(() {
          _occupancySummary = summary;
          _buildingOccupancies = buildings;
          _occupancyLoading = false;
          _occupancyLoadError = null;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _occupancySummary = null;
          _buildingOccupancies = [];
          _occupancyLoading = false;
          _occupancyLoadError = error.userMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _occupancySummary = null;
          _buildingOccupancies = [];
          _occupancyLoading = false;
          _occupancyLoadError =
              'Occupancy report is unavailable right now. Please try again shortly.';
        });
      }
      print('ReportsAnalyticsScreen: Occupancy load error: $error');
    }
  }

  Future<void> _loadComplaintsData() async {
    if (mounted) {
      setState(() {
        _complaintsLoading = true;
        _complaintsLoadError = null;
      });
    }

    try {
      final summary = await _reportsService.getComplaintsSummary(
        year: selectedDate.year,
        month: selectedDate.month,
      );
      final trends = await _reportsService.getMonthlyComplaintsTrends();

      if (mounted) {
        setState(() {
          _complaintsSummary = summary;
          _complaintsTrends = trends;
          _complaintsLoading = false;
          _complaintsLoadError = null;
        });
      }
    } on ReportsServiceException catch (error) {
      if (mounted) {
        setState(() {
          _complaintsSummary = null;
          _complaintsTrends = [];
          _complaintsLoading = false;
          _complaintsLoadError = error.userMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _complaintsSummary = null;
          _complaintsTrends = [];
          _complaintsLoading = false;
          _complaintsLoadError =
              'Complaints report is unavailable right now. Please try again shortly.';
        });
      }
      print('ReportsAnalyticsScreen: Complaints load error: $error');
    }
  }

  Future<void> _loadDeliveriesData() async {
    try {
      final count = await _reportsService.getDeliveriesCount(
        year: selectedDate.year,
        month: selectedDate.month,
      );

      if (mounted) {
        setState(() {
          _deliveriesCount = count;
        });
      }
    } on ReportsServiceException catch (_) {
      if (mounted) {
        setState(() {
          _deliveriesCount = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _deliveriesCount = null;
        });
      }
      print('ReportsAnalyticsScreen: Deliveries load error: $error');
    }
  }

  String get selectedMonth {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[selectedDate.month - 1]} ${selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Reports & Analytics'),
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      _buildFilterRow(),
                      _buildKpiCards(),
                      _buildTabSwitcher(),
                      _buildCharts(),
                      SizedBox(height: 80.h),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Text(
            'Loading reports data...',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Color(0xFF0E4778),
                  size: 24.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Dashboard',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Track billing, collections & key metrics for $selectedMonth',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null && picked != selectedDate) {
                  setState(() {
                    selectedDate = picked;
                  });
                  _loadData();
                }
              },
              child: Container(
                height: 52.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 18.w,
                      color: Color(0xFF0E4778),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        selectedMonth,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Container(
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E4778).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () async {
                if (selectedTabIndex == 0) {
                  if (_detailedReport == null) {
                    await _generateDetailedReport();
                  } else {
                    await _exportDetailedPdf();
                  }
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Export is not available yet for this report.',
                    ),
                    backgroundColor: const Color(0xFF0E4778),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_download, color: Colors.white, size: 20.w),
                  SizedBox(width: 8.w),
                  Text(
                    'Export',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    if (selectedTabIndex != 0) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnalyticsKpiCard(
                    key: const ValueKey('kpi-collections'),
                    title: 'Collections Received',
                    value:
                        _financialSummary?.formattedCollectionsReceived ?? '—',
                    isUnavailable: _financialSummary == null,
                    growth: '+0%',
                    isPositive: true,
                    showGrowth: false,
                    color: const Color(0xFF0E4778),
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AnalyticsKpiCard(
                    key: const ValueKey('kpi-occupancy'),
                    title: 'Occupancy Rate',
                    value: _occupancySummary?.formattedOccupancyRate ?? '—',
                    isUnavailable: _occupancySummary == null,
                    growth: '+0%',
                    isPositive: true,
                    color: const Color(0xFF10B981),
                    icon: Icons.home,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnalyticsKpiCard(
                    key: const ValueKey('kpi-resolved-issues'),
                    title: 'Resolved Issues',
                    value: _complaintsSummary == null
                        ? '—'
                        : '${_complaintsSummary!.resolvedComplaints}',
                    isUnavailable: _complaintsSummary == null,
                    growth: _complaintsSummary?.formattedResolutionRate ?? '',
                    isPositive: true,
                    color: const Color(0xFF8B5CF6),
                    icon: Icons.check_circle,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AnalyticsKpiCard(
                    key: const ValueKey('kpi-deliveries'),
                    title: 'Deliveries',
                    value: _deliveriesCount == null ? '—' : '$_deliveriesCount',
                    isUnavailable: _deliveriesCount == null,
                    growth: _deliveriesCount == null ? '' : '+0%',
                    isPositive: true,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.local_shipping,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SegmentedTabBar(
        tabs: tabs,
        selectedIndex: selectedTabIndex,
        onTabSelected: (index) {
          setState(() {
            selectedTabIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildCharts() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          if (selectedTabIndex == 0) ...[
            // Financial Tab
            if (_financialLoadError != null)
              _buildFinancialErrorBanner(_financialLoadError!),
            if (_financialLoadError != null) SizedBox(height: 12.h),
            _buildFinancialSummaryCard(),
            SizedBox(height: 20.h),
            _buildDesktopOnlyFinancialReportsCard(),
          ] else if (selectedTabIndex == 1) ...[
            // Occupancy Tab
            if (_occupancyLoading)
              _buildReportLoadingState('Loading occupancy data...')
            else if (_occupancyLoadError != null)
              _buildReportErrorCard(
                title: 'Occupancy data unavailable',
                message: _occupancyLoadError!,
              )
            else if (_occupancySummary != null) ...[
              OccupancyChart(occupancySummary: _occupancySummary!),
              SizedBox(height: 20.h),
              BuildingOccupancyChart(buildingOccupancies: _buildingOccupancies),
            ],
          ] else if (selectedTabIndex == 2) ...[
            // Complaints Tab
            if (_complaintsLoading)
              _buildReportLoadingState('Loading complaints data...')
            else if (_complaintsLoadError != null)
              _buildReportErrorCard(
                title: 'Complaints data unavailable',
                message: _complaintsLoadError!,
              )
            else if (_complaintsSummary != null) ...[
              ComplaintsChart(
                complaintsSummary: _complaintsSummary!,
                complaintsTrends: _complaintsTrends,
              ),
              SizedBox(height: 20.h),
              ComplaintCategoryChart(complaintsSummary: _complaintsSummary!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReportLoadingState(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 12.h),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildReportErrorCard({
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0D7D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8D3340),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF784E54)),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB91C1C)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    final summary = _financialSummary;
    String formatValue(String Function(FinancialSummary s) select) {
      return summary == null ? 'Unavailable' : select(summary);
    }

    String formatCount(int? value) => value == null ? 'Unavailable' : '$value';

    Widget row(String label, String value) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing Summary',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 10.h),
          row('Total billed', formatValue((s) => s.formattedTotalBilled)),
          row(
            'Collections received',
            formatValue((s) => s.formattedCollectionsReceived),
          ),
          row('Outstanding', formatValue((s) => s.formattedOutstanding)),
          row(
            'Overdue outstanding',
            formatValue((s) => s.formattedOverdueOutstanding),
          ),
          row(
            'Available resident credit',
            formatValue((s) => s.formattedAvailableCredit),
          ),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          SizedBox(height: 8.h),
          row('Bills - Pending', formatCount(summary?.pendingBills)),
          row(
            'Bills - Partially paid',
            formatCount(summary?.partiallyPaidBills),
          ),
          row('Bills - Paid', formatCount(summary?.paidBills)),
          row('Bills - Overdue', formatCount(summary?.overdueBills)),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          SizedBox(height: 8.h),
          row(
            'UPI collections',
            summary == null
                ? 'Unavailable'
                : '${summary.upiCollection.formattedTotal} (${summary.upiCollection.count})',
          ),
          row(
            'Cash collections',
            summary == null
                ? 'Unavailable'
                : '${summary.cashCollection.formattedTotal} (${summary.cashCollection.count})',
          ),
          row(
            'Bank transfer collections',
            summary == null
                ? 'Unavailable'
                : '${summary.bankTransferCollection.formattedTotal} (${summary.bankTransferCollection.count})',
          ),
          row(
            'Cheque collections',
            summary == null
                ? 'Unavailable'
                : '${summary.chequeCollection.formattedTotal} (${summary.chequeCollection.count})',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOnlyFinancialReportsCard() {
    final visible = _visibleDetailedRows;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resident financial report',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 12.h),
          const Text('Report Type'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All Residents')),
              ButtonSegment(
                value: 'individual',
                label: Text('Individual Resident'),
              ),
            ],
            selected: {_detailMode},
            onSelectionChanged: (value) => _changeDetailMode(value.first),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  _detailRange == null
                      ? 'All history (optional dates)'
                      : '${_detailRange!.start.toIso8601String().substring(0, 10)} – ${_detailRange!.end.toIso8601String().substring(0, 10)}',
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDateRange:
                        _detailRange ??
                        DateTimeRange(
                          start: DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            1,
                          ),
                          end: DateTime.now(),
                        ),
                  );
                  if (picked != null) {
                    setState(() {
                      _detailRange = picked;
                      _detailedReport = null;
                      _selectedResidentId = null;
                      _residentSearch.clear();
                    });
                  }
                },
              ),
              if (_detailRange != null)
                TextButton(
                  onPressed: () => setState(() {
                    _detailRange = null;
                    _detailedReport = null;
                  }),
                  child: const Text('Clear dates'),
                ),
              if (_detailMode == 'all' || _selectedResidentId != null)
                FilledButton.icon(
                  onPressed: _detailLoading ? null : _generateDetailedReport,
                  icon: _detailLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.assessment),
                  label: Text(
                    _detailLoading ? 'Generating…' : 'Generate Report',
                  ),
                ),
            ],
          ),
          if (_detailMode == 'individual') ...[
            SizedBox(height: 12.h),
            DropdownMenu<String>(
              controller: _residentSearch,
              enableFilter: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Search Resident by name, phone or unit'),
              onSelected: (value) => setState(() {
                _selectedResidentId = value;
                _detailedReport = null;
              }),
              dropdownMenuEntries: _residentOptions.map((row) {
                final label = _residentLabel(row);
                return DropdownMenuEntry(
                  value: row['residentId'] as String,
                  label: label,
                );
              }).toList(),
            ),
          ],
          if (_detailError != null)
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Text(
                _detailError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_detailedReport != null) ...[
            for (final warning
                in (_detailedReport!['coverageWarnings'] as List? ?? const []))
              Text(
                warning.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            SizedBox(height: 14.h),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: visible.isEmpty ? null : _exportDetailedPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: visible.isEmpty ? null : _exportDetailedExcel,
                  icon: const Icon(Icons.table_view),
                  label: const Text('Export Excel'),
                ),
              ],
            ),
            if (_detailMode == 'all') ...[
              SizedBox(height: 12.h),
              Builder(
                builder: (_) {
                  final totals = Map<String, dynamic>.from(
                    _detailedReport!['totals'] as Map,
                  );
                  return Text(
                    'Residents: ${totals['residentsCount']}   Billed: ${_minor(totals['billedMinor'])}   Paid: ${_minor(totals['paidMinor'])}   Credit applied: ${_minor(totals['creditAppliedMinor'])}   Available credit: ${_minor(totals['availableCreditMinor'])}   Outstanding: ${_minor(totals['outstandingMinor'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  );
                },
              ),
            ],
            for (final row in visible) ...[
              const Divider(height: 20),
              Builder(
                builder: (_) {
                  final identity = Map<String, dynamic>.from(
                    row['identity'] as Map? ?? {},
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${identity['name'] ?? 'Resident'}${identity['deleted'] == true ? ' · Deleted' : ' · Active'}',
                    ),
                    subtitle: Text(
                      '${identity['phone'] ?? 'Phone unavailable'} · Unit ${identity['unit'] ?? 'unavailable'} · ${identity['residentType'] ?? 'Resident'}\nBilled ${_minor(row['billedMinor'])}  Paid ${_minor(row['paidMinor'])}  Credit applied ${_minor(row['creditAppliedMinor'])}  Available credit ${_minor(row['availableCreditMinor'])}  Outstanding ${_minor(row['outstandingMinor'])}',
                    ),
                  );
                },
              ),
              for (final payment
                  in (row['payments'] as List? ?? const []).whereType<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Received ${_minor(payment['receivedAmountMinor'])} · ${payment['method']}',
                  ),
                  subtitle: Text(
                    'Transaction: ${payment['transactionId']} · Reference: ${payment['reference'] ?? '—'}\nReceived: ${_reportTimestamp(payment['receivedAtMs'])} · Created: ${_reportTimestamp(payment['createdAtMs'])}',
                  ),
                ),
              for (final bill
                  in (row['bills'] as List? ?? const []).whereType<Map>())
                ExpansionTile(
                  title: Text(
                    '${bill['description']} · ${bill['billingPeriod']} · ${bill['status']}',
                  ),
                  subtitle: Text(
                    'Billed ${_minor(bill['amountMinor'])}, paid ${_minor(bill['paidMinor'])}, outstanding ${_minor(bill['outstandingMinor'])}',
                  ),
                  children: [
                    for (final payment
                        in (bill['settlements'] as List? ?? const [])
                            .whereType<Map>())
                      ListTile(
                        dense: true,
                        title: Text(
                          '${_minor(payment['amountMinor'])} · ${payment['method']}',
                        ),
                        subtitle: Text(
                          'Reference: ${payment['reference'] ?? '—'} · Received: ${DateTime.fromMillisecondsSinceEpoch(payment['receivedAtMs'] as int).toLocal()}',
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ],
      ),
    );
  }

  static String _minor(Object? value) =>
      value is int ? formatInrMinorUnitsForReports(value) : '—';

  static String _reportTimestamp(Object? value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(
          value,
          isUtc: true,
        ).toIso8601String()
      : '—';
}

// Reusable KPI Card Widget
class AnalyticsKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String growth;
  final bool isPositive;
  final bool showGrowth;
  final bool isUnavailable;
  final Color color;
  final IconData icon;

  const AnalyticsKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.growth,
    required this.isPositive,
    this.showGrowth = true,
    this.isUnavailable = false,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 168.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40.h,
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Icon(icon, color: color, size: 21.w),
                ),
                const Spacer(),
                if (showGrowth && !isUnavailable && growth.isNotEmpty)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFDC2626).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 12.w,
                              color: isPositive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFDC2626),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              growth,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 30.h,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 34.h),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  height: 1.1,
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 14.h),
            child: isUnavailable
                ? Text(
                    'Unavailable',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A94A3),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// Segmented Tab Bar Widget
class SegmentedTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;

  const SegmentedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
