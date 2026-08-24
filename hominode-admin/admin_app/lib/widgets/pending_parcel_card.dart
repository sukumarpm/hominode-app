import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/parcel_entry.dart';

// ============================================================================
// PENDING PARCEL CARD WIDGET
// ============================================================================
// Card component for displaying pending parcel information

class PendingParcelCard extends StatelessWidget {
  final ParcelEntry parcel;
  final VoidCallback onMarkAsCollected;
  final VoidCallback onRemind;

  const PendingParcelCard({
    super.key,
    required this.parcel,
    required this.onMarkAsCollected,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = parcel.isOverdue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Profile + Name + Badge
            Row(
              children: [
                // Profile Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? const Color(0xFFFFE5E5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: isOverdue
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? const Color(0xFFFFE5E5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOverdue ? 'OVERDUE' : 'Pending',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOverdue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Received Time
            Text(
              'Received: ${parcel.formattedReceivedTime}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 12),

            // Divider
            Container(height: 1, color: const Color(0xFFE5E7EB)),

            const SizedBox(height: 12),

            // Details
            _buildDetailRow('Courier :', parcel.courier),
            if (parcel.trackingId.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Tracking :', parcel.trackingId),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Remind Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onRemind();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF0E4778)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Remind',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Collected Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onMarkAsCollected();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Collected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
