import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/experiments/app_experiments.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/remote_config_service.dart';
import '../../features/challenges/presentation/pages/challenges_page.dart';
import '../../features/home/presentation/pages/place_screen.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/shop/presentation/pages/shop_page.dart';

class MainLayout extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  late int _currentIndex;
  late PageController _pageController;

  static const List<Widget> _pages = [
    PlaceScreen(),
    ChallengesPage(),
    ShopPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _currentIndex) {
      _onItemTapped(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _trackTabSelection(index, source: 'swipe');
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
    _trackTabSelection(index, source: 'bottom_nav');
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _trackTabSelection(int index, {required String source}) {
    final analytics = ref.read(analyticsServiceProvider);
    final tabName = switch (index) {
      0 => 'map',
      1 => 'challenges',
      2 => 'shop',
      3 => 'profile',
      _ => 'unknown',
    };

    unawaited(
      analytics.logFunnelStep(
        funnel: 'navigation',
        step: 'tab_selected',
        source: source,
        extraParameters: {'tab': tabName},
      ),
    );

    if (index == 2) {
      final variant = ref.read(
        trackedExperimentVariantProvider(
          AppExperimentKeys.shopEngagementVariant,
        ),
      );
      unawaited(
        analytics.logFunnelStep(
          funnel: 'shop',
          step: 'shop_page_opened',
          source: source,
          variant: variant,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: _currentIndex == 0
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        children: _pages,
      ),
      floatingActionButton: _RunFab(
        onPressed: () {
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
                  step: 'open_run_launch',
                  source: 'run_fab',
                  variant: variant,
                ),
          );
          context.push(Routes.runTracking);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _PanarBottomBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _RunFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _RunFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        heroTag: 'run_fab',
        onPressed: onPressed,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.rocket_launch_outlined, size: 28),
      ),
    );
  }
}

class _PanarBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PanarBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.sentiment_satisfied_alt_outlined,
            activeIcon: Icons.sentiment_satisfied_alt,
            label: 'Carte',
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield,
            label: 'Défis',
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          const SizedBox(width: 64),
          _NavItem(
            icon: Icons.shopping_bag_outlined,
            activeIcon: Icons.shopping_bag,
            label: 'Boutique',
            isSelected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.remove_red_eye_outlined,
            activeIcon: Icons.remove_red_eye,
            label: 'Profil',
            isSelected: currentIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.textPrimary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
