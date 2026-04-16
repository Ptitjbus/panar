import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../data/datasources/run_interaction_remote_datasource.dart';
import '../../data/repositories/run_interaction_repository_impl.dart';
import '../../domain/entities/run_interaction_entity.dart';
import '../../domain/repositories/run_interaction_repository.dart';

// --- Datasource & Repository providers ---

final runInteractionDatasourceProvider =
    Provider<RunInteractionRemoteDatasource>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return RunInteractionRemoteDatasource(client);
    });

final runInteractionRepositoryProvider = Provider<RunInteractionRepository>((
  ref,
) {
  final datasource = ref.watch(runInteractionDatasourceProvider);
  return RunInteractionRepositoryImpl(datasource);
});

// --- Incoming interactions state (for the runner's overlay) ---

class IncomingInteractionsNotifier
    extends StateNotifier<List<RunInteractionEntity>> {
  final RunInteractionRepository _repo;
  StreamSubscription<RunInteractionEntity>? _subscription;

  IncomingInteractionsNotifier(this._repo) : super([]);

  void startListening(String sessionId) {
    _subscription?.cancel();
    _subscription = _repo.watchIncomingInteractions(sessionId).listen((
      interaction,
    ) {
      if (!mounted) return;
      state = [interaction, ...state];
      _hapticAndSound(interaction);
    });
  }

  void _hapticAndSound(RunInteractionEntity interaction) {
    // Three heavy impacts for a strong, noticeable buzz pattern
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 90), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);

    if (interaction.type == InteractionType.soundboard &&
        interaction.content != null) {
      _playAsset('sounds/${interaction.content!}.mp3');
    } else if (interaction.type == InteractionType.voiceMessage &&
        interaction.audioUrl != null) {
      // Short notification beep then auto-play the voice message
      _playAsset('sounds/notification.mp3');
      Future.delayed(
        const Duration(milliseconds: 600),
        () => playAudio(interaction.audioUrl!),
      );
    } else {
      // Short notification beep for encouragements, emojis, direct messages
      _playAsset('sounds/notification.mp3');
    }
  }

  Future<void> _playAsset(String assetPath) async {
    debugPrint('[Audio] ▶ playing $assetPath');
    final p = AudioPlayer();
    p.onPlayerStateChanged.listen(
      (s) => debugPrint('[Audio] state → $s'),
    );
    try {
      p.onPlayerComplete.listen((_) {
        debugPrint('[Audio] ✓ complete $assetPath');
        p.dispose();
      });
      await p.play(AssetSource(assetPath));
      debugPrint('[Audio] play() returned for $assetPath');
    } catch (e, st) {
      debugPrint('[Audio] ✗ error ($assetPath): $e\n$st');
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  /// Downloads [url] to a temp file then plays it via DeviceFileSource.
  /// This is more reliable than UrlSource on iOS with the ambient audio session.
  Future<void> playAudio(String url) async {
    File? tmpFile;
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      httpClient.close();

      final dir = await getTemporaryDirectory();
      tmpFile = File(
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await tmpFile.writeAsBytes(bytes);

      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) {
        p.dispose();
        tmpFile?.delete().catchError((e) => tmpFile!);
      });
      await p.play(DeviceFileSource(tmpFile.path));
    } catch (e) {
      debugPrint('[Audio] playAudio error: $e');
      tmpFile?.delete().catchError((e) => tmpFile!);
    }
  }

  void dismiss(String interactionId) {
    state = state.where((i) => i.id != interactionId).toList();
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    state = [];
  }

  void debugInject(RunInteractionEntity interaction) {
    if (!mounted) return;
    state = [interaction, ...state];
    _hapticAndSound(interaction);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final incomingInteractionsProvider = StateNotifierProvider<
    IncomingInteractionsNotifier, List<RunInteractionEntity>>((ref) {
  final repo = ref.watch(runInteractionRepositoryProvider);
  return IncomingInteractionsNotifier(repo);
});

// --- Sending interactions (for the viewer/friend screen) ---

class SendInteractionNotifier extends StateNotifier<AsyncValue<void>> {
  final RunInteractionRepository _repo;

  SendInteractionNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> send({
    required String sessionId,
    required String runnerId,
    required InteractionType type,
    String? content,
    String? audioUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.sendInteraction(
        sessionId: sessionId,
        runnerId: runnerId,
        type: type,
        content: content,
        audioUrl: audioUrl,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final sendInteractionProvider =
    StateNotifierProvider.family<SendInteractionNotifier, AsyncValue<void>, String>((
      ref,
      sessionId,
    ) {
      final repo = ref.watch(runInteractionRepositoryProvider);
      return SendInteractionNotifier(repo);
    });
