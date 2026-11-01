import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Account deletion is a verified, manually reviewed request, not an immediate
/// Firebase Auth or Firestore deletion.
const accountDeletionRequestUrl = 'https://hominode.com/account-deletion';

Future<void> openAccountDeletionRequest(BuildContext context) async {
  try {
    final opened = await launchUrl(
      Uri.parse(accountDeletionRequestUrl),
      mode: LaunchMode.externalApplication,
    );
    if (opened) return;
  } catch (_) {
    // The page is still available at the public URL shown below.
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the request form. Visit hominode.com/account-deletion.'),
      ),
    );
  }
}
