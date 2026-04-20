import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/friends_provider.dart';
import '../widgets/friend_list_item.dart';
import '../widgets/friend_request_item.dart';
import '../widgets/sent_request_item.dart';
import '../widgets/friend_search_dialog.dart';

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final authState = ref.watch(authStateProvider);
    final currentUserId = authState.value?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Rechercher un ami',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const FriendSearchDialog(),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(friendsNotifierProvider.notifier).loadFriends();
        },
        child: friendsState.isLoading && friendsState.friends.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Received requests section
                  if (friendsState.receivedRequests.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Demandes reçues',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final request = friendsState.receivedRequests[index];
                        final requesterProfile = request.requesterProfile;

                        if (requesterProfile == null) {
                          return const SizedBox.shrink();
                        }

                        return FriendRequestItem(
                          friendship: request,
                          requesterUsername: requesterProfile.username,
                        );
                      }, childCount: friendsState.receivedRequests.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // Sent requests section
                  if (friendsState.sentRequests.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Demandes envoyées',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final request = friendsState.sentRequests[index];
                        final addresseeProfile = request.addresseeProfile;

                        if (addresseeProfile == null) {
                          return const SizedBox.shrink();
                        }

                        return SentRequestItem(
                          friendship: request,
                          addresseeUsername: addresseeProfile.username,
                        );
                      }, childCount: friendsState.sentRequests.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // Friends section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Mes amis',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Friends list
                  if (friendsState.friends.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucun ami pour le moment',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const FriendSearchDialog(),
                                );
                              },
                              icon: const Icon(
                                Icons.person_add,
                                color: AppColors.textPrimary,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                              ),
                              label: const Text('Ajouter un ami'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final friendship = friendsState.friends[index];
                        if (currentUserId == null) {
                          return const SizedBox.shrink();
                        }

                        final friendProfile = friendship.getOtherUserProfile(
                          currentUserId,
                        );

                        if (friendProfile == null) {
                          return const SizedBox.shrink();
                        }

                        return FriendListItem(
                          friendship: friendship,
                          friendUsername: friendProfile.username,
                        );
                      }, childCount: friendsState.friends.length),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const FriendSearchDialog(),
          );
        },
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
