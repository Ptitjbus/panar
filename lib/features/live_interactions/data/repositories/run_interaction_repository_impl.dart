import '../../domain/entities/run_interaction_entity.dart';
import '../../domain/repositories/run_interaction_repository.dart';
import '../datasources/run_interaction_remote_datasource.dart';

class RunInteractionRepositoryImpl implements RunInteractionRepository {
  final RunInteractionRemoteDatasource _datasource;

  RunInteractionRepositoryImpl(this._datasource);

  @override
  Future<void> sendInteraction({
    required String sessionId,
    required String runnerId,
    required InteractionType type,
    String? content,
    String? audioUrl,
  }) async {
    await _datasource.sendInteraction(
      sessionId: sessionId,
      runnerId: runnerId,
      type: type,
      content: content,
      audioUrl: audioUrl,
    );
  }

  @override
  Stream<RunInteractionEntity> watchIncomingInteractions(String sessionId) =>
      _datasource.watchIncomingInteractions(sessionId);

  @override
  Future<void> markAsRead(String interactionId) =>
      _datasource.markAsRead(interactionId);
}
