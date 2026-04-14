import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../live_interactions/domain/entities/run_interaction_entity.dart';
import '../../../live_interactions/presentation/providers/live_interactions_provider.dart';
import '../../../live_interactions/presentation/widgets/interaction_overlay_widget.dart';
import '../providers/run_tracking_provider.dart';
import '../widgets/run_map_widget.dart';
import '../widgets/run_metric_card.dart';

class RunTrackingPage extends ConsumerStatefulWidget {
  const RunTrackingPage({super.key});

  @override
  ConsumerState<RunTrackingPage> createState() => _RunTrackingPageState();
}

class _RunTrackingPageState extends ConsumerState<RunTrackingPage> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(runTrackingProvider.notifier).startRun();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(runTrackingProvider);
    final theme = Theme.of(context);

    // Centrer la carte sur le dernier point GPS
    ref.listen(runTrackingProvider, (previous, next) {
      if (next.points.isNotEmpty) {
        final last = next.points.last;
        _mapController.move(LatLng(last.latitude, last.longitude), 16);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePopCallback(runState.status);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Carte en plein écran
            RunMapWidget(
              points: runState.points,
              mapController: _mapController,
            ),

            // Bouton retour
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: 0.85,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _handleBackButton(runState.status),
                  ),
                ),
              ),
            ),

            // Message d'erreur permission
            if (runState.errorMessage != null)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      runState.errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),

            // Overlay interactions amis
            const InteractionOverlayWidget(),

            // Bouton debug (mode debug uniquement)
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

            // Overlay stats + contrôles en bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Métriques
                    Row(
                      children: [
                        Expanded(
                          child: RunMetricCard(
                            label: 'DISTANCE',
                            value: runState.formattedDistance,
                            unit: 'km',
                          ),
                        ),
                        Expanded(
                          child: RunMetricCard(
                            label: 'DURÉE',
                            value: runState.formattedDuration,
                            unit: 'mm:ss',
                          ),
                        ),
                        Expanded(
                          child: RunMetricCard(
                            label: 'ALLURE',
                            value: runState.formattedPace,
                            unit: '/km',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Boutons de contrôle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pause / Reprendre
                        FloatingActionButton(
                          heroTag: 'pause_resume',
                          onPressed: () {
                            if (runState.status == RunStatus.running) {
                              ref.read(runTrackingProvider.notifier).pauseRun();
                            } else if (runState.status == RunStatus.paused) {
                              ref
                                  .read(runTrackingProvider.notifier)
                                  .resumeRun();
                            }
                          },
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Icon(
                            runState.status == RunStatus.paused
                                ? Icons.play_arrow
                                : Icons.pause,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),

                        // Stop
                        FloatingActionButton.large(
                          heroTag: 'stop',
                          onPressed: () => _handleStop(),
                          backgroundColor: theme.colorScheme.errorContainer,
                          child: Icon(
                            Icons.stop,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
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

  void _showDebugPanel(BuildContext context, WidgetRef ref) {
    final runState = ref.read(runTrackingProvider);

    void inject(InteractionType type, {String? content, String? audioUrl}) {
      ref.read(incomingInteractionsProvider.notifier).debugInject(
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
            content: Text('Pas encore de session active — démarre d\'abord la course.'),
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
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_alt_rounded, color: Colors.teal),
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
                    onTap: () => inject(InteractionType.encouragement, content: 'Allez tu gères !'),
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
                    onTap: () => inject(InteractionType.directMessage, content: "T'es incroyable continue !"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_up, color: Colors.green),
                    title: const Text('Soundboard — Commandante'),
                    subtitle: const Text('Joue le clip audio local'),
                    onTap: () => inject(InteractionType.soundboard, content: 'commandante'),
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
      context.go(Routes.home);
    }
  }

  Future<void> _handleBackButton(RunStatus status) async {
    if (status == RunStatus.running || status == RunStatus.paused) {
      final confirmed = await _showStopDialog();
      if (!confirmed || !mounted) return;
      await ref.read(runTrackingProvider.notifier).stopRun();
      if (!mounted) return;
      context.go(Routes.home);
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _handleStop() async {
    final confirmed = await _showStopDialog();
    if (!confirmed || !mounted) return;

    final elapsedBeforeStop = ref.read(runTrackingProvider).elapsedSeconds;
    final activityId = await ref.read(runTrackingProvider.notifier).stopRun();
    if (!mounted) return;

    if (activityId == null && elapsedBeforeStop < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course trop courte (moins d\'1 min) — non enregistrée.'),
          duration: Duration(seconds: 3),
        ),
      );
      context.go(Routes.home);
      return;
    }

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
