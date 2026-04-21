import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/experiments/app_experiments.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../../shared/widgets/panar_wizard_footer.dart';
import '../../../notifications/notification_setup_service.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

// Steps:
// 0: Username      — "Comment on t'appel ?"
// 1: Activity      — "Comment tu te défini ?"
// 2: Time          — "Tu es plutôt ?"
// 3: Location      — localisation permission
// 4: Notifications — notifications permission
// 5: Avatar        — personnalise ton Peton
// 6: Friends       — ramène tes potes

const _kTotalSteps = 7;

// Preset avatar colors (stored as 8-char ARGB hex, no '#')
const _kAvatarColors = [
  ('FFF4A574', Color(0xFFF4A574)), // orange (default)
  ('FF9B5FE0', Color(0xFF9B5FE0)), // violet
  ('FF5B8FE8', Color(0xFF5B8FE8)), // bleu
  ('FF5BC490', Color(0xFF5BC490)), // vert
  ('FFE85B8F', Color(0xFFE85B8F)), // rose
  ('FFFFE066', Color(0xFFFFE066)), // jaune
  ('FFE85B5B', Color(0xFFE85B5B)), // rouge
];

class UsernameSetupPage extends ConsumerStatefulWidget {
  const UsernameSetupPage({super.key});

  @override
  ConsumerState<UsernameSetupPage> createState() => _UsernameSetupPageState();
}

class _UsernameSetupPageState extends ConsumerState<UsernameSetupPage> {
  final _pageController = PageController();
  int _step = 0;
  bool _didRestoreProgress = false;

  // Step 0 – username
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isCheckingAvailability = false;
  bool? _isAvailable;

  // Step 1 – activity
  int? _selectedActivity;

  // Step 2 – time preference
  int? _selectedTime;

  // Step 5 – avatar color (ARGB hex string)
  String _selectedAvatarColor = _kAvatarColors[0].$1;

  String get _onboardingVariant => ref.read(
    trackedExperimentVariantProvider(AppExperimentKeys.onboardingVariant),
  );

  String get _petonVariant => ref.read(
    trackedExperimentVariantProvider(
      AppExperimentKeys.petonCustomizationVariant,
    ),
  );

