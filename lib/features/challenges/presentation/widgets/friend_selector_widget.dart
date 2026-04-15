import 'package:flutter/material.dart';
import '../../../../features/friends/domain/entities/friendship_entity.dart';

class FriendSelectorWidget extends StatefulWidget {
  final List<FriendshipEntity> friends;
  final String currentUserId;
  final bool multiSelect;
  final void Function(List<String> selectedIds) onSelectionChanged;

  const FriendSelectorWidget({
    super.key,
    required this.friends,
    required this.currentUserId,
    this.multiSelect = false,
    required this.onSelectionChanged,
  });

  @override
  State<FriendSelectorWidget> createState() => _FriendSelectorWidgetState();
}

class _FriendSelectorWidgetState extends State<FriendSelectorWidget> {
  final Set<String> _selected = {};
  String _search = '';

  List<(String id, String username)> get _filtered {
    return widget.friends
        .map((f) {
          // Use the friendship entity's method to get the other user's profile
          final profile = f.getOtherUserProfile(widget.currentUserId);
          if (profile == null) return null;
          return (profile.id, profile.username);
        })
        .whereType<(String, String)>()
        .where((pair) =>
            _search.isEmpty ||
            pair.$2.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  void _toggle(String id) {
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      } else {
        _selected
          ..clear()
          ..add(id);
      }
    });
    widget.onSelectionChanged(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un ami...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 8),
        ..._filtered.map((pair) {
          final isSelected = _selected.contains(pair.$1);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(
              backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
              child: Text(
                pair.$2[0].toUpperCase(),
                style: TextStyle(
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('@${pair.$2}', style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: colorScheme.primary)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: isSelected ? colorScheme.primary.withValues(alpha: 0.08) : null,
            onTap: () => _toggle(pair.$1),
          );
        }),
      ],
    );
  }
}
