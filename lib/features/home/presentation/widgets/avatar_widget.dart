import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

/// Widget that displays a wandering avatar on the Place map
class AvatarWidget extends StatefulWidget {
  final AvatarEntity avatar;
  final Offset? initialPosition;
  final void Function(Offset position)? onPositionChanged;
  final VoidCallback? onTap;
  final bool isRunning;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.initialPosition,
    this.onPositionChanged,
    this.onTap,
    this.isRunning = false,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  late Offset _position;
  final bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    // Use initial position or default to center of 2000x2000 canvas
    _position = widget.initialPosition ?? const Offset(1000, 1000);
    // Notify initial position safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPositionChanged?.call(_position);
    });
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      // Fallback to turquoise if color parsing fails
      return const Color(0xFF4ECDC4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(widget.avatar.colorHex);

    return Positioned(
      left: _position.dx - 20, // Center the 40px avatar
      top: _position.dy - 20,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedAvatarWidget(
              isMoving: _isMoving,
              size: 40,
              colorFilter: color,
              showShadow: true,
            ),
            if (widget.isRunning)
              Positioned(
                top: -12,
                right: -20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_run, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'En course',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
