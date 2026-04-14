import '../../domain/entities/run_session_entity.dart';
import '../../domain/repositories/run_session_repository.dart';
import '../datasources/run_session_remote_datasource.dart';

class RunSessionRepositoryImpl implements RunSessionRepository {
  final RunSessionRemoteDatasource _datasource;

  RunSessionRepositoryImpl(this._datasource);

  @override
  Future<RunSessionEntity> createSession(String userId) =>
      _datasource.createSession(userId);

  @override
  Future<void> updateSession({
    required String sessionId,
    required double distanceMeters,
    required int elapsedSeconds,
    double? currentPaceSecondsPerKm,
  }) =>
      _datasource.updateSession(
        sessionId: sessionId,
        distanceMeters: distanceMeters,
        elapsedSeconds: elapsedSeconds,
        currentPaceSecondsPerKm: currentPaceSecondsPerKm,
      );

  @override
  Future<void> endSession(String sessionId) =>
      _datasource.endSession(sessionId);

  @override
  Future<List<RunSessionEntity>> getActiveFriendSessions() =>
      _datasource.getActiveFriendSessions();

  @override
  Stream<RunSessionEntity?> watchSession(String sessionId) =>
      _datasource.watchSession(sessionId);
}
