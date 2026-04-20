import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/challenge_template_model.dart';

class ChallengeTemplateRemoteDataSource {
  final SupabaseClient _client;
  ChallengeTemplateRemoteDataSource(this._client);

  Future<List<ChallengeTemplateModel>> getTemplates() async {
    try {
      final response = await _client
          .from('challenge_templates')
          .select()
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 10));
      return (response as List)
          .map((j) => ChallengeTemplateModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get challenge templates: $e');
    }
  }
}

final challengeTemplateDataSourceProvider =
    Provider<ChallengeTemplateRemoteDataSource>((ref) {
  return ChallengeTemplateRemoteDataSource(ref.watch(supabaseClientProvider));
});
