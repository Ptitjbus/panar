import 'package:flutter/material.dart';

typedef OnSendSound = void Function(String clipName);

const _sounds = [
  (name: 'cheries', label: 'Chéri(e) !', icon: Icons.favorite_rounded),
  (name: 'commandante', label: 'Commandante !', icon: Icons.military_tech_rounded),
  (name: 'fils_de_pute', label: 'Fils de p***', icon: Icons.sentiment_very_dissatisfied_rounded),
  (name: 'miserable', label: 'Misérable !', icon: Icons.mood_bad_rounded),
  (name: 'pet', label: 'Prrr... 💨', icon: Icons.air_rounded),
];

const _kColor = Color(0xFF0891B2);

class SoundboardSection extends StatelessWidget {
  final OnSendSound onSend;

  const SoundboardSection({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sounds.map((sound) {
        return _SoundButton(sound: sound, onTap: () => onSend(sound.name));
      }).toList(),
    );
  }
}

class _SoundButton extends StatefulWidget {
  final ({String name, String label, IconData icon}) sound;
  final VoidCallback onTap;

  const _SoundButton({required this.sound, required this.onTap});

  @override
  State<_SoundButton> createState() => _SoundButtonState();
}

class _SoundButtonState extends State<_SoundButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.88,
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
    setState(() => _sent = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _sent = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _ctrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _sent
                ? _kColor.withValues(alpha: 0.2)
                : _kColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _sent
                  ? _kColor
                  : _kColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _sent ? Icons.check_rounded : widget.sound.icon,
                size: 18,
                color: _kColor,
              ),
              const SizedBox(width: 7),
              Text(
                widget.sound.label,
                style: TextStyle(
                  color: _kColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
