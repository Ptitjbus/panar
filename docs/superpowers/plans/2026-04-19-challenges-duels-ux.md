# Challenges & Duels UX/UI + Cancel + Live Waiting Room Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refonte UX/UI minimaliste des défis et duels, ajout de l'annulation/suppression, et salle d'attente live avec countdown simultané.

**Architecture:** Les trois axes sont liés — on commence par les migrations Supabase, puis la couche domaine/data/providers, puis l'UI. Chaque tâche compile de façon autonome. La salle d'attente s'appuie sur un stream Supabase Realtime (pattern identique à `run_sessions`).

**Tech Stack:** Flutter/Dart, Riverpod (StateNotifier + StreamProvider), Supabase Flutter (.stream() realtime), go_router, Material 3

---

## File Map

### Nouveaux fichiers
| Fichier | Responsabilité |
|---------|---------------|
| `lib/core/constants/app_colors.dart` | Palette de couleurs centralisée |
| `lib/features/challenges/domain/entities/duel_ready_state_entity.dart` | Entité état "prêt" d'un joueur en salle d'attente |
| `lib/features/challenges/presentation/pages/duel_waiting_room_page.dart` | Écran salle d'attente duel live |

### Fichiers modifiés
| Fichier | Ce qui change |
|---------|--------------|
| `lib/features/challenges/domain/entities/duel_entity.dart` | + `DuelStatus.cancelled`, + `cancelledById` sur `DuelEntity` |
| `lib/features/challenges/domain/entities/group_challenge_participant_entity.dart` | + `ParticipantStatus.left` |
| `lib/features/challenges/data/models/duel_model.dart` | + sérialisation `cancelledById` |
| `lib/features/challenges/data/datasources/duel_remote_datasource.dart` | + `cancelDuel`, `setReady`, `watchReadyStates` |
| `lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart` | + `deleteChallenge`, `leaveChallenge` |
| `lib/features/challenges/domain/repositories/duel_repository.dart` | + signatures nouvelles méthodes |
| `lib/features/challenges/domain/repositories/group_challenge_repository.dart` | + signatures nouvelles méthodes |
| `lib/features/challenges/data/repositories/duel_repository_impl.dart` | + implémentations nouvelles méthodes |
| `lib/features/challenges/data/repositories/group_challenge_repository_impl.dart` | + implémentations nouvelles méthodes |
| `lib/features/challenges/presentation/providers/duel_provider.dart` | + `cancelDuel`, `setReady` dans notifier ; + `duelReadyStatesProvider` |
| `lib/features/challenges/presentation/providers/group_challenge_provider.dart` | + `deleteChallenge`, `leaveChallenge` |
| `lib/features/challenges/presentation/widgets/duel_card.dart` | Refonte visuelle minimaliste |
| `lib/features/challenges/presentation/widgets/group_challenge_card.dart` | Refonte visuelle minimaliste |
| `lib/features/challenges/presentation/pages/duel_detail_page.dart` | Refonte UI + bouton annuler + route salle d'attente |
| `lib/features/challenges/presentation/pages/group_challenge_detail_page.dart` | Refonte UI + bouton supprimer/quitter |
| `lib/core/constants/route_constants.dart` | + `duelWaitingRoom` route |
| `lib/app.dart` | + import + GoRoute pour `DuelWaitingRoomPage` |

---

## Task 1 — Migrations Supabase

**Files:**
- N/A (via MCP tool `mcp__supabase__apply_migration`)

- [ ] **Step 1.1: Appliquer migration 1 — cancelled_by_id sur duels**

Via MCP `mcp__supabase__apply_migration` avec nom `add_cancelled_duel_support` et SQL :

```sql
ALTER TABLE duels
  ADD COLUMN IF NOT EXISTS cancelled_by_id UUID REFERENCES profiles(id);

ALTER TABLE duels
  DROP CONSTRAINT IF EXISTS duels_status_check;

ALTER TABLE duels
  ADD CONSTRAINT duels_status_check
  CHECK (status IN ('pending','accepted','rejected','active','completed','cancelled'));
```

- [ ] **Step 1.2: Appliquer migration 2 — statut left sur participants**

Via MCP `mcp__supabase__apply_migration` avec nom `add_left_participant_status` et SQL :

```sql
ALTER TABLE group_challenge_participants
  DROP CONSTRAINT IF EXISTS group_challenge_participants_status_check;

ALTER TABLE group_challenge_participants
  ADD CONSTRAINT group_challenge_participants_status_check
  CHECK (status IN ('invited','accepted','rejected','left'));
```

- [ ] **Step 1.3: Appliquer migration 3 — table duel_ready_states**

Via MCP `mcp__supabase__apply_migration` avec nom `create_duel_ready_states` et SQL :

```sql
CREATE TABLE IF NOT EXISTS duel_ready_states (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  duel_id    UUID NOT NULL REFERENCES duels(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ready_at   TIMESTAMPTZ,
  UNIQUE(duel_id, user_id)
);

ALTER TABLE duel_ready_states ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read ready states"
  ON duel_ready_states FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM duels
      WHERE duels.id = duel_ready_states.duel_id
        AND (duels.challenger_id = auth.uid() OR duels.challenged_id = auth.uid())
    )
  );

CREATE POLICY "Users can upsert their own ready state"
  ON duel_ready_states FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

- [ ] **Step 1.4: Vérifier les tables dans Supabase**

Via MCP `mcp__supabase__execute_sql` :
```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'duels' AND column_name = 'cancelled_by_id';

