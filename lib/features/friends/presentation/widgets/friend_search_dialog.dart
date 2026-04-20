import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
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
    final theme = Theme.of(context);
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.background,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Ajouter un ami', style: theme.textTheme.headlineSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Trouve un utilisateur par son pseudo.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: '@pseudo (min. 3 caractères)',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: hasQuery
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          color: AppColors.textSecondary,
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              Flexible(child: _buildResults(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.textPrimary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      final hasSearched = _searchController.text.trim().length >= 3;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearched ? Icons.person_search : Icons.search,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearched
                  ? 'Aucun utilisateur trouvé'
                  : 'Recherchez un utilisateur par son nom',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSending = _sendingRequests.contains(user.id);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceDark,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              onBackgroundImageError: user.avatarUrl != null
                  ? (exception, stackTrace) {}
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.username[0].toUpperCase(),
                      style: theme.textTheme.labelMedium,
                    )
                  : null,
            ),
            title: Text(
              '@${user.username}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: user.fullName != null
                ? Text(user.fullName!, style: theme.textTheme.bodySmall)
                : null,
            trailing: SizedBox(
              width: 96,
              height: 36,
              child: ElevatedButton(
                onPressed: isSending
                    ? null
                    : () => _sendFriendRequest(user.id, user.username),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.surfaceDark,
                  disabledForegroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ajouter'),
              ),
            ),
          ),
        );
      },
    );
  }
}