  @override
  void dispose() {
    _usernameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'onboarding',
              step: 'username_setup_opened',
              source: 'route',
              variant: _onboardingVariant,
            ),
      );
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    if (_step < _kTotalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'onboarding',
            step: 'wizard_completed',
            source: 'username_setup',
            variant: _onboardingVariant,
          ),
    );

    // Set flag immediately so the router doesn't redirect back to this page
    // while the async DB write is in-flight.
    ref.read(wizardCompleteProvider.notifier).state = true;

    await ref
        .read(profileNotifierProvider.notifier)
        .markOnboardingComplete(avatarColor: _selectedAvatarColor);

    if (mounted) context.go(Routes.home);
  }

  // ── Permission handlers ───────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    var granted = false;
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        final permission = await Geolocator.requestPermission();
        granted =
            permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always;
      } else if (status == LocationPermission.whileInUse ||
          status == LocationPermission.always) {
        granted = true;
      } else if (status == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
    await ref
        .read(profileNotifierProvider.notifier)
        .updateOnboardingProgress(onboardingLocationPermissionGranted: granted);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'onboarding',
            step: granted
                ? 'location_permission_accepted'
                : 'location_permission_denied',
            source: 'username_setup',
            variant: _onboardingVariant,
          ),
    );
    _next();
  }

  Future<void> _requestNotifications() async {
    var granted = false;
    try {
      await NotificationSetupService.initialize(requestPermission: true);
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {}
    await ref
        .read(profileNotifierProvider.notifier)
        .updateOnboardingProgress(
          onboardingNotificationsPermissionGranted: granted,
        );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'onboarding',
            step: granted
                ? 'notification_permission_accepted'
                : 'notification_permission_denied',
            source: 'username_setup',
            variant: _onboardingVariant,
          ),
    );
    _next();
  }

  Future<void> _skipLocation() async {
    await ref
        .read(profileNotifierProvider.notifier)
        .updateOnboardingProgress(onboardingLocationPermissionGranted: false);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'onboarding',
            step: 'location_permission_skipped',
            source: 'username_setup',
            variant: _onboardingVariant,
          ),
    );
    _next();
  }

  Future<void> _skipNotifications() async {
    await ref
        .read(profileNotifierProvider.notifier)
        .updateOnboardingProgress(
          onboardingNotificationsPermissionGranted: false,
        );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'onboarding',
            step: 'notification_permission_skipped',
            source: 'username_setup',
            variant: _onboardingVariant,
          ),
    );
    _next();
  }

  Future<void> _saveAvatarAndNext() async {
    await ref
        .read(profileNotifierProvider.notifier)
        .updateOnboardingProgress(
          onboardingAvatarDone: true,
          avatarColor: _selectedAvatarColor,
        );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'peton_customization',
            step: 'avatar_color_confirmed',
            source: 'username_setup',
            variant: _petonVariant,
            extraParameters: {'avatar_color': _selectedAvatarColor},
          ),
    );
    _next();
  }

  int _firstIncompleteStep(ProfileEntity profile) {
    if (!profile.onboardingUsernameDone && !profile.hasCompletedOnboarding) {
      return 0;
    }
    if (profile.onboardingActivityIndex == null) return 1;
    if (profile.onboardingTimeIndex == null) return 2;
    if (profile.onboardingLocationPermissionGranted == null) return 3;
    if (profile.onboardingNotificationsPermissionGranted == null) return 4;
    if (!profile.onboardingAvatarDone) return 5;
    return 6;
  }

  void _restoreProgress(ProfileEntity profile) {
    if (_didRestoreProgress) return;
    _didRestoreProgress = true;

    final targetStep = _firstIncompleteStep(profile);
    final username = profile.username.trim();

    setState(() {
      if (username.isNotEmpty) {
        _usernameController.text = username;
      }
      _selectedActivity = profile.onboardingActivityIndex;
      _selectedTime = profile.onboardingTimeIndex;
      _selectedAvatarColor = profile.avatarColor ?? _selectedAvatarColor;
      _step = targetStep;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.jumpToPage(targetStep);

      if (targetStep == 0 && username.isNotEmpty) {
        final err = Validators.validateUsername(username);
        if (err == null) {
          _checkAvailability(username);
        }
      }
    });
  }

  // ── Username step helpers ─────────────────────────────────────────────────

  Future<void> _checkAvailability(String username) async {
    if (username.length < 3) {
      setState(() => _isAvailable = null);
      return;
    }
    setState(() => _isCheckingAvailability = true);
    try {
      final isAvailable = await ref
          .read(profileNotifierProvider.notifier)
          .checkUsernameAvailability(username);
      if (mounted) {
        setState(() {
          _isAvailable = isAvailable;
          _isCheckingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingAvailability = false;
          _isAvailable = null;
        });
      }
    }
  }

  Future<void> _submitUsername() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAvailable != true) return;

    final username = _usernameController.text.trim();
    final success = await ref
        .read(profileNotifierProvider.notifier)
        .updateUsername(username);

    if (success && mounted) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'peton_customization',
              step: 'peton_name_confirmed',
              source: 'username_setup',
              variant: _petonVariant,
            ),
      );
      await ref
          .read(profileNotifierProvider.notifier)
          .updateOnboardingProgress(onboardingUsernameDone: true);
      _next();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    if (profile != null && !_didRestoreProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restoreProgress(profile);
      });
    }

    ref.listen<ProfileState>(profileNotifierProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _UsernameStep(
            formKey: _formKey,
            controller: _usernameController,
            isChecking: _isCheckingAvailability,
            isAvailable: _isAvailable,
            isLoading: profileState.isLoading,
            step: _step,
            onChanged: (v) {
              final err = Validators.validateUsername(v);
              if (err == null) {
                _checkAvailability(v);
              } else {
                setState(() => _isAvailable = null);
              }
            },
            onContinue: (_isAvailable == true && !profileState.isLoading)
                ? _submitUsername
                : null,
            continueLabel: profileState.isLoading
                ? 'Chargement...'
                : 'Continuer',
          ),
          _ChoiceStep(
            step: _step,
            category: 'Profil',
            question: 'Comment tu te défini ?',
            choices: const [
              'Je marche pour me détendre 🚶🏽‍♂️',
              'Je cours après le bus 🚌',
              'Je cours pour ma santé 🍻',
              'Je veux être régulier ⏱️',
            ],
            selected: _selectedActivity,
            onSelect: (i) {
              setState(() => _selectedActivity = i);
              unawaited(
                ref
                    .read(analyticsServiceProvider)
                    .logFunnelStep(
                      funnel: 'onboarding',
                      step: 'activity_selected',
                      source: 'username_setup',
                      variant: _onboardingVariant,
                      extraParameters: {'activity_index': i},
                    ),
              );
              unawaited(
                ref
                    .read(profileNotifierProvider.notifier)
                    .updateOnboardingProgress(onboardingActivityIndex: i),
              );
            },
            onBack: _back,
            onContinue: _selectedActivity != null ? _next : null,
          ),
          _ChoiceStep(
            step: _step,
            category: 'Profil',
            question: 'Tu es plutôt ?',
            choices: const [
              'Lève tôt 🌅',
              "Tabasseur d'oreiller 🛌",
              'En activité pour digérer 🍔',
              'Coureur de jupon 🌃',
            ],
            selected: _selectedTime,
            onSelect: (i) {
              setState(() => _selectedTime = i);
              unawaited(
                ref
                    .read(analyticsServiceProvider)
                    .logFunnelStep(
                      funnel: 'onboarding',
                      step: 'time_selected',
                      source: 'username_setup',
                      variant: _onboardingVariant,
                      extraParameters: {'time_index': i},
                    ),
              );
              unawaited(
                ref
                    .read(profileNotifierProvider.notifier)
                    .updateOnboardingProgress(onboardingTimeIndex: i),
              );
            },
            onBack: _back,
            onContinue: _selectedTime != null ? _next : null,
          ),
          _PermissionStep(
            step: _step,
            category: 'Confidentialité',
            question:
                'On a besoin de te pister pour profiter pleinement de Panar 🗺️',
            actionLabel: 'Autoriser la localisation',
            onBack: _back,
            onAction: _requestLocation,
            onSkip: () {
              unawaited(_skipLocation());
            },
          ),
          _PermissionStep(
            step: _step,
            category: 'Confidentialité',
            question:
                'On a également besoin de te bipper, 30 à 40 fois par jour 🤯',
            actionLabel: 'Autoriser les notifications',
            onBack: _back,
            onAction: _requestNotifications,
            onSkip: () {
              unawaited(_skipNotifications());
            },
          ),
          _AvatarStep(
            step: _step,
            selectedColor: _selectedAvatarColor,
            onColorSelected: (hex) {
              setState(() => _selectedAvatarColor = hex);
              unawaited(
                ref
                    .read(analyticsServiceProvider)
                    .logFunnelStep(
                      funnel: 'peton_customization',
                      step: 'avatar_color_selected',
                      source: 'username_setup',
                      variant: _petonVariant,
                      extraParameters: {'avatar_color': hex},
                    ),
              );
            },
            onBack: _back,
            onContinue: () {
              unawaited(_saveAvatarAndNext());
            },
          ),
          _FriendsStep(step: _step, onBack: _back, onFinish: _finish),
        ],
      ),
    );
  }
}

