# Security App - Visitor Management Complete Guide

## Overview
Complete implementation guide for the Visitor Management screen in the Security Guard App. This screen allows security personnel to approve visitor requests, track active visitors, and view visitor history.

---

## Screen Structure

### File: `lib/security_visitor_management_screen.dart`

### Purpose
- Approve/reject pending visitor requests
- Track visitors currently inside the property
- View completed visitor records with duration
- Search and filter visitors
- Quick access to QR scanner

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│ StandardHeader: "Visitor Management"                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ [🏠] Visitor Management                    [QR Scanner 📷] │
│      Approve pending requests                               │
│                                                             │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐                       │
│ │   [⏳]  │ │   [📅]  │ │   [⏱️]  │                       │
│ │    5    │ │   12    │ │    -    │                       │
│ │ Pending │ │ Today's │ │   Avg   │                       │
│ │Awaiting │ │ Total   │ │Response │                       │
│ └─────────┘ └─────────┘ └─────────┘                       │
│                                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ 🔍 Search visitors...                          [X]  │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │  Pending  │  Active  │  History  │                   │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ [👤] John Doe                                       │   │
│ │      +91 98765 43210                                │   │
│ │                                                     │   │
│ │      [🏠] A-101  •  [👤] Amit Kumar                │   │
│ │      [📝] Purpose: Personal Visit                   │   │
│ │      [🕐] Expected: 10:30 AM                        │   │
│ │                                                     │   │
│ │      [✓ Approve]  [✗ Reject]                       │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                    [Scan QR] FAB
```

---

## Complete Implementation

### 1. Main Screen Widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/standard_header.dart';
import 'security_qr_scanner_screen.dart';
import 'services/visitor_service.dart';

class SecurityVisitorManagementScreen extends StatefulWidget {
  final int initialTab;
  
  const SecurityVisitorManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<SecurityVisitorManagementScreen> createState() => 
      _SecurityVisitorManagementScreenState();
}

class _SecurityVisitorManagementScreenState 
    extends State<SecurityVisitorManagementScreen>
    with TickerProviderStateMixin {
  
  // Tab management
  int _currentTab = 0;
  late PageController _pageController;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Services
  final VisitorService _visitorService = VisitorService();
  
  // Real-time counts
  int _pendingCount = 0;
  int _activeCount = 0;
  int _historyCount = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _pageController = PageController(initialPage: _currentTab);
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Visitor Management'),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Page Header
                _buildPageHeader(),
                
                const SizedBox(height: 16),
                
                // Summary Metrics
                _buildSummaryMetrics(),
                
                const SizedBox(height: 20),
                
                // Search Bar
                _buildSearchBar(),
                
                const SizedBox(height: 20),
                
                // Tab Switcher
                _buildTabSwitcher(),
                
                const SizedBox(height: 16),
                
                // Content Area
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentTab = index);
                      HapticFeedback.lightImpact();
                    },
                    children: [
                      _buildPendingTab(),
                      _buildActiveTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onQRScannerTap,
        backgroundColor: const Color(0xFF2563EB),
        elevation: 4,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
        label: const Text(
          'Scan QR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Page Header
  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visitor Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSubtitleForTab(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _onQRScannerTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitleForTab() {
    switch (_currentTab) {
      case 0:
        return 'Approve pending visitor requests';
      case 1:
        return 'Track active visitors inside';
      case 2:
        return 'View completed visitor records';
      default:
        return 'Manage visitor entries';
    }
  }

  // Summary Metrics
  Widget _buildSummaryMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: _getStatIcon(0),
              iconColor: _getStatColor(0),
              iconBg: _getStatColor(0).withOpacity(0.1),
              value: _getStatValue(0),
              label: _getStatTitle(0),
              subtitle: _getStatSubtitle(0),
              subtitleColor: _getStatColor(0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: _getStatIcon(1),
              iconColor: _getStatColor(1),
              iconBg: _getStatColor(1).withOpacity(0.1),
              value: _getStatValue(1),
              label: _getStatTitle(1),
              subtitle: _getStatSubtitle(1),
              subtitleColor: _getStatColor(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: _getStatIcon(2),
              iconColor: _getStatColor(2),
              iconBg: _getStatColor(2).withOpacity(0.1),
              value: _getStatValue(2),
              label: _getStatTitle(2),
              subtitle: _getStatSubtitle(2),
              subtitleColor: _getStatColor(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Dynamic stat data
  String _getStatTitle(int index) {
    switch (_currentTab) {
      case 0:
        return ['Pending', 'Today\'s Total', 'Avg. Response'][index];
      case 1:
        return ['Active', 'Today\'s Total', 'Avg. Duration'][index];
      case 2:
        return ['Today\'s Visits', 'Weekly Total', 'Avg. Duration'][index];
      default:
        return '';
    }
  }

  String _getStatValue(int index) {
    switch (_currentTab) {
      case 0:
        return [_pendingCount.toString(), _pendingCount.toString(), '-'][index];
      case 1:
        return [_activeCount.toString(), _activeCount.toString(), '-'][index];
      case 2:
        return [_historyCount.toString(), _historyCount.toString(), '-'][index];
      default:
        return '0';
    }
  }

  String _getStatSubtitle(int index) {
    switch (_currentTab) {
      case 0:
        return ['Awaiting approval', 'Requests received', 'Response time'][index];
      case 1:
        return ['Currently inside', 'Visitors today', 'Stay duration'][index];
      case 2:
        return ['Completed visits', 'This week', 'Visit duration'][index];
      default:
        return '';
    }
  }

  IconData _getStatIcon(int index) {
    switch (_currentTab) {
      case 0:
        return [Icons.pending_actions, Icons.today, Icons.timer][index];
      case 1:
        return [Icons.people, Icons.today, Icons.schedule][index];
      case 2:
        return [Icons.history, Icons.date_range, Icons.schedule][index];
      default:
        return Icons.info;
    }
  }

  Color _getStatColor(int index) {
    switch (_currentTab) {
      case 0:
        return [
          const Color(0xFFF59E0B),
          const Color(0xFF2563EB),
          const Color(0xFF8B5CF6)
        ][index];
      case 1:
        return [
          const Color(0xFF16A34A),
          const Color(0xFF2563EB),
          const Color(0xFF8B5CF6)
        ][index];
      case 2:
        return [
          const Color(0xFF8B5CF6),
          const Color(0xFF2563EB),
          const Color(0xFF16A34A)
        ][index];
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Search Bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search visitors...',
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Tab Switcher
  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: _buildTabButton('Pending', 0)),
            Expanded(child: _buildTabButton('Active', 1)),
            Expanded(child: _buildTabButton('History', 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF111827)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  void _onTabChanged(int index) async {
    if (index == _currentTab) return;
    
    HapticFeedback.selectionClick();
    
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    setState(() => _currentTab = index);
  }

  // Tab Content Builders
  Widget _buildPendingTab() {
    return StreamBuilder<List<VisitorModel>>(
      stream: _visitorService.getPendingVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final visitors = snapshot.data ?? [];
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pendingCount != visitors.length) {
            setState(() => _pendingCount = visitors.length);
          }
        });
        
        final filteredVisitors = _getFilteredVisitors(visitors);
        
        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions,
            title: _searchQuery.isNotEmpty
                ? 'No visitors found'
                : 'No Pending Requests',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'All requests have been processed',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredVisitors.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPendingVisitorCard(filteredVisitors[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveTab() {
    return StreamBuilder<List<VisitorModel>>(
      stream: _visitorService.getActiveVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final visitors = snapshot.data ?? [];
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _activeCount != visitors.length) {
            setState(() => _activeCount = visitors.length);
          }
        });
        
        final filteredVisitors = _getFilteredVisitors(visitors);
        
        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people,
            title: _searchQuery.isNotEmpty
                ? 'No visitors found'
                : 'No Active Visitors',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'No visitors are currently inside',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredVisitors.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildActiveVisitorCard(filteredVisitors[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<VisitorModel>>(
      stream: _visitorService.getHistoryVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final visitors = snapshot.data ?? [];
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _historyCount != visitors.length) {
            setState(() => _historyCount = visitors.length);
          }
        });
        
        final filteredVisitors = _getFilteredVisitors(visitors);
        
        if (filteredVisitors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: _searchQuery.isNotEmpty
                ? 'No visitors found'
                : 'No History Records',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Completed visitor records will appear here',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredVisitors.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildHistoryVisitorCard(filteredVisitors[index]),
            );
          },
        );
      },
    );
  }

  // Filter visitors
  List<VisitorModel> _getFilteredVisitors(List<VisitorModel> visitors) {
    if (_searchQuery.isEmpty) return visitors;
    return visitors.where((visitor) {
      return visitor.visitorName.toLowerCase().contains(_searchQuery) ||
             visitor.residentName.toLowerCase().contains(_searchQuery) ||
             visitor.flatLabel.toLowerCase().contains(_searchQuery) ||
             visitor.purpose.toLowerCase().contains(_searchQuery) ||
             visitor.phone.contains(_searchQuery);
    }).toList();
  }

  // Empty state
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading visitors',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Visitor Cards - Continued in next section...
```

