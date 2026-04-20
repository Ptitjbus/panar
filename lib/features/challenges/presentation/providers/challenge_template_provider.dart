import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/challenge_template_remote_datasource.dart';
import '../../domain/entities/challenge_template_entity.dart';

class ChallengeTemplateState {
  final List<ChallengeTemplateEntity> soloTemplates;
  final List<ChallengeTemplateEntity> groupTemplates;
  final List<ChallengeTemplateEntity> monthlyTemplates;
  final bool isLoading;
  final String? errorMessage;

  const ChallengeTemplateState({
    this.soloTemplates = const [],
    this.groupTemplates = const [],
    this.monthlyTemplates = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChallengeTemplateState copyWith({
    List<ChallengeTemplateEntity>? soloTemplates,
    List<ChallengeTemplateEntity>? groupTemplates,
    List<ChallengeTemplateEntity>? monthlyTemplates,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChallengeTemplateState(
      soloTemplates: soloTemplates ?? this.soloTemplates,
      groupTemplates: groupTemplates ?? this.groupTemplates,
      monthlyTemplates: monthlyTemplates ?? this.monthlyTemplates,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChallengeTemplateNotifier extends StateNotifier<ChallengeTemplateState> {
  final ChallengeTemplateRemoteDataSource _ds;

  ChallengeTemplateNotifier(this._ds) : super(const ChallengeTemplateState()) {
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final all = await _ds.getTemplates();
      state = state.copyWith(
        soloTemplates: all.where((t) => t.isSolo).toList(),
        groupTemplates: all.where((t) => t.isGroup).toList(),
        monthlyTemplates: all.where((t) => t.isMonthly).toList(),
        isLoading: false,
      );
    } on DatabaseFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur de connexion');
    }
  }
}

final challengeTemplateNotifierProvider =
    StateNotifierProvider<ChallengeTemplateNotifier, ChallengeTemplateState>((ref) {
  return ChallengeTemplateNotifier(ref.watch(challengeTemplateDataSourceProvider));
});
