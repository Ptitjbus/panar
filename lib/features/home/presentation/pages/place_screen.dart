import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../activities/presentation/providers/activity_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/avatar_provider.dart';
import '../../domain/entities/avatar_entity.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/place_grid.dart';
import '../widgets/user_drawer.dart';

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

  void _centerCameraOnAvatar({bool animate = true}) {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;

    // Get current transformation to preserve scale
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    // Calculate the translation to center the avatar at current position
    final translateX =
        screenSize.width / 2 - _currentAvatarPosition.dx * currentScale;
    final translateY =
        screenSize.height / 2 - _currentAvatarPosition.dy * currentScale;

    // Create target transformation matrix with preserved scale
    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, currentScale) // Scale X
      ..setEntry(1, 1, currentScale) // Scale Y
      ..setEntry(2, 2, currentScale); // Scale Z
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

  void _showUserDrawer(AvatarEntity avatar) {
    if (!mounted) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // Invalidate activities to force refresh
    ref.invalidate(userActivitiesProvider(avatar.userId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: UserDrawer(avatar: avatar, email: user.email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarAsync = ref.watch(userAvatarProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Panar'),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
        elevation: 0,
        actions: [
          // Bouton amis
          IconButton(
            icon: const Icon(Icons.people_outlined),
            tooltip: 'Amis',
            onPressed: () {
              context.push(Routes.friends);
            },
          ),
          // Bouton déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text(
                    'Êtes-vous sûr de vouloir vous déconnecter ?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(Routes.login);
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          avatarAsync.when(
            loading: () => _buildEmptyPlace(context, colorScheme),
            error: (error, stack) {
              // Show error via snackbar
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to load avatar: $error'),
                    backgroundColor: colorScheme.error,
                  ),
                );
              });
              return _buildEmptyPlace(context, colorScheme);
            },
            data: (avatar) {
              if (avatar == null) {
                // No avatar exists yet, show empty place
                return _buildEmptyPlace(context, colorScheme);
              }

              return _buildPlaceWithAvatar(context, colorScheme, avatar);
            },
          ),
          // Recenter button
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'recenter_fab',
              onPressed: _centerCameraOnAvatar,
              tooltip: 'Recentrer sur mon avatar',
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.my_location, color: colorScheme.onPrimary),
            ),
          ),
        ],
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
          child: CustomPaint(
            painter: PlaceGridPainter(colorScheme: colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceWithAvatar(
    BuildContext context,
    ColorScheme colorScheme,
    AvatarEntity avatar,
  ) {
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
          child: CustomPaint(
            painter: PlaceGridPainter(colorScheme: colorScheme),
            child: Stack(
              children: [
                AvatarWidget(
                  avatar: avatar,
                  onPositionChanged: _onAvatarPositionChanged,
                  onTap: () => _showUserDrawer(avatar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
