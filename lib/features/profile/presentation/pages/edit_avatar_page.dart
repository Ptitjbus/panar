import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/experiments/app_experiments.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/domain/entities/avatar_mood.dart';
import '../../../home/presentation/providers/avatar_provider.dart';

const _kAvatarPalette = <String>[
  '#FF6B6B',
  '#4ECDC4',
  '#45B7D1',
  '#FFA07A',
  '#98D8C8',
  '#F7DC6F',
  '#BB8FCE',
  '#85C1E2',
  '#00A8E8',
  '#FF8FAB',
];

class EditAvatarPage extends ConsumerStatefulWidget {
  const EditAvatarPage({super.key});

  @override
  ConsumerState<EditAvatarPage> createState() => _EditAvatarPageState();
}

class _EditAvatarPageState extends ConsumerState<EditAvatarPage> {
  final _nameController = TextEditingController();
  String? _selectedColorHex;
  bool _initialized = false;

  String get _petonVariant => ref.read(
    trackedExperimentVariantProvider(
      AppExperimentKeys.petonCustomizationVariant,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'peton_customization',
              step: 'edit_avatar_opened',
              source: 'profile',
              variant: _petonVariant,
            ),
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null) return const Color(0xFFF4A574);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFF4A574);
    }
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final trimmedName = _nameController.text.trim();

    final success = await ref
        .read(avatarCustomizationNotifierProvider.notifier)
        .updateAvatar(
          userId: user.id,
          displayName: trimmedName,
          colorHex: _selectedColorHex,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Peton mis à jour !'
              : ref.read(avatarCustomizationNotifierProvider).errorMessage ??
                    'Erreur lors de la mise à jour',
        ),
      ),
    );
    if (success) context.pop();
    if (success) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'peton_customization',
              step: 'edit_avatar_saved',
              source: 'profile',
              variant: _petonVariant,
              extraParameters: {
                'has_name': trimmedName.isNotEmpty,
                'has_color': _selectedColorHex != null,
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarAsync = ref.watch(userAvatarProvider);
    final editState = ref.watch(avatarCustomizationNotifierProvider);
    final theme = Theme.of(context);

    final avatar = avatarAsync.valueOrNull;
    if (avatar != null && !_initialized) {
      _initialized = true;
      _nameController.text = avatar.displayName ?? '';
      _selectedColorHex = avatar.colorHex;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  const PanarBreadcrumb('Mon peton'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Modifier mon peton',
                style: theme.textTheme.headlineLarge,
              ),
            ),

            const SizedBox(height: 20),

            // Preview
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(80),
                ),
                child: AnimatedAvatarWidget(
                  isMoving: false,
                  size: 140,
                  mood: AvatarMood.happy,
                  colorFilter: _parseColor(_selectedColorHex),
                  showShadow: false,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nom du peton', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Papanar',
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Couleur du peton',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _kAvatarPalette.map((hex) {
                        final selected = _selectedColorHex == hex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColorHex = hex);
                            unawaited(
                              ref
                                  .read(analyticsServiceProvider)
                                  .logFunnelStep(
                                    funnel: 'peton_customization',
                                    step: 'edit_avatar_color_selected',
                                    source: 'profile',
                                    variant: _petonVariant,
                                    extraParameters: {'avatar_color': hex},
                                  ),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _parseColor(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    PanarButton.black(
                      label: editState.isLoading
                          ? 'Sauvegarde...'
                          : 'Sauvegarder',
                      onPressed: editState.isLoading ? null : _save,
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
}
