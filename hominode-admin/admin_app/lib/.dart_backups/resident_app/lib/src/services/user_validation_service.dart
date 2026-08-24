// lib/src/services/user_validation_service.dart
// User Validation Service - Validates user access to flat-based data

import 'package:flutter/material.dart';
import 'user_data_service.dart';

/// User Validation Service
/// Validates user access to flat-based data (Community Wall, Marketplace, Messages)
class UserValidationService {
  // Singleton pattern
  static final UserValidationService instance = UserValidationService._internal();
  factory UserValidationService() => instance;
  UserValidationService._internal();

  final _userDataService = UserDataService();

  /// Check if user has flat assigned
  Future<bool> hasFlat() async {
    try {
      final userData = await _userDataService.getCurrentUserData();
      final flatId = userData?['flatId'];
      final hasFlat = flatId != null && flatId.toString().isNotEmpty;
      
      print('🔍 User flat check: ${hasFlat ? "Has flat ($flatId)" : "No flat assigned"}');
      return hasFlat;
    } catch (e) {
      print('❌ Error checking flat: $e');
      return false;
    }
  }

  /// Check if user is active
  Future<bool> isActive() async {
    try {
      final userData = await _userDataService.getCurrentUserData();
      final status = userData?['status'];
      final isActive = status == 'active';
      
      print('🔍 User status check: $status');
      return isActive;
    } catch (e) {
      print('❌ Error checking status: $e');
      return false;
    }
  }

  /// Check if user can access flat-based data
  /// Returns true only if user has flat AND is active
  Future<bool> canAccessFlatData() async {
    final hasFlat = await this.hasFlat();
    final isActive = await this.isActive();
    final canAccess = hasFlat && isActive;
    
    print('🔍 Flat data access check: ${canAccess ? "ALLOWED" : "DENIED"}');
    return canAccess;
  }

  /// Get user's flat ID
  Future<String?> getUserFlatId() async {
    try {
      final userData = await _userDataService.getCurrentUserData();
      final flatId = userData?['flatId'];
      
      print('🔍 User flat ID: ${flatId ?? "None"}');
      return flatId?.toString();
    } catch (e) {
      print('❌ Error getting flat ID: $e');
      return null;
    }
  }

  /// Show error message if user cannot access data
  void showAccessDeniedMessage(BuildContext context, {String? reason}) {
    final message = reason ?? 'Access denied. Please contact admin to assign you to a flat.';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info message about flat-based access
  void showFlatAccessInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flat-Based Access'),
        content: const Text(
          'You can only see posts and listings from members of your flat. '
          'This ensures privacy and relevance for your community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Validate access and show error if denied
  /// Returns true if access is allowed, false otherwise
  Future<bool> validateAndShowError(BuildContext context) async {
    final canAccess = await canAccessFlatData();
    
    if (!canAccess) {
      final hasFlat = await this.hasFlat();
      final isActive = await this.isActive();
      
      String reason;
      if (!hasFlat) {
        reason = 'You must be assigned to a flat to access this feature. Please contact your admin.';
      } else if (!isActive) {
        reason = 'Your account is inactive. Please contact your admin.';
      } else {
        reason = 'Access denied. Please contact your admin.';
      }
      
      showAccessDeniedMessage(context, reason: reason);
    }
    
    return canAccess;
  }
}