SELECT constraint_name FROM information_schema.table_constraints
WHERE table_name = 'duel_ready_states';
```

Expected : retourner les colonnes et contraintes créées.

- [ ] **Step 1.5: Commit**

```bash
git add -A
git commit -m "feat: add Supabase migrations for cancelled duels, left participants, and duel_ready_states"
```

---

## Task 2 — AppColors + DuelReadyStateEntity

**Files:**
- Create: `lib/core/constants/app_colors.dart`
- Create: `lib/features/challenges/domain/entities/duel_ready_state_entity.dart`

- [ ] **Step 2.1: Créer AppColors**

```dart
// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color background   = Color(0xFFF2F2F7);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color accent       = Color(0xFF007AFF);
  static const Color success      = Color(0xFF34C759);
  static const Color danger       = Color(0xFFFF3B30);
  static const Color textPrimary  = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF6C6C70);
  static const Color border       = Color(0xFFE5E5EA);

  // Chip backgrounds (15% opacity)
  static const Color chipAccentBg  = Color(0x1A007AFF);
  static const Color chipSuccessBg = Color(0x1A34C759);
  static const Color chipDangerBg  = Color(0x1AFF3B30);
  static const Color chipNeutralBg = Color(0xFFE5E5EA);
}
```

- [ ] **Step 2.2: Créer DuelReadyStateEntity**

```dart
// lib/features/challenges/domain/entities/duel_ready_state_entity.dart
class DuelReadyStateEntity {
  final String id;
  final String duelId;
  final String userId;
  final DateTime? readyAt;

  const DuelReadyStateEntity({
    required this.id,
    required this.duelId,
    required this.userId,
    this.readyAt,
  });

  bool get isReady => readyAt != null;

  factory DuelReadyStateEntity.fromJson(Map<String, dynamic> json) {
    return DuelReadyStateEntity(
      id: json['id'] as String,
      duelId: json['duel_id'] as String,
      userId: json['user_id'] as String,
      readyAt: json['ready_at'] != null
          ? DateTime.parse(json['ready_at'] as String)
          : null,
    );
  }
}
```

- [ ] **Step 2.3: Vérifier la compilation**

```bash
flutter analyze lib/core/constants/app_colors.dart lib/features/challenges/domain/entities/duel_ready_state_entity.dart
```

Expected : no issues.

- [ ] **Step 2.4: Commit**

```bash
git add lib/core/constants/app_colors.dart lib/features/challenges/domain/entities/duel_ready_state_entity.dart
git commit -m "feat: add AppColors constants and DuelReadyStateEntity"
```

---

## Task 3 — DuelStatus.cancelled + DuelEntity.cancelledById

**Files:**
- Modify: `lib/features/challenges/domain/entities/duel_entity.dart`

- [ ] **Step 3.1: Mettre à jour duel_entity.dart**

Remplacer le fichier entier :

```dart
// lib/features/challenges/domain/entities/duel_entity.dart
import '../../../profile/domain/entities/profile_entity.dart';

enum DuelStatus {
  pending,
  accepted,
  rejected,
  active,
  completed,
  cancelled;

  static DuelStatus fromString(String s) {
    switch (s) {
      case 'accepted':  return DuelStatus.accepted;
      case 'rejected':  return DuelStatus.rejected;
      case 'active':    return DuelStatus.active;
      case 'completed': return DuelStatus.completed;
      case 'cancelled': return DuelStatus.cancelled;
      default:          return DuelStatus.pending;
    }
  }

  String toJson() => name;
}

enum DuelTiming {
  live,
  async;

  static DuelTiming fromString(String s) =>
      s == 'async' ? DuelTiming.async : DuelTiming.live;

  String toJson() => name;
}

class DuelEntity {
  final String id;
  final String challengerId;
  final String challengedId;
  final DuelStatus status;
  final DuelTiming timing;
  final int? deadlineHours;
  final String? challengerActivityId;
  final String? challengedActivityId;
  final String? winnerId;
  final String? cancelledById;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProfileEntity? challengerProfile;
  final ProfileEntity? challengedProfile;
  final double? targetDistanceMeters;
  final String? description;

  const DuelEntity({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    required this.status,
    required this.timing,
    this.deadlineHours,
    this.challengerActivityId,
    this.challengedActivityId,
    this.winnerId,
    this.cancelledById,
    required this.createdAt,
    required this.updatedAt,
    this.challengerProfile,
    this.challengedProfile,
    this.targetDistanceMeters,
    this.description,
  });

  bool get isPending    => status == DuelStatus.pending;
  bool get isActive     => status == DuelStatus.active;
  bool get isCompleted  => status == DuelStatus.completed;
  bool get isCancelled  => status == DuelStatus.cancelled;

  ProfileEntity? getOtherProfile(String currentUserId) =>
      currentUserId == challengerId ? challengedProfile : challengerProfile;

  String getOtherUserId(String currentUserId) =>
      currentUserId == challengerId ? challengedId : challengerId;
}
```

- [ ] **Step 3.2: Vérifier — flutter analyze signalera les switch exhaustifs à corriger dans duel_card.dart et duel_detail_page.dart (c'est attendu)**

```bash
flutter analyze lib/features/challenges/domain/entities/duel_entity.dart
```

Expected : no issues on this file specifically (les erreurs exhaustive switch sont dans d'autres fichiers, traitées dans Task 12 et 14).

- [ ] **Step 3.3: Commit**

```bash
git add lib/features/challenges/domain/entities/duel_entity.dart
git commit -m "feat: add DuelStatus.cancelled and cancelledById to DuelEntity"
```

---

## Task 4 — ParticipantStatus.left

**Files:**
- Modify: `lib/features/challenges/domain/entities/group_challenge_participant_entity.dart`

- [ ] **Step 4.1: Ajouter ParticipantStatus.left**

Remplacer uniquement l'enum `ParticipantStatus` :

```dart
enum ParticipantStatus {
  invited,
  accepted,
  rejected,
  left;

  static ParticipantStatus fromString(String s) {
    switch (s) {
      case 'accepted': return ParticipantStatus.accepted;
      case 'rejected': return ParticipantStatus.rejected;
      case 'left':     return ParticipantStatus.left;
      default:         return ParticipantStatus.invited;
    }
  }

