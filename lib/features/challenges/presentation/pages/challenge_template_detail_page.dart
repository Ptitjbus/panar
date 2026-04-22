import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../domain/entities/challenge_template_entity.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/challenge_template_provider.dart';
import '../providers/duel_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/friend_selector_widget.dart';

class ChallengeTemplateDetailPage extends ConsumerStatefulWidget {
  final String templateId;

  const ChallengeTemplateDetailPage({super.key, required this.templateId});

  @override
  ConsumerState<ChallengeTemplateDetailPage> createState() =>
      _ChallengeTemplateDetailPageState();
}

class _ChallengeTemplateDetailPageState
    extends ConsumerState<ChallengeTemplateDetailPage> {
  List<String> _selectedFriendIds = [];
  bool _isLaunching = false;

  Future<void> _launch(ChallengeTemplateEntity template) async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      if (template.isSolo) {
        final duel = await ref.read(duelNotifierProvider.notifier).createDuel(
          timing: DuelTiming.async,
          deadlineHours: template.durationDays * 24,
          targetDistanceMeters: template.targetDistanceMeters,
          description: template.title,
        );
        if (!mounted) return;
        if (duel != null) {
          context.pushReplacement(
            Routes.duelDetail.replaceFirst(':id', duel.id),
          );
        }
      } else {
        final challenge = await ref
            .read(groupChallengeNotifierProvider.notifier)
            .createChallenge(
              title: template.title,
              durationDays: template.durationDays,
              friendIds: _selectedFriendIds,
              targetDistanceMeters: template.targetDistanceMeters,
              description: template.description,
            );
        if (!mounted) return;
        if (challenge != null) {
          context.pushReplacement(
            Routes.groupChallengeDetail.replaceFirst(':id', challenge.id),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templateState = ref.watch(challengeTemplateNotifierProvider);
    final allTemplates = [
      ...templateState.soloTemplates,
      ...templateState.groupTemplates,
      ...templateState.monthlyTemplates,
    ];
    final template =
        allTemplates.where((t) => t.id == widget.templateId).firstOrNull;

    if (template == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: Text('Défi introuvable')),
      );
    }

    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final friendsState = ref.watch(friendsNotifierProvider);
    final needFriends = !template.isSolo;
    final canLaunch = template.isSolo || _selectedFriendIds.isNotEmpty;

    String typeLabel;
    if (template.isSolo) {
      typeLabel = 'Solo';
    } else if (template.isMonthly) {
      typeLabel = 'Du mois';
    } else {
      typeLabel = 'Groupe';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFD9D9D9),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      typeLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    template.emoji,
                    style: const TextStyle(fontSize: 52),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template.title,
                    style: GoogleFonts.londrinaSolid(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetaChip(
                      text: '${template.points}💡',
                      background: const Color(0xFF909090),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetaChip(
                      text: template.targetDistanceLabel,
                      background: const Color(0xFF909090),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetaChip(
                      text: 'J-${template.durationDays}',
                      background: Colors.black,
                      foreground: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (template.description != null &&
                template.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'A propos',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  template.description!,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (needFriends) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Choisir avec qui',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Sélectionne les amis avec qui tu veux relever ce défi.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FriendSelectorWidget(
                  friends: friendsState.friends,
                  currentUserId: currentUserId,
                  multiSelect: true,
                  onSelectionChanged: (ids) =>
                      setState(() => _selectedFriendIds = ids),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                onPressed:
                    canLaunch && !_isLaunching ? () => _launch(template) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLaunching
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        template.isSolo
                            ? 'Lancer le défi'
                            : (_selectedFriendIds.isEmpty
                                ? 'Sélectionne des amis pour lancer'
                                : 'Lancer avec ${_selectedFriendIds.length} ami${_selectedFriendIds.length > 1 ? 's' : ''}'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _MetaChip({
    required this.text,
    required this.background,
    this.foreground = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 51,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.londrinaSolid(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: foreground,
        ),
      ),
    );
  }
}
