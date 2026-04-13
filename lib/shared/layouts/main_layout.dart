import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_constants.dart';
import '../../features/challenges/presentation/pages/challenges_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/shop/presentation/pages/shop_page.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  late PageController _pageController;

  static const List<Widget> _pages = [
    HomePage(),
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      floatingActionButton: _RunFab(
        onPressed: () => context.push(Routes.runLaunch),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Accueil',
              isSelected: _currentIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            _NavItem(
              icon: Icons.emoji_events_outlined,
              activeIcon: Icons.emoji_events,
              label: 'Défis',
              isSelected: _currentIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            // Espace central pour le FAB
            const SizedBox(width: 64),
            _NavItem(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag,
              label: 'Boutique',
              isSelected: _currentIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profil',
              isSelected: _currentIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _RunFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.play_arrow_rounded, size: 36),
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
    final colorScheme = Theme.of(context).colorScheme;
    final color =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
