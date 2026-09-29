import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../services/bill_firestore_service.dart';
import '../services/resident_direct_upi_service.dart';

typedef PaymentReceiptPicker = Future<XFile?> Function(ImageSource source);

class SubmitPaymentProofScreen extends StatefulWidget {
  final Map<String, dynamic> bill;
  final Map<String, dynamic>? existingV2Proof;
  final ResidentDirectUpiService? service;
  final PaymentReceiptPicker? receiptPicker;

  const SubmitPaymentProofScreen({
    super.key,
    required this.bill,
    this.existingV2Proof,
    this.service,
    this.receiptPicker,
  });

  @override
  State<SubmitPaymentProofScreen> createState() =>
      _SubmitPaymentProofScreenState();
}

class _SubmitPaymentProofScreenState extends State<SubmitPaymentProofScreen> {
  final _referenceController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _receiptImage;
  Uint8List? _receiptBytes;
  bool _isSubmitting = false;
  bool? _existingReceiptUploaded;

  ResidentDirectUpiService get _service =>
      widget.service ?? ResidentDirectUpiService();

  static const Color _primaryBlue = Color(0xFF0E4778);

  @override
  void initState() {
    super.initState();
    final proof = widget.existingV2Proof;
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select receipt: $e')));
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
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose Photo'),
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
      _showMessage('Please sign in again.');
      return;
    }

    if (_receiptImage == null) {
      _showMessage('Please attach your payment receipt.');
      return;
    }

    final billId = widget.bill['id']?.toString() ?? '';
    final communityId = widget.bill['communityId']?.toString() ?? '';
    final flatId = widget.bill['flatId']?.toString() ?? '';
    final v2Amount =
        widget.existingV2Proof?['submittedAmountMinor'] ??
        widget.bill['outstandingAmountMinor'];
    final amount = (widget.bill['amount'] as num?)?.toDouble() ?? 0;
    final amountValid = isV2
        ? BillFirestoreService.isV2InrBill(widget.bill) &&
              v2Amount is int &&
              v2Amount > 0
        : amount > 0;

    if (billId.isEmpty ||
        communityId.isEmpty ||
        (!isV2 && flatId.isEmpty) ||
        !amountValid) {
      _showMessage('Bill information is incomplete.');
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
          final preparation = await _service.preparePayment(billId);
          final attempt = _service.createV2ProofSubmissionAttempt(
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

      print('💳 PAYMENT SUBMISSION DATA: $paymentData');

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
            widget.existingV2Proof?['submittedAmountMinor'] ??
                widget.bill['outstandingAmountMinor'],
          )
        : '₹${((widget.bill['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Payment Proof'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existingV2Proof == null
                        ? 'Amount Due'
                        : 'Reserved Payment Amount',
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
                child: const Text(
                  'Receipt already uploaded. This payment is awaiting Admin verification.',
                ),
              ),
            ],

            SizedBox(height: 20.h),

            Text(
              'Transaction / Reference No.',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),

            if (_existingReceiptUploaded != true)
              TextField(
                controller: _referenceController,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Optional',
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
              'Payment Receipt',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),

            SizedBox(height: 10.h),

            if (_existingReceiptUploaded != true)
              InkWell(
                onTap: _isSubmitting ? null : _chooseReceiptSource,
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  width: double.infinity,
                  height: 180.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.shade300),
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
                            const Text('Take photo or choose from gallery'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16.r),
                          child: Image.memory(
                            _receiptBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),

            SizedBox(height: 12.h),

            if (_existingReceiptUploaded != true && _receiptImage != null)
              TextButton.icon(
                onPressed: _isSubmitting ? null : _chooseReceiptSource,
                icon: const Icon(Icons.refresh),
                label: const Text('Change Receipt'),
              ),

            SizedBox(height: 28.h),

            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: _isSubmitting || _existingReceiptUploaded == true
                    ? null
                    : _submitPaymentProof,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
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
                            ? 'Awaiting Admin verification'
                            : widget.existingV2Proof == null
                            ? 'Submit for Verification'
                            : 'Resume Receipt Upload',
                      ),
              ),
            ),

            SizedBox(height: 14.h),

            const Text(
              'Your bill will remain pending until the payment is verified by your community administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
