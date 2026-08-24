import 'package:flutter/material.dart';
import '../services/gate_service.dart';

class EditGateModal extends StatefulWidget {
  final GateModel gate;
  const EditGateModal({super.key, required this.gate});
  static Future<void> show(BuildContext context, GateModel gate) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.92 > 600 ? 600 : MediaQuery.of(context).size.width * 0.92,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 8,
              child: EditGateModal(gate: gate),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
  }
  @override
  State<EditGateModal> createState() => _EditGateModalState();
}
