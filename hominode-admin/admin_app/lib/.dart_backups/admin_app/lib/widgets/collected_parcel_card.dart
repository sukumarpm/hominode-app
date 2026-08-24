import 'package:flutter/material.dart';
import '../models/parcel_entry.dart';

// ============================================================================
// COLLECTED PARCEL CARD WIDGET
// ============================================================================
// Card component for displaying collected parcel information

class CollectedParcelCard extends StatelessWidget {
  final ParcelEntry parcel;

  const CollectedParcelCard({
    super.key,
    required this.parcel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Profile Icon
            Row(
              children: [
                // Profile Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name + Unit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.residentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unit ${parcel.unit}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'COLLECTED',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Collected Time
            Text(
              'Collected: ${parcel.formattedCollectedTime}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Divider
            Container(
              height: 1,
              color: const Color(0xFFE5E7EB),
            ),
            
            const SizedBox(height: 12),
            
            // Parcel Details
            _buildDetailRow('Courier :', parcel.courier),
            const SizedBox(height: 8),
            _buildDetailRow('Received :', parcel.formattedReceivedTime),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}