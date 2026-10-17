import 'package:flutter/material.dart';

class CashPaymentInfoCard extends StatelessWidget {
  const CashPaymentInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082F73).withValues(alpha: .06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
