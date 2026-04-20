import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/friends/domain/entities/friendship_entity.dart';

class FriendSelectorWidget extends StatefulWidget {
  final List<FriendshipEntity> friends;
  final String currentUserId;
  final bool multiSelect;
  final List<String> initialSelectedIds;
  final void Function(List<String> selectedIds) onSelectionChanged;

  const FriendSelectorWidget({
    super.key,
    required this.friends,
    required this.currentUserId,
    this.multiSelect = false,
    this.initialSelectedIds = const [],
    required this.onSelectionChanged,
  });

  @override
  State<FriendSelectorWidget> createState() => _FriendSelectorWidgetState();
}

class _FriendSelectorWidgetState extends State<FriendSelectorWidget> {
  final Set<String> _selected = {};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelectedIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selected.isNotEmpty) {
        widget.onSelectionChanged(_selected.toList());
      }
    });
  }

  List<(String id, String username)> get _filtered {
    return widget.friends
        .map((f) {
          final profile = f.getOtherUserProfile(widget.currentUserId);
          if (profile == null) return null;
          return (profile.id, profile.username);
        })
        .whereType<(String, String)>()
        .where(
          (pair) =>
              _search.isEmpty ||
              pair.$2.toLowerCase().contains(_search.toLowerCase()),
        )
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextField(
          decoration: const InputDecoration(
            hintText: 'Rechercher un ami...',
            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 12),

        // Friend list
        ..._filtered.map((pair) => _FriendTile(
              id: pair.$1,
              username: pair.$2,
              isSelected: _selected.contains(pair.$1),
              multiSelect: widget.multiSelect,
              onTap: () => _toggle(pair.$1),
            )),

        if (_filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Aucun ami trouvé',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String id;
  final String username;
  final bool isSelected;
  final bool multiSelect;
  final VoidCallback onTap;

  const _FriendTile({
    required this.id,
    required this.username,
    required this.isSelected,
    required this.multiSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                username[0].toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Username
            Expanded(
              child: Text(
                '@$username',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),

            // Selection indicator
            if (multiSelect)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: AppColors.accent)
                    : null,
              )
            else if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