Due to length, I'll continue with the visitor cards and actions in the next file. Let me create that now.


  // Pending Visitor Card
  Widget _buildPendingVisitorCard(VisitorModel visitor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visitor.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Flat and Resident Info
            Row(
              children: [
                const Icon(
                  Icons.home_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  visitor.flatLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visitor.residentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Purpose
            Row(
              children: [
                const Icon(
                  Icons.description_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visitor.purpose,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            
            if (visitor.expectedTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expected: ${_formatTime(visitor.expectedTime!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _onApproveVisitor(
                      visitor.id,
                      visitor.visitorName,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _onRejectVisitor(
                      visitor.id,
                      visitor.visitorName,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  // Active Visitor Card
  Widget _buildActiveVisitorCard(VisitorModel visitor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visitor.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Flat and Resident Info
            Row(
              children: [
                const Icon(
                  Icons.home_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  visitor.flatLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visitor.residentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Purpose
            Row(
              children: [
                const Icon(
                  Icons.description_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visitor.purpose,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Entry Time Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF16A34A).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.login_rounded,
                    size: 16,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Entered at: ${visitor.checkInTime != null ? _formatTime(visitor.checkInTime!) : 'N/A'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Mark Exit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onMarkExit(
                  visitor.id,
                  visitor.visitorName,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Mark Exit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // History Visitor Card
  Widget _buildHistoryVisitorCard(VisitorModel visitor) {
    final duration = visitor.checkOutTime != null && visitor.checkInTime != null
        ? visitor.checkOutTime!.difference(visitor.checkInTime!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF6B7280),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visitor.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Flat and Resident Info
            Row(
              children: [
                const Icon(
                  Icons.home_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  visitor.flatLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visitor.residentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Time Badges
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Entry',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          visitor.checkInTime != null
                              ? _formatTime(visitor.checkInTime!)
                              : 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          visitor.checkOutTime != null
                              ? _formatTime(visitor.checkOutTime!)
                              : 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            if (duration != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9333EA).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Color(0xFF9333EA),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Duration: ${_formatDuration(duration)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9333EA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Action Handlers
  void _onApproveVisitor(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();
    
    try {
      await _visitorService.approveVisitor(visitorId);
      await _visitorService.checkInVisitor(visitorId);
      
      if (mounted) {
        _showSnackBar(
          '$visitorName approved and checked in',
          const Color(0xFF16A34A),
          Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to approve visitor: $e',
          const Color(0xFFEF4444),
          Icons.error,
        );
      }
    }
  }

  void _onRejectVisitor(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();
    
    try {
      await _visitorService.rejectVisitor(visitorId);
      
      if (mounted) {
        _showSnackBar(
          '$visitorName request rejected',
          const Color(0xFFEF4444),
          Icons.cancel,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to reject visitor: $e',
          const Color(0xFFEF4444),
          Icons.error,
        );
      }
    }
  }

  void _onMarkExit(String visitorId, String visitorName) async {
    HapticFeedback.mediumImpact();
    
    try {
      await _visitorService.checkOutVisitor(visitorId);
      
      if (mounted) {
        _showSnackBar(
          '$visitorName marked as exited',
          const Color(0xFF16A34A),
          Icons.logout,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to mark exit: $e',
          const Color(0xFFEF4444),
          Icons.error,
        );
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _onQRScannerTap() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityQrScannerScreen(),
      ),
    );
  }

  // Helper Methods
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
```

---

## Key Features

### 1. Real-Time Data Streaming
- Uses `StreamBuilder` for live updates
- Automatically updates when visitors are added/modified
- No manual refresh needed

### 2. Three Tabs
- **Pending**: Visitors awaiting approval
- **Active**: Visitors currently inside
- **History**: Completed visits with duration

### 3. Search Functionality
- Search by visitor name
- Search by resident name
- Search by flat number
- Search by phone number
- Search by purpose
- Real-time filtering

### 4. Action Buttons
- **Approve**: Approves and checks in visitor
- **Reject**: Rejects visitor request
- **Mark Exit**: Checks out active visitor

### 5. Visual Feedback
- Color-coded cards (yellow=pending, green=active, gray=history)
- Success/error snackbars
- Haptic feedback on actions
- Loading states
- Empty states

---

## Firestore Integration

### Queries Used

**Pending Visitors**:
```dart
.where('adminId', '==', adminId)
.where('isApproved', '==', false)
```

**Active Visitors**:
```dart
.where('adminId', '==', adminId)
.where('isApproved', '==', true)
.where('actualArrival', '!=', null)
.where('departure', '==', null)
```

**History Visitors**:
```dart
.where('adminId', '==', adminId)
.where('departure', '!=', null)
```

### Updates Performed

**Approve Visitor**:
```dart
{
  'isApproved': true,
  'approvedAt': FieldValue.serverTimestamp(),
  'actualArrival': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}
```

**Reject Visitor**:
```dart
{
  'isApproved': false,
  'rejectedAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}
```

**Mark Exit**:
```dart
{
  'departure': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}
```

---

## Testing Checklist

- [ ] Pending tab shows unapproved visitors
- [ ] Approve button works and moves visitor to Active
- [ ] Reject button works and removes visitor
- [ ] Active tab shows checked-in visitors
- [ ] Mark Exit button works and moves to History
- [ ] History tab shows completed visits with duration
- [ ] Search filters all tabs correctly
- [ ] Tab switching is smooth
- [ ] Real-time updates work
- [ ] Empty states display correctly
- [ ] Error handling works
- [ ] QR scanner button navigates correctly

---

## Next Steps

1. Copy this implementation to Security App
2. Update imports to match Security App structure
3. Test with real Firestore data
4. Verify role-based access control
5. Test on physical device

---

**Status**: Complete & Ready for Implementation  
**Last Updated**: March 6, 2026
