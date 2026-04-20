import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../domain/entities/avatar_entity.dart';

class QuickInteractionSheet extends StatelessWidget {
  final AvatarEntity avatar;
  final String username;
  final bool isOnline;
  final VoidCallback onChallenge;
  final VoidCallback? onCheer;
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
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + safeBottom),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedAvatarWidget(
                        isMoving: false,
                        size: 28,
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
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF00C853)
                                      : AppColors.textSecondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'En ligne' : 'Hors ligne',
                                style: GoogleFonts.inter(
                                  color: isOnline
                                      ? const Color(0xFF00C853)
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onWatchLive != null)
                      _IconChipButton(
                        icon: Icons.visibility_rounded,
                        label: 'Live',
                        onTap: onWatchLive,
                      ),
                  ],
                ),
                if (isOnline) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Réagir vite',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...['❤️', '🎉', '🍾', '🔥'].map(
                          (emoji) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _RoundEmojiButton(
                              emoji: emoji,
                              onTap: () => onSendEmoji(emoji),
                            ),
                          ),
                        ),
                        _RoundEmojiButton(emoji: '+', onTap: onOpenEmojiPicker),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MainActionButton(
                        label: 'Lancer un défi',
                        icon: Icons.flag_rounded,
                        onTap: onChallenge,
                      ),
                    ),
                    if (onCheer != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MainActionButton(
                          label: isOnline ? 'Encourager' : 'Féliciter',
                          icon: Icons.celebration_rounded,
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.surfaceDark),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: emoji == '+' ? 26 : 23,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _IconChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MainActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