// ── Shared: progress bar + header ─────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int step;
  final String category;

  const _StepHeader({required this.step, required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.surface),
                FractionallySizedBox(
                  widthFactor: (step + 1) / _kTotalSteps,
                  child: Container(height: 8, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PanarBreadcrumb(category),
        ),
      ],
    );
  }
}

// ── Step 0: Username ──────────────────────────────────────────────────────────

class _UsernameStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isChecking;
  final bool? isAvailable;
  final bool isLoading;
  final int step;
  final ValueChanged<String> onChanged;
  final VoidCallback? onContinue;
  final String continueLabel;

  const _UsernameStep({
    required this.formKey,
    required this.controller,
    required this.isChecking,
    required this.isAvailable,
    required this.isLoading,
    required this.step,
    required this.onChanged,
    required this.onContinue,
    required this.continueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _StepHeader(step: step, category: 'Profil'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Comment on t'appel ?",
              style: theme.textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                enabled: !isLoading,
                validator: Validators.validateUsername,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: 'Ton pseudo de peton...',
                  suffixIcon: isChecking
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : isAvailable == true
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : isAvailable == false
                      ? const Icon(Icons.error, color: AppColors.danger)
                      : null,
                ),
              ),
            ),
          ),
          if (isAvailable == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Ce pseudo est déjà pris',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ),
          const Spacer(),
          PanarWizardFooter(
            onContinue: onContinue,
            continueLabel: continueLabel,
          ),
        ],
      ),
    );
  }
}

