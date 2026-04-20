import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/widgets/friend_list_item.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../../home/domain/entities/avatar_mood.dart';
import '../../../home/presentation/providers/avatar_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../shop/presentation/providers/shop_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
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
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final avatarAsync = ref.watch(userAvatarProvider);
    final moodAsync = ref.watch(userAvatarMoodProvider);
    final theme = Theme.of(context);

    final avatar = avatarAsync.valueOrNull;
    final mood = moodAsync.valueOrNull ?? AvatarMood.neutral;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('Non connecté'));

          return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur profil: $e')),
            data: (profile) {
              final metadataUsername =
                  user.userMetadata?['username'] as String? ?? '';
              final emailPrefix = user.email.split('@').first;
              final username =
                  (profile?.username ?? metadataUsername).trim().isNotEmpty
                  ? (profile?.username ?? metadataUsername).trim()
                  : emailPrefix;
              final displayName =
                  (avatar?.displayName ?? profile?.fullName ?? username).trim();
              final avatarColorHex = avatar?.colorHex ?? profile?.avatarColor;

              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Row(
                        children: [
                          const PanarBreadcrumb('Mon profil'),
                          const Spacer(),
                          Icon(
                            Icons.settings_outlined,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        'Bienvenue chez toi !',
                        style: theme.textTheme.headlineLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Text(
                        'Ici tu retrouves tes courses, ton peton...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),

                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.textPrimary,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: const [
                        Tab(text: 'Profil'),
                        Tab(text: 'Mes activités'),
                      ],
                    ),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _ProfileTab(
                            displayName: displayName,
                            username: username,
                            mood: mood,
                            currentUserId: user.id,
                            avatarColorHex: avatarColorHex,
                          ),
                          const _ActivitiesTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  final String displayName;
  final String username;
  final AvatarMood mood;
  final String currentUserId;
  final String? avatarColorHex;

  const _ProfileTab({
    required this.displayName,
    required this.username,
    required this.mood,
    required this.currentUserId,
    required this.avatarColorHex,
  });

  Color? _parseAvatarColor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final sanitized = value.trim().replaceFirst('#', '');
    try {
      if (sanitized.length == 6) {
        return Color(int.parse('FF$sanitized', radix: 16));
      }
      if (sanitized.length == 8) {
        return Color(int.parse(sanitized, radix: 16));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final friendsState = ref.watch(friendsNotifierProvider);
    final ownedItemsAsync = ref.watch(ownedShopItemsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Hero mascot
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: AnimatedAvatarWidget(
              isMoving: false,
              size: 160,
              mood: mood,
              colorFilter: _parseAvatarColor(avatarColorHex),
              showShadow: false,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(displayName, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text('@$username', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),

        PanarButton(
          label: 'Modifier mon peton',
          onPressed: () => context.push(Routes.editAvatar),
        ),
        const SizedBox(height: 24),

        // Implication
        Text('Implication', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text('Tu as encouragé', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text('45', style: theme.textTheme.displaySmall),
              Text('Petons ce mois-ci', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PanarButton(
          label: 'Retourner sur le terrain',
          onPressed: () => context.go(Routes.home, extra: {'index': 0}),
        ),
        const SizedBox(height: 24),

        Text('Mes objets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ownedItemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Erreur chargement objets: $e',
            style: theme.textTheme.bodyMedium,
          ),
          data: (items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Aucun objet acheté pour le moment.',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }

            final dateFormat = DateFormat('dd/MM/yyyy');
            return Column(
              children: items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${item.category} • ${item.pricePaidPetons} 💡',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        dateFormat.format(item.purchasedAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),

        // Amis
        Text('Mes amis', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),

        if (friendsState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (friendsState.friends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Aucun ami pour le moment.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          ...friendsState.friends.map((f) {
            final profile = f.getOtherUserProfile(currentUserId);
            final name = profile?.username ?? '—';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FriendListItem(friendship: f, friendUsername: name),
            );
          }),

        const SizedBox(height: 12),
        PanarButton(
          label: 'Voir tous mes amis',
          onPressed: () => context.push(Routes.friends),
        ),
        const SizedBox(height: 16),

        // Invite
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Inviter des amis*', style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '*Astuce du Panar\nTu recevras 500 💡 par ami qui nous rejoint',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Tes activités arrivent bientôt...',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
