import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Helper function to darken a color by a given factor (0.0 to 1.0)
Color _darkenColor(Color color, double factor) {
  assert(factor >= 0 && factor <= 1, 'Factor must be between 0 and 1');

  final hsl = HSLColor.fromColor(color);
  final darkerHsl = hsl.withLightness(
    (hsl.lightness * (1 - factor)).clamp(0.0, 1.0),
  );
  return darkerHsl.toColor();
}

/// Optimized widget that displays a Lottie-animated avatar
/// with automatic state transitions between idle and walking animations.
///
/// Performance optimizations:
/// - RepaintBoundary to isolate repaints
/// - AnimatedSwitcher for smooth transitions
/// - Proper key management to prevent unnecessary rebuilds
/// - Const constructor where possible
class AnimatedAvatarWidget extends StatelessWidget {
  /// Whether the avatar is currently moving
  final bool isMoving;

  /// Size of the avatar (width and height)
  final double size;

  /// Optional color filter to tint the avatar
  final Color? colorFilter;

  /// Whether to show a shadow behind the avatar
  final bool showShadow;

  const AnimatedAvatarWidget({
    super.key,
    required this.isMoving,
    this.size = 40.0,
    this.colorFilter,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final animationPath = isMoving
        ? 'assets/animations/avatar_walk.json'
        : 'assets/animations/avatar_idle.json';

    // Build the Lottie animation
    Widget avatar = Lottie.asset(
      animationPath,
      key: ValueKey(animationPath), // Key for AnimatedSwitcher
      width: size,
      height: size,
      fit: BoxFit.contain,
      repeat: true,
      animate: true,
      // Enable merge paths for better performance
      options: LottieOptions(enableMergePaths: true),
      // Fallback when the Lottie file fails to load (e.g. on simulator)
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorFilter ?? const Color(0xFF4ECDC4),
          ),
          child: Icon(
            Icons.person,
            size: size * 0.55,
            color: Colors.white,
          ),
        );
      },
      // Apply color filters with black eyes/mouth and darker back leg
      delegates: colorFilter != null
          ? LottieDelegates(
              values: [
                // Black color for eyes and mouth (HEAD Outlines)
                ValueDelegate.colorFilter(
                  const ['HEAD Outlines', '**'],
                  value: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcATop,
                  ),
                ),
                // Color the body
                ValueDelegate.colorFilter(const [
                  'Shape Layer 1',
                  '**',
                ], value: ColorFilter.mode(colorFilter!, BlendMode.srcATop)),
                // Color the front leg
                ValueDelegate.colorFilter(const [
                  'LEG front',
                  '**',
                ], value: ColorFilter.mode(colorFilter!, BlendMode.srcATop)),
                // Color the back leg (slightly darker for depth)
                ValueDelegate.colorFilter(
                  const ['LEG Back', '**'],
                  value: ColorFilter.mode(
                    _darkenColor(colorFilter!, 0.15),
                    BlendMode.srcATop,
                  ),
                ),
              ],
            )
          : LottieDelegates(
              values: [
                // Black color for eyes and mouth even without colorFilter
                ValueDelegate.colorFilter(
                  const ['HEAD Outlines', '**'],
                  value: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcATop,
                  ),
                ),
              ],
            ),
    );

    // Add shadow if requested
    if (showShadow) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: avatar,
      );
    }

    // Use AnimatedSwitcher for smooth transitions between states
    // Isolate repaints with RepaintBoundary for performance
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: avatar,
      ),
    );
  }
}
