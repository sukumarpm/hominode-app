import 'package:flutter/material.dart';
import '../models/family_member.dart';

class FamilyCard extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const FamilyCard({
    super.key,
    required this.member,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.relation} • ${member.age} years',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
