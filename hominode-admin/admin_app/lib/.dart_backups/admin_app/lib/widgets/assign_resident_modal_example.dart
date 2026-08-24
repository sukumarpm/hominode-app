import 'package:flutter/material.dart';
import 'assign_resident_modal.dart';

/// Example usage of AssignResidentModal
/// Demonstrates different scenarios and API integration patterns
class AssignResidentModalExample extends StatelessWidget {
  const AssignResidentModalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Resident Modal Examples'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildExampleButton(
                context,
                'Basic Example (Mock Data)',
                () => _showBasicExample(context),
              ),
              const SizedBox(height: 16),
              _buildExampleButton(
                context,
                'With Loading State',
                () => _showLoadingExample(context),
              ),
              const SizedBox(height: 16),
              _buildExampleButton(
                context,
                'Empty State (No Residents)',
                () => _showEmptyExample(context),
              ),
              const SizedBox(height: 16),
              _buildExampleButton(
                context,
                'Error State (Load Failure)',
                () => _showErrorExample(context),
              ),
              const SizedBox(height: 16),
              _buildExampleButton(
                context,
                'Assignment Success',
                () => _showSuccessExample(context),
              ),
              const SizedBox(height: 16),
              _buildExampleButton(
                context,
                'Assignment Failure',
                () => _showAssignmentErrorExample(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExampleButton(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Example 1: Basic with mock data
  void _showBasicExample(BuildContext context) {
    AssignResidentModal.show(
      context,
      flatId: 'A101',
      flatLabel: 'A101',
      // Uses default mock data (no loadResidents callback)
      onAssign: (request) async {
        await Future.delayed(const Duration(milliseconds: 800));
        print('Assigned ${request.residentId} to ${request.flatId}');
      },
    );
  }

  // Example 2: With loading state
  void _showLoadingExample(BuildContext context) {
    AssignResidentModal.show(
      context,
      flatId: 'B205',
      flatLabel: 'B205',
      loadResidents: () async {
        // Simulate slow API call
        await Future.delayed(const Duration(seconds: 2));
        return [
          ResidentSummary(
            id: '1',
            name: 'John Doe',
            uniqueId: 'RES-001',
            status: ResidentStatus.available,
          ),
          ResidentSummary(
            id: '2',
            name: 'Jane Smith',
            uniqueId: 'RES-002',
            status: ResidentStatus.assigned,
            flatLabel: 'B205',
          ),
          ResidentSummary(
            id: '3',
            name: 'Robert Johnson',
            uniqueId: 'RES-003',
            status: ResidentStatus.available,
          ),
          ResidentSummary(
            id: '4',
            name: 'Emily Davis',
            uniqueId: 'RES-004',
            status: ResidentStatus.available,
          ),
        ];
      },
      onAssign: (request) async {
        await Future.delayed(const Duration(milliseconds: 800));
      },
    );
  }

  // Example 3: Empty state
  void _showEmptyExample(BuildContext context) {
    AssignResidentModal.show(
      context,
      flatId: 'C308',
      flatLabel: 'C308',
      loadResidents: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        return []; // No residents
      },
      onAssign: (request) async {
        await Future.delayed(const Duration(milliseconds: 800));
      },
    );
  }

  // Example 4: Load error
  void _showErrorExample(BuildContext context) {
    AssignResidentModal.show(
      context,
      flatId: 'D412',
      flatLabel: 'D412',
      loadResidents: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        throw Exception('Failed to load residents from server');
      },
      onAssign: (request) async {
        await Future.delayed(const Duration(milliseconds: 800));
      },
    );
  }

  // Example 5: Successful assignment
  void _showSuccessExample(BuildContext context) {
    AssignResidentModal.show(
      context,
      flatId: 'E501',
      flatLabel: 'E501',
      loadResidents: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        return [
          ResidentSummary(
            id: '1',
            name: 'Alice Williams',
            uniqueId: 'RES-010',
            status: ResidentStatus.available,
          ),
          ResidentSummary(
            id: '2',
            name: 'Bob Brown',
            uniqueId: 'RES-011',
            status: ResidentStatus.available,
          ),
        ];
      },
      onAssign: (request) async {
        // Simulate API call
        await Future.delayed(const Duration(milliseconds: 1000));
        // Success - modal will close and show success message
      },
    );
  }

  // Example 6: Assignment error
  void _showAssignmentErrorExample(BuildContext context) {
    AssignResidentModal.show(
      context,
      flatId: 'F602',
      flatLabel: 'F602',
      loadResidents: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        return [
          ResidentSummary(
            id: '1',
            name: 'Charlie Wilson',
            uniqueId: 'RES-020',
            status: ResidentStatus.available,
          ),
          ResidentSummary(
            id: '2',
            name: 'Diana Martinez',
            uniqueId: 'RES-021',
            status: ResidentStatus.assigned,
            flatLabel: 'D412',
          ),
        ];
      },
      onAssign: (request) async {
        await Future.delayed(const Duration(milliseconds: 800));
        throw Exception('Failed to assign resident - flat already occupied');
      },
    );
  }
}

// Example with API integration pattern
class AssignResidentApiExample {
  // Example API service
  static Future<List<ResidentSummary>> loadResidentsFromApi() async {
    // TODO: Replace with actual API call
    // final response = await http.get('https://api.example.com/residents');
    // return (response.data as List)
    //     .map((json) => ResidentSummary.fromJson(json))
    //     .toList();

    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      ResidentSummary(
        id: '1',
        name: 'John Doe',
        uniqueId: 'RES-001',
        status: ResidentStatus.available,
      ),
      ResidentSummary(
        id: '2',
        name: 'Jane Smith',
        uniqueId: 'RES-002',
        status: ResidentStatus.assigned,
        flatLabel: 'B205',
      ),
      ResidentSummary(
        id: '3',
        name: 'Robert Johnson',
        uniqueId: 'RES-003',
        status: ResidentStatus.available,
      ),
    ];
  }

  static Future<void> assignResidentToFlat(
    AssignResidentRequest request,
  ) async {
    // TODO: Replace with actual API call
    // await http.post(
    //   'https://api.example.com/flats/${request.flatId}/assign',
    //   body: {
    //     'residentId': request.residentId,
    //     'ownershipType': request.ownershipType,
    //   },
    // );

    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 1000));
    print('Assigned resident ${request.residentId} to flat ${request.flatId}');
  }

  // Usage example
  static void showModal(BuildContext context, String flatId) {
    AssignResidentModal.show(
      context,
      flatId: flatId,
      flatLabel: flatId,
      loadResidents: loadResidentsFromApi,
      onAssign: assignResidentToFlat,
    );
  }
}
