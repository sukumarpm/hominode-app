import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/standard_header.dart';

class AboutHominodeScreen extends StatelessWidget {
  const AboutHominodeScreen({super.key});

  static final website = Uri.parse('https://marantrix.com');
  static final support = Uri.parse('mailto:hominodecare@gmail.com');

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Report unavailable browser/email apps without leaving the page.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this link. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    appBar: const StandardAppBar(title: 'About Hominode', showBackButton: true),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOMINODE', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Smart place. Better lives.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          const Text(
            'Hominode helps residential communities manage visitors, security, residents, billing, facilities, announcements and everyday community operations.',
          ),
          const SizedBox(height: 24),
          const Text('Developed by Marantrix.'),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _openLink(context, website),
            icon: const Icon(Icons.language),
            label: const Text('https://marantrix.com'),
          ),
          TextButton.icon(
            onPressed: () => _openLink(context, support),
            icon: const Icon(Icons.email_outlined),
            label: const Text('hominodecare@gmail.com'),
          ),
        ],
      ),
    ),
  );
}
