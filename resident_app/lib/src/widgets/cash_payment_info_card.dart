import 'package:flutter/material.dart';

class CashPaymentInfoCard extends StatelessWidget {
  const CashPaymentInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: Color(0xFF0E4778)),
              SizedBox(width: 8),
              Text('Cash', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Pay cash at your community office. An Admin records and confirms it; the resident app does not mark cash bills paid.',
          ),
        ],
      ),
    );
  }
}
