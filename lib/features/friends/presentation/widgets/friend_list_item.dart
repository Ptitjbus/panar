import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(friendUsername[0].toUpperCase())),
        title: Text('@$friendUsername'),
        trailing: PopupMenuButton<String>(
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
                  Text('Retirer cet ami', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
