import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';

class PetonsDatasource {
  final SupabaseClient _client;

  PetonsDatasource(this._client);

  /// Incrémente le solde de petons de l'utilisateur et retourne le nouveau solde.
  Future<int> awardPetons(String userId, int amount) async {
    try {
      final response = await _client.rpc(
        'increment_petons',
        params: {'user_id_input': userId, 'amount_input': amount},
      );
      return (response as int?) ?? 0;
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    }
  }

  Future<int> getBalance(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('petons_balance')
          .eq('id', userId)
          .single();
      return (response['petons_balance'] as int?) ?? 0;
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    }
  }
}

final petonsDatasourceProvider = Provider<PetonsDatasource>((ref) {
  return PetonsDatasource(ref.watch(supabaseClientProvider));
});
