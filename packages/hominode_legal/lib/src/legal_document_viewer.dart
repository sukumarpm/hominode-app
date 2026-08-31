import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

abstract final class HominodeLegalDocuments {
  static const privacyPolicyAsset =
      'packages/hominode_legal/assets/legal/HOMINODE_Privacy_Policy_v1.0.pdf';
  static const termsAndConditionsAsset =
      'packages/hominode_legal/assets/legal/HOMINODE_Terms_and_Conditions_v1.0.pdf';
}

class HominodeLegalDocumentViewer extends StatefulWidget {
  const HominodeLegalDocumentViewer({
    required this.title,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String assetPath;

  @override
  State<HominodeLegalDocumentViewer> createState() =>
      _HominodeLegalDocumentViewerState();
}

class _HominodeLegalDocumentViewerState
    extends State<HominodeLegalDocumentViewer> {
  late final Future<Uint8List> _document = _loadDocument();

  Future<Uint8List> _loadDocument() async {
    final data = await rootBundle.load(widget.assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: PdfPreview(
      build: (_) => _document,
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      dynamicLayout: false,
      useActions: false,
      pdfFileName: widget.assetPath.split('/').last,
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onError: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This legal document could not be opened. Please try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
