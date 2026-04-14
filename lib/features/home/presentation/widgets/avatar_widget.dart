import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

/// Widget that displays a wandering avatar on the Place map
class AvatarWidget extends StatefulWidget {
  final AvatarEntity avatar;
  final void Function(Offset position)? onPositionChanged;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.onPositionChanged,
    this.onTap,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  late Offset _position;
  Timer? _movementTimer;
  Timer? _movementStateTimer;
  final Random _random = Random();
  Duration _animationDuration = const Duration(milliseconds: 800);
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    // Start at center of 2000x2000 canvas
    _position = const Offset(1000, 1000);
    // Notify initial position
    widget.onPositionChanged?.call(_position);
    _startRandomMovement();
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _movementStateTimer?.cancel();
    super.dispose();
  }

  void _startRandomMovement() {
    _scheduleNextMove();
  }

  void _scheduleNextMove() {
    // Random interval between 3-6 seconds for smoother feel
    final intervalSeconds = 3 + _random.nextDouble() * 3;
    _movementTimer = Timer(
      Duration(milliseconds: (intervalSeconds * 1000).round()),
      _moveToRandomPosition,
    );
  }

  void _moveToRandomPosition() {
    if (!mounted) return;

    // Random direction (0-360 degrees) and distance (20-100 px)
    final angle = _random.nextDouble() * 2 * pi;
    final distance = 20 + _random.nextDouble() * 80;

    // Calculate new position
    final dx = _position.dx + cos(angle) * distance;
    final dy = _position.dy + sin(angle) * distance;

    // Clamp to boundaries (considering 40px avatar size)
    final newX = dx.clamp(20.0, 1980.0);
    final newY = dy.clamp(20.0, 1980.0);

    // Random animation duration between 1500-2500ms for smoother movement
    final durationMs = 1500 + _random.nextInt(1001);

    setState(() {
      _position = Offset(newX, newY);
      _animationDuration = Duration(milliseconds: durationMs);
      _isMoving = true; // Start walking animation
    });

    // Notify position change
    widget.onPositionChanged?.call(_position);

    // Stop walking animation when movement completes
    _movementStateTimer?.cancel();
    _movementStateTimer = Timer(_animationDuration, () {
      if (mounted) {
        setState(() {
          _isMoving = false; // Return to idle animation
        });
      }
    });

    // Schedule next move
    _scheduleNextMove();
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

    return AnimatedPositioned(
      duration: _animationDuration,
      curve: Curves.easeInOutCubic,
      left: _position.dx - 20, // Center the 40px avatar
      top: _position.dy - 20,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedAvatarWidget(
          isMoving: _isMoving,
          size: 40,
          colorFilter: color,
          showShadow: true,
        ),
      ),
    );
  }
}
