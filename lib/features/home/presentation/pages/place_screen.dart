import 'dart:math' as math;
import 'dart:async';
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
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../../friends/presentation/widgets/friend_list_item.dart';
import '../../../friends/presentation/widgets/friend_request_item.dart';
import '../../../friends/presentation/widgets/friend_search_dialog.dart';
import '../../../friends/presentation/widgets/sent_request_item.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../live_interactions/domain/entities/run_interaction_entity.dart';
import '../../../live_interactions/presentation/providers/live_interactions_provider.dart';
import '../../../live_interactions/presentation/providers/run_session_provider.dart';
import '../providers/avatar_provider.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../domain/entities/avatar_mood.dart';
import '../../../live_interactions/domain/entities/run_session_entity.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/quick_interaction_sheet.dart';

/// Main screen displaying the Place interactive map
class PlaceScreen extends ConsumerStatefulWidget {
  const PlaceScreen({super.key});

  @override
  ConsumerState<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends ConsumerState<PlaceScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  Offset _currentAvatarPosition = const Offset(1000, 1000);

  String get _mapVariant => ref.read(
    trackedExperimentVariantProvider(
      AppExperimentKeys.interactiveMapDuelVariant,
    ),
  );

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Center camera on avatar position after first frame without animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCameraOnAvatar(animate: false);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onAvatarPositionChanged(Offset position) {
    if (!mounted) return;
    // Update position without setState - only used by _centerCameraOnAvatar
    _currentAvatarPosition = position;
  }

  // Default zoom applied on first load — 1.0 = full canvas visible, 2.0 = 2× closer
  static const double _initialZoom = 1.75;

  void _centerCameraOnAvatar({bool animate = true}) {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;

    // Get current transformation to preserve scale
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    // On the very first (non-animated) call the scale is still the default 1.0.
    // Use a closer zoom so avatars are not too small.
    final targetScale = (!animate && currentScale == 1.0)
        ? _initialZoom
        : currentScale;

    // Calculate the translation to center the avatar at current position
    final translateX =
        screenSize.width / 2 - _currentAvatarPosition.dx * targetScale;
    final translateY =
        screenSize.height / 2 - _currentAvatarPosition.dy * targetScale;

    // Create target transformation matrix with preserved scale
    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, targetScale) // Scale X
      ..setEntry(1, 1, targetScale) // Scale Y
      ..setEntry(2, 2, targetScale); // Scale Z
    targetMatrix.setTranslationRaw(translateX, translateY, 0);

    // Apply transformation directly or with animation
    if (!animate) {
      // No animation - just set the value directly
      _transformationController.value = targetMatrix;
      return;
    }

