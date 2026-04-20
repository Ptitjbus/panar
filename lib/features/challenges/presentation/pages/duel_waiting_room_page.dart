import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/duel_provider.dart';

class DuelWaitingRoomPage extends ConsumerStatefulWidget {
  final String duelId;
  const DuelWaitingRoomPage({super.key, required this.duelId});

  @override
  ConsumerState<DuelWaitingRoomPage> createState() => _DuelWaitingRoomPageState();
}

class _DuelWaitingRoomPageState extends ConsumerState<DuelWaitingRoomPage> {
  bool _countdownStarted = false;
  int _countdown = 3;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  bool _timeoutDialogShown = false;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _setReady() async {
    await ref.read(duelNotifierProvider.notifier).setReady(widget.duelId);
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !_timeoutDialogShown) {
        _timeoutDialogShown = true;
        _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Adversaire absent'),
        content: const Text("L'adversaire n'a pas rejoint la salle d'attente."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(duelNotifierProvider.notifier).cancelDuel(widget.duelId);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Annuler le duel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _timeoutDialogShown = false);
              _startTimeoutTimer();
            },
            child: const Text('Attendre encore'),
          ),
        ],
      ),
    );
  }

  void _startCountdown() {
    if (_countdownStarted) return;
    _countdownStarted = true;
    _timeoutTimer?.cancel();

    var count = 3;
    setState(() => _countdown = count);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      count--;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (count <= 0) {
        timer.cancel();
        context.push(Routes.runTracking);
      } else {
        setState(() => _countdown = count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final duelState = ref.watch(duelNotifierProvider);

    final duel = [
      ...duelState.myDuels,
      ...duelState.pendingInvites,
    ].where((d) => d.id == widget.duelId).firstOrNull;

    final readyStatesAsync = ref.watch(duelReadyStatesProvider(widget.duelId));

    ref.listen(duelReadyStatesProvider(widget.duelId), (_, next) {
      next.whenData((states) {
        final expectedUserIds = duel == null
            ? <String>{}
            : <String>{duel.challengerId, if (duel.challengedId != null) duel.challengedId!};
        final readyUserIds = states
            .where((s) => s.isReady)
            .map((s) => s.userId)
            .toSet();
        final allReady = (expectedUserIds.isNotEmpty &&
                expectedUserIds.every(readyUserIds.contains)) ||
            (states.length >= 2 && states.every((s) => s.isReady));
        if (allReady) _startCountdown();
      });
    });

    final otherName = duel?.getOtherProfile(currentUserId)?.username ?? '…';
    final myUsername = duel != null
        ? (currentUserId == duel.challengerId
            ? duel.challengerProfile?.username ?? 'Moi'
            : duel.challengedProfile?.username ?? 'Moi')
        : 'Moi';

    final readyStates = readyStatesAsync.valueOrNull ?? [];
    final myState = readyStates.where((s) => s.userId == currentUserId).firstOrNull;
    final otherUserId = duel == null
        ? null
        : (currentUserId == duel.challengerId ? duel.challengedId : duel.challengerId);
    final otherState = readyStates
        .where((s) => otherUserId != null && s.userId == otherUserId)
        .firstOrNull;
    final myIsReady = myState?.isReady ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text("Salle d'attente", style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            if (_countdownStarted) ...[
              Text(
                '$_countdown',
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Partez !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PlayerStatus(
                    name: myUsername,
                    isReady: myState?.isReady ?? false,
                    isMe: true,
                  ),
                  const Column(
                    children: [
                      Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                    ],
                  ),
                  _PlayerStatus(
                    name: '@$otherName',
                    isReady: otherState?.isReady ?? false,
                    isMe: false,
                  ),
                ],
              ),

              const Spacer(),

              if (!myIsReady)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _setReady,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Je suis prêt !',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.chipSuccessBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success),
                      SizedBox(width: 8),
                      Text(
                        'Tu es prêt — en attente de l\'adversaire…',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerStatus extends StatelessWidget {
  final String name;
  final bool isReady;
  final bool isMe;
  const _PlayerStatus({required this.name, required this.isReady, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReady ? AppColors.chipSuccessBg : AppColors.chipNeutralBg,
            border: Border.all(
              color: isReady ? AppColors.success : AppColors.border,
              width: 2,
            ),
          ),
          child: Icon(
            isReady ? Icons.check_rounded : Icons.person_rounded,
            size: 34,
            color: isReady ? AppColors.success : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          isReady ? 'Prêt ✓' : 'En attente…',
          style: TextStyle(
            fontSize: 12,
            color: isReady ? AppColors.success : AppColors.textSecondary,
            fontWeight: isReady ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
