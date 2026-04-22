import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/group_challenge_card.dart';

class DuelsPage extends ConsumerWidget {
  const DuelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final theme = Theme.of(context);

    final completedCount = state.myChallenges
        .where((c) => c.isCompleted)
        .length;
    final activeCount = state.myChallenges.where((c) => c.isActive).length;
    final boardPosition = completedCount.clamp(0, 30);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(groupChallengeNotifierProvider.notifier)
              .loadChallenges(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanarBreadcrumb('Collaboration'),
                      const SizedBox(height: 12),
                      Text(
                        'A deux on va plus loin !',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Petit pas par petit pas',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _CollaborativeBoardCard(
                    position: boardPosition,
                    completedCount: completedCount,
                    activeCount: activeCount,
                  ),
                ),
              ),
              if (state.pendingInvites.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Text(
                      'Invitations reçues',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final challenge = state.pendingInvites[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: GroupChallengeCard(
                        challenge: challenge,
                        currentUserId: currentUserId,
                        onRespond: (accept) => ref
                            .read(groupChallengeNotifierProvider.notifier)
                            .respondToChallenge(challenge.id, accept: accept),
                      ),
                    );
                  }, childCount: state.pendingInvites.length),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Mes quêtes collaboratives',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              if (state.myChallenges.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Aucune quête collaborative pour le moment.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: GroupChallengeCard(
                        challenge: state.myChallenges[i],
                        currentUserId: currentUserId,
                      ),
                    ),
                    childCount: state.myChallenges.length,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: PanarButton(
                    label: 'Créer une quête collaborative',
                    onPressed: () => context.push(Routes.createGroupChallenge),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollaborativeBoardCard extends StatelessWidget {
  final int position;
  final int completedCount;
  final int activeCount;

  const _CollaborativeBoardCard({
    required this.position,
    required this.completedCount,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentCase = position <= 0 ? 1 : position;
    final boardPoints = _boardPoints(total: 30);

    return Container(
      height: 620,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plateau collaboratif',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Validez des quêtes ensemble pour avancer case par case.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Case actuelle: $currentCase / 30',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completedCount validées',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BoardPathPainter(points: boardPoints),
                      ),
                    ),
                    ...List.generate(boardPoints.length, (index) {
                      final node = boardPoints[index];
                      final left = node.dx * constraints.maxWidth - 14;
                      final top = node.dy * constraints.maxHeight - 14;
                      final caseNumber = index + 1;
                      final isCurrent = caseNumber == currentCase;

                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.textPrimary
                                : const Color(0xFFC8C8C8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.textPrimary
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                          child: Text(
                            '$caseNumber',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                    if (activeCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$activeCount quête${activeCount > 1 ? 's' : ''} en cours',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Règle: 1 quête collaborative terminée = +1 case',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Offset> _boardPoints({required int total}) {
    return List.generate(total, (index) {
      final t = index / (total - 1);
      final x = 0.5 + 0.38 * math.sin(t * math.pi * 3);
      final y = 0.05 + 0.90 * t;
      return Offset(x, y);
    });
  }
}

class _BoardPathPainter extends CustomPainter {
  final List<Offset> points;

  _BoardPathPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    final first = Offset(
      points.first.dx * size.width,
      points.first.dy * size.height,
    );
    path.moveTo(first.dx, first.dy);

    for (final p in points.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }

    final paint = Paint()
      ..color = const Color(0xFFB2B2B2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BoardPathPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}
