import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../providers/run_history_provider.dart';
import '../providers/run_tracking_provider.dart';
import '../widgets/run_static_map_widget.dart';

class RunStatsPage extends ConsumerStatefulWidget {
  final String activityId;

  const RunStatsPage({super.key, required this.activityId});

  @override
  ConsumerState<RunStatsPage> createState() => _RunStatsPageState();
}

class _RunStatsPageState extends ConsumerState<RunStatsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(runActivityDetailProvider(widget.activityId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detailAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('Erreur lors du chargement', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(runActivityDetailProvider(widget.activityId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (detail) {
          final activity = detail.activity;
          final points = detail.points;

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: const PanarBreadcrumb('Récapitulatif'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text('Places aux\nchiffres !', style: theme.textTheme.displaySmall),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text('Parlons peu parlons bien...', style: theme.textTheme.bodyMedium),
                ),

                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.textPrimary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
                  tabs: const [Tab(text: 'Donnée'), Tab(text: 'Parcours')],
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Données tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                        child: Column(
                          children: [
                            _BigStat(
                              value: activity.formattedDuration,
                              label: 'Temps',
                            ),
                            const SizedBox(height: 32),
                            _BigStat(
                              value: activity.formattedDistance.replaceAll(' km', ''),
                              label: 'Kilomètres',
                            ),
                            const SizedBox(height: 32),
                            _BigStat(
                              value: activity.formattedPace.replaceAll(' /km', ''),
                              label: 'Min/Km',
                            ),
                            const SizedBox(height: 48),
                            Row(
                              children: [
                                Expanded(
                                  child: PanarButton(
                                    label: 'Partager',
                                    onPressed: () {},
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PanarButton.black(
                                    label: 'Continuer',
                                    onPressed: () {
                                      ref.read(runTrackingProvider.notifier).resetRun();
                                      context.go(Routes.home);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Parcours tab
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Expanded(child: RunStaticMapWidget(points: points)),
                            const SizedBox(height: 20),
                            PanarButton.black(
                              label: "Retour à l'accueil",
                              onPressed: () {
                                ref.read(runTrackingProvider.notifier).resetRun();
                                context.go(Routes.home);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;

  const _BigStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.londrinaSolid(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
