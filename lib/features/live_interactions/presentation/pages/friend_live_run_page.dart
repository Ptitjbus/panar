import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/run_interaction_entity.dart';
import '../../domain/entities/run_session_entity.dart';
import '../providers/live_interactions_provider.dart';
import '../providers/run_session_provider.dart';
import '../widgets/direct_message_section.dart';
import '../widgets/emoji_reaction_section.dart';
import '../widgets/encouragement_section.dart';
import '../widgets/live_stats_widget.dart';
import '../widgets/soundboard_section.dart';
import '../widgets/voice_recorder_section.dart';

class FriendLiveRunPage extends ConsumerWidget {
  final String sessionId;
  final String runnerId;
  final String runnerName;

  const FriendLiveRunPage({
    super.key,
    required this.sessionId,
    required this.runnerId,
    required this.runnerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(watchedSessionProvider(sessionId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LiveDot(),
            const SizedBox(width: 8),
            Text(
              runnerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (session) {
          if (session == null || !session.isActive) {
            return const _SessionEndedView();
          }
          return _LiveRunBody(
            session: session,
            sessionId: sessionId,
            runnerId: runnerId,
          );
        },
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SessionEndedView extends StatelessWidget {
  const _SessionEndedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'La course est terminée',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _LiveRunBody extends ConsumerWidget {
  final RunSessionEntity session;
  final String sessionId;
  final String runnerId;

  const _LiveRunBody({
    required this.session,
    required this.sessionId,
    required this.runnerId,
  });

  void _send(
    WidgetRef ref, {
    required InteractionType type,
    String? content,
    String? audioUrl,
  }) {
    ref.read(sendInteractionProvider(sessionId).notifier).send(
          sessionId: sessionId,
          runnerId: runnerId,
          type: type,
          content: content,
          audioUrl: audioUrl,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sendState = ref.watch(sendInteractionProvider(sessionId));
    final isSending = sendState is AsyncLoading;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            LiveStatsWidget(session: session),
            const SizedBox(height: 20),
            _SectionCard(
              icon: Icons.favorite_rounded,
              color: const Color(0xFFFF8C00),
              title: 'Encouragements',
              child: EncouragementSection(
                onSend: (msg) =>
                    _send(ref, type: InteractionType.encouragement, content: msg),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.emoji_emotions_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Réactions',
              child: EmojiReactionSection(
                onSend: (emoji) =>
                    _send(ref, type: InteractionType.emoji, content: emoji),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.chat_bubble_rounded,
              color: const Color(0xFF2563EB),
              title: 'Message',
              child: DirectMessageSection(
                onSend: (msg) =>
                    _send(ref, type: InteractionType.directMessage, content: msg),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.campaign_rounded,
              color: const Color(0xFF0891B2),
              title: 'Soundboard',
              child: SoundboardSection(
                onSend: (clip) =>
                    _send(ref, type: InteractionType.soundboard, content: clip),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.mic_rounded,
              color: const Color(0xFF059669),
              title: 'Message vocal',
              child: VoiceRecorderSection(
                onSend: (url) =>
                    _send(ref, type: InteractionType.voiceMessage, audioUrl: url),
              ),
            ),
          ],
        ),
        if (isSending)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Envoi en cours…',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}
