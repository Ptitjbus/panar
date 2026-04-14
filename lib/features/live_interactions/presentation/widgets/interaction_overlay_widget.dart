import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/observers/route_observer.dart';
import '../../domain/entities/run_interaction_entity.dart';
import '../providers/live_interactions_provider.dart';

class InteractionOverlayWidget extends ConsumerStatefulWidget {
  const InteractionOverlayWidget({super.key});

  @override
  ConsumerState<InteractionOverlayWidget> createState() =>
      _InteractionOverlayWidgetState();
}

class _InteractionOverlayWidgetState
    extends ConsumerState<InteractionOverlayWidget> with RouteAware {
  final Map<String, Timer> _dismissTimers = {};

  /// True when RunTrackingPage is the top route (not covered by another page).
  bool _isRouteActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    for (final t in _dismissTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  /// Called when FriendLiveRunPage (or any page) is pushed on top.
  @override
  void didPushNext() {
    _isRouteActive = false;
  }

  /// Called when the page on top is popped, revealing RunTrackingPage.
  @override
  void didPopNext() {
    _isRouteActive = true;
    // Start dismiss timer for any interaction that arrived while we were away.
    final interactions = ref.read(incomingInteractionsProvider);
    if (interactions.isNotEmpty) {
      _scheduleDismiss(interactions.first.id);
    }
  }

  /// Schedules a dismiss after 5 s.
  /// If the route is not active when the timer fires, it retries every second
  /// until it becomes active — so the notification stays visible for a full 5 s
  /// after the user returns to the map.
  void _scheduleDismiss(String id) {
    if (_dismissTimers.containsKey(id)) return;
    _dismissTimers[id] = Timer(const Duration(seconds: 5), () {
      _dismissTimers.remove(id);
      if (!mounted) return;
      if (!_isRouteActive) {
        // Route is still covered — retry in 1 s
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _scheduleDismiss(id);
        });
        return;
      }
      ref.read(incomingInteractionsProvider.notifier).dismiss(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final interactions = ref.watch(incomingInteractionsProvider);

    if (interactions.isEmpty) return const SizedBox.shrink();

    final interaction = interactions.first;
    // Start dismiss timer only while the route is active.
    if (_isRouteActive) {
      _scheduleDismiss(interaction.id);
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
          return SlideTransition(
            position: slide,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: _InteractionCard(
          key: ValueKey(interaction.id),
          interaction: interaction,
          onDismiss: () {
            _dismissTimers[interaction.id]?.cancel();
            _dismissTimers.remove(interaction.id);
            ref
                .read(incomingInteractionsProvider.notifier)
                .dismiss(interaction.id);
          },
          onPlayAudio: interaction.audioUrl != null
              ? () => ref
                    .read(incomingInteractionsProvider.notifier)
                    .playAudio(interaction.audioUrl!)
              : null,
        ),
      ),
    );
  }
}

// --- Per-type visual config ---

typedef _TypeConfig = ({
  String emoji,
  Color color,
  Color onColor,
});

_TypeConfig _configFor(InteractionType type) {
  switch (type) {
    case InteractionType.encouragement:
      return (
        emoji: '💪',
        color: const Color(0xFFFF8C00),
        onColor: Colors.white,
      );
    case InteractionType.emoji:
      return (
        emoji: '🎉',
        color: const Color(0xFF8B5CF6),
        onColor: Colors.white,
      );
    case InteractionType.directMessage:
      return (
        emoji: '💬',
        color: const Color(0xFF2563EB),
        onColor: Colors.white,
      );
    case InteractionType.voiceMessage:
      return (
        emoji: '🎵',
        color: const Color(0xFF059669),
        onColor: Colors.white,
      );
    case InteractionType.soundboard:
      return (
        emoji: '🔊',
        color: const Color(0xFF0891B2),
        onColor: Colors.white,
      );
  }
}

// --- Card widget ---

class _InteractionCard extends StatefulWidget {
  final RunInteractionEntity interaction;
  final VoidCallback onDismiss;
  final VoidCallback? onPlayAudio;

  const _InteractionCard({
    super.key,
    required this.interaction,
    required this.onDismiss,
    this.onPlayAudio,
  });

  @override
  State<_InteractionCard> createState() => _InteractionCardState();
}

class _InteractionCardState extends State<_InteractionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward().then((_) => _pulse.reverse());
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _title {
    final name = widget.interaction.senderName ?? 'Un ami';
    switch (widget.interaction.type) {
      case InteractionType.encouragement:
        return '$name t\'encourage !';
      case InteractionType.emoji:
        return '$name réagit';
      case InteractionType.directMessage:
        return '$name t\'écrit';
      case InteractionType.voiceMessage:
        return '$name t\'envoie un vocal';
      case InteractionType.soundboard:
        return '$name envoie un son';
    }
  }

  String? get _body {
    switch (widget.interaction.type) {
      case InteractionType.encouragement:
      case InteractionType.directMessage:
        return widget.interaction.content;
      case InteractionType.emoji:
        return widget.interaction.content;
      case InteractionType.voiceMessage:
      case InteractionType.soundboard:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _configFor(widget.interaction.type);
    final body = _body;

    return ScaleTransition(
      scale: _scale,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.hardEdge,
        shadowColor: cfg.color.withValues(alpha: 0.4),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cfg.color, cfg.color.withValues(alpha: 0.82)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Big emoji bubble
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.interaction.type == InteractionType.emoji &&
                            widget.interaction.content != null
                        ? widget.interaction.content!
                        : cfg.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          color: cfg.onColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (body != null && body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cfg.onColor.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Play audio button
                if (widget.onPlayAudio != null) ...[
                  const SizedBox(width: 4),
                  _OverlayIconButton(
                    icon: Icons.play_circle_fill_rounded,
                    color: cfg.onColor,
                    onTap: widget.onPlayAudio!,
                    tooltip: 'Écouter',
                  ),
                ],
                const SizedBox(width: 2),
                _OverlayIconButton(
                  icon: Icons.close_rounded,
                  color: cfg.onColor.withValues(alpha: 0.7),
                  onTap: widget.onDismiss,
                  tooltip: 'Fermer',
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  const _OverlayIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
