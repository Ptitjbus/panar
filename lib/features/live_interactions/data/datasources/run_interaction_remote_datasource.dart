import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/run_interaction_entity.dart';
import '../models/run_interaction_model.dart';

class RunInteractionRemoteDatasource {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  RunInteractionRemoteDatasource(this._client);

  Future<void> sendInteraction({
    required String sessionId,
    required String runnerId,
    required InteractionType type,
    String? content,
    String? audioUrl,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) return;
    try {
      await _client.from('run_interactions').insert({
        'session_id': sessionId,
        'sender_id': senderId,
        'runner_id': runnerId,
        'type': type.toJson(),
        'content': content,
        'audio_url': audioUrl,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure('Impossible d\'envoyer l\'interaction: ${e.message}');
    }
  }

  Stream<RunInteractionEntity> watchIncomingInteractions(String sessionId) {
    final controller = StreamController<RunInteractionEntity>.broadcast();

    final channelName = 'run_interactions:$sessionId';
    final existing = _channels[channelName];
    existing?.unsubscribe();

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'run_interactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            try {
              final data = payload.newRecord;
              // Fetch sender profile separately to enrich the interaction
              _client
                  .from('profiles')
                  .select('display_name, username, avatar_url')
                  .eq('id', data['sender_id'] as String)
                  .single()
                  .then((profile) {
                final enriched = {
                  ...data,
                  'profiles': profile,
                };
                final interaction = RunInteractionModel.fromJson(enriched);
                if (!controller.isClosed) {
                  controller.add(interaction);
                }
              }).catchError((_) {
                // Fallback: emit without profile info
                final interaction = RunInteractionModel.fromJson(data);
                if (!controller.isClosed) {
                  controller.add(interaction);
                }
              });
            } catch (_) {}
          },
        )
        .subscribe();

    _channels[channelName] = channel;

    controller.onCancel = () {
      channel.unsubscribe();
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  Future<void> markAsRead(String interactionId) async {
    try {
      await _client.from('run_interactions').update({
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', interactionId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure('Impossible de marquer comme lu: ${e.message}');
    }
  }

  void dispose() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }
}
