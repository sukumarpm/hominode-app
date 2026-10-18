import 'dart:async';
import 'package:flutter/material.dart';
import '../services/resident_private_images.dart';

/// Keeps the approved banner layout; only its image layer crossfades.
class CommunityImageSlideshow extends StatefulWidget {
  const CommunityImageSlideshow({
    super.key,
    required this.images,
    required this.foregroundBuilder,
    this.active = true,
    this.fallback = const AssetImage('assets/hominode_residential_hero.jpg'),
    this.imageProvider = residentImageProvider,
  });
  final List<String> images;
  final bool active;
  final ImageProvider fallback;
  final ImageProvider Function(String) imageProvider;
  final Widget Function(BuildContext, int, int) foregroundBuilder;
  @override
  State<CommunityImageSlideshow> createState() =>
      _CommunityImageSlideshowState();
}

class _CommunityImageSlideshowState extends State<CommunityImageSlideshow>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _index = 0;
  bool _resumed = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.active && _resumed && widget.images.length > 1) {
      _timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => setState(() => _index = (_index + 1) % widget.images.length),
      );
    }
  }

  @override
  void didUpdateWidget(covariant CommunityImageSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images ||
        oldWidget.active != widget.active) {
      if (oldWidget.images != widget.images) _index = 0;
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reference = widget.images.isEmpty ? null : widget.images[_index];
    return GestureDetector(
      onHorizontalDragEnd: widget.images.length < 2
          ? null
          : (details) {
              final velocity = details.primaryVelocity;
              if (velocity == null || velocity == 0) return;
              setState(
                () => _index =
                    (_index + (velocity < 0 ? 1 : -1) + widget.images.length) %
                    widget.images.length,
              );
              _schedule();
            },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image(image: widget.fallback, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: reference == null
                  ? const SizedBox.shrink()
                  : Image(
                      key: ValueKey(reference),
                      image: widget.imageProvider(reference),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ),
          widget.foregroundBuilder(context, _index, widget.images.length),
        ],
      ),
    );
  }
}
