import 'package:flutter/material.dart';
import '../models/visitor_verification_receipt.dart';
import '../models/visitor_model.dart';

class VisitorVerificationReceiptDialog extends StatelessWidget {
  const VisitorVerificationReceiptDialog({
    super.key,
    required this.receipt,
    required this.onDone,
  });
  final VisitorVerificationReceipt receipt;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(receipt.title),
    content: SingleChildScrollView(
      child: Text(
        '${receipt.message}\n\n'
        'Pet declared on receipt: ${VisitorModel.describePetDeclaration(receipt.data['bringingPet'])}',
      ),
    ),
    actions: [TextButton(onPressed: onDone, child: const Text('Done'))],
  );
}
