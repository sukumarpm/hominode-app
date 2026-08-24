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

class _EditGateModalState extends State<EditGateModal> {
  final _formKey = GlobalKey<FormState>();
  final GateService _gateService = GateService();
  late String _gateName;
  late String _gateType;
  late String _workingStatus;
  late String _shiftTime;
  bool _isLoading = false;
  
  final List<String> _gateTypes = ['Main Gate', 'Side Gate', 'Back Gate', 'Parking Gate', 'Service Gate', 'Emergency Gate', 'Pedestrian Gate', 'Vehicle Gate'];
  final List<String> _workingStatuses = ['Active', 'Inactive', 'Maintenance', 'Under Repair'];
  final List<String> _shiftTimes = ['Full Day (24 Hours)', 'Morning (6 AM - 2 PM)', 'Afternoon (2 PM - 10 PM)', 'Night (10 PM - 6 AM)', 'Day Shift (6 AM - 6 PM)', 'Night Shift (6 PM - 6 AM)'];
  
  @override
  void initState() {
    super.initState();
    _gateName = widget.gate.gateName;
    _gateType = widget.gate.gateType;
    _workingStatus = widget.gate.workingStatus;
    _shiftTime = widget.gate.shiftTime ?? 'Full Day (24 Hours)';
  }
  
  Future<void> _handleUpdateGate() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _isLoading = true; });
    try {
      final success = await _gateService.updateGate(gateId: widget.gate.id, gateName: _gateName, gateType: _gateType, workingStatus: _workingStatus, shiftTime: _shiftTime);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place updated successfully'), backgroundColor: Color(0xFF10B981)));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update place'), backgroundColor: Color(0xFFEF4444)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_location_alt, color: Color(0xFF2563EB), size: 20)),
        const SizedBox(width: 12),
        const Expanded(child: Text('Edit Place', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111111)))),
        InkWell(onTap: () => Navigator.pop(context), borderRadius: BorderRadius.circular(20), child: Container(width: 40, height: 40, alignment: Alignment.center, child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20))),
      ])),
      const Divider(height: 1),
      Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Place Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
        const SizedBox(height: 8),
        TextFormField(initialValue: _gateName, decoration: InputDecoration(hintText: 'e.g., Main Entrance Gate', hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), validator: (value) { if (value == null || value.trim().isEmpty) return 'Please enter place name'; return null; }, onSaved: (value) => _gateName = value!.trim()),
        const SizedBox(height: 16),
        const Text('Place Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: _gateType, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), items: _gateTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (value) { setState(() { _gateType = value!; }); }),
        const SizedBox(height: 16),
        const Text('Working Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: _workingStatus, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), items: _workingStatuses.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(), onChanged: (value) { setState(() { _workingStatus = value!; }); }),
        const SizedBox(height: 16),
        const Text('Shift Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: _shiftTime, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), items: _shiftTimes.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(), onChanged: (value) { setState(() { _shiftTime = value!; }); }),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6B7280), side: const BorderSide(color: Color(0xFFE5E7EB), width: 1), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _handleUpdateGate, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: const Color(0xFF93C5FD)), child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Update Place', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
        ]),
      ]))))
    ]);
  }
}