  String toJson() => name;
}
```

- [ ] **Step 4.2: Vérifier**

```bash
flutter analyze lib/features/challenges/domain/entities/group_challenge_participant_entity.dart
```

Expected : no issues.

- [ ] **Step 4.3: Commit**

```bash
git add lib/features/challenges/domain/entities/group_challenge_participant_entity.dart
git commit -m "feat: add ParticipantStatus.left for group challenge leave flow"
```

---

## Task 5 — DuelModel — sérialisation cancelledById

**Files:**
- Modify: `lib/features/challenges/data/models/duel_model.dart`

- [ ] **Step 5.1: Mettre à jour DuelModel**

Remplacer le fichier entier :

```dart
// lib/features/challenges/data/models/duel_model.dart
import '../../../profile/data/models/profile_model.dart';
import '../../domain/entities/duel_entity.dart';

class DuelModel extends DuelEntity {
  const DuelModel({
    required super.id,
    required super.challengerId,
    required super.challengedId,
    required super.status,
    required super.timing,
    super.deadlineHours,
    super.challengerActivityId,
    super.challengedActivityId,
    super.winnerId,
    super.cancelledById,
    required super.createdAt,
    required super.updatedAt,
    super.challengerProfile,
    super.challengedProfile,
    super.targetDistanceMeters,
    super.description,
  });

  factory DuelModel.fromJson(Map<String, dynamic> json) {
    return DuelModel(
      id: json['id'] as String,
      challengerId: json['challenger_id'] as String,
      challengedId: json['challenged_id'] as String,
      status: DuelStatus.fromString(json['status'] as String),
      timing: DuelTiming.fromString(json['timing'] as String),
      deadlineHours: json['deadline_hours'] as int?,
      challengerActivityId: json['challenger_activity_id'] as String?,
      challengedActivityId: json['challenged_activity_id'] as String?,
      winnerId: json['winner_id'] as String?,
      cancelledById: json['cancelled_by_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      challengerProfile: json['challenger'] != null
          ? ProfileModel.fromJson(json['challenger'] as Map<String, dynamic>).toEntity()
          : null,
      challengedProfile: json['challenged'] != null
          ? ProfileModel.fromJson(json['challenged'] as Map<String, dynamic>).toEntity()
          : null,
      targetDistanceMeters: (json['target_distance_meters'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenger_id': challengerId,
    'challenged_id': challengedId,
    'status': status.toJson(),
    'timing': timing.toJson(),
    if (deadlineHours != null) 'deadline_hours': deadlineHours,
    if (challengerActivityId != null) 'challenger_activity_id': challengerActivityId,
    if (challengedActivityId != null) 'challenged_activity_id': challengedActivityId,
    if (winnerId != null) 'winner_id': winnerId,
    if (cancelledById != null) 'cancelled_by_id': cancelledById,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (targetDistanceMeters != null) 'target_distance_meters': targetDistanceMeters,
    if (description != null) 'description': description,
  };

  DuelEntity toEntity() => DuelEntity(
    id: id,
    challengerId: challengerId,
    challengedId: challengedId,
    status: status,
    timing: timing,
    deadlineHours: deadlineHours,
    challengerActivityId: challengerActivityId,
    challengedActivityId: challengedActivityId,
    winnerId: winnerId,
    cancelledById: cancelledById,
    createdAt: createdAt,
    updatedAt: updatedAt,
    challengerProfile: challengerProfile,
    challengedProfile: challengedProfile,
    targetDistanceMeters: targetDistanceMeters,
    description: description,
  );
}
```

- [ ] **Step 5.2: Vérifier**

```bash
flutter analyze lib/features/challenges/data/models/duel_model.dart
```

Expected : no issues.

- [ ] **Step 5.3: Commit**

```bash
git add lib/features/challenges/data/models/duel_model.dart
git commit -m "feat: serialize cancelledById in DuelModel"
```

---

## Task 6 — DuelRemoteDataSource — cancelDuel, setReady, watchReadyStates

**Files:**
- Modify: `lib/features/challenges/data/datasources/duel_remote_datasource.dart`

- [ ] **Step 6.1: Ajouter l'import de DuelReadyStateEntity en haut du fichier**

Ajouter après les imports existants :

```dart
import '../../domain/entities/duel_ready_state_entity.dart';
```

- [ ] **Step 6.2: Ajouter les trois méthodes à la classe DuelRemoteDataSource (avant la closing brace `}`)**

```dart
  Future<void> cancelDuel(String duelId, String cancelledById) async {
    try {
      await _client
          .from('duels')
          .update({
            'status': 'cancelled',
            'cancelled_by_id': cancelledById,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to cancel duel: $e');
    }
  }

  Future<void> setReady(String duelId, String userId) async {
    try {
      await _client
          .from('duel_ready_states')
          .upsert(
            {'duel_id': duelId, 'user_id': userId, 'ready_at': DateTime.now().toIso8601String()},
            onConflict: 'duel_id,user_id',
          )
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to set ready: $e');
    }
  }

  Stream<List<DuelReadyStateEntity>> watchReadyStates(String duelId) {
    return _client
        .from('duel_ready_states')
        .stream(primaryKey: ['id'])
        .eq('duel_id', duelId)
        .map((rows) => rows
            .map((r) => DuelReadyStateEntity.fromJson(r))
            .toList());
  }
```

- [ ] **Step 6.3: Vérifier**

```bash
flutter analyze lib/features/challenges/data/datasources/duel_remote_datasource.dart
```

Expected : no issues.

- [ ] **Step 6.4: Commit**

```bash
git add lib/features/challenges/data/datasources/duel_remote_datasource.dart
git commit -m "feat: add cancelDuel, setReady, watchReadyStates to DuelRemoteDataSource"
```

---

## Task 7 — GroupChallengeRemoteDataSource — deleteChallenge, leaveChallenge

**Files:**
- Modify: `lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart`

- [ ] **Step 7.1: Ajouter les deux méthodes à GroupChallengeRemoteDataSource (avant la closing brace `}`)**

```dart
  Future<void> deleteChallenge(String challengeId) async {
    try {
      await _client
          .from('group_challenges')
          .delete()
          .eq('id', challengeId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to delete challenge: $e');
    }
  }

  Future<void> leaveChallenge(String challengeId, String userId) async {
    try {
      await _client
          .from('group_challenge_participants')
          .update({'status': 'left'})
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to leave challenge: $e');
    }
  }
```

- [ ] **Step 7.2: Vérifier**

```bash
flutter analyze lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart
```

Expected : no issues.

- [ ] **Step 7.3: Commit**

```bash
git add lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart
git commit -m "feat: add deleteChallenge and leaveChallenge to GroupChallengeRemoteDataSource"
```

---

## Task 8 — DuelRepository interface + impl

**Files:**
- Modify: `lib/features/challenges/domain/repositories/duel_repository.dart`
- Modify: `lib/features/challenges/data/repositories/duel_repository_impl.dart`

- [ ] **Step 8.1: Mettre à jour l'interface DuelRepository**

Remplacer le fichier entier :

```dart
// lib/features/challenges/domain/repositories/duel_repository.dart
import '../entities/duel_entity.dart';
import '../entities/duel_ready_state_entity.dart';

abstract class DuelRepository {
  Future<List<DuelEntity>> getMyDuels();
  Future<List<DuelEntity>> getPendingInvites();
  Future<DuelEntity> createDuel({
    required String challengedId,
    required DuelTiming timing,
    int? deadlineHours,
    double? targetDistanceMeters,
    String? description,
  });
  Future<void> respondToDuel(String duelId, {required bool accept});
  Future<void> linkActivity(String duelId, String activityId, {required bool isChallenger});
  Future<void> resolveWinner(String duelId);
  Future<void> cancelDuel(String duelId);
  Future<void> setReady(String duelId);
  Stream<List<DuelReadyStateEntity>> watchReadyStates(String duelId);
}
```

- [ ] **Step 8.2: Ajouter les trois méthodes dans DuelRepositoryImpl (avant la closing brace `}`)**

```dart
  @override
  Future<void> cancelDuel(String duelId) async {
    await _ds.cancelDuel(duelId, _userId);
  }

  @override
  Future<void> setReady(String duelId) async {
    await _ds.setReady(duelId, _userId);
  }

  @override
  Stream<List<DuelReadyStateEntity>> watchReadyStates(String duelId) {
    return _ds.watchReadyStates(duelId);
  }
```

Et ajouter l'import manquant en haut de `duel_repository_impl.dart` :

```dart
import '../../domain/entities/duel_ready_state_entity.dart';
```

- [ ] **Step 8.3: Vérifier**

```bash
flutter analyze lib/features/challenges/domain/repositories/duel_repository.dart lib/features/challenges/data/repositories/duel_repository_impl.dart
```

Expected : no issues.

- [ ] **Step 8.4: Commit**

```bash
git add lib/features/challenges/domain/repositories/duel_repository.dart lib/features/challenges/data/repositories/duel_repository_impl.dart
git commit -m "feat: add cancelDuel, setReady, watchReadyStates to DuelRepository"
```

---

## Task 9 — GroupChallengeRepository interface + impl

**Files:**
- Modify: `lib/features/challenges/domain/repositories/group_challenge_repository.dart`
- Modify: `lib/features/challenges/data/repositories/group_challenge_repository_impl.dart`

- [ ] **Step 9.1: Mettre à jour l'interface GroupChallengeRepository**

Remplacer le fichier entier :

```dart
// lib/features/challenges/domain/repositories/group_challenge_repository.dart
import '../entities/group_challenge_entity.dart';

abstract class GroupChallengeRepository {
  Future<List<GroupChallengeEntity>> getMyChallenges();
  Future<List<GroupChallengeEntity>> getPendingInvites();
  Future<GroupChallengeEntity> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
    double? targetDistanceMeters,
    String? description,
  });
  Future<void> respondToChallenge(String challengeId, {required bool accept});
  Future<void> forceStart(String challengeId);
  Future<void> incrementDistance(String challengeId, double additionalMeters);
  Future<GroupChallengeEntity> getChallenge(String challengeId);
  Future<void> deleteChallenge(String challengeId);
  Future<void> leaveChallenge(String challengeId);
}
```

- [ ] **Step 9.2: Ajouter les deux méthodes dans GroupChallengeRepositoryImpl (avant la closing brace `}`)**

```dart
  @override
  Future<void> deleteChallenge(String challengeId) async {
    await _ds.deleteChallenge(challengeId);
  }

