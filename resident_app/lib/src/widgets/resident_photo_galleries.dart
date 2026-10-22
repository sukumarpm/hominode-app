import 'package:flutter/material.dart';
import '../services/apartment_images_service.dart';
import '../services/resident_private_images.dart';

/// Each scope retains a separate stream, selection, error and legacy label.
class ResidentPhotoGalleries extends StatelessWidget {
  const ResidentPhotoGalleries({super.key, required this.communityId});
  final String communityId;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in const {
          'COMMUNITY': 'Community photos',
          'BUILDING': 'Building photos',
          'UNIT': 'Apartment photos',
          'LEGACY': 'Legacy photos (read-only)',
        }.entries)
          _PhotoSection(
            key: ValueKey('$communityId/${entry.key}'),
            communityId: communityId,
            scope: entry.key,
            title: entry.value,
          ),
      ],
    ),
  );
}

class _PhotoSection extends StatefulWidget {
  const _PhotoSection({
    super.key,
    required this.communityId,
    required this.scope,
    required this.title,
  });
  final String communityId, scope, title;
  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  late final images = ApartmentImagesService().streamCommunityImages(
    widget.communityId,
    legacy: widget.scope == 'LEGACY',
    ownershipScope: widget.scope == 'LEGACY' ? 'COMMUNITY' : widget.scope,
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
      StreamBuilder<List<String>>(
        stream: images,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Photo access could not be verified. Please try again.',
              ),
            );
          if (!snapshot.hasData)
            return const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            );
          final photos = snapshot.data!;
          if (photos.isEmpty)
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No photos available.'),
            );
          return SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: photos.length,
              itemBuilder: (context, index) => Column(
                children: [
                  Expanded(
                    child: Image(
                      image: residentImageProvider(photos[index]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) =>
                          const Center(child: Text('Image unavailable.')),
                    ),
                  ),
                  Text('${index + 1} / ${photos.length}'),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
    ],
  );
}
