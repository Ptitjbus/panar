import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../domain/entities/avatar_entity.dart';

class QuickInteractionSheet extends StatelessWidget {
  final AvatarEntity avatar;
  final String username;
  final bool isOnline;
  final VoidCallback onChallenge;
  final VoidCallback? onCheer;
  final VoidCallback onOpenProfile;
  final VoidCallback? onWatchLive;
  final ValueChanged<String> onSendEmoji;
  final VoidCallback onOpenEmojiPicker;

  const QuickInteractionSheet({
    super.key,
    required this.avatar,
    required this.username,
    required this.isOnline,
    required this.onChallenge,
    this.onCheer,
    required this.onOpenProfile,
    required this.onSendEmoji,
    required this.onOpenEmojiPicker,
    this.onWatchLive,
  });

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFF4A574);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _parseColor(avatar.colorHex);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + safeBottom),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          if (isOnline) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...['❤️', '🎉', '🍾', '🔥'].map(
                  (emoji) => _RoundEmojiButton(
                    emoji: emoji,
                    onTap: () => onSendEmoji(emoji),
                  ),
                ),
                _RoundEmojiButton(emoji: '+', onTap: onOpenEmojiPicker),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: AnimatedAvatarWidget(
                        isMoving: false,
                        size: 20,
                        colorFilter: avatarColor,
                        showShadow: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.londrinaSolid(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF00FF4D)
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'En ligne maintenant' : 'Hors ligne',
                                style: GoogleFonts.inter(
                                  color: isOnline
                                      ? const Color(0xFF00FF4D)
                                      : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onWatchLive != null) ...[
                      _ActionIconButton(emoji: '👀', onTap: onWatchLive),
                      const SizedBox(width: 6),
                    ],
                    _ActionIconButton(emoji: '✉️', onTap: onOpenProfile),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MainActionButton(
                        label: 'Lancer un défi 🎯',
                        onTap: onChallenge,
                      ),
                    ),
                    if (onCheer != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MainActionButton(
                          label: 'Féliciter 🎉',
                          onTap: onCheer!,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundEmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _RoundEmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: emoji == '+' ? 30 : 27,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final String emoji;
  final VoidCallback? onTap;

  const _ActionIconButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF969696),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MainActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