  @override
  Future<void> leaveChallenge(String challengeId) async {
    await _ds.leaveChallenge(challengeId, _userId);
  }
```

- [ ] **Step 9.3: Vérifier**

```bash
flutter analyze lib/features/challenges/domain/repositories/group_challenge_repository.dart lib/features/challenges/data/repositories/group_challenge_repository_impl.dart
```

Expected : no issues.

- [ ] **Step 9.4: Commit**

```bash
git add lib/features/challenges/domain/repositories/group_challenge_repository.dart lib/features/challenges/data/repositories/group_challenge_repository_impl.dart
git commit -m "feat: add deleteChallenge and leaveChallenge to GroupChallengeRepository"
```

---

## Task 10 — DuelNotifier — cancelDuel, setReady + duelReadyStatesProvider

**Files:**
- Modify: `lib/features/challenges/presentation/providers/duel_provider.dart`

- [ ] **Step 10.1: Ajouter l'import DuelReadyStateEntity en haut du fichier**

```dart
import '../../domain/entities/duel_ready_state_entity.dart';
```

- [ ] **Step 10.2: Ajouter cancelDuel et setReady dans DuelNotifier (avant `void clearMessages()`)**

```dart
  Future<bool> cancelDuel(String duelId) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      await repo.cancelDuel(duelId);
      state = state.copyWith(successMessage: 'Duel annulé');
      await loadDuels();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: "Erreur lors de l'annulation");
      return false;
    }
  }

  Future<void> setReady(String duelId) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      await repo.setReady(duelId);
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur salle d\'attente');
    }
  }
