import 'package:flutter/material.dart';
import 'services/flat_service.dart';
import 'widgets/flat_occupancy_grid_with_state.dart';

/// Demo page showing how to use the complete flat management system
/// 
/// This demonstrates:
/// 1. Initializing FlatService with mock data
/// 2. Opening the Flat Occupancy Grid modal
/// 3. All status flows working automatically
/// 
/// USAGE:
/// - Tap "Open Flat Grid" to see the grid
/// - Tap any flat tile to open appropriate modal
/// - All status changes update immediately in grid and list views
class FlatManagementDemo extends StatefulWidget {
  const FlatManagementDemo({super.key});

  @override
  State<FlatManagementDemo> createState() => _FlatManagementDemoState();
}

class _FlatManagementDemoState extends State<FlatManagementDemo> {
  late final FlatService _flatService;

  @override
  void initState() {
    super.initState();
    // Initialize the flat service (single source of truth)
    _flatService = FlatService();
    // Use real Firestore data instead of mock data
    // _flatService.initializeMockData(); // REMOVED - using real data
    
    // Listen to changes for status display
    _flatService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _flatService.removeListener(_onDataChanged);
    _flatService.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  void _openFlatGrid() {
    FlatOccupancyGridWithState.show(
      context,
      flatService: _flatService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _flatService.getStatusCounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flat Management System'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.apartment,
                size: 80,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(height: 24),
              const Text(
                'Flat Management System',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete flat occupancy tracking with real-time status updates',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Status Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Current Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusItem(
                          'Occupied',
                          counts['occupied'] ?? 0,
                          const Color(0xFF10B981),
                        ),
                        _buildStatusItem(
                          'Vacant',
                          counts['vacant'] ?? 0,
                          const Color(0xFF9CA3AF),
                        ),
                        _buildStatusItem(
                          'Maintenance',
                          counts['maintenance'] ?? 0,
                          const Color(0xFFFBBF24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${counts['total']} flats',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Open Grid Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _openFlatGrid,
                  icon: const Icon(Icons.grid_view, size: 24),
                  label: const Text(
                    'Open Flat Grid',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'How to use:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionItem('Tap any flat tile to view/edit details'),
                    _buildInstructionItem('Grey tiles = Vacant (can assign resident)'),
                    _buildInstructionItem('Green tiles = Occupied (can remove/change status)'),
                    _buildInstructionItem('Yellow tiles = Maintenance (can change status)'),
                    _buildInstructionItem('All changes update immediately in real-time'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1D4ED8),
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1D4ED8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
