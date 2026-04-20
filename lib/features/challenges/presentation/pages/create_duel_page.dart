import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/experiments/app_experiments.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';

enum _CreateDefiStep { friends, groupSize, difficulty, type, naming }

const _kDefiTypes = <String>[
  'Fréquence de course',
  'Dénivelé',
  'Distance',
  'Thème',
  'Tant qu\'on transpire c\'est bon',
];

const _kDefiDifficulties = <String, double>{
  'Tranquille': 3000,
  'Ça commence à chauffer': 5000,
  'Très dur': 10000,
  'Tape pas dans le muuur gros': 21097,
};

class CreateDuelPage extends ConsumerStatefulWidget {
  final String? initialFriendId;

  const CreateDuelPage({super.key, this.initialFriendId});

  @override
  ConsumerState<CreateDuelPage> createState() => _CreateDuelPageState();
}

class _CreateDuelPageState extends ConsumerState<CreateDuelPage> {
  bool _isSolo = false;
  _CreateDefiStep _currentStep = _CreateDefiStep.friends;

  int _groupSize = 2;
  String _selectedDifficulty = _kDefiDifficulties.keys.first;
  String _selectedType = _kDefiTypes.first;
  final Set<String> _selectedFriendIds = <String>{};
  final TextEditingController _defiNameController = TextEditingController();

  bool _isSubmitting = false;

