import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/experiments/app_experiments.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../challenges/domain/entities/duel_entity.dart';
import '../../../challenges/presentation/providers/duel_provider.dart';
import '../../../live_interactions/domain/entities/run_interaction_entity.dart';
import '../../../live_interactions/presentation/providers/live_interactions_provider.dart';
import '../../../live_interactions/presentation/widgets/interaction_overlay_widget.dart';
import '../providers/run_tracking_provider.dart';

// Background and mascot images — replace with local assets when available
const _kBackgroundUrl =
    'https://www.figma.com/api/mcp/asset/31b10466-9fea-4a10-9cfb-4ec2ef009022';
const _kMascotUrl =
    'https://www.figma.com/api/mcp/asset/43f7de75-117a-4401-91ec-4b6b84ad187f';

class RunTrackingPage extends ConsumerStatefulWidget {
  const RunTrackingPage({super.key});

  @override
  ConsumerState<RunTrackingPage> createState() => _RunTrackingPageState();
}

class _RunTrackingPageState extends ConsumerState<RunTrackingPage> {
  bool _showDataView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(runTrackingProvider.notifier).resetRun();
    });
  }

  Future<void> _startRun() async {
    final variant = ref.read(
      trackedExperimentVariantProvider(
        AppExperimentKeys.runLaunchLiveVariant,
      ),
    );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'run_launch',
            step: 'run_tracking_opened',
            source: 'run_tracking_page',
            variant: variant,
          ),
    );
    await ref.read(runTrackingProvider.notifier).startRun();
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(runTrackingProvider);

    final isIdle = runState.status == RunStatus.idle;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePopCallback(runState.status);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Background + mascot always visible
            _MascotView(runState: runState, showStats: !isIdle),

            // Data view when running/paused and toggled
            if (!isIdle && _showDataView) _DataView(runState: runState),

            if (runState.errorMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      runState.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),

            const InteractionOverlayWidget(),

            if (kDebugMode)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'debug_interactions',
                  backgroundColor: Colors.purple,
                  onPressed: () => _showDebugPanel(context, ref),
                  child: const Icon(Icons.bug_report, color: Colors.white),
                ),
              ),

            // Prep overlay in idle state
            if (isIdle) _PrepOverlay(onStart: _startRun),

            // Controls bar when active
            if (!isIdle)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ControlsBar(
                  runState: runState,
                  showDataView: _showDataView,
                  onToggleView: () =>
                      setState(() => _showDataView = !_showDataView),
                  onPause: () =>
                      ref.read(runTrackingProvider.notifier).pauseRun(),
                  onResume: () =>
                      ref.read(runTrackingProvider.notifier).resumeRun(),
                  onStop: _handleStop,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDebugPanel(BuildContext context, WidgetRef ref) {
    final runState = ref.read(runTrackingProvider);

    void inject(InteractionType type, {String? content, String? audioUrl}) {
      ref
          .read(incomingInteractionsProvider.notifier)
          .debugInject(
            RunInteractionEntity(
              id: 'debug_${DateTime.now().millisecondsSinceEpoch}',
              sessionId: 'debug',
              senderId: 'debug',
              runnerId: 'debug',
              type: type,
              content: content,
              audioUrl: audioUrl,
              createdAt: DateTime.now(),
              senderName: 'Kevin (debug)',
            ),
          );
      Navigator.of(context).pop();
    }

    void openFriendView() {
      final sessionId = runState.liveSessionId;
      if (sessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pas encore de session active — démarre d\'abord la course.',
            ),
          ),
        );
        return;
      }
      Navigator.of(context).pop();
      context.push(
        Routes.friendLiveRun,
        extra: {
          'sessionId': sessionId,
          'runnerId': ref.read(authStateProvider).value?.id ?? '',
          'runnerName': 'Toi (debug)',
        },
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '🐛 Debug — Interactions live',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.teal,
                    ),
                    title: const Text('Voir comme ami'),
                    subtitle: Text(
                      runState.liveSessionId != null
                          ? 'Ouvre la vue ami sur ta session'
                          : 'Démarre d\'abord la course',
                    ),
                    onTap: openFriendView,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.orange),
                    title: const Text('Encouragement'),
                    subtitle: const Text('"Allez tu gères !"'),
                    onTap: () => inject(
                      InteractionType.encouragement,
                      content: 'Allez tu gères !',
                    ),
                  ),
                  ListTile(
                    leading: const Text('🔥', style: TextStyle(fontSize: 22)),
                    title: const Text('Emoji'),
                    subtitle: const Text('"🔥"'),
                    onTap: () => inject(InteractionType.emoji, content: '🔥'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble, color: Colors.blue),
                    title: const Text('Message direct'),
                    subtitle: const Text('"T\'es incroyable continue !"'),
                    onTap: () => inject(
                      InteractionType.directMessage,
                      content: "T'es incroyable continue !",
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_up, color: Colors.green),
                    title: const Text('Soundboard — Commandante'),
                    subtitle: const Text('Joue le clip audio local'),
                    onTap: () => inject(
                      InteractionType.soundboard,
                      content: 'commandante',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.mic, color: Colors.purple),
                    title: const Text('Message vocal (notification)'),
                    subtitle: const Text('Son de notif + overlay vocal'),
                    onTap: () => inject(InteractionType.voiceMessage),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePopCallback(RunStatus status) async {
    if (status == RunStatus.running || status == RunStatus.paused) {
      final confirmed = await _showStopDialog();
      if (!confirmed || !mounted) return;
      await ref.read(runTrackingProvider.notifier).stopRun();
      if (!mounted) return;
      context.go(Routes.home);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.home);
      }
    }
  }

  Future<void> _handleStop() async {
    final confirmed = await _showStopDialog();
    if (!confirmed || !mounted) return;

    final elapsedBeforeStop = ref.read(runTrackingProvider).elapsedSeconds;
    final variant = ref.read(
      trackedExperimentVariantProvider(AppExperimentKeys.runLaunchLiveVariant),
    );
    final activityId = await ref.read(runTrackingProvider.notifier).stopRun();
    if (!mounted) return;

    if (activityId == null && elapsedBeforeStop < 60) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'run_launch',
              step: 'run_stopped_too_short',
              source: 'run_tracking_page',
              variant: variant,
            ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Course trop courte (moins d\'1 min) — non enregistrée.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      context.go(Routes.home);
      return;
    }

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'run_launch',
            step: 'run_completed',
            source: 'run_tracking_page',
            variant: variant,
          ),
    );
    context.go(Routes.runReward, extra: {'activityId': activityId});
  }

  Future<bool> _showStopDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la course ?'),
        content: const Text(
          'Votre progression sera sauvegardée. Voulez-vous vraiment terminer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─── Vue Préparation (overlay) ───────────────────────────────────────────────

class _PrepOverlay extends ConsumerWidget {
  final Future<void> Function() onStart;

  const _PrepOverlay({required this.onStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelState = ref.watch(duelNotifierProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final theme = Theme.of(context);

    final activeDuels = duelState.myDuels
        .where(
          (d) =>
              d.status == DuelStatus.active || d.status == DuelStatus.accepted,
        )
        .toList();

    return Positioned.fill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Transparent top — back button only
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (context.canPop()) context.pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Spacer — background + avatar visible through here
          const Spacer(),

          // Bottom panel
          Container(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.97),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prêt à courir !', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  'Lance ta course et relève tes défis activés.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('Défis activés', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (activeDuels.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Aucun défi activé — active un défi depuis l\'onglet Défis.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: activeDuels.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          _ActiveDuelTile(duel: activeDuels[i]),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      'Démarrer la course',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveDuelTile extends StatelessWidget {
  final DuelEntity duel;

  const _ActiveDuelTile({required this.duel});

  @override
  Widget build(BuildContext context) {
    final desc = duel.description ?? '';
    final name = desc.contains(' • ') ? desc.split(' • ').first.trim() : desc;
    final target = duel.targetDistanceMeters;
    final targetLabel = target != null
        ? '${(target / 1000).toStringAsFixed(0)} km'
        : '—';
    final icon = duel.isSolo ? '🏃' : '⚔️';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Défi',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  targetLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              duel.status == DuelStatus.active ? 'En cours' : 'Accepté',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vue Mascotte ───────────────────────────────────────────────────────────

class _MascotView extends StatelessWidget {
  const _MascotView({required this.runState, this.showStats = true});

  final RunTrackingState runState;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Background illustration
        Positioned.fill(
          child: Image.network(
            _kBackgroundUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) =>
                const ColoredBox(color: Color(0xFFD9D9D9)),
          ),
        ),

        // Top header background
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: topPadding + 120,
            decoration: const BoxDecoration(
              color: Color(0xFFD9D9D9),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
        ),

        // Stat pills — only when running/paused
        if (showStats)
          Positioned(
            top: topPadding + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatPill(label: 'Temps', value: runState.formattedDuration),
                _StatPill(
                  label: 'Distance',
                  value: '${runState.formattedDistance} km',
                ),
                _StatPill(label: 'Allure', value: runState.formattedPace),
              ],
            ),
          ),

        // Mascot
        Positioned(
          left: 36,
          right: 65,
          top: topPadding + 200,
          height: 320,
          child: Image.network(
            _kMascotUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),

        // Bottom spacer for controls bar
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 150,
          child: SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF09090B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF09090B)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF09090B),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Vue Data ────────────────────────────────────────────────────────────────

class _DataView extends StatelessWidget {
  const _DataView({required this.runState});

  final RunTrackingState runState;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        SizedBox(height: topPadding),

        // Section Temps
        Expanded(
          flex: 37,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  runState.formattedDuration,
                  style: GoogleFonts.londrinaSolid(
                    fontSize: 96,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF09090B),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Temps',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF09090B),
                  ),
                ),
              ],
            ),
          ),
        ),

        const _Divider(),

        // Section Kilomètres
        Expanded(
          flex: 32,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  runState.formattedDistance,
                  style: GoogleFonts.londrinaSolid(
                    fontSize: 96,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF09090B),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kilomètres',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF09090B),
                  ),
                ),
              ],
            ),
          ),
        ),

        const _Divider(),

        // Section Rythme
        Expanded(
          flex: 31,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          runState.formattedPace,
                          style: GoogleFonts.londrinaSolid(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF09090B),
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rythme actuel',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF09090B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(
                  color: Color(0x80000000),
                  width: 1,
                  thickness: 1,
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          runState.formattedAveragePace,
                          style: GoogleFonts.londrinaSolid(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF09090B),
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rythme moyen',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF09090B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Space for controls bar
        const SizedBox(height: 150),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0x80000000));
  }
}

