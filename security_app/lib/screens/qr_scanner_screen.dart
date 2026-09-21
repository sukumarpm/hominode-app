import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/app_colors.dart';
import '../services/visitor_service.dart';

class _VisitorQrPayload {
  final String? qrToken;
  final String? legacyVisitorId;

  const _VisitorQrPayload({this.qrToken, this.legacyVisitorId});
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool isScanning = true;
  bool flashOn = false;
  bool isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  _VisitorQrPayload? _parseVisitorQr(String rawValue) {
    final value = rawValue.trim();

    if (value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map<String, dynamic>) {
        // New Hominode QR
        final type = decoded['type']?.toString();
        final token = decoded['token']?.toString().trim();

        if (type == 'hominode_visitor' && token != null && token.isNotEmpty) {
          return _VisitorQrPayload(qrToken: token);
        }

        // Legacy Resident QR
        final visitorId = decoded['visitorId']?.toString().trim();

        if (visitorId != null && visitorId.isNotEmpty) {
          return _VisitorQrPayload(legacyVisitorId: visitorId);
        }
      }
    } catch (_) {
      // Older QR versions may have contained only
      // the visitor Firestore ID.
      return _VisitorQrPayload(legacyVisitorId: value);
    }

    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!isScanning || isProcessing) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();

      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      final payload = _parseVisitorQr(rawValue);

      if (payload == null) {
        setState(() {
          isScanning = false;
          isProcessing = false;
        });

        await cameraController.stop();

        if (!mounted) return;

        _showErrorDialog(
          'Invalid QR Code',
          'This is not a valid Hominode visitor pass.',
        );

        return;
      }

      setState(() {
        isScanning = false;
        isProcessing = true;
      });

      await cameraController.stop();

      if (!mounted) return;

      if (payload.qrToken != null) {
        await _fetchVisitorByQrToken(payload.qrToken!);
      } else if (payload.legacyVisitorId != null) {
        await _fetchLegacyVisitor(payload.legacyVisitorId!);
      }

      return;
    }
  }

  Future<void> _fetchLegacyVisitor(String visitorId) async {
    final id = visitorId.trim();

    if (id.isEmpty) {
      _showErrorDialog('Invalid Visitor Pass', 'This visitor pass is invalid.');
      return;
    }

    try {
      final communityId = await _requireSecurityCommunityId();

      final ref = FirebaseFirestore.instance.collection('visitors').doc(id);

      final doc = await ref.get();

      if (!doc.exists || doc.data() == null) {
        _showErrorDialog(
          'Visitor Not Found',
          'This visitor pass could not be found.',
        );
        return;
      }

      final data = doc.data()!;

      if (data['communityId']?.toString().trim() != communityId) {
        _showErrorDialog(
          'Invalid Visitor Pass',
          'This visitor pass is not valid for your assigned community.',
        );
        return;
      }

      await _processVisitorDocument(ref, data);
    } on FirebaseException catch (e) {
      debugPrint('Legacy visitor lookup Firebase error: ${e.code}');

      _showErrorDialog(
        'Invalid Visitor Pass',
        'This visitor pass cannot be used at your assigned community.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _fetchVisitorByQrToken(String qrToken) async {
    try {
      final communityId = await _requireSecurityCommunityId();

      final snapshot = await FirebaseFirestore.instance
          .collection('visitors')
          .where('communityId', isEqualTo: communityId)
          .where('qrToken', isEqualTo: qrToken)
          .limit(2)
          .get();

      if (snapshot.docs.isEmpty) {
        _showErrorDialog(
          'Invalid Visitor Pass',
          'No valid visitor pass was found for this community.',
        );
        return;
      }

      // qrToken should identify exactly one visitor.
      if (snapshot.docs.length != 1) {
        _showErrorDialog(
          'Visitor Pass Error',
          'This visitor pass cannot be processed. Please contact the community administrator.',
        );
        return;
      }

      final doc = snapshot.docs.single;

      await _processVisitorDocument(doc.reference, doc.data());
    } on FirebaseException catch (e) {
      debugPrint('QR visitor lookup Firebase error: ${e.code}');

      if (e.code == 'permission-denied') {
        _showErrorDialog(
          'Invalid Visitor Pass',
          'This visitor pass cannot be used at your assigned community.',
        );
      } else {
        _showErrorDialog('Unable to Process Visitor', 'Please try again.');
      }
    } catch (e) {
      debugPrint('QR visitor lookup error: $e');

      _showErrorDialog('Unable to Process Visitor', 'Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _processVisitorDocument(
    DocumentReference<Map<String, dynamic>> visitorRef,
    Map<String, dynamic> data,
  ) async {
    final securityCommunityId = await _requireSecurityCommunityId();

    final visitorCommunityId = data['communityId']?.toString().trim() ?? '';

    if (visitorCommunityId.isEmpty ||
        visitorCommunityId != securityCommunityId) {
      _showErrorDialog(
        'Invalid Visitor Pass',
        'This visitor pass is not valid for your assigned community.',
      );
      return;
    }

    final status = data['status']?.toString().trim() ?? '';

    if (status == 'expected' || status == 'pending' || status == 'approved') {
      await VisitorService().checkInVisitor(visitorRef.id);

      if (!mounted) return;

      _showSuccessDialog(data, isCheckIn: true);

      return;
    }

    if (status == 'inside') {
      await VisitorService().checkOutVisitor(visitorRef.id);

      if (!mounted) return;

      _showSuccessDialog(data, isCheckIn: false);

      return;
    }

    if (status == 'completed') {
      _showErrorDialog(
        'Already Checked Out',
        'This visitor has already checked out.',
      );

      return;
    }

    _showErrorDialog(
      'Visitor Cannot Be Processed',
      'This visitor pass is not currently valid for gate entry or exit.',
    );
  }

  Future<String> _requireSecurityCommunityId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Security session has expired. Please sign in again.');
    }

    final securityDoc = await FirebaseFirestore.instance
        .collection('securityStaff')
        .doc(user.uid)
        .get();

    if (!securityDoc.exists) {
      throw Exception('Security profile not found.');
    }

    final data = securityDoc.data();

    if (data == null) {
      throw Exception('Security profile is invalid.');
    }

    final profileUid = data['uid']?.toString().trim() ?? '';
    final role = data['role']?.toString().trim() ?? '';
    final isActive = data['isActive'] == true;
    final communityId = data['communityId']?.toString().trim() ?? '';

    if (profileUid != user.uid ||
        role != 'security' ||
        !isActive ||
        communityId.isEmpty) {
      throw Exception('Security account is not authorized.');
    }

    return communityId;
  }

  Future<void> _fetchVisitor(String visitorDocumentId) async {
    final visitorId = visitorDocumentId.trim();

    if (visitorId.isEmpty) {
      _showErrorDialog(
        'Invalid Visitor Code',
        'Please scan a valid QR code or enter a visitor code.',
      );
      return;
    }

    try {
      debugPrint('QR/manual visitor lookup requested.');

      // ----------------------------------------------------------
      // 1. Resolve authenticated Security user's community.
      // ----------------------------------------------------------
      final securityCommunityId = await _requireSecurityCommunityId();

      // ----------------------------------------------------------
      // 2. Read the exact visitor document.
      //
      // Firestore Security Rules must ALSO enforce community
      // ownership. This client-side check is an additional guard.
      // ----------------------------------------------------------
      final visitorRef = FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId);

      final doc = await visitorRef.get();

      if (!doc.exists) {
        _showErrorDialog(
          'Visitor Not Found',
          'No valid visitor pass was found.',
        );
        return;
      }

      final data = doc.data();

      if (data == null) {
        _showErrorDialog(
          'Visitor Not Found',
          'No valid visitor pass was found.',
        );
        return;
      }

      // ----------------------------------------------------------
      // 3. Critical tenant/community ownership validation.
      // ----------------------------------------------------------
      final visitorCommunityId = data['communityId']?.toString().trim() ?? '';

      if (visitorCommunityId.isEmpty ||
          visitorCommunityId != securityCommunityId) {
        // Do not disclose whether a visitor exists in another
        // community.
        _showErrorDialog(
          'Invalid Visitor Pass',
          'This visitor pass is not valid for your assigned community.',
        );
        return;
      }

      final status = data['status']?.toString().trim() ?? '';
      final visitorName =
          data['visitorName']?.toString().trim().isNotEmpty == true
          ? data['visitorName'].toString().trim()
          : 'Unknown';

      debugPrint('Visitor validated: $visitorName');
      debugPrint('Visitor status: $status');

      // ----------------------------------------------------------
      // 4. Process only known visitor states.
      // ----------------------------------------------------------
      if (status == 'expected' || status == 'pending' || status == 'approved') {
        // Expected visitor entering the property.
        await VisitorService().checkInVisitor(visitorRef.id);

        if (!mounted) return;

        _showSuccessDialog(data, isCheckIn: true);
      } else if (status == 'inside') {
        // Visitor leaving the property.
        await VisitorService().checkOutVisitor(visitorRef.id);

        if (!mounted) return;

        _showSuccessDialog(data, isCheckIn: false);
      } else if (status == 'completed') {
        _showErrorDialog(
          'Already Checked Out',
          'This visitor has already checked out.',
        );
      } else {
        _showErrorDialog(
          'Visitor Cannot Be Processed',
          'This visitor pass is not currently valid for gate entry or exit.',
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('Visitor processing Firebase error: ${e.code}');

      // Important:
      // Do not expose permission-denied details or another
      // community's existence to the Security user.
      if (e.code == 'permission-denied') {
        _showErrorDialog(
          'Invalid Visitor Pass',
          'This visitor pass cannot be used at your assigned community.',
        );
      } else {
        _showErrorDialog('Unable to Process Visitor', 'Please try again.');
      }
    } catch (e) {
      debugPrint('Visitor processing error: $e');

      _showErrorDialog(
        'Unable to Process Visitor',
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _processManualVisitorCode(String code) async {
    if (isProcessing) {
      return;
    }

    final normalizedCode = code.trim().toUpperCase().replaceAll(' ', '');

    if (normalizedCode.isEmpty) {
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final communityId = await _requireSecurityCommunityId();

      debugPrint('MANUAL LOOKUP communityId=$communityId');
      debugPrint('MANUAL LOOKUP passCode=$normalizedCode');

      final snapshot = await FirebaseFirestore.instance
          .collection('visitors')
          .where('communityId', isEqualTo: communityId)
          .where('visitorPassCode', isEqualTo: normalizedCode)
          .limit(2)
          .get();

      debugPrint('MANUAL LOOKUP matches=${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        _showErrorDialog(
          'Visitor Pass Not Found',
          'No visitor pass matching this code was found for your community.',
        );
        return;
      }

      if (snapshot.docs.length != 1) {
        _showErrorDialog(
          'Visitor Pass Error',
          'This visitor pass cannot be processed. Please contact the community administrator.',
        );
        return;
      }

      final doc = snapshot.docs.single;

      await _processVisitorDocument(doc.reference, doc.data());
    } on FirebaseException catch (e) {
      debugPrint('Manual visitor lookup Firebase error: ${e.code}');

      if (e.code == 'permission-denied') {
        _showErrorDialog(
          'Visitor Pass Not Valid',
          'This visitor pass cannot be used at your assigned community.',
        );
      } else {
        _showErrorDialog('Unable to Process Visitor', 'Please try again.');
      }
    } catch (e) {
      debugPrint('Manual visitor lookup error: $e');

      _showErrorDialog('Unable to Process Visitor', 'Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog(
    Map<String, dynamic> data, {
    required bool isCheckIn,
  }) {
    final visitorName = data['visitorName'] ?? 'Unknown';
    final phone = data['phoneNumber'] ?? 'N/A';
    final flatId = data['flatId'] ?? 'N/A';
    final hostName = data['hostName'] ?? 'Unknown';
    final purpose = data['purpose'] ?? 'No purpose';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF16A34A),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isCheckIn ? 'Entry Granted ✓' : 'Exit Recorded ✓',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCheckIn
                    ? 'Visitor has been checked in'
                    : 'Visitor has been checked out',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Visitor Name', visitorName),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.home, 'Flat Number', flatId),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.person_outline, 'Resident', hostName),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.phone, 'Phone', phone),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.description, 'Purpose', purpose),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCheckIn
                          ? 'Entry Time: ${_formatTime(DateTime.now())}'
                          : 'Exit Time: ${_formatTime(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      isScanning = true;
      isProcessing = false;
    });
    cameraController.start();
  }

  void _toggleFlash() {
    setState(() {
      flashOn = !flashOn;
    });
    cameraController.toggleTorch();
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(controller: cameraController, onDetect: _onDetect),
            if (isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.accentTeal),
                ),
              ),
            Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildScanningFrame(),
                const Spacer(),
                _buildBottomSection(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'QR Gate Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan visitor QR code',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                flashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _toggleFlash,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningFrame() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.accentTeal, width: 4),
                    left: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.accentTeal, width: 4),
                    right: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.accentTeal, width: 4),
                    left: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.accentTeal, width: 4),
                    right: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManualEntryDialog() async {
    if (isProcessing) return;

    setState(() {
      isScanning = false;
    });

    await cameraController.stop();

    if (!mounted) return;

    final controller = TextEditingController();

    try {
      final enteredCode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.cardWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.keyboard_alt_outlined, color: AppColors.primaryTeal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manual Visitor Entry',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Visitor code / pass ID',
                hintText: 'Enter visitor code',
                prefixIcon: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.primaryTeal,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryTeal,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) {
                final code = value.trim();

                if (code.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(code);
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final code = controller.text.trim();

                  if (code.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(code);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (enteredCode == null || enteredCode.trim().isEmpty) {
        _resetScanner();
        return;
      }

      await _processManualVisitorCode(enteredCode.trim());
    } catch (e) {
      debugPrint('Manual visitor entry error: $e');

      if (!mounted) return;

      _showErrorDialog('Unable to Process Visitor', 'Please try again.');
    } finally {
      controller.dispose();
    }
  }

  String? _extractVisitorIdFromQr(String rawValue) {
    final value = rawValue.trim();

    if (value.isEmpty) {
      return null;
    }

    // Current Hominode Resident QR format:
    // JSON containing visitorId and visitor details.
    try {
      final decoded = jsonDecode(value);

      if (decoded is Map<String, dynamic>) {
        final visitorId = decoded['visitorId']?.toString().trim();

        if (visitorId != null && visitorId.isNotEmpty) {
          return visitorId;
        }
      }
    } catch (_) {
      // Backward compatibility:
      // old/simple QR may contain only the visitor document ID.
    }

    // Plain visitor ID fallback.
    return value;
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Align QR code within the frame',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showManualEntryDialog,
              icon: const Icon(Icons.keyboard, color: Colors.white),
              label: const Text(
                'Manual Entry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