  String get _challengeCreationVariant => ref.read(
    trackedExperimentVariantProvider(
      AppExperimentKeys.challengeCreationVariant,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialFriendId != null && widget.initialFriendId!.isNotEmpty) {
      _selectedFriendIds.add(widget.initialFriendId!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'challenge_creation',
              step: 'create_duel_opened',
              source: 'create_duel_page',
              variant: _challengeCreationVariant,
            ),
      );
    });
  }

  @override
  void dispose() {
    _defiNameController.dispose();
    super.dispose();
  }

  List<_CreateDefiStep> get _flow {
    return [
      _CreateDefiStep.friends,
      if (!_isSolo && _groupSize > 2) _CreateDefiStep.groupSize,
      _CreateDefiStep.difficulty,
      _CreateDefiStep.type,
      _CreateDefiStep.naming,
    ];
  }

  bool _canProceedFromCurrentStep() {
    switch (_currentStep) {
      case _CreateDefiStep.groupSize:
      case _CreateDefiStep.difficulty:
      case _CreateDefiStep.type:
        return true;
      case _CreateDefiStep.friends:
        return _isSolo || _selectedFriendIds.isNotEmpty;
      case _CreateDefiStep.naming:
        return _defiNameController.text.trim().isNotEmpty;
    }
  }

  void _goNext() {
    if (!_canProceedFromCurrentStep()) {
      final message = switch (_currentStep) {
        _CreateDefiStep.friends => 'Sélectionne au moins un ami ou joue solo.',
        _CreateDefiStep.naming => 'Donne un nom à ton défi.',
        _ => 'Complète cette étape.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'challenge_creation',
            step: 'step_validated',
            source: 'create_duel_page',
            variant: _challengeCreationVariant,
            extraParameters: {'step': _currentStep.name},
          ),
    );
    final flow = _flow;
    final idx = flow.indexOf(_currentStep);
    if (idx < flow.length - 1) {
      setState(() => _currentStep = flow[idx + 1]);
    }
  }

  void _goBack() {
    final flow = _flow;
    final idx = flow.indexOf(_currentStep);
    if (idx > 0) {
      setState(() => _currentStep = flow[idx - 1]);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (!_canProceedFromCurrentStep()) {
      _goNext();
      return;
    }

    setState(() => _isSubmitting = true);

    final notifier = ref.read(duelNotifierProvider.notifier);
    final targetDistance = _kDefiDifficulties[_selectedDifficulty];
    final challengeName = _defiNameController.text.trim();
    final modeLabel = _isSolo ? 'solo' : 'group';
    final description =
        '$challengeName • $_selectedType • $_selectedDifficulty • mode:$modeLabel';

    int created = 0;

    if (_isSolo) {
      final duel = await notifier.createDuel(
        timing: DuelTiming.live,
        targetDistanceMeters: targetDistance,
        description: description,
      );
      if (duel != null) created++;
    } else {
      for (final friendId in _selectedFriendIds) {
        final duel = await notifier.createDuel(
          challengedId: friendId,
          timing: DuelTiming.live,
          targetDistanceMeters: targetDistance,
          description: description,
        );
        if (duel != null) created++;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created > 0) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'challenge_creation',
              step: 'duel_created',
              source: 'create_duel_page',
              variant: _challengeCreationVariant,
              extraParameters: {
                'is_solo': _isSolo,
                'friends_count': _selectedFriendIds.length,
              },
            ),
      );
      Navigator.of(context).pop();
      final msg = _isSolo
          ? 'Défi solo créé !'
          : '$created défi${created > 1 ? 's' : ''} envoyé${created > 1 ? 's' : ''} !';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logFunnelStep(
              funnel: 'challenge_creation',
              step: 'duel_creation_failed',
              source: 'create_duel_page',
              variant: _challengeCreationVariant,
            ),
      );
      final error = ref.read(duelNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur de création du défi.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String get _primaryActionLabel {
    switch (_currentStep) {
      case _CreateDefiStep.friends:
        return _isSolo ? 'Continuer' : 'Inviter (${_selectedFriendIds.length})';
      case _CreateDefiStep.naming:
        return 'Terminer';
      default:
        return 'Continuer';
    }
  }

  Widget _buildTitle(ThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFriendsStep(ThemeData theme, WidgetRef ref) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final friends = friendsState.friends
        .map((f) => f.getOtherUserProfile(currentUserId))
        .whereType<dynamic>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(
          theme,
          'Tu fais ce défi avec qui ?',
          _isSolo
              ? 'Tu fais ça en solo, respect !'
              : 'Invite des amis pour réaliser ce défi ensemble',
        ),
        if (!_isSolo) ...[
          if (friendsState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (friends.isEmpty)
            Text('Aucun ami disponible.', style: theme.textTheme.bodyMedium)
          else
            ...friends.map((profile) {
              final selected = _selectedFriendIds.contains(profile.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FriendPickCard(
                  username: profile.username,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedFriendIds.remove(profile.id);
                      } else {
                        _selectedFriendIds.add(profile.id);
                      }
                    });
                  },
                ),
              );
            }),
          const SizedBox(height: 10),
        ],
        // Solo checkbox (Figma: "Je me la joue solo")
        GestureDetector(
          onTap: () => setState(() {
            _isSolo = !_isSolo;
            if (_isSolo) _selectedFriendIds.clear();
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _isSolo ? AppColors.textPrimary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isSolo ? Colors.white : AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _isSolo
                      ? const Icon(Icons.check, size: 14, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Je me la joue solo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isSolo ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSizeStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(
          theme,
          'À combien de personnes ?',
          'Pas plus de 4, faut pas être trop gourmand',
        ),
        Row(
          children: [
            _SquareIconButton(
              icon: Icons.remove,
              onTap: () {
                if (_groupSize > 2) {
                  setState(() {
                    _groupSize -= 1;
                    while (_selectedFriendIds.length > _groupSize - 1) {
                      _selectedFriendIds.remove(_selectedFriendIds.last);
                    }
                  });
                }
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$_groupSize', style: theme.textTheme.titleLarge),
              ),
            ),
            const SizedBox(width: 12),
            _SquareIconButton(
              icon: Icons.add,
              onTap: () {
                if (_groupSize < 4) setState(() => _groupSize += 1);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDifficultyStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(
          theme,
          'Difficulté du défi',
          'À toi de faire le bon choix...',
        ),
        ..._kDefiDifficulties.keys.map(
          (difficulty) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModeCard(
              label: difficulty,
              selected: _selectedDifficulty == difficulty,
              onTap: () => setState(() => _selectedDifficulty = difficulty),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(theme, 'Type de défi', 'À toi de faire le bon choix...'),
        ..._kDefiTypes.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModeCard(
              label: type,
              selected: _selectedType == type,
              onTap: () => setState(() => _selectedType = type),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNamingStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(
          theme,
          'Comment on appelle ton défi',
          'Sois créatif, c\'est le moment !',
        ),
        TextField(
          controller: _defiNameController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nom du défi',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep(ThemeData theme, WidgetRef ref) {
    return switch (_currentStep) {
      _CreateDefiStep.friends => _buildFriendsStep(theme, ref),
      _CreateDefiStep.groupSize => _buildGroupSizeStep(theme),
      _CreateDefiStep.difficulty => _buildDifficultyStep(theme),
      _CreateDefiStep.type => _buildTypeStep(theme),
      _CreateDefiStep.naming => _buildNamingStep(theme),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Création défi')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _buildCurrentStep(theme, ref),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SquareIconButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: _isSubmitting ? null : _goBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : (_currentStep == _CreateDefiStep.naming
                                  ? _submit
                                  : _goNext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _primaryActionLabel,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _FriendPickCard extends StatelessWidget {
  final String username;
  final bool selected;
  final VoidCallback onTap;

  const _FriendPickCard({
    required this.username,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surfaceDark,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Actif récemment',
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white)
            else
              const Icon(
                Icons.radio_button_unchecked,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SquareIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 56,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
