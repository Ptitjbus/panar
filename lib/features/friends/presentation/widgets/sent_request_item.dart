import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/friendship_entity.dart';
import '../providers/friends_provider.dart';

/// Widget to display a sent friend request with cancel button
class SentRequestItem extends ConsumerStatefulWidget {
  final FriendshipEntity friendship;
  final String addresseeUsername;

  const SentRequestItem({
    super.key,
    required this.friendship,
    required this.addresseeUsername,
  });

  @override
  ConsumerState<SentRequestItem> createState() => _SentRequestItemState();
}

class _SentRequestItemState extends ConsumerState<SentRequestItem> {
  bool _isCancelling = false;

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: Text(
          'Voulez-vous annuler votre demande d\'ami à @${widget.addresseeUsername} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isCancelling = true;
      });

      final success = await ref
          .read(friendsNotifierProvider.notifier)
          .cancelSentRequest(widget.friendship.id);

      if (mounted) {
        setState(() {
          _isCancelling = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande annulée'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          final errorMessage =
              ref.read(friendsNotifierProvider).errorMessage ??
              'Erreur lors de l\'annulation';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Text(
            widget.addresseeUsername[0].toUpperCase(),
            style: TextStyle(color: Colors.orange.shade700),
          ),
        ),
        title: Text('@${widget.addresseeUsername}'),
        subtitle: const Text('En attente...'),
        trailing: _isCancelling
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(
                onPressed: _cancelRequest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Annuler'),
              ),
      ),
    );
  }
}
