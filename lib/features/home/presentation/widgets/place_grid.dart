import 'package:flutter/material.dart';

/// Custom painter for the Place grid
class PlaceGridPainter extends CustomPainter {
  final ColorScheme colorScheme;

  PlaceGridPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    const double spacing = 25.0;
    const double dotRadius = 1.5;

    // Draw dots in a grid pattern
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PlaceGridPainter oldDelegate) {
    // Repaint if color scheme changes (e.g., theme switch)
    return oldDelegate.colorScheme != colorScheme;
  }
}
