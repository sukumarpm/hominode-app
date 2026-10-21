import 'package:flutter/material.dart';
import '../services/resident_private_images.dart';

/// Presentation only: references retain their saved order and authorized reader.
class MarketplaceImageGallery extends StatefulWidget {
  const MarketplaceImageGallery({
    super.key,
    required this.images,
    this.height = 300,
    this.imageProvider = residentImageProvider,
    this.initialIndex = 0,
    this.fullScreen = false,
  });

  final List<String> images;
  final double height;
  final ImageProvider Function(String) imageProvider;
  final int initialIndex;
  final bool fullScreen;

  @override
  State<MarketplaceImageGallery> createState() => _GalleryState();
}

class _GalleryState extends State<MarketplaceImageGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(MarketplaceImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.images.length != oldWidget.images.length ||
        widget.images.asMap().entries.any(
          (entry) => oldWidget.images[entry.key] != entry.value,
        )) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _placeholder(String label) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_not_supported_outlined, size: 48),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );

  void _open(int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Product images'),
            leading: IconButton(
              tooltip: 'Close image viewer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: MarketplaceImageGallery(
              images: widget.images,
              imageProvider: widget.imageProvider,
              initialIndex: index,
              fullScreen: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;
    final content = Column(
      children: [
        Expanded(
          child: widget.images.isEmpty
              ? _placeholder('No images available')
              : PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    final reference = widget.images[index];
                    Widget image = reference.trim().isEmpty
                        ? _placeholder('Image unavailable')
                        : Image(
                            image: widget.imageProvider(reference),
                            fit: widget.fullScreen
                                ? BoxFit.contain
                                : BoxFit.cover,
                            frameBuilder: (_, child, frame, synchronous) =>
                                synchronous || frame != null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (_, __, ___) =>
                                _placeholder('Image unavailable'),
                          );
                    if (widget.fullScreen) {
                      image = InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(child: image),
                      );
                    }
                    return Semantics(
                      label:
                          'Product image ${index + 1} of ${widget.images.length}',
                      button: !widget.fullScreen,
                      child: widget.fullScreen
                          ? image
                          : InkWell(
                              onTap: () => _open(index),
                              child: SizedBox.expand(child: image),
                            ),
                    );
                  },
                ),
        ),
        if (multiple)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_index + 1}/${widget.images.length}'),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(
                    widget.images.length,
                    (index) => Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _index
                            ? (widget.fullScreen
                                  ? Colors.white
                                  : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.fullScreen
                      ? 'Swipe to browse · Pinch to zoom'
                      : 'Swipe for more images',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
    return DefaultTextStyle.merge(
      style: TextStyle(
        color: widget.fullScreen ? Colors.white : Colors.black87,
      ),
      child: IconTheme(
        data: IconThemeData(
          color: widget.fullScreen ? Colors.white70 : Colors.grey,
        ),
        child: ColoredBox(
          color: widget.fullScreen ? Colors.black : Colors.grey.shade200,
          child: widget.fullScreen
              ? content
              : SizedBox(height: widget.height, child: content),
        ),
      ),
    );
  }
}
