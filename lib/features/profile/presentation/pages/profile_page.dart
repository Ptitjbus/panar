import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/providers/avatar_provider.dart';
import '../../../home/domain/entities/avatar_mood.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

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

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _displayNameController = TextEditingController();
  String? _selectedColorHex;
  String? _initializedAvatarId;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null) return const Color(0xFF4ECDC4);
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4ECDC4);
    }
  }

  Future<void> _saveAvatar() async {
    final user = ref.read(authStateProvider).value;
    final avatar = ref.read(userAvatarProvider).valueOrNull;
    if (user == null || avatar == null) return;

    final success = await ref
        .read(avatarCustomizationNotifierProvider.notifier)
        .updateAvatar(
          userId: user.id,
          displayName: _displayNameController.text.trim(),
          colorHex: _selectedColorHex,
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Avatar mis a jour')),
      );
    } else {
      final error = ref.read(avatarCustomizationNotifierProvider).errorMessage;
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? 'Erreur de mise a jour')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final avatarAsync = ref.watch(userAvatarProvider);
    final moodAsync = ref.watch(userAvatarMoodProvider);
    final avatarEditState = ref.watch(avatarCustomizationNotifierProvider);

    final avatar = avatarAsync.valueOrNull;
    if (avatar != null && _initializedAvatarId != avatar.id) {
      _initializedAvatarId = avatar.id;
      _displayNameController.text = avatar.displayName ?? '';
      _selectedColorHex = avatar.colorHex;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Utilisateur non connecte'));
          }
          return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Erreur profil: $error')),
            data: (profile) {
              return avatarAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Erreur avatar: $error')),
                data: (avatarData) {
                  if (profile == null || avatarData == null) {
                    return const Center(child: Text('Profil indisponible'));
                  }

                  final mood = moodAsync.valueOrNull ?? AvatarMood.neutral;
                  final currentColor = _parseColor(_selectedColorHex ?? avatarData.colorHex);

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            AnimatedAvatarWidget(
                              isMoving: false,
                              size: 140,
                              colorFilter: currentColor,
                              showShadow: true,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${mood.emoji} ${mood.label}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '@${profile.username}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Nom du personnage',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _displayNameController,
                        decoration: InputDecoration(
                          hintText: 'Ex: Bolt',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Couleur du personnage',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _kAvatarPalette.map((hex) {
                          final selected = _selectedColorHex == hex;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColorHex = hex),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _parseColor(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? Colors.black : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: avatarEditState.isLoading ? null : _saveAvatar,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: avatarEditState.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Sauvegarder',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erreur auth: $error')),
      ),
    );
  }
}