// ── Steps 1 & 2: Choice ───────────────────────────────────────────────────────

class _ChoiceStep extends StatelessWidget {
  final int step;
  final String category;
  final String question;
  final List<String> choices;
  final int? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  const _ChoiceStep({
    required this.step,
    required this.category,
    required this.question,
    required this.choices,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _StepHeader(step: step, category: category),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(question, style: theme.textTheme.headlineLarge),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: choices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final isSelected = selected == i;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      choices[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          PanarWizardFooter(onBack: onBack, onContinue: onContinue),
        ],
      ),
    );
  }
}

// ── Steps 3 & 4: Permission ───────────────────────────────────────────────────

class _PermissionStep extends StatelessWidget {
  final int step;
  final String category;
  final String question;
  final String actionLabel;
  final VoidCallback onBack;
  final VoidCallback onAction;
  final VoidCallback onSkip;

  const _PermissionStep({
    required this.step,
    required this.category,
    required this.question,
    required this.actionLabel,
    required this.onBack,
    required this.onAction,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _StepHeader(step: step, category: category),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(question, style: theme.textTheme.headlineLarge),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PanarButton(label: actionLabel, onPressed: onAction),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: onSkip,
              child: Text(
                'Pas maintenant',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const Spacer(),
          PanarWizardFooter(onBack: onBack, onContinue: onSkip),
        ],
      ),
    );
  }
}

// ── Step 5: Avatar ────────────────────────────────────────────────────────────

class _AvatarStep extends StatelessWidget {
  final int step;
  final String selectedColor;
  final ValueChanged<String> onColorSelected;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _AvatarStep({
    required this.step,
    required this.selectedColor,
    required this.onColorSelected,
    required this.onBack,
    required this.onContinue,
  });

  Color get _currentColor {
    final hex = selectedColor;
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _StepHeader(step: step, category: 'Personnalisation'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Personnalise\nton Peton !',
              style: theme.textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 24),

          // Avatar preview
          Expanded(
            child: Center(
              child: AnimatedAvatarWidget(
                isMoving: true,
                size: 240,
                colorFilter: _currentColor,
                showShadow: false,
              ),
            ),
          ),

          // Color picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _kAvatarColors.map((entry) {
                final (hex, color) = entry;
                final isSelected = selectedColor == hex;
                return GestureDetector(
                  onTap: () => onColorSelected(hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          PanarWizardFooter(
            onBack: onBack,
            onContinue: onContinue,
            continueLabel: 'Continuer',
          ),
        ],
      ),
    );
  }
}

// ── Step 6: Friends ───────────────────────────────────────────────────────────

class _FriendsStep extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _FriendsStep({
    required this.step,
    required this.onBack,
    required this.onFinish,
  });

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: 'https://panar.app'));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lien copié !')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _StepHeader(step: step, category: 'Invitation'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Ramène tes potes et motives les avec des défis',
              style: theme.textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 32),

          // QR + Copy link row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // QR placeholder
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_2,
                      size: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _copyLink(context),
                    child: Container(
                      height: 66,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Copier le lien',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Astuce du Panar', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Tu recevras 500 💡 par ami qui nous rejoint',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const Spacer(),

          Center(
            child: GestureDetector(
              onTap: onFinish,
              child: Text(
                'Pas maintenant',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          PanarWizardFooter(
            onBack: onBack,
            onContinue: onFinish,
            continueLabel: 'Terminer',
          ),
        ],
      ),
    );
  }
}
