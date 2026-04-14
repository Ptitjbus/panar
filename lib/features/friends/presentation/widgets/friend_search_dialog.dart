import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../providers/friends_provider.dart';

/// Dialog for searching and adding friends
class FriendSearchDialog extends ConsumerStatefulWidget {
  const FriendSearchDialog({super.key});

  @override
  ConsumerState<FriendSearchDialog> createState() => _FriendSearchDialogState();
}

class _FriendSearchDialogState extends ConsumerState<FriendSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<ProfileEntity> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  final Set<String> _sendingRequests = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous debounce timer
    _debounce?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    // Set up new debounce timer (300ms)
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await ref
            .read(friendsNotifierProvider.notifier)
            .searchUsers(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
            _errorMessage = 'Erreur lors de la recherche';
          });
        }
      }
    });
  }

  Future<void> _sendFriendRequest(String userId, String username) async {
    setState(() {
      _sendingRequests.add(userId);
    });

    final success = await ref
        .read(friendsNotifierProvider.notifier)
        .sendFriendRequest(userId);

    if (mounted) {
      setState(() {
        _sendingRequests.remove(userId);
      });

      if (success) {
        // Remove from search results
        setState(() {
          _searchResults.removeWhere((user) => user.id == userId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demande envoyée à @$username'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error from provider
        final errorMessage =
            ref.read(friendsNotifierProvider).errorMessage ?? 'Erreur inconnue';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Rechercher un ami',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Nom d\'utilisateur (min. 3 caractères)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Results
            Flexible(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    // Loading state
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    // Empty state
    if (_searchResults.isEmpty) {
      final hasSearched = _searchController.text.trim().length >= 3;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearched ? Icons.person_search : Icons.search,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearched
                  ? 'Aucun utilisateur trouvé'
                  : 'Recherchez un utilisateur par son nom',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Results list
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSending = _sendingRequests.contains(user.id);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            onBackgroundImageError: user.avatarUrl != null
                ? (exception, stackTrace) {
                    // Silently fail, will show child (initials)
                  }
                : null,
            child: (user.avatarUrl == null)
                ? Text(user.username[0].toUpperCase())
                : null,
          ),
          title: Text('@${user.username}'),
          subtitle: user.fullName != null ? Text(user.fullName!) : null,
          trailing: ElevatedButton(
            onPressed: isSending
                ? null
                : () => _sendFriendRequest(user.id, user.username),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Ajouter'),
          ),
        );
      },
    );
  }
}