// ─── Barre de contrôles ──────────────────────────────────────────────────────

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.runState,
    required this.showDataView,
    required this.onToggleView,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final RunTrackingState runState;
  final bool showDataView;
  final VoidCallback onToggleView;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPaused = runState.status == RunStatus.paused;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bouton carte (vue mascotte) — fond jaune quand sélectionné
          _CircleButton(
            size: 63,
            backgroundColor: !showDataView
                ? const Color(0xFFF8FDAB)
                : Colors.black,
            onPressed: () {
              if (showDataView) onToggleView();
            },
            child: Icon(
              Icons.map_outlined,
              size: 26,
              color: !showDataView ? Colors.black : Colors.white,
            ),
          ),

          // Contrôle central (pause/reprise + arrêt explicite)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: isPaused ? onResume : onPause,
                onLongPress: onStop,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Arrêter',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bouton stats (vue data)
          _CircleButton(
            size: 63,
            backgroundColor: showDataView
                ? const Color(0xFFF8FDAB)
                : Colors.black,
            onPressed: () {
              if (!showDataView) onToggleView();
            },
            child: Text(
              '📈',
              style: TextStyle(
                fontSize: 25,
                color: showDataView ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.backgroundColor,
    required this.onPressed,
    required this.child,
  });

  final double size;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}
