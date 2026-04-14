import 'package:flutter/material.dart';

typedef OnSendEncouragement = void Function(String message);

const _encouragements = [
  ('Allez !', '🚀'),
  ("T'es chaud !", '🔥'),
  ('Incroyable !', '🌟'),
  ('Bravo !', '👏'),
  ('Continue !', '💨'),
  ('Tu gères !', '💪'),
];

class EncouragementSection extends StatelessWidget {
  final OnSendEncouragement onSend;

  const EncouragementSection({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _encouragements.map(((String, String) entry) {
        final (label, emoji) = entry;
        return _EncouragementChip(
          label: label,
          emoji: emoji,
          onTap: () => onSend(label),
        );
      }).toList(),
    );
  }
}

class _EncouragementChip extends StatefulWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _EncouragementChip({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_EncouragementChip> createState() => _EncouragementChipState();
}

class _EncouragementChipState extends State<_EncouragementChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.reverse().then((_) => _ctrl.forward());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFFF8C00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
