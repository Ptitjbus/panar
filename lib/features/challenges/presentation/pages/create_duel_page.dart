import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';
import '../widgets/friend_selector_widget.dart';

class CreateDuelPage extends ConsumerStatefulWidget {
  const CreateDuelPage({super.key});

  @override
  ConsumerState<CreateDuelPage> createState() => _CreateDuelPageState();
}

// Distance options in meters: null means no target
const _kDistanceOptions = <String, double?>{
  'Libre': null,
  '1 km': 1000,
  '3 km': 3000,
  '5 km': 5000,
  '10 km': 10000,
  '15 km': 15000,
  '21 km': 21097,
  '42 km': 42195,
};

class _CreateDuelPageState extends ConsumerState<CreateDuelPage> {
  String? _selectedFriendId;
  DuelTiming _timing = DuelTiming.live;
  int _deadlineHours = 48;
  double? _targetDistanceMeters;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne un ami')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final desc = _descriptionController.text.trim();
    final duel = await ref.read(duelNotifierProvider.notifier).createDuel(
      challengedId: _selectedFriendId!,
      timing: _timing,
      deadlineHours: _timing == DuelTiming.async ? _deadlineHours : null,
      targetDistanceMeters: _targetDistanceMeters,
      description: desc.isEmpty ? null : desc,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (duel != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation envoyée !')),
      );
    } else {
      final error = ref.read(duelNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau duel ⚔️')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisir un ami', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            FriendSelectorWidget(
              friends: friendsState.friends,
              currentUserId: currentUserId,
              multiSelect: false,
              onSelectionChanged: (ids) => setState(() {
                _selectedFriendId = ids.isNotEmpty ? ids.first : null;
              }),
            ),
            const SizedBox(height: 24),
            const Text('Type de duel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimingOption(
                    emoji: '⚡',
                    label: 'Maintenant',
                    sublabel: 'Live',
                    selected: _timing == DuelTiming.live,
                    onTap: () => setState(() => _timing = DuelTiming.live),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimingOption(
                    emoji: '🕐',
                    label: 'Quand tu veux',
                    sublabel: 'Différé',
                    selected: _timing == DuelTiming.async,
                    onTap: () => setState(() => _timing = DuelTiming.async),
                  ),
                ),
              ],
            ),
            if (_timing == DuelTiming.async) ...[
              const SizedBox(height: 20),
              const Text('Délai pour répondre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 24, label: Text('24h')),
                  ButtonSegment(value: 48, label: Text('48h')),
                  ButtonSegment(value: 72, label: Text('72h')),
                ],
                selected: {_deadlineHours},
                onSelectionChanged: (s) => setState(() => _deadlineHours = s.first),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Distance cible', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<double?>(
              value: _targetDistanceMeters,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: _kDistanceOptions.entries
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                  .toList(),
              onChanged: (v) => setState(() => _targetDistanceMeters = v),
            ),
            const SizedBox(height: 24),
            const Text('Description (optionnel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex : Qui fera le plus de km ce week-end ?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Envoyer l\'invitation ⚔️', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _TimingOption({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F3FF) : const Color(0xFFF9FAFB),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? const Color(0xFF6C63FF) : Colors.black87)),
            Text(sublabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