    // Animate from current to target matrix
    _animation = Matrix4Tween(begin: currentMatrix, end: targetMatrix).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    void listener() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    }

    _animation!.addListener(listener);

    _animationController.reset();
    _animationController.forward().then((_) {
      _animation?.removeListener(listener);
      _animation = null;
    });
  }

  Future<void> _sendInteraction({
    required RunSessionEntity session,
    required AvatarEntity avatar,
    required InteractionType type,
    String? content,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(sendInteractionProvider(session.id).notifier)
          .send(
            sessionId: session.id,
            runnerId: avatar.userId,
            type: type,
            content: content,
          );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Interaction envoyée')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Envoi impossible: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openChallengeForFriend(String friendId) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'interactive_map',
            step: 'challenge_friend_from_map',
            source: 'place_screen',
            variant: _mapVariant,
          ),
    );
    context.push(Routes.createDuel, extra: {'friendId': friendId});
  }

  void _openProfileTab() {
    context.go(Routes.home, extra: {'index': 3});
  }

  void _openFriendSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => const FriendSearchDialog(),
    );
  }

  Future<void> _showEmojiPicker(
    AvatarEntity avatar,
    RunSessionEntity? session,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final emoji in [
                '👏',
                '💪',
                '🚀',
                '🙌',
                '⚡',
                '🤝',
                '🫶',
                '🥵',
              ])
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(emoji),
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible: cet ami ne court pas en direct.'),
        ),
      );
      return;
    }
    await _sendInteraction(
      session: session,
      avatar: avatar,
      type: InteractionType.emoji,
      content: selected,
    );
  }

  void _showQuickInteractionSheet(
    AvatarEntity avatar, {
    required String username,
    RunSessionEntity? session,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isOnline = session != null;
        return QuickInteractionSheet(
          avatar: avatar,
          username: username,
          isOnline: isOnline,
          onWatchLive: session != null
              ? () {
                  final variant = ref.read(
                    trackedExperimentVariantProvider(
                      AppExperimentKeys.runLaunchLiveVariant,
                    ),
                  );
                  unawaited(
                    ref
                        .read(analyticsServiceProvider)
                        .logFunnelStep(
                          funnel: 'live_interaction',
                          step: 'watch_live_from_map',
                          source: 'quick_interaction_sheet',
                          variant: variant,
                        ),
                  );
                  Navigator.of(sheetContext).pop();
                  context.push(
                    Routes.friendLiveRun,
                    extra: {
                      'sessionId': session.id,
                      'runnerId': avatar.userId,
                      'runnerName': username,
                    },
                  );
                }
              : null,
          onChallenge: () {
            Navigator.of(sheetContext).pop();
            _openChallengeForFriend(avatar.userId);
          },
          onCheer: session == null
              ? null
              : () {
                  final variant = ref.read(
                    trackedExperimentVariantProvider(
                      AppExperimentKeys.runLaunchLiveVariant,
                    ),
                  );
                  unawaited(
                    ref
                        .read(analyticsServiceProvider)
                        .logFunnelStep(
                          funnel: 'live_interaction',
                          step: 'cheer_friend_from_map',
                          source: 'quick_interaction_sheet',
                          variant: variant,
                        ),
                  );
                  Navigator.of(sheetContext).pop();
                  context.push(
                    Routes.friendLiveRun,
                    extra: {
                      'sessionId': session.id,
                      'runnerId': avatar.userId,
                      'runnerName': username,
                    },
                  );
                },
          onSendEmoji: (emoji) async {
            if (session == null) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cet ami n’a pas de course live en cours.'),
                ),
              );
              return;
            }
            Navigator.of(sheetContext).pop();
            final variant = ref.read(
              trackedExperimentVariantProvider(
                AppExperimentKeys.runLaunchLiveVariant,
              ),
            );
            unawaited(
              ref
                  .read(analyticsServiceProvider)
                  .logFunnelStep(
                    funnel: 'live_interaction',
                    step: 'emoji_sent_from_map',
                    source: 'quick_interaction_sheet',
                    variant: variant,
                    extraParameters: {'interaction_type': 'emoji'},
                  ),
            );
            await _sendInteraction(
              session: session,
              avatar: avatar,
              type: InteractionType.emoji,
              content: emoji,
            );
          },
          onOpenEmojiPicker: () async {
            Navigator.of(sheetContext).pop();
            await _showEmojiPicker(avatar, session);
          },
        );
      },
    );
  }

  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final avatarAsync = ref.watch(userAvatarProvider);
    final moodAsync = ref.watch(userAvatarMoodProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Content area — map (Communauté) or friends list (Amis)
          if (_tabIndex == 0)
            avatarAsync.when(
              loading: () => _buildEmptyPlace(context, colorScheme),
              error: (error, stack) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load avatar: $error')),
                  );
                });
                return _buildEmptyPlace(context, colorScheme);
              },
              data: (avatar) {
                if (avatar == null) {
                  return _buildEmptyPlace(context, colorScheme);
                }
                final mood = moodAsync.valueOrNull ?? AvatarMood.neutral;
                return _buildPlaceWithAvatar(
                  context,
                  colorScheme,
                  avatar,
                  mood,
                );
              },
            )
          else
            _buildFriendsList(context),

          // Top overlay: search + toggle + notifications
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _PlaceIconButton(
                  icon: _tabIndex == 1 ? Icons.person_add : Icons.search,
                  onTap: () {
                    if (_tabIndex == 1) {
                      unawaited(
                        ref
                            .read(analyticsServiceProvider)
                            .logFunnelStep(
                              funnel: 'interactive_map',
                              step: 'open_friend_search',
                              source: 'place_screen',
                              variant: _mapVariant,
                            ),
                      );
                      _openFriendSearchDialog();
                      return;
                    }
                    setState(() => _tabIndex = 1);
                  },
                ),
                const Spacer(),
                _TabToggle(
                  tabs: const ['Communauté', 'Amis'],
                  selectedIndex: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
                const Spacer(),
                const _NotificationBell(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final currentUserId = ref.read(authStateProvider).value?.id ?? '';
    final theme = Theme.of(context);

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Space for top overlay
            SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Mes amis', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openFriendSearchDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                    ),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: friendsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      children: [
                        if (friendsState.receivedRequests.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Demandes reçues',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          ...friendsState.receivedRequests.map((request) {
                            final requesterProfile = request.requesterProfile;
                            if (requesterProfile == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FriendRequestItem(
                                friendship: request,
                                requesterUsername: requesterProfile.username,
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                        if (friendsState.sentRequests.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Demandes envoyées',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          ...friendsState.sentRequests.map((request) {
                            final addresseeProfile = request.addresseeProfile;
                            if (addresseeProfile == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SentRequestItem(
                                friendship: request,
                                addresseeUsername: addresseeProfile.username,
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                        if (friendsState.friends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: Text(
                              'Aucun ami pour le moment.\nUtilise "Ajouter" pour en trouver !',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        else
                          ...friendsState.friends.map((f) {
                            final profile = f.getOtherUserProfile(
                              currentUserId,
                            );
                            if (profile == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FriendListItem(
                                friendship: f,
                                friendUsername: profile.username,
                              ),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlace(BuildContext context, ColorScheme colorScheme) {
    return SafeArea(
      top: false, // Allow map to extend behind AppBar
      child: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: EdgeInsets.zero,
        minScale: 0.5,
        maxScale: 3.0,
        constrained: false,
        child: SizedBox(
          width: 2000,
          height: 2000,
          child: _PlaceBackground(colorScheme: colorScheme),
        ),
      ),
    );
  }

  Widget _buildPlaceWithAvatar(
    BuildContext context,
    ColorScheme colorScheme,
    AvatarEntity avatar,
    AvatarMood mood,
  ) {
    final friendsAvatarsAsync = ref.watch(friendsAvatarsProvider);
    final activeSessionsAsync = ref.watch(activeFriendSessionsProvider);
    final user = ref.read(authStateProvider).value;
    final currentUserId = user?.id ?? '';

    // Build username map from profiles (always up-to-date, unlike avatar.displayName)
    final friendsState = ref.watch(friendsNotifierProvider);
    final friendUsernameById = <String, String>{
      for (final f in friendsState.friends)
        f.getOtherUserId(currentUserId):
            f.getOtherUserProfile(currentUserId)?.username ?? '',
    };

    final activeSessions = activeSessionsAsync.valueOrNull ?? [];
    final activeFriendIds = activeSessions.map((s) => s.userId).toSet();
    final activeSessionsByUserId = {
      for (final s in activeSessions) s.userId: s,
    };

    return SafeArea(
      top: false, // Allow map to extend behind AppBar
      child: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: EdgeInsets.zero,
        minScale: 0.5,
        maxScale: 3.0,
        constrained: false,
        child: SizedBox(
          width: 2000,
          height: 2000,
          child: _PlaceBackground(
            colorScheme: colorScheme,
            child: Stack(
              children: [
                // Current user avatar
                AvatarWidget(
                  key: const ValueKey('user_avatar'),
                  avatar: avatar,
                  mood: mood,
                  onPositionChanged: _onAvatarPositionChanged,
                  onTap: _openProfileTab,
                ),
                // Friends avatars (on top)
                ...friendsAvatarsAsync.when(
                  data: (friendsAvatars) => friendsAvatars.map((friendAvatar) {
                    // Create a random initial position for each friend closely around the center
                    final random = math.Random(friendAvatar.id.hashCode);
                    final distance =
                        60 + random.nextDouble() * 100; // max 160 px distance
                    final angle = random.nextDouble() * 2 * math.pi;
                    final initialPosition = Offset(
                      1000 + math.cos(angle) * distance,
                      1000 + math.sin(angle) * distance,
                    );

                    final isRunning = activeFriendIds.contains(
                      friendAvatar.userId,
                    );

                    return AvatarWidget(
                      key: ValueKey('friend_${friendAvatar.id}'),
                      avatar: friendAvatar,
                      initialPosition: initialPosition,
                      isRunning: isRunning,
                      onTap: () => _showQuickInteractionSheet(
                        friendAvatar,
                        username:
                            friendUsernameById[friendAvatar.userId] ??
                            friendAvatar.displayName ??
                            '',
                        session: activeSessionsByUserId[friendAvatar.userId],
                      ),
                    );
                  }).toList(),
                  loading: () => [],
                  error: (error, stack) => [],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationCountProvider);

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const NotificationsPage(),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PlaceIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _PlaceBackground extends StatelessWidget {
  final ColorScheme colorScheme;
  final Widget child;

  const _PlaceBackground({
    required this.colorScheme,
    this.child = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/map.png', fit: BoxFit.cover),
        ColoredBox(color: colorScheme.surface.withValues(alpha: 0.06)),
        child,
      ],
    );
  }
}

class _TabToggle extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabToggle({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (i) {
          final selected = selectedIndex == i;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.textPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[i],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
