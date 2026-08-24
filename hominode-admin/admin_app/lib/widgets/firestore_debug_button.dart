import 'package:flutter/material.dart';
import '../services/firestore_test_service.dart';
import '../services/user_service.dart';

/// Debug button to test Firestore connectivity
class FirestoreDebugButton extends StatelessWidget {
  const FirestoreDebugButton({super.key});

  Future<void> _runTests(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Running Firestore tests...\nCheck console for results'),
          ],
        ),
      ),
    );

    try {
      final testService = FirestoreTestService();
      await testService.runAllTests();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tests completed! Check console for results.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tests failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _testCreateUser(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating test user...\nCheck console for details'),
          ],
        ),
      ),
    );

    try {
      final userService = UserService();
      final userId = await userService.createUser(
        name: 'Debug Test User',
        phone: '9999999999',
        password: 'TestPass123',
        email: 'debug@test.com',
        familyMembers: 1,
      );
      
      print('\n✅ Test user created with ID: $userId');
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test user created! ID: $userId\nCheck console for details.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('\n❌ Failed to create test user: $e');
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _testFetchUsers(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching users...\nCheck console for details'),
          ],
        ),
      ),
    );

    try {
      final userService = UserService();
      final users = await userService.getAvailableUsers().first;
      
      print('\n✅ Fetched ${users.length} available users');
      for (var user in users) {
        print('   - ${user.name} (${user.phone})');
      }
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${users.length} available users\nCheck console for details.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('\n❌ Failed to fetch users: $e');
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showDebugMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firestore Debug Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _runTests(context);
              },
              icon: const Icon(Icons.science),
              label: const Text('Run All Tests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _testCreateUser(context);
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Test Create User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _testFetchUsers(context);
              },
              icon: const Icon(Icons.people),
              label: const Text('Test Fetch Users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showDebugMenu(context),
      backgroundColor: Colors.red,
      child: const Icon(Icons.bug_report, color: Colors.white),
    );
  }
}
