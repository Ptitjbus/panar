import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../live_interactions/presentation/providers/run_session_provider.dart';
import '../../domain/entities/friendship_entity.dart';
import '../providers/friends_provider.dart';

/// Widget to display a friend in the friends list
class FriendListItem extends ConsumerWidget {
  final FriendshipEntity friendship;
  final String friendUsername;

  const FriendListItem({
    super.key,
    required this.friendship,
    required this.friendUsername,
  });

  Future<void> _showRemoveConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet ami'),
        content: Text(
          'Voulez-vous vraiment retirer @$friendUsername de vos amis ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(friendsNotifierProvider.notifier)
          .removeFriend(friendship.id);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('@$friendUsername a été retiré de vos amis'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          final errorMessage =
              ref.read(friendsNotifierProvider).errorMessage ??
              'Erreur lors de la suppression';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authStateProvider).value?.id;
    final friendId = currentUserId != null
        ? friendship.getOtherUserId(currentUserId)
        : null;

    final activeSessions = ref.watch(activeFriendSessionsProvider).value ?? [];
    final activeSession = friendId != null
        ? activeSessions.where((s) => s.userId == friendId).firstOrNull
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(friendUsername[0].toUpperCase())),
        title: Text('@$friendUsername'),
        subtitle: activeSession != null
            ? Row(
                children: [
                  const Icon(Icons.directions_run, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'En course — ${activeSession.formattedDistance} km',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeSession != null)
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.green),
                tooltip: 'Suivre en direct',
                onPressed: () => context.push(
                  Routes.friendLiveRun,
                  extra: {
                    'sessionId': activeSession.id,
                    'runnerId': friendId,
                    'runnerName': friendUsername,
                  },
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'remove') {
                  _showRemoveConfirmation(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Retirer cet ami',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
