import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../services/bill_firestore_service.dart';
import '../services/resident_direct_upi_service.dart';
import '../widgets/resident_visitor_page_background.dart';

typedef PaymentReceiptPicker = Future<XFile?> Function(ImageSource source);

class SubmitPaymentProofScreen extends StatefulWidget {
  final Map<String, dynamic> bill;
  final Map<String, dynamic>? existingV2Proof;
  final ResidentDirectUpiService? service;
  final PaymentReceiptPicker? receiptPicker;
  final DirectUpiPaymentPreparation? preparation;
  final bool flexibleAmountsEnabled;

  const SubmitPaymentProofScreen({
    super.key,
    required this.bill,
    this.existingV2Proof,
    this.service,
    this.receiptPicker,
    this.preparation,
    this.flexibleAmountsEnabled = flexibleResidentV2PaymentAmountsEnabled,
  });

  @override
  State<SubmitPaymentProofScreen> createState() =>
      _SubmitPaymentProofScreenState();
}

class _SubmitPaymentProofScreenState extends State<SubmitPaymentProofScreen> {
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _receiptImage;
  Uint8List? _receiptBytes;
  bool _isSubmitting = false;
  bool? _existingReceiptUploaded;
  ResidentV2ProofSubmissionAttempt? _v2Attempt;

  ResidentDirectUpiService get _service =>
      widget.service ?? ResidentDirectUpiService();

  static const Color _primaryBlue = Color(0xFF0E4778);

  @override
  void initState() {
    super.initState();
    final proof = widget.existingV2Proof;
    final amountMinor =
        widget.preparation?.paymentAmountMinor ??
        proof?['submittedAmountMinor'] ??
        widget.bill['outstandingAmountMinor'];
    if (amountMinor is int) _amountController.text = _inrText(amountMinor);
    if (proof != null) _checkExistingReceipt(proof);
  }

