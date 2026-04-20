import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import '../../features/home/domain/entities/avatar_mood.dart';

final Map<String, Future<String>> _avatarSvgCache = <String, Future<String>>{};

String _svgPathForMood(AvatarMood mood, {bool isMoving = false}) {
  if (isMoving) return 'assets/images/avatar_running.svg';
  return switch (mood) {
    AvatarMood.crying => 'assets/images/avatar_sad.svg',
    AvatarMood.tired => 'assets/images/avatar_tired.svg',
    AvatarMood.neutral => 'assets/images/avatar_neutral.svg',
    AvatarMood.happy => 'assets/images/avatar_normal.svg',
    AvatarMood.excited => 'assets/images/avatar_normal.svg',
  };
}

String _hexRgb(Color color) {
  final argb = color.toARGB32();
  final red = (argb >> 16) & 0xFF;
  final green = (argb >> 8) & 0xFF;
  final blue = argb & 0xFF;
  return '#${red.toRadixString(16).padLeft(2, '0').toUpperCase()}${green.toRadixString(16).padLeft(2, '0').toUpperCase()}${blue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

Future<String> _loadSvgWithBodyColor(String assetPath, Color bodyColor) {
  final cacheKey = '$assetPath-${bodyColor.toARGB32()}';
  return _avatarSvgCache.putIfAbsent(cacheKey, () async {
    final rawSvg = await rootBundle.loadString(assetPath);
    final bodyGroupPattern = RegExp(
      r"""<g\b[^>]*\bid=(['"])body\1[^>]*>([\s\S]*?)</g>""",
    );
    final fillPattern = RegExp(r"""(\bfill=)(['"])([^'"]*)(\2)""");
    final bodyHex = _hexRgb(bodyColor);

    return rawSvg.replaceFirstMapped(bodyGroupPattern, (bodyMatch) {
      final group = bodyMatch.group(0)!;
      return group.replaceAllMapped(fillPattern, (fillMatch) {
        final currentValue = fillMatch.group(3)?.toLowerCase();
        if (currentValue == 'none') return fillMatch.group(0)!;
        return '${fillMatch.group(1)}${fillMatch.group(2)}$bodyHex${fillMatch.group(4)}';
      });
    });
  });
}

/// Widget that displays the Peton character as an SVG illustration.
/// The SVG is chosen based on mood and movement state.
class AnimatedAvatarWidget extends StatelessWidget {
  final bool isMoving;
  final double size;
  final AvatarMood mood;
  final bool showShadow;

  /// Optional color applied only to the SVG group with `id="body"`.
  final Color? colorFilter;

  const AnimatedAvatarWidget({
    super.key,
    required this.isMoving,
    this.size = 40.0,
    this.mood = AvatarMood.neutral,
    this.colorFilter,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final path = _svgPathForMood(mood, isMoving: isMoving);
    final color = colorFilter;
    final svgKey = color == null
        ? ValueKey(path)
        : ValueKey('$path-${color.toARGB32()}');

    Widget svg;
    if (color == null) {
      svg = SvgPicture.asset(
        path,
        key: svgKey,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else {
      svg = FutureBuilder<String>(
        future: _loadSvgWithBodyColor(path, color),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return SvgPicture.asset(
              path,
              key: svgKey,
              width: size,
              height: size,
              fit: BoxFit.contain,
            );
          }
          return SvgPicture.string(
            snapshot.data!,
            key: svgKey,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        },
      );
    }

    if (showShadow) {
      svg = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: svg,
      );
    }

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: svg,
      ),
    );
  }
}
