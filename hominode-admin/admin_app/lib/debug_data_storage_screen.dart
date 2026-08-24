import 'package:flutter/material.dart';
import 'services/data_storage_diagnostic.dart';

/// Debug screen to test and verify data storage
class DebugDataStorageScreen extends StatefulWidget {
  const DebugDataStorageScreen({super.key});

  @override
  State<DebugDataStorageScreen> createState() => _DebugDataStorageScreenState();
}

class _DebugDataStorageScreenState extends State<DebugDataStorageScreen> {
  final DataStorageDiagnostic _diagnostic = DataStorageDiagnostic();
  String _output = 'Tap "Run Diagnostic" to start...';
  bool _isRunning = false;

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
      _output = 'Running diagnostic...\n';
    });

    try {
      await _diagnostic.runCompleteDiagnostic();
      setState(() {
        _output = 'Diagnostic complete! Check console for details.';
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Storage Diagnostic'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data Storage Diagnostic Tool',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This tool will:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('1. Check your admin profile'),
            const Text('2. Create a test resident'),
            const Text('3. Verify all data is stored correctly'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isRunning ? null : _runDiagnostic,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isRunning
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Run Diagnostic',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Check the console/terminal for detailed output',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
