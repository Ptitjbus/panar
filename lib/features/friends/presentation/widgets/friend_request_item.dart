import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/friendship_entity.dart';
import '../providers/friends_provider.dart';

/// Widget to display a friend request with accept/reject buttons
class FriendRequestItem extends ConsumerStatefulWidget {
  final FriendshipEntity friendship;
  final String requesterUsername;

  const FriendRequestItem({
    super.key,
    required this.friendship,
    required this.requesterUsername,
  });

  @override
  ConsumerState<FriendRequestItem> createState() => _FriendRequestItemState();
}

class _FriendRequestItemState extends ConsumerState<FriendRequestItem> {
  bool _isProcessing = false;

  Future<void> _acceptRequest() async {
    setState(() {
      _isProcessing = true;
    });

    final success = await ref
        .read(friendsNotifierProvider.notifier)
        .acceptRequest(widget.friendship.id);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vous êtes maintenant ami avec @${widget.requesterUsername}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMessage =
            ref.read(friendsNotifierProvider).errorMessage ??
            'Erreur lors de l\'acceptation';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest() async {
    setState(() {
      _isProcessing = true;
    });

    final success = await ref
        .read(friendsNotifierProvider.notifier)
        .rejectRequest(widget.friendship.id);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande refusée'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        final errorMessage =
            ref.read(friendsNotifierProvider).errorMessage ??
            'Erreur lors du refus';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(widget.requesterUsername[0].toUpperCase()),
        ),
        title: Text('@${widget.requesterUsername}'),
        subtitle: const Text('Demande d\'ami'),
        trailing: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accept button
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Accepter',
                    onPressed: _acceptRequest,
                  ),
                  // Reject button
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Refuser',
                    onPressed: _rejectRequest,
                  ),
                ],
              ),
      ),
    );
  }
}