```

- [ ] **Step 10.3: Ajouter le StreamProvider duelReadyStatesProvider à la fin du fichier (après `duelNotifierProvider`)**

```dart
final duelReadyStatesProvider =
    StreamProvider.family<List<DuelReadyStateEntity>, String>((ref, duelId) {
  final repo = ref.watch(duelRepositoryProvider);
  return repo.watchReadyStates(duelId);
});
```

- [ ] **Step 10.4: Vérifier**

```bash
flutter analyze lib/features/challenges/presentation/providers/duel_provider.dart
```

Expected : no issues.

- [ ] **Step 10.5: Commit**

```bash
git add lib/features/challenges/presentation/providers/duel_provider.dart
git commit -m "feat: add cancelDuel, setReady to DuelNotifier and duelReadyStatesProvider"
```

---

## Task 11 — GroupChallengeNotifier — deleteChallenge, leaveChallenge

**Files:**
- Modify: `lib/features/challenges/presentation/providers/group_challenge_provider.dart`

- [ ] **Step 11.1: Ajouter deleteChallenge et leaveChallenge dans GroupChallengeNotifier (avant `void clearMessages()`)**

```dart
  Future<bool> deleteChallenge(String challengeId) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.deleteChallenge(challengeId);
      state = state.copyWith(successMessage: 'Défi supprimé');
      await loadChallenges();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la suppression');
      return false;
    }
  }

  Future<bool> leaveChallenge(String challengeId) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.leaveChallenge(challengeId);
      state = state.copyWith(successMessage: 'Défi quitté');
      await loadChallenges();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du retrait');
      return false;
    }
  }
```

- [ ] **Step 11.2: Vérifier**

```bash
flutter analyze lib/features/challenges/presentation/providers/group_challenge_provider.dart
```

Expected : no issues.

- [ ] **Step 11.3: Commit**

```bash
git add lib/features/challenges/presentation/providers/group_challenge_provider.dart
git commit -m "feat: add deleteChallenge and leaveChallenge to GroupChallengeNotifier"
```

---

## Task 12 — DuelCard — refonte visuelle minimaliste

**Files:**
- Modify: `lib/features/challenges/presentation/widgets/duel_card.dart`

- [ ] **Step 12.1: Remplacer DuelCard entier**

```dart
// lib/features/challenges/presentation/widgets/duel_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../domain/entities/duel_entity.dart';

class DuelCard extends StatelessWidget {
  final DuelEntity duel;
  final String currentUserId;

