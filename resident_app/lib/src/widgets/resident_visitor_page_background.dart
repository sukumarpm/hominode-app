import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// The light architectural backdrop used by Resident Home, shared with
/// visitor-related pages so their foreground cards remain easy to read.
class ResidentVisitorPageBackground extends StatelessWidget {
  const ResidentVisitorPageBackground({
    super.key,
    required this.child,
    this.blurSigma = 8,
  });

  final Widget child;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Image.asset(
            'assets/hominode_residential_hero.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFFF7FAFD)),
          ),
        ),
        const ColoredBox(color: Color(0xB8F7FAFD)),
        child,
      ],
    );
  }
}
