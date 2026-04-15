import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/friend_selector_widget.dart';

const _kDistanceOptions = <String, double?>{
  'Libre': null,
  '5 km': 5000,
  '10 km': 10000,
  '21 km': 21097,
  '42 km': 42195,
  '50 km': 50000,
  '100 km': 100000,
  '200 km': 200000,
};

class CreateGroupChallengePage extends ConsumerStatefulWidget {
  const CreateGroupChallengePage({super.key});

  @override
  ConsumerState<CreateGroupChallengePage> createState() =>
      _CreateGroupChallengePageState();
}

class _CreateGroupChallengePageState extends ConsumerState<CreateGroupChallengePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _durationDays = 7;
  double? _targetDistanceMeters;
  List<String> _selectedFriendIds = [];
  bool _isSubmitting = false;
  bool _templateApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_templateApplied) {
      _templateApplied = true;
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null) {
        _titleController.text = extra['title'] as String? ?? '';
        _durationDays = extra['duration_days'] as int? ?? 7;
        _targetDistanceMeters = extra['target_distance_meters'] as double?;
        if (extra['description'] != null) {
          _descriptionController.text = extra['description'] as String;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donne un nom au défi')),
      );
      return;
    }
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne au moins un ami')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final desc = _descriptionController.text.trim();
    final challenge = await ref
        .read(groupChallengeNotifierProvider.notifier)
        .createChallenge(
          title: title,
          durationDays: _durationDays,
          friendIds: _selectedFriendIds,
          targetDistanceMeters: _targetDistanceMeters,
          description: desc.isEmpty ? null : desc,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (challenge != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Défi créé ! Invitations envoyées.')),
      );
    } else {
      final error = ref.read(groupChallengeNotifierProvider).errorMessage;
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
      appBar: AppBar(title: const Text('Nouveau défi groupe 🏆')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nom du défi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Ex : Marathon de mars',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Durée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 jours')),
                ButtonSegment(value: 7, label: Text('7 jours')),
                ButtonSegment(value: 30, label: Text('30 jours')),
              ],
              selected: {_durationDays},
              onSelectionChanged: (s) => setState(() => _durationDays = s.first),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            const Text('Description (optionnel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex : Qui accumule le plus de km en avril ?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inviter des amis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_selectedFriendIds.isNotEmpty)
                  Text(
                    '${_selectedFriendIds.length} sélectionné${_selectedFriendIds.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FriendSelectorWidget(
              friends: friendsState.friends,
              currentUserId: currentUserId,
              multiSelect: true,
              onSelectionChanged: (ids) => setState(() => _selectedFriendIds = ids),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Créer le défi 🏆', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
