import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onCommencer() async {
    await ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
    if (mounted) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomeStep(onCommencer: _onCommencer),
          const _AuthStep(),
        ],
      ),
    );
  }
}

// ─── Step 0: Welcome ─────────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onCommencer;

  const _WelcomeStep({required this.onCommencer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),

            SizedBox(
              height: 220,
              child: AnimatedAvatarWidget(
                isMoving: false,
                size: 220,
                colorFilter: const Color(0xFFF4A574),
                showShadow: false,
              ),
            ),

            const Spacer(),

            Text(
              'BIENVENUE\nSUR PANAR',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Rejoins la communauté des petons',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 48),

            PanarButton(label: 'Commencer', onPressed: onCommencer),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Auth ─────────────────────────────────────────────────────────────

class _AuthStep extends ConsumerWidget {
  const _AuthStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'NE PERD PAS\nTON PETON',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Et suis-ta progression',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const Spacer(),

            SizedBox(
              height: 260,
              child: AnimatedAvatarWidget(
                isMoving: true,
                size: 260,
                colorFilter: const Color(0xFFF4A574),
                showShadow: false,
              ),
            ),

            const Spacer(),

            // Google button
            _SocialButton(
              iconWidget: Image.asset(
                'assets/images/google_logo.png',
                height: 22,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.login, size: 22),
              ),
              label: 'Inscription avec Google',
              isLoading: isLoading,
              onTap: isLoading
                  ? null
                  : () async {
                      await ref
                          .read(authNotifierProvider.notifier)
                          .signInWithGoogle();
                    },
            ),

            const SizedBox(height: 12),

            // Apple button
            _SocialButton(
              iconWidget:
                  const Icon(Icons.apple, size: 26, color: AppColors.textPrimary),
              label: 'Inscription avec Apple',
              isLoading: isLoading,
              onTap: isLoading ? null : () {},
            ),

            const SizedBox(height: 32),

            GestureDetector(
              onTap: () => context.go(Routes.login),
              child: Text(
                "J'ai déjà un compte",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Social Button ────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _SocialButton({
    required this.iconWidget,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
