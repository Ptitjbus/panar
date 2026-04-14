import '../entities/run_interaction_entity.dart';

abstract class RunInteractionRepository {
  /// Envoie une interaction à un coureur.
  Future<void> sendInteraction({
    required String sessionId,
    required String runnerId,
    required InteractionType type,
    String? content,
    String? audioUrl,
  });

  /// Stream des nouvelles interactions reçues pour une session.
  Stream<RunInteractionEntity> watchIncomingInteractions(String sessionId);

  /// Marque une interaction comme lue.
  Future<void> markAsRead(String interactionId);
}