  const DuelCard({super.key, required this.duel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final otherProfile = duel.getOtherProfile(currentUserId);
    final otherName = otherProfile?.username ?? '…';

    final (chipLabel, chipBg, chipFg) = _chipStyle(currentUserId);
    final subtitleParts = <String>[
      duel.timing == DuelTiming.live ? 'Live' : 'Différé',
      if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
        '${duel.deadlineHours}h',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          Routes.duelDetail.replaceFirst(':id', duel.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
                    const SizedBox(height: 6),
                    Text(
                      'vs @$otherName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _chipStyle(String currentUserId) {
    switch (duel.status) {
      case DuelStatus.pending:
        return duel.challengerId == currentUserId
            ? ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary)
            : ('Invitation reçue', AppColors.chipAccentBg, AppColors.accent);
      case DuelStatus.accepted:
        return ('Accepté', AppColors.chipAccentBg, AppColors.accent);
      case DuelStatus.active:
        return ('En cours', AppColors.accent, AppColors.surface);
      case DuelStatus.completed:
        return duel.winnerId == currentUserId
            ? ('Victoire ✓', AppColors.chipSuccessBg, AppColors.success)
            : ('Défaite', AppColors.chipDangerBg, AppColors.danger);
      case DuelStatus.rejected:
        return ('Refusé', AppColors.chipNeutralBg, AppColors.textSecondary);
      case DuelStatus.cancelled:
        return ('Annulé', AppColors.chipNeutralBg, AppColors.textSecondary);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
```

- [ ] **Step 12.2: Vérifier**

```bash
flutter analyze lib/features/challenges/presentation/widgets/duel_card.dart
```

Expected : no issues.

- [ ] **Step 12.3: Commit**

```bash
git add lib/features/challenges/presentation/widgets/duel_card.dart
git commit -m "feat: refonte visuelle minimaliste DuelCard"
```

---

## Task 13 — GroupChallengeCard — refonte visuelle minimaliste

**Files:**
- Modify: `lib/features/challenges/presentation/widgets/group_challenge_card.dart`

- [ ] **Step 13.1: Remplacer GroupChallengeCard entier**

```dart
// lib/features/challenges/presentation/widgets/group_challenge_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';

class GroupChallengeCard extends StatelessWidget {
  final GroupChallengeEntity challenge;
  final String currentUserId;
  final void Function(bool accept)? onRespond;

  const GroupChallengeCard({
    super.key,
    required this.challenge,
    required this.currentUserId,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final myParticipation = challenge.participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull;
    final isInvited = myParticipation?.status == ParticipantStatus.invited;

    final (chipLabel, chipBg, chipFg) = _chipStyle(isInvited);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isInvited
            ? null
            : () => context.push(
                Routes.groupChallengeDetail.replaceFirst(':id', challenge.id),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
                  const Spacer(),
                  if (!isInvited)
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                challenge.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${challenge.participants.length} participant${challenge.participants.length > 1 ? 's' : ''} · ${challenge.durationDays}j',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (challenge.isActive) ...[
                const SizedBox(height: 12),
                ...challenge.sortedLeaderboard.take(3).toList().asMap().entries.map((e) {
                  final medals = ['🥇', '🥈', '🥉'];
                  final p = e.value;
                  final isMe = p.userId == currentUserId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(medals[e.key], style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '@${p.profile?.username ?? p.userId.substring(0, 6)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          p.formattedDistance,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isMe ? FontWeight.w700 : FontWeight.normal,
                            color: isMe ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (isInvited && onRespond != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onRespond!(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Accepter', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond!(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _chipStyle(bool isInvited) {
    if (isInvited) return ('Invitation', AppColors.chipAccentBg, AppColors.accent);
    if (challenge.isActive) {
      return ('${challenge.daysRemaining}j restants', AppColors.chipAccentBg, AppColors.accent);
    }
    if (challenge.isCompleted) return ('Terminé', AppColors.chipNeutralBg, AppColors.textSecondary);
    return ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
```

- [ ] **Step 13.2: Vérifier**

```bash
flutter analyze lib/features/challenges/presentation/widgets/group_challenge_card.dart
```

Expected : no issues.

- [ ] **Step 13.3: Commit**

```bash
git add lib/features/challenges/presentation/widgets/group_challenge_card.dart
git commit -m "feat: refonte visuelle minimaliste GroupChallengeCard"
```

---

## Task 14 — DuelDetailPage — refonte UI + annuler + route salle d'attente

**Files:**
- Modify: `lib/features/challenges/presentation/pages/duel_detail_page.dart`

- [ ] **Step 14.1: Remplacer DuelDetailPage entier**

```dart
// lib/features/challenges/presentation/pages/duel_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';

class DuelDetailPage extends ConsumerStatefulWidget {
  final String duelId;
  const DuelDetailPage({super.key, required this.duelId});

  @override
  ConsumerState<DuelDetailPage> createState() => _DuelDetailPageState();
}

class _DuelDetailPageState extends ConsumerState<DuelDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(duelNotifierProvider.notifier).loadDuels();
    });
  }

  Future<void> _confirmCancel(String duelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler le duel ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Annuler le duel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await ref.read(duelNotifierProvider.notifier).cancelDuel(duelId);
      if (success && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(duelNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final duel = [
      ...state.myDuels,
      ...state.pendingInvites,
    ].where((d) => d.id == widget.duelId).firstOrNull;

    if (duel == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Duel'),
        ),
        body: const Center(child: Text('Duel introuvable')),
      );
    }

    final otherProfile = duel.getOtherProfile(currentUserId);
    final otherName = otherProfile?.username ?? '…';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('vs @$otherName', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status + timing
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DuelStatusChip(duel: duel, currentUserId: currentUserId),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: duel.timing == DuelTiming.live
                      ? Icons.bolt_rounded
                      : Icons.schedule_rounded,
                  label: duel.timing == DuelTiming.live ? 'Live' : 'Différé',
                ),
                if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
                  _InfoRow(icon: Icons.timer_outlined, label: 'Délai : ${duel.deadlineHours}h'),
                if (duel.targetDistanceMeters != null)
                  _InfoRow(
                    icon: Icons.straighten_rounded,
                    label: '${(duel.targetDistanceMeters! / 1000).toStringAsFixed(1)} km',
                    highlight: true,
                  ),
                if (duel.description != null && duel.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    duel.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pending — accept/reject
          if (duel.isPending && duel.challengedId == currentUserId)
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu as reçu ce défi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => ref
                              .read(duelNotifierProvider.notifier)
                              .respondToDuel(widget.duelId, accept: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Accepter'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => ref
                              .read(duelNotifierProvider.notifier)
                              .respondToDuel(widget.duelId, accept: false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Refuser', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Accepted live — salle d'attente
          if ((duel.status == DuelStatus.accepted || duel.status == DuelStatus.active) &&
              duel.timing == DuelTiming.live) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  Routes.duelWaitingRoom.replaceFirst(':id', duel.id),
                ),
                icon: const Icon(Icons.people_rounded, size: 22),
                label: const Text(
                  "Rejoindre la salle d'attente",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],

          // Accepted async — start run directly
          if ((duel.status == DuelStatus.accepted || duel.status == DuelStatus.active) &&
              duel.timing == DuelTiming.async) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => context.push(Routes.runTracking),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Démarrer ma course',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],

          // Completed — résultat
          if (duel.isCompleted) ...[
            const SizedBox(height: 12),
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Résultat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  if (duel.winnerId != null)
                    Text(
                      duel.winnerId == currentUserId ? '🥇 Victoire !' : '🥈 Défaite',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: duel.winnerId == currentUserId ? AppColors.success : AppColors.danger,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Annuler (tout statut sauf completed et cancelled)
          if (duel.status != DuelStatus.completed && duel.status != DuelStatus.cancelled) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(duel.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Annuler le duel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _InfoRow({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: highlight ? AppColors.accent : AppColors.textPrimary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuelStatusChip extends StatelessWidget {
  final DuelEntity duel;
  final String currentUserId;
  const _DuelStatusChip({required this.duel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (duel.status) {
      DuelStatus.pending   => ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary),
      DuelStatus.accepted  => ('Accepté', AppColors.chipAccentBg, AppColors.accent),
      DuelStatus.active    => ('En cours', AppColors.accent, AppColors.surface),
      DuelStatus.completed => duel.winnerId == currentUserId
          ? ('Victoire ✓', AppColors.chipSuccessBg, AppColors.success)
          : ('Défaite', AppColors.chipDangerBg, AppColors.danger),
      DuelStatus.rejected  => ('Refusé', AppColors.chipNeutralBg, AppColors.textSecondary),
      DuelStatus.cancelled => ('Annulé', AppColors.chipNeutralBg, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
```

- [ ] **Step 14.2: Vérifier (Routes.duelWaitingRoom sera en erreur jusqu'à Task 16 — c'est attendu)**

```bash
flutter analyze lib/features/challenges/presentation/pages/duel_detail_page.dart
```

Expected : 1 erreur sur `Routes.duelWaitingRoom` (non encore défini). Les autres : no issues.

- [ ] **Step 14.3: Commit**

```bash
git add lib/features/challenges/presentation/pages/duel_detail_page.dart
git commit -m "feat: refonte DuelDetailPage avec annulation et route salle d'attente"
```

---

## Task 15 — GroupChallengeDetailPage — refonte UI + supprimer/quitter

**Files:**
- Modify: `lib/features/challenges/presentation/pages/group_challenge_detail_page.dart`

- [ ] **Step 15.1: Remplacer GroupChallengeDetailPage entier**

```dart
// lib/features/challenges/presentation/pages/group_challenge_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../providers/group_challenge_provider.dart';

class GroupChallengeDetailPage extends ConsumerWidget {
  final String challengeId;
  const GroupChallengeDetailPage({super.key, required this.challengeId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le défi ?'),
        content: const Text('Le défi sera supprimé pour tous les participants. Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(groupChallengeNotifierProvider.notifier)
          .deleteChallenge(challengeId);
      if (success && context.mounted) context.pop();
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le défi ?'),
        content: const Text('Tu ne pourras plus participer à ce défi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(groupChallengeNotifierProvider.notifier)
          .leaveChallenge(challengeId);
      if (success && context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final challenge = [...state.myChallenges, ...state.pendingInvites]
        .where((c) => c.id == challengeId)
        .firstOrNull;

    if (challenge == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('Défi')),
        body: const Center(child: Text('Défi introuvable')),
      );
    }

    final pendingParticipants = challenge.participants
        .where((p) => p.status == ParticipantStatus.invited)
        .toList();

    final myParticipation = challenge.participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull;

    final isCreator = challenge.creatorId == currentUserId;
    final canLeave = !isCreator &&
        (myParticipation?.status == ParticipantStatus.accepted ||
         myParticipation?.status == ParticipantStatus.invited);
    final canDelete = isCreator && !challenge.isCompleted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(groupChallengeNotifierProvider.notifier).loadChallenges(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChallengeStatusChip(challenge: challenge),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.calendar_today_rounded, label: '${challenge.durationDays} jours'),
                  if (challenge.isActive)
                    _InfoRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: '${challenge.daysRemaining} jour${challenge.daysRemaining > 1 ? 's' : ''} restant${challenge.daysRemaining > 1 ? 's' : ''}',
                      highlight: true,
                    ),
                  if (challenge.targetDistanceMeters != null)
                    _InfoRow(
                      icon: Icons.straighten_rounded,
                      label: 'Objectif : ${(challenge.targetDistanceMeters! / 1000).toStringAsFixed(0)} km',
                      highlight: true,
                    ),
                  if (challenge.description != null && challenge.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      challenge.description!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Force-start
            if (isCreator && challenge.canForceStart) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(groupChallengeNotifierProvider.notifier)
                      .forceStart(challengeId),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lancer maintenant', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            // Leaderboard
            const SizedBox(height: 20),
            const Text(
              'Classement',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),

            if (challenge.participants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun participant pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...challenge.sortedLeaderboard.toList().asMap().entries.map((entry) {
                final rank = entry.key;
                final p = entry.value;
                final medals = ['🥇', '🥈', '🥉'];
                final medalEmoji = rank < 3 ? medals[rank] : '${rank + 1}.';
                final isMe = p.userId == currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFF0F7FF) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMe ? AppColors.accent : AppColors.border,
                      width: isMe ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(medalEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@${p.profile?.username ?? p.userId.substring(0, 6)}${isMe ? ' (moi)' : ''}',
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.w700 : FontWeight.normal,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        p.formattedDistance,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isMe ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Participants en attente
            if (pendingParticipants.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'En attente de réponse',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...pendingParticipants.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.chipNeutralBg,
                      child: Icon(Icons.person, color: AppColors.textSecondary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('@${p.profile?.username ?? p.userId.substring(0, 6)}')),
                    const Text('En attente…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              )),
            ],

            // Actions destructives
            const SizedBox(height: 28),
            if (canDelete)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmDelete(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Supprimer le défi', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            if (canLeave)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmLeave(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Quitter le défi', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _InfoRow({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: highlight ? AppColors.accent : AppColors.textPrimary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeStatusChip extends StatelessWidget {
  final GroupChallengeEntity challenge;
  const _ChallengeStatusChip({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = challenge.isActive
        ? ('En cours', AppColors.accent, AppColors.surface)
        : challenge.isCompleted
            ? ('Terminé', AppColors.chipNeutralBg, AppColors.textSecondary)
            : ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
```

- [ ] **Step 15.2: Vérifier**

```bash
flutter analyze lib/features/challenges/presentation/pages/group_challenge_detail_page.dart
```

Expected : no issues.

- [ ] **Step 15.3: Commit**

```bash
git add lib/features/challenges/presentation/pages/group_challenge_detail_page.dart
git commit -m "feat: refonte GroupChallengeDetailPage avec suppression et quitter"
```

---

## Task 16 — Route duelWaitingRoom

**Files:**
- Modify: `lib/core/constants/route_constants.dart`

- [ ] **Step 16.1: Ajouter la route duelWaitingRoom**

Dans `route_constants.dart`, ajouter après `duelDetail` :

```dart
static const String duelWaitingRoom = '/challenges/duels/:id/waiting';
```

- [ ] **Step 16.2: Vérifier que les erreurs de Task 14 disparaissent**

```bash
flutter analyze lib/core/constants/route_constants.dart lib/features/challenges/presentation/pages/duel_detail_page.dart
```

Expected : no issues.

- [ ] **Step 16.3: Commit**

```bash
git add lib/core/constants/route_constants.dart
git commit -m "feat: add duelWaitingRoom route constant"
```

---

## Task 17 — DuelWaitingRoomPage

**Files:**
- Create: `lib/features/challenges/presentation/pages/duel_waiting_room_page.dart`
- Modify: `lib/app.dart`

- [ ] **Step 17.1: Créer DuelWaitingRoomPage**

```dart
// lib/features/challenges/presentation/pages/duel_waiting_room_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/duel_provider.dart';

class DuelWaitingRoomPage extends ConsumerStatefulWidget {
  final String duelId;
  const DuelWaitingRoomPage({super.key, required this.duelId});

  @override
  ConsumerState<DuelWaitingRoomPage> createState() => _DuelWaitingRoomPageState();
}

class _DuelWaitingRoomPageState extends ConsumerState<DuelWaitingRoomPage> {
  bool _isReady = false;
  bool _countdownStarted = false;
  int _countdown = 3;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  bool _timeoutDialogShown = false;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setReady() {
    setState(() => _isReady = true);
    ref.read(duelNotifierProvider.notifier).setReady(widget.duelId);
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !_timeoutDialogShown) {
        _timeoutDialogShown = true;
        _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Adversaire absent'),
        content: const Text("L'adversaire n'a pas rejoint la salle d'attente."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(duelNotifierProvider.notifier).cancelDuel(widget.duelId);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Annuler le duel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _timeoutDialogShown = false);
              _startTimeoutTimer();
            },
            child: const Text('Attendre encore'),
          ),
        ],
      ),
    );
  }

  void _startCountdown() {
    if (_countdownStarted) return;
    _countdownStarted = true;
    _timeoutTimer?.cancel();

    var count = 3;
    setState(() => _countdown = count);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      count--;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (count <= 0) {
        timer.cancel();
        context.push(Routes.runTracking);
      } else {
        setState(() => _countdown = count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final duelState = ref.watch(duelNotifierProvider);

    final duel = [
      ...duelState.myDuels,
      ...duelState.pendingInvites,
    ].where((d) => d.id == widget.duelId).firstOrNull;

    final readyStatesAsync = ref.watch(duelReadyStatesProvider(widget.duelId));

    ref.listen(duelReadyStatesProvider(widget.duelId), (_, next) {
      next.whenData((states) {
        final allReady = states.length >= 2 && states.every((s) => s.isReady);
        if (allReady) _startCountdown();
      });
    });

    final otherName = duel?.getOtherProfile(currentUserId)?.username ?? '…';
    final myUsername = duel != null
        ? (currentUserId == duel.challengerId
            ? duel.challengerProfile?.username ?? 'Moi'
            : duel.challengedProfile?.username ?? 'Moi')
        : 'Moi';

    final readyStates = readyStatesAsync.valueOrNull ?? [];
    final myState = readyStates.where((s) => s.userId == currentUserId).firstOrNull;
    final otherState = readyStates.where((s) => s.userId != currentUserId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text("Salle d'attente", style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Countdown display
            if (_countdownStarted) ...[
              Text(
                '$_countdown',
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Partez !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ] else ...[
              // Players status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PlayerStatus(
                    name: myUsername,
                    isReady: myState?.isReady ?? false,
                    isMe: true,
                  ),
                  const Column(
                    children: [
                      Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                    ],
                  ),
                  _PlayerStatus(
                    name: '@$otherName',
                    isReady: otherState?.isReady ?? false,
                    isMe: false,
                  ),
                ],
              ),

              const Spacer(),

              // Ready button
              if (!_isReady)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _setReady,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Je suis prêt !',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.chipSuccessBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success),
                      SizedBox(width: 8),
                      Text(
                        'Tu es prêt — en attente de l\'adversaire…',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerStatus extends StatelessWidget {
  final String name;
  final bool isReady;
  final bool isMe;
  const _PlayerStatus({required this.name, required this.isReady, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReady ? AppColors.chipSuccessBg : AppColors.chipNeutralBg,
            border: Border.all(
              color: isReady ? AppColors.success : AppColors.border,
              width: 2,
            ),
          ),
          child: Icon(
            isReady ? Icons.check_rounded : Icons.person_rounded,
            size: 34,
            color: isReady ? AppColors.success : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          isReady ? 'Prêt ✓' : 'En attente…',
          style: TextStyle(
            fontSize: 12,
            color: isReady ? AppColors.success : AppColors.textSecondary,
            fontWeight: isReady ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 17.2: Ajouter la route dans app.dart**

Dans `lib/app.dart`, ajouter l'import :

```dart
import 'features/challenges/presentation/pages/duel_waiting_room_page.dart';
```

Puis ajouter la GoRoute après la route `duelDetail` (après la closing `),` de duelDetail) :

```dart
GoRoute(
  path: Routes.duelWaitingRoom,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return DuelWaitingRoomPage(duelId: id);
  },
),
```

- [ ] **Step 17.3: Vérifier la compilation complète**

```bash
flutter analyze
```

Expected : no issues.

- [ ] **Step 17.4: Vérifier le build**

```bash
flutter build ios --no-codesign 2>&1 | tail -20
```

Expected : `Build complete.`

- [ ] **Step 17.5: Commit final**

```bash
git add lib/features/challenges/presentation/pages/duel_waiting_room_page.dart lib/app.dart
git commit -m "feat: add DuelWaitingRoomPage and register route in app router"
```

---

## Checklist de vérification finale

Avant de considérer l'implémentation terminée, vérifier :

- [ ] `flutter analyze` passe sans erreurs
- [ ] L'enum `DuelStatus.cancelled` a un case dans tous les switch : `DuelCard._chipStyle`, `_DuelStatusChip` dans `duel_detail_page.dart`
- [ ] Le bouton "Annuler le duel" s'affiche sur `DuelDetailPage` pour les deux participants
- [ ] Le bouton "Supprimer le défi" s'affiche uniquement pour le créateur (non `completed`)
- [ ] Le bouton "Quitter le défi" s'affiche pour les participants non-créateurs
- [ ] Sur `DuelDetailPage`, un duel live `accepted` route vers `/challenges/duels/:id/waiting`, pas vers `/run/tracking`
- [ ] Sur `DuelDetailPage`, un duel async `accepted` route encore vers `/run/tracking`
- [ ] `DuelWaitingRoomPage` écoute le stream et déclenche le countdown quand les deux `isReady`
- [ ] Le timer 5min affiche le dialog "Adversaire absent"