  Future<void> _checkExistingReceipt(Map<String, dynamic> proof) async {
    try {
      final uploaded = await _service.isV2ProofReceiptUploaded(proof);
      if (mounted) setState(() => _existingReceiptUploaded = uploaded);
    } on ResidentDirectUpiException catch (error) {
      if (mounted) {
        setState(() => _existingReceiptUploaded = false);
        _showMessage(error.message);
      }
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final image = widget.receiptPicker == null
          ? await _picker.pickImage(
              source: source,
              imageQuality: 85,
              maxWidth: 1800,
            )
          : await widget.receiptPicker!(source);

      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();

      setState(() {
        _receiptImage = image;
        _receiptBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('payment_receipt_select_error'.tr())),
      );
    }
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text('take_photo'.tr()),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('choose_photo'.tr()),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickReceipt(source);
    }
  }

  Future<void> _submitPaymentProof() async {
    if (_isSubmitting) return;

    final isV2 = widget.bill['schemaVersion'] == 2;
    final user = isV2 ? null : FirebaseAuth.instance.currentUser;

    if (!isV2 && user == null) {
      _showMessage('login_again'.tr());
      return;
    }

    if (_receiptImage == null) {
      _showMessage('attach_payment_receipt'.tr());
      return;
    }

    final billId = widget.bill['id']?.toString() ?? '';
    final communityId = widget.bill['communityId']?.toString() ?? '';
    final flatId = widget.bill['flatId']?.toString() ?? '';
    final selectedV2Amount =
        widget.preparation?.paymentAmountMinor ??
        (widget.existingV2Proof != null
            ? widget.existingV2Proof!['submittedAmountMinor']
            : parseResidentInrMinorUnits(_amountController.text));
    final amount = (widget.bill['amount'] as num?)?.toDouble() ?? 0;
    final amountValid = isV2
        ? BillFirestoreService.isV2InrBill(widget.bill) &&
              selectedV2Amount is int &&
              selectedV2Amount > 0 &&
              selectedV2Amount <= 9007199254740991 &&
              (widget.flexibleAmountsEnabled ||
                  widget.preparation != null ||
                  selectedV2Amount == widget.bill['outstandingAmountMinor'])
        : amount > 0;

    if (billId.isEmpty ||
        communityId.isEmpty ||
        (!isV2 && flatId.isEmpty) ||
        !amountValid) {
      _showMessage('bill_info_incomplete'.tr());
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    Reference? uploadedReceiptRef;

    try {
      if (isV2) {
        final bytes = Uint8List.fromList(
          _receiptBytes ?? await _receiptImage!.readAsBytes(),
        );
        final extension = _fileExtension(_receiptImage!.name);
        final existingProof = widget.existingV2Proof;
        if (existingProof != null) {
          await _service.resumeV2PaymentProofUpload(
            proof: existingProof,
            receiptBytes: bytes,
            receiptExtension: extension,
          );
        } else {
          final preparation =
              widget.preparation ??
              await _service.preparePayment(
                billId,
                submittedAmountMinor: selectedV2Amount as int,
                allowFlexibleAmounts: widget.flexibleAmountsEnabled,
              );
          if (preparation.paymentAmountMinor != selectedV2Amount) {
            throw const ResidentDirectUpiException(
              ResidentDirectUpiFailure.billRevisionChanged,
            );
          }
          final attempt = _v2Attempt ??= _service
              .createV2ProofSubmissionAttempt(
                preparation: preparation,
                receiptBytes: bytes,
                receiptExtension: extension,
                paymentReference: _referenceController.text,
              );
          await _service.submitV2PaymentProof(attempt);
        }
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final residentUid = user!.uid;
      await _service.ensureNoPendingProofForBill(billId);

      final paymentRef = FirebaseFirestore.instance
          .collection('payments')
          .doc();

      final extension = _fileExtension(_receiptImage!.name);

      final storagePath =
          'payment_receipts/'
          '$communityId/'
          '$billId/'
          '$residentUid/'
          '${paymentRef.id}.$extension';

      uploadedReceiptRef = FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: _contentType(extension),
        customMetadata: {
          'paymentId': paymentRef.id,
          'billId': billId,
          'communityId': communityId,
          'residentUid': user.uid,
        },
      );

      await uploadedReceiptRef.putFile(File(_receiptImage!.path), metadata);

      final now = Timestamp.now();

      final paymentData = <String, dynamic>{
        'id': paymentRef.id,
        'communityId': communityId,
        'billId': billId,
        'flatId': flatId,
        'userId': residentUid,
        'amount': amount,
        'provider': 'direct_upi',
        'method': 'upi',
        'verificationMode': 'manual',
        'evidenceType': 'receipt',
        'status': 'pending',
        'transactionId': _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        'receiptPath': storagePath,
        'paymentDate': now,
        'createdAt': now,
        'updatedAt': now,
      };

      await paymentRef.set(paymentData);

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ResidentDirectUpiException catch (error) {
      if (!mounted) return;

      _showMessage(error.message);
    } catch (e) {
      // Avoid leaving an orphan receipt if Firestore creation fails.
      if (uploadedReceiptRef != null) {
        try {
          await uploadedReceiptRef.delete();
        } catch (_) {}
      }

      if (!mounted) return;

      _showMessage('Payment proof could not be submitted: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _fileExtension(String path) {
    final extension = path.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return 'png';
      case 'heic':
        return 'heic';
      case 'heif':
        return 'heif';
      default:
        return 'jpg';
    }
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isV2 = widget.bill['schemaVersion'] == 2;
    final displayAmount = isV2
        ? BillFirestoreService.formatV2BillMinorUnits(
            widget.bill,
            widget.preparation?.paymentAmountMinor ??
                widget.existingV2Proof?['submittedAmountMinor'] ??
                parseResidentInrMinorUnits(_amountController.text) ??
                widget.bill['outstandingAmountMinor'],
          )
        : '₹${((widget.bill['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('payment_proof_title'.tr()),
        backgroundColor: Colors.white.withValues(alpha: .82),
        foregroundColor: const Color(0xFF0E2247),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F9FD),
      body: ResidentVisitorPageBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(23.r),
                  border: Border.all(color: Colors.white, width: 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF082F73).withValues(alpha: .07),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.preparation != null
                          ? 'payment_amount_title'.tr()
                          : widget.existingV2Proof == null
                          ? 'payment_amount_due'.tr()
                          : 'reserved_payment_amount'.tr(),
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      displayAmount,
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                      ),
                    ),
                    if (isV2 && widget.existingV2Proof == null) ...[
                      SizedBox(height: 12.h),
                      Text(
                        '${'selected_bill_outstanding'.tr()}: ${BillFirestoreService.formatV2BillMinorUnits(widget.bill, widget.bill['outstandingAmountMinor'])}',
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _amountController,
                        enabled:
                            widget.preparation == null &&
                            widget.flexibleAmountsEnabled &&
                            !_isSubmitting &&
                            _v2Attempt == null,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'payment_amount_inr'.tr(),
                          prefixText: '₹',
                          helperText: 'two_decimal_places'.tr(),
                        ),
                      ),
                      if (parseResidentInrMinorUnits(_amountController.text) !=
                          null)
                        Text(
                          'difference_from_bill'.tr(
                            namedArgs: {
                              'amount': _differenceText(
                                parseResidentInrMinorUnits(
                                  _amountController.text,
                                )!,
                                widget.bill['outstandingAmountMinor'] as int,
                              ),
                            },
                          ),
                        ),
                      if (widget.flexibleAmountsEnabled)
                        Text('excess_credit_info'.tr()),
                    ],
                  ],
                ),
              ),

              if (_existingReceiptUploaded == true) ...[
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9FCEB),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text('receipt_pending_admin_verification'.tr()),
                ),
              ],

              SizedBox(height: 20.h),

              Text(
                'transaction_reference'.tr(),
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8.h),

              if (_existingReceiptUploaded != true)
                TextField(
                  controller: _referenceController,
                  maxLength: 200,
                  enabled: _v2Attempt == null,
                  decoration: InputDecoration(
                    hintText: 'optional'.tr(),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

              SizedBox(height: 24.h),

              Text(
                'payment_receipt'.tr(),
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),

              SizedBox(height: 10.h),

              if (_existingReceiptUploaded != true)
                InkWell(
                  onTap: _isSubmitting || _v2Attempt != null
                      ? null
                      : _chooseReceiptSource,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: 180.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xFFDCE5EF)),
                    ),
                    child: _receiptImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 42.w,
                                color: _primaryBlue,
                              ),
                              SizedBox(height: 10.h),
                              Text('select_receipt_image'.tr()),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16.r),
                            child: SizedBox(
                              height: 180.h,
                              child: Image.memory(
                                _receiptBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                  ),
                ),

              SizedBox(height: 12.h),

              if (_existingReceiptUploaded != true && _receiptImage != null)
                TextButton.icon(
                  onPressed: _isSubmitting || _v2Attempt != null
                      ? null
                      : _chooseReceiptSource,
                  icon: const Icon(Icons.refresh),
                  label: Text('change_receipt'.tr()),
                ),

              SizedBox(height: 28.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting || _existingReceiptUploaded == true
                      ? null
                      : _submitPaymentProof,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF243143),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 52.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _existingReceiptUploaded == true
                              ? 'awaiting_admin_verification'.tr()
                              : widget.existingV2Proof == null
                              ? _v2Attempt == null
                                    ? 'submit_for_verification'.tr()
                                    : 'retry_payment_proof'.tr()
                              : 'resume_receipt_upload'.tr(),
                        ),
                ),
              ),

              SizedBox(height: 14.h),

              Text(
                'payment_return_not_verified'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _inrText(int minor) =>
      '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

  String _differenceText(int amount, int outstanding) {
    final difference = amount - outstanding;
    final sign = difference > 0
        ? '+'
        : difference < 0
        ? '−'
        : '';
    return '$sign₹${_inrText(difference.abs())}';
  }
}
