import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/group_challenge_provider.dart';

const _kQuestDistanceOptions = <String, double>{
  '25 km': 25000,
  '50 km': 50000,
  '75 km': 75000,
  '100 km': 100000,
};

class CreateGroupChallengePage extends ConsumerStatefulWidget {
  const CreateGroupChallengePage({super.key});

  @override
  ConsumerState<CreateGroupChallengePage> createState() =>
      _CreateGroupChallengePageState();
}

class _CreateGroupChallengePageState
    extends ConsumerState<CreateGroupChallengePage> {
  String? _selectedFriendId;
  double _targetDistanceMeters = 50000;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne un ami pour la quête.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final challenge = await ref
        .read(groupChallengeNotifierProvider.notifier)
        .createChallenge(
          title: 'Pied dans le pied',
          durationDays: 30,
          friendIds: [_selectedFriendId!],
          targetDistanceMeters: _targetDistanceMeters,
          description: 'Petit pas par petit pas',
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (challenge != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quête collaborative envoyée !')),
      );
    } else {
      final error = ref.read(groupChallengeNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur de création de quête.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final friends = friendsState.friends
        .map((f) => f.getOtherUserProfile(currentUserId))
        .whereType<ProfileEntity>()
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: PanarBreadcrumb('Collaboration'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Pied dans le pied',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(
                'Invite un ami à se motiver ensemble',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButtonFormField<double>(
                initialValue: _targetDistanceMeters,
                decoration: InputDecoration(
                  labelText: 'Objectif commun',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _kQuestDistanceOptions.entries
                    .map(
                      (entry) => DropdownMenuItem<double>(
                        value: entry.value,
                        child: Text(entry.key),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _targetDistanceMeters = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: friendsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : friends.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ajoute des amis pour lancer une quête collaborative.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      itemCount: friends.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final profile = friends[index];
                        final isSelected = _selectedFriendId == profile.id;
                        final subtitle = index == 0
                            ? 'Actif il y a 2 heures'
                            : 'Actif récemment';
                        return _FriendTile(
                          username: profile.username,
                          subtitle: subtitle,
                          isSelected: isSelected,
                          onTap: () => setState(() {
                            _selectedFriendId = isSelected ? null : profile.id;
                          }),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceDark,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton(
                        onPressed: (_selectedFriendId == null || _isSubmitting)
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceDark,
                          foregroundColor: AppColors.textPrimary,
                          disabledBackgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : Text(
                                'Inviter (${_selectedFriendId == null ? 0 : 1})',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String username;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendTile({
    required this.username,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.textPrimary : AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isSelected ? Colors.white24 : Colors.black12,
                child: Text(
                  username.isEmpty ? '?' : username[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
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
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
