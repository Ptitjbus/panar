import 'package:flutter/material.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../domain/entities/avatar_mood.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

/// Widget that displays a wandering avatar on the Place map
class AvatarWidget extends StatefulWidget {
  final AvatarEntity avatar;
  final Offset? initialPosition;
  final void Function(Offset position)? onPositionChanged;
  final VoidCallback? onTap;
  final bool isRunning;
  final bool isOnline;
  final AvatarMood mood;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.initialPosition,
    this.onPositionChanged,
    this.onTap,
    this.isRunning = false,
    this.isOnline = false,
    this.mood = AvatarMood.neutral,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  static const double _avatarSize = 112;
  late Offset _position;
  final bool _isMoving = false;

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFF4A574);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx - (_avatarSize / 2),
      top: _position.dy - (_avatarSize / 2),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedAvatarWidget(
              isMoving: widget.isRunning || _isMoving,
              size: _avatarSize,
              mood: widget.mood,
              colorFilter: _parseColor(widget.avatar.colorHex),
              showShadow: true,
            ),
            if (widget.isRunning)
              Positioned(
                top: -14,
                right: -24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
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
              )
            else if (widget.isOnline)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
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
