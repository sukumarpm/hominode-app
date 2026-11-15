import 'package:flutter/material.dart';

import '../services/listing_firestore_service.dart';

/// Keeps confirmation visible until the existing deletion service confirms it.
class MarketplaceDeleteListingDialog extends StatefulWidget {
  const MarketplaceDeleteListingDialog({super.key, required this.onDelete});

  final Future<ServiceResult> Function() onDelete;

  @override
  State<MarketplaceDeleteListingDialog> createState() =>
      _MarketplaceDeleteListingDialogState();
}

class _MarketplaceDeleteListingDialogState
    extends State<MarketplaceDeleteListingDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final result = await widget.onDelete();
      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _deleting = false;
        _error =
            result.message ?? 'Unable to remove the listing. Please retry.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error =
            'Unable to remove the listing. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      title: const Text('Delete Product'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Are you sure you want to delete this product?'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _deleting ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: _deleting
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Deleting…'),
                  ],
                )
              : const Text('Delete'),
        ),
      ],
    ),
  );
}
