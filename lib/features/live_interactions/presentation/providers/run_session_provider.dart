import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/providers/supabase_provider.dart';
import '../../data/datasources/run_session_remote_datasource.dart';
import '../../data/repositories/run_session_repository_impl.dart';
import '../../domain/entities/run_session_entity.dart';
import '../../domain/repositories/run_session_repository.dart';

// --- Datasource & Repository providers ---

final runSessionDatasourceProvider = Provider<RunSessionRemoteDatasource>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return RunSessionRemoteDatasource(client);
});

final runSessionRepositoryProvider = Provider<RunSessionRepository>((ref) {
  final datasource = ref.watch(runSessionDatasourceProvider);
  return RunSessionRepositoryImpl(datasource);
});

// --- Active friend sessions ---

final activeFriendSessionsProvider =
    FutureProvider<List<RunSessionEntity>>((ref) async {
      final repo = ref.read(runSessionRepositoryProvider);
      return repo.getActiveFriendSessions();
    });

// --- Watch a specific session (for the viewer screen) ---

final watchedSessionProvider =
    StreamProvider.family<RunSessionEntity?, String>((ref, sessionId) {
      final repo = ref.watch(runSessionRepositoryProvider);
      return repo.watchSession(sessionId);
    });

// --- Current run session state (used by runner) ---

class RunSessionState {
  final String? sessionId;
  final bool isPublishing;

  const RunSessionState({this.sessionId, this.isPublishing = false});

  RunSessionState copyWith({String? sessionId, bool? isPublishing}) {
    return RunSessionState(
      sessionId: sessionId ?? this.sessionId,
      isPublishing: isPublishing ?? this.isPublishing,
    );
  }
}

class RunSessionNotifier extends StateNotifier<RunSessionState> {
  final RunSessionRepository _repo;
  final SupabaseClient _client;

  RunSessionNotifier(this._repo, this._client)
    : super(const RunSessionState());

  Future<String?> startSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    state = state.copyWith(isPublishing: true);
    try {
      final session = await _repo.createSession(userId);
      state = RunSessionState(sessionId: session.id, isPublishing: false);
      return session.id;
    } catch (_) {
      state = state.copyWith(isPublishing: false);
      return null;
    }
  }

  Future<void> updateSession({
    required double distanceMeters,
    required int elapsedSeconds,
    double? currentPaceSecondsPerKm,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    try {
      await _repo.updateSession(
        sessionId: sessionId,
        distanceMeters: distanceMeters,
        elapsedSeconds: elapsedSeconds,
        currentPaceSecondsPerKm: currentPaceSecondsPerKm,
      );
    } catch (_) {
      // Non-bloquant — les mises à jour stats peuvent échouer silencieusement
    }
  }

  Future<void> endSession() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    try {
      await _repo.endSession(sessionId);
    } catch (_) {}
    state = const RunSessionState();
  }

  void clearSession() {
    state = const RunSessionState();
  }
}

final runSessionNotifierProvider =
    StateNotifierProvider<RunSessionNotifier, RunSessionState>((ref) {
      final repo = ref.watch(runSessionRepositoryProvider);
      final client = ref.watch(supabaseClientProvider);
      return RunSessionNotifier(repo, client);
    });
