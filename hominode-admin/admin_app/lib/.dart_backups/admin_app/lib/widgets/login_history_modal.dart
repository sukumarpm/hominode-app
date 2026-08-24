import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LoginHistoryModal extends StatelessWidget {
  const LoginHistoryModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildFilterSection(),
                const SizedBox(height: 20),
                ..._buildLoginHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.history,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'Recent login activity and sessions',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Color(0xFF6B7280), size: 20),
          const SizedBox(width: 8),
          const Text(
            'Last 30 days',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '15 Sessions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLoginHistory() {
    final loginSessions = [
      {
        'device': 'Windows PC',
        'location': 'Mumbai, India',
        'ip': '192.168.1.100',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'status': 'Active',
        'browser': 'Chrome 120.0',
      },
      {
        'device': 'Android Phone',
        'location': 'Mumbai, India',
        'ip': '192.168.1.101',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'status': 'Ended',
        'browser': 'Mobile App',
      },
      {
        'device': 'iPhone',
        'location': 'Delhi, India',
        'ip': '203.192.12.45',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'status': 'Ended',
        'browser': 'Safari 17.0',
      },
      {
        'device': 'MacBook Pro',
        'location': 'Bangalore, India',
        'ip': '203.192.12.67',
        'time': DateTime.now().subtract(const Duration(days: 2)),
        'status': 'Ended',
        'browser': 'Chrome 119.0',
      },
      {
        'device': 'Windows PC',
        'location': 'Mumbai, India',
        'ip': '192.168.1.100',
        'time': DateTime.now().subtract(const Duration(days: 3)),
        'status': 'Ended',
        'browser': 'Edge 120.0',
      },
    ];

    return loginSessions.map((session) => _buildLoginItem(session)).toList();
  }

  Widget _buildLoginItem(Map<String, dynamic> session) {
    final isActive = session['status'] == 'Active';
    final deviceIcon = _getDeviceIcon(session['device']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  deviceIcon,
                  color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          session['device'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive 
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            session['status'],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session['browser'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                TextButton(
                  onPressed: () {
                    // End session functionality
                  },
                  child: const Text(
                    'End Session',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                session['location'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.public, size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                session['ip'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(session['time']),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String device) {
    if (device.contains('Phone') || device.contains('Android')) {
      return Icons.smartphone;
    } else if (device.contains('iPhone')) {
      return Icons.phone_iphone;
    } else if (device.contains('Mac')) {
      return Icons.laptop_mac;
    } else {
      return Icons.computer;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(time);
    }
  }
}