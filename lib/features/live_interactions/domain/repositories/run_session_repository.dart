import '../entities/run_session_entity.dart';

abstract class RunSessionRepository {
  /// Crée une session active au démarrage d'une course.
  Future<RunSessionEntity> createSession(String userId);

  /// Met à jour les stats de la session en cours.
  Future<void> updateSession({
    required String sessionId,
    required double distanceMeters,
    required int elapsedSeconds,
    double? currentPaceSecondsPerKm,
  });

  /// Termine la session.
  Future<void> endSession(String sessionId);

  /// Retourne les sessions actives des amis acceptés.
  Future<List<RunSessionEntity>> getActiveFriendSessions();

  /// Stream de mises à jour d'une session spécifique.
  Stream<RunSessionEntity?> watchSession(String sessionId);
}
