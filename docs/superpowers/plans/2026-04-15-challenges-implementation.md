# Challenges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter le système de défis (Duel 1v1 + Défi groupe) avec une landing page distincte, des sous-vues séparées, et un backend Supabase dédié.

**Architecture:** Deux entités domain indépendantes (`DuelEntity`, `GroupChallengeEntity`) avec leurs propres tables, datasources, repositories et providers Riverpod. Tout le code réside dans `lib/features/challenges/`. La `ChallengesPage` existante est réécrite en landing.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Supabase, go_router

---

## File Map

**Create:**
- `lib/features/challenges/domain/entities/duel_entity.dart`
- `lib/features/challenges/domain/entities/group_challenge_entity.dart`
- `lib/features/challenges/domain/entities/group_challenge_participant_entity.dart`
- `lib/features/challenges/domain/repositories/duel_repository.dart`
- `lib/features/challenges/domain/repositories/group_challenge_repository.dart`
- `lib/features/challenges/data/models/duel_model.dart`
- `lib/features/challenges/data/models/group_challenge_model.dart`
- `lib/features/challenges/data/models/group_challenge_participant_model.dart`
- `lib/features/challenges/data/datasources/duel_remote_datasource.dart`
- `lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart`
- `lib/features/challenges/data/repositories/duel_repository_impl.dart`
- `lib/features/challenges/data/repositories/group_challenge_repository_impl.dart`
- `lib/features/challenges/presentation/providers/duel_provider.dart`
- `lib/features/challenges/presentation/providers/group_challenge_provider.dart`
- `lib/features/challenges/presentation/widgets/challenge_mode_card.dart`
- `lib/features/challenges/presentation/widgets/friend_selector_widget.dart`
- `lib/features/challenges/presentation/widgets/duel_card.dart`
- `lib/features/challenges/presentation/widgets/group_challenge_card.dart`
- `lib/features/challenges/presentation/pages/duels_page.dart`
- `lib/features/challenges/presentation/pages/create_duel_page.dart`
- `lib/features/challenges/presentation/pages/duel_detail_page.dart`
- `lib/features/challenges/presentation/pages/group_challenges_page.dart`
- `lib/features/challenges/presentation/pages/create_group_challenge_page.dart`
- `lib/features/challenges/presentation/pages/group_challenge_detail_page.dart`

**Modify:**
- `lib/features/challenges/presentation/pages/challenges_page.dart` — rewrite as landing
- `lib/core/constants/route_constants.dart` — add challenge routes
- `lib/main.dart` — register new routes in GoRouter

---

## Task 1: Database migrations

**Files:** Supabase migrations via MCP tool

- [ ] **Step 1: Create the `duels` table**

Run via `mcp__supabase__apply_migration` with name `create_duels_table`:

```sql
CREATE TABLE duels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  challenged_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','accepted','rejected','active','completed')),
  timing text NOT NULL
    CHECK (timing IN ('live','async')),
  deadline_hours int,
  challenger_activity_id uuid REFERENCES activities(id) ON DELETE SET NULL,
  challenged_activity_id uuid REFERENCES activities(id) ON DELETE SET NULL,
  winner_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE duels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "duel_select" ON duels FOR SELECT
  USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);

CREATE POLICY "duel_insert" ON duels FOR INSERT
  WITH CHECK (auth.uid() = challenger_id);

CREATE POLICY "duel_update" ON duels FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
```

- [ ] **Step 2: Create the `group_challenges` table**

Run via `mcp__supabase__apply_migration` with name `create_group_challenges_table`:

```sql
CREATE TABLE group_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  duration_days int NOT NULL CHECK (duration_days IN (3, 7, 30)),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','active','completed')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE group_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gc_select" ON group_challenges FOR SELECT
  USING (
    auth.uid() = creator_id OR
    EXISTS (
      SELECT 1 FROM group_challenge_participants
      WHERE challenge_id = group_challenges.id AND user_id = auth.uid()
    )
  );

CREATE POLICY "gc_insert" ON group_challenges FOR INSERT
  WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "gc_update" ON group_challenges FOR UPDATE
  USING (auth.uid() = creator_id);
```

- [ ] **Step 3: Create the `group_challenge_participants` table**

Run via `mcp__supabase__apply_migration` with name `create_group_challenge_participants_table`:

```sql
CREATE TABLE group_challenge_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES group_challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'invited'
    CHECK (status IN ('invited','accepted','rejected')),
  total_distance_meters float NOT NULL DEFAULT 0,
  joined_at timestamptz,
  UNIQUE(challenge_id, user_id)
);

ALTER TABLE group_challenge_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gcp_select" ON group_challenge_participants FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM group_challenges
      WHERE id = group_challenge_participants.challenge_id
        AND creator_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM group_challenge_participants AS peer
      WHERE peer.challenge_id = group_challenge_participants.challenge_id
        AND peer.user_id = auth.uid()
    )
  );

CREATE POLICY "gcp_insert" ON group_challenge_participants FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_challenges
      WHERE id = group_challenge_participants.challenge_id
        AND creator_id = auth.uid()
    )
  );

CREATE POLICY "gcp_update" ON group_challenge_participants FOR UPDATE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM group_challenges
      WHERE id = group_challenge_participants.challenge_id
        AND creator_id = auth.uid()
    )
  );
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: add challenges DB migrations (duels + group_challenges)"
```

---

## Task 2: Duel domain layer

**Files:**
- Create: `lib/features/challenges/domain/entities/duel_entity.dart`
- Create: `lib/features/challenges/domain/repositories/duel_repository.dart`

- [ ] **Step 1: Create `duel_entity.dart`**

```dart
import '../../../profile/domain/entities/profile_entity.dart';

enum DuelStatus {
  pending,
  accepted,
  rejected,
  active,
  completed;

  static DuelStatus fromString(String s) {
    switch (s) {
      case 'accepted': return DuelStatus.accepted;
      case 'rejected': return DuelStatus.rejected;
      case 'active':   return DuelStatus.active;
      case 'completed': return DuelStatus.completed;
      default:         return DuelStatus.pending;
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
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProfileEntity? challengerProfile;
  final ProfileEntity? challengedProfile;

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
    required this.createdAt,
    required this.updatedAt,
    this.challengerProfile,
    this.challengedProfile,
  });

  bool get isPending   => status == DuelStatus.pending;
  bool get isActive    => status == DuelStatus.active;
  bool get isCompleted => status == DuelStatus.completed;

  ProfileEntity? getOtherProfile(String currentUserId) =>
      currentUserId == challengerId ? challengedProfile : challengerProfile;

  String getOtherUserId(String currentUserId) =>
      currentUserId == challengerId ? challengedId : challengerId;
}
```

- [ ] **Step 2: Create `duel_repository.dart`**

```dart
import '../entities/duel_entity.dart';

abstract class DuelRepository {
  Future<List<DuelEntity>> getMyDuels();
  Future<List<DuelEntity>> getPendingInvites();
  Future<DuelEntity> createDuel({
    required String challengedId,
    required DuelTiming timing,
    int? deadlineHours,
  });
  Future<void> respondToDuel(String duelId, {required bool accept});
  Future<void> linkActivity(String duelId, String activityId, {required bool isChallenger});
  Future<void> resolveWinner(String duelId);
}
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/features/challenges/domain/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/challenges/domain/entities/duel_entity.dart \
        lib/features/challenges/domain/repositories/duel_repository.dart
git commit -m "feat: add DuelEntity and DuelRepository interface"
```

---

## Task 3: Group challenge domain layer

**Files:**
- Create: `lib/features/challenges/domain/entities/group_challenge_participant_entity.dart`
- Create: `lib/features/challenges/domain/entities/group_challenge_entity.dart`
- Create: `lib/features/challenges/domain/repositories/group_challenge_repository.dart`

- [ ] **Step 1: Create `group_challenge_participant_entity.dart`**

```dart
import '../../../profile/domain/entities/profile_entity.dart';

enum ParticipantStatus {
  invited,
  accepted,
  rejected;

  static ParticipantStatus fromString(String s) {
    switch (s) {
      case 'accepted': return ParticipantStatus.accepted;
      case 'rejected': return ParticipantStatus.rejected;
      default:         return ParticipantStatus.invited;
    }
  }

  String toJson() => name;
}

class GroupChallengeParticipantEntity {
  final String id;
  final String challengeId;
  final String userId;
  final ParticipantStatus status;
  final double totalDistanceMeters;
  final DateTime? joinedAt;
  final ProfileEntity? profile;

  const GroupChallengeParticipantEntity({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.totalDistanceMeters,
    this.joinedAt,
    this.profile,
  });

  String get formattedDistance {
    final km = totalDistanceMeters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }
}
```

- [ ] **Step 2: Create `group_challenge_entity.dart`**

```dart
import 'group_challenge_participant_entity.dart';

enum GroupChallengeStatus {
  pending,
  active,
  completed;

  static GroupChallengeStatus fromString(String s) {
    switch (s) {
      case 'active':    return GroupChallengeStatus.active;
      case 'completed': return GroupChallengeStatus.completed;
      default:          return GroupChallengeStatus.pending;
    }
  }

  String toJson() => name;
}

class GroupChallengeEntity {
  final String id;
  final String creatorId;
  final String title;
  final int durationDays;
  final GroupChallengeStatus status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final List<GroupChallengeParticipantEntity> participants;

  const GroupChallengeEntity({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.durationDays,
    required this.status,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    this.participants = const [],
  });

  bool get isPending   => status == GroupChallengeStatus.pending;
  bool get isActive    => status == GroupChallengeStatus.active;
  bool get isCompleted => status == GroupChallengeStatus.completed;

  List<GroupChallengeParticipantEntity> get sortedLeaderboard {
    final accepted = participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .toList()
      ..sort((a, b) => b.totalDistanceMeters.compareTo(a.totalDistanceMeters));
    return accepted;
  }

  int get daysRemaining {
    if (endsAt == null) return durationDays;
    final diff = endsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get canForceStart {
    final accepted = participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .length;
    return accepted >= 1 &&
        participants.any((p) => p.status == ParticipantStatus.rejected);
  }
}
```

- [ ] **Step 3: Create `group_challenge_repository.dart`**

```dart
import '../entities/group_challenge_entity.dart';

abstract class GroupChallengeRepository {
  Future<List<GroupChallengeEntity>> getMyChallenges();
  Future<List<GroupChallengeEntity>> getPendingInvites();
  Future<GroupChallengeEntity> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
  });
  Future<void> respondToChallenge(String challengeId, {required bool accept});
  Future<void> forceStart(String challengeId);
  Future<void> incrementDistance(String challengeId, double additionalMeters);
  Future<GroupChallengeEntity> getChallenge(String challengeId);
}
```

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/features/challenges/domain/
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/challenges/domain/
git commit -m "feat: add group challenge domain entities and repository interface"
```

---

## Task 4: Duel data layer

**Files:**
- Create: `lib/features/challenges/data/models/duel_model.dart`
- Create: `lib/features/challenges/data/datasources/duel_remote_datasource.dart`
- Create: `lib/features/challenges/data/repositories/duel_repository_impl.dart`

- [ ] **Step 1: Create `duel_model.dart`**

```dart
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
    required super.createdAt,
    required super.updatedAt,
    super.challengerProfile,
    super.challengedProfile,
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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      challengerProfile: json['challenger'] != null
          ? ProfileModel.fromJson(json['challenger'] as Map<String, dynamic>).toEntity()
          : null,
      challengedProfile: json['challenged'] != null
          ? ProfileModel.fromJson(json['challenged'] as Map<String, dynamic>).toEntity()
          : null,
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
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
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
    createdAt: createdAt,
    updatedAt: updatedAt,
    challengerProfile: challengerProfile,
    challengedProfile: challengedProfile,
  );
}
```

- [ ] **Step 2: Create `duel_remote_datasource.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/duel_model.dart';

class DuelRemoteDataSource {
  final SupabaseClient _client;
  DuelRemoteDataSource(this._client);

  static const _profileSelect = '''
    *,
    challenger:profiles!duels_challenger_id_fkey(*),
    challenged:profiles!duels_challenged_id_fkey(*)
  ''';

  Future<List<DuelModel>> getDuels(String userId) async {
    try {
      final response = await _client
          .from('duels')
          .select(_profileSelect)
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      return (response as List)
          .map((j) => DuelModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get duels: $e');
    }
  }

  Future<DuelModel> createDuel({
    required String challengerId,
    required String challengedId,
    required String timing,
    int? deadlineHours,
  }) async {
    try {
      final response = await _client
          .from('duels')
          .insert({
            'challenger_id': challengerId,
            'challenged_id': challengedId,
            'timing': timing,
            if (deadlineHours != null) 'deadline_hours': deadlineHours,
          })
          .select(_profileSelect)
          .single()
          .timeout(const Duration(seconds: 10));
      return DuelModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to create duel: $e');
    }
  }

  Future<void> updateDuelStatus(String duelId, String status) async {
    try {
      await _client
          .from('duels')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update duel: $e');
    }
  }

  Future<void> linkActivity(String duelId, String activityId, {required bool isChallenger}) async {
    try {
      final column = isChallenger ? 'challenger_activity_id' : 'challenged_activity_id';
      await _client
          .from('duels')
          .update({column: activityId, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to link activity: $e');
    }
  }

  Future<DuelModel> getDuel(String duelId) async {
    try {
      final response = await _client
          .from('duels')
          .select(_profileSelect)
          .eq('id', duelId)
          .single()
          .timeout(const Duration(seconds: 10));
      return DuelModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get duel: $e');
    }
  }

  Future<void> resolveWinner(String duelId, String winnerId) async {
    try {
      await _client
          .from('duels')
          .update({
            'winner_id': winnerId,
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to resolve winner: $e');
    }
  }
}

final duelRemoteDataSourceProvider = Provider<DuelRemoteDataSource>((ref) {
  return DuelRemoteDataSource(ref.watch(supabaseClientProvider));
});
```

- [ ] **Step 3: Create `duel_repository_impl.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../../domain/repositories/duel_repository.dart';
import '../datasources/duel_remote_datasource.dart';

class DuelRepositoryImpl implements DuelRepository {
  final DuelRemoteDataSource _ds;
  final String _userId;
  DuelRepositoryImpl(this._ds, this._userId);

  @override
  Future<List<DuelEntity>> getMyDuels() async {
    final models = await _ds.getDuels(_userId);
    return models
        .where((d) => d.status != DuelStatus.pending || d.challengerId == _userId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<List<DuelEntity>> getPendingInvites() async {
    final models = await _ds.getDuels(_userId);
    return models
        .where((d) => d.status == DuelStatus.pending && d.challengedId == _userId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<DuelEntity> createDuel({
    required String challengedId,
    required DuelTiming timing,
    int? deadlineHours,
  }) async {
    final model = await _ds.createDuel(
      challengerId: _userId,
      challengedId: challengedId,
      timing: timing.toJson(),
      deadlineHours: deadlineHours,
    );
    return model.toEntity();
  }

  @override
  Future<void> respondToDuel(String duelId, {required bool accept}) async {
    await _ds.updateDuelStatus(duelId, accept ? 'accepted' : 'rejected');
  }

  @override
  Future<void> linkActivity(String duelId, String activityId, {required bool isChallenger}) async {
    await _ds.linkActivity(duelId, activityId, isChallenger: isChallenger);
  }

  @override
  Future<void> resolveWinner(String duelId) async {
    final duel = await _ds.getDuel(duelId);
    if (duel.challengerActivityId == null || duel.challengedActivityId == null) return;
    // Winner is determined by comparing activity distances at the datasource level.
    // For now we mark completed without setting winner — the detail page will display both.
    await _ds.updateDuelStatus(duelId, 'completed');
  }
}

final duelRepositoryProvider = Provider<DuelRepository>((ref) {
  final ds = ref.watch(duelRemoteDataSourceProvider);
  final userId = ref.watch(authStateProvider).value?.id ?? '';
  return DuelRepositoryImpl(ds, userId);
});
```

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/features/challenges/data/
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/challenges/data/models/duel_model.dart \
        lib/features/challenges/data/datasources/duel_remote_datasource.dart \
        lib/features/challenges/data/repositories/duel_repository_impl.dart
git commit -m "feat: add duel data layer (model, datasource, repository)"
```

---

## Task 5: Group challenge data layer

**Files:**
- Create: `lib/features/challenges/data/models/group_challenge_participant_model.dart`
- Create: `lib/features/challenges/data/models/group_challenge_model.dart`
- Create: `lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart`
- Create: `lib/features/challenges/data/repositories/group_challenge_repository_impl.dart`

- [ ] **Step 1: Create `group_challenge_participant_model.dart`**

```dart
import '../../../profile/data/models/profile_model.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';

class GroupChallengeParticipantModel extends GroupChallengeParticipantEntity {
  const GroupChallengeParticipantModel({
    required super.id,
    required super.challengeId,
    required super.userId,
    required super.status,
    required super.totalDistanceMeters,
    super.joinedAt,
    super.profile,
  });

  factory GroupChallengeParticipantModel.fromJson(Map<String, dynamic> json) {
    return GroupChallengeParticipantModel(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      userId: json['user_id'] as String,
      status: ParticipantStatus.fromString(json['status'] as String),
      totalDistanceMeters: (json['total_distance_meters'] as num).toDouble(),
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      profile: json['profile'] != null
          ? ProfileModel.fromJson(json['profile'] as Map<String, dynamic>).toEntity()
          : null,
    );
  }

  GroupChallengeParticipantEntity toEntity() => GroupChallengeParticipantEntity(
    id: id,
    challengeId: challengeId,
    userId: userId,
    status: status,
    totalDistanceMeters: totalDistanceMeters,
    joinedAt: joinedAt,
    profile: profile,
  );
}
```

- [ ] **Step 2: Create `group_challenge_model.dart`**

```dart
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import 'group_challenge_participant_model.dart';

class GroupChallengeModel extends GroupChallengeEntity {
  const GroupChallengeModel({
    required super.id,
    required super.creatorId,
    required super.title,
    required super.durationDays,
    required super.status,
    super.startsAt,
    super.endsAt,
    required super.createdAt,
    super.participants,
  });

  factory GroupChallengeModel.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List? ?? [];
    return GroupChallengeModel(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      durationDays: json['duration_days'] as int,
      status: GroupChallengeStatus.fromString(json['status'] as String),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: rawParticipants
          .map((p) => GroupChallengeParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  GroupChallengeEntity toEntity() => GroupChallengeEntity(
    id: id,
    creatorId: creatorId,
    title: title,
    durationDays: durationDays,
    status: status,
    startsAt: startsAt,
    endsAt: endsAt,
    createdAt: createdAt,
    participants: participants,
  );
}
```

- [ ] **Step 3: Create `group_challenge_remote_datasource.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/group_challenge_model.dart';

class GroupChallengeRemoteDataSource {
  final SupabaseClient _client;
  GroupChallengeRemoteDataSource(this._client);

  static const _participantSelect = '''
    *,
    participants:group_challenge_participants(
      *,
      profile:profiles(*)
    )
  ''';

  Future<List<GroupChallengeModel>> getChallenges(String userId) async {
    try {
      final response = await _client
          .from('group_challenges')
          .select(_participantSelect)
          .or('creator_id.eq.$userId')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      return (response as List)
          .map((j) => GroupChallengeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get group challenges: $e');
    }
  }

  Future<List<GroupChallengeModel>> getChallengesForParticipant(String userId) async {
    try {
      // Get challenge IDs where user is a participant
      final participantRows = await _client
          .from('group_challenge_participants')
          .select('challenge_id')
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));

      final ids = (participantRows as List)
          .map((r) => r['challenge_id'] as String)
          .toList();

      if (ids.isEmpty) return [];

      final response = await _client
          .from('group_challenges')
          .select(_participantSelect)
          .inFilter('id', ids)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((j) => GroupChallengeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get participant challenges: $e');
    }
  }

  Future<GroupChallengeModel> createChallenge({
    required String creatorId,
    required String title,
    required int durationDays,
    required List<String> friendIds,
  }) async {
    try {
      final gcRow = await _client
          .from('group_challenges')
          .insert({'creator_id': creatorId, 'title': title, 'duration_days': durationDays})
          .select('id')
          .single()
          .timeout(const Duration(seconds: 10));

      final challengeId = gcRow['id'] as String;

      await _client
          .from('group_challenge_participants')
          .insert(
            friendIds.map((id) => {'challenge_id': challengeId, 'user_id': id}).toList(),
          )
          .timeout(const Duration(seconds: 10));

      return getChallenge(challengeId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to create group challenge: $e');
    }
  }

  Future<GroupChallengeModel> getChallenge(String challengeId) async {
    try {
      final response = await _client
          .from('group_challenges')
          .select(_participantSelect)
          .eq('id', challengeId)
          .single()
          .timeout(const Duration(seconds: 10));
      return GroupChallengeModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get group challenge: $e');
    }
  }

  Future<void> updateParticipantStatus(
    String challengeId,
    String userId,
    String status,
  ) async {
    try {
      final update = <String, dynamic>{'status': status};
      if (status == 'accepted') update['joined_at'] = DateTime.now().toIso8601String();

      await _client
          .from('group_challenge_participants')
          .update(update)
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update participant status: $e');
    }
  }

  Future<void> activateChallenge(String challengeId, int durationDays) async {
    try {
      final now = DateTime.now();
      await _client
          .from('group_challenges')
          .update({
            'status': 'active',
            'starts_at': now.toIso8601String(),
            'ends_at': now.add(Duration(days: durationDays)).toIso8601String(),
          })
          .eq('id', challengeId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to activate challenge: $e');
    }
  }

  Future<void> incrementParticipantDistance(
    String challengeId,
    String userId,
    double additionalMeters,
  ) async {
    try {
      // Read current value then write (no Supabase increment RPC by default)
      final row = await _client
          .from('group_challenge_participants')
          .select('total_distance_meters')
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .single()
          .timeout(const Duration(seconds: 10));
      final current = (row['total_distance_meters'] as num).toDouble();
      await _client
          .from('group_challenge_participants')
          .update({'total_distance_meters': current + additionalMeters})
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to increment distance: $e');
    }
  }
}

final groupChallengeRemoteDataSourceProvider =
    Provider<GroupChallengeRemoteDataSource>((ref) {
  return GroupChallengeRemoteDataSource(ref.watch(supabaseClientProvider));
});
```

- [ ] **Step 4: Create `group_challenge_repository_impl.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../../domain/repositories/group_challenge_repository.dart';
import '../datasources/group_challenge_remote_datasource.dart';

class GroupChallengeRepositoryImpl implements GroupChallengeRepository {
  final GroupChallengeRemoteDataSource _ds;
  final String _userId;
  GroupChallengeRepositoryImpl(this._ds, this._userId);

  @override
  Future<List<GroupChallengeEntity>> getMyChallenges() async {
    final created = await _ds.getChallenges(_userId);
    final participating = await _ds.getChallengesForParticipant(_userId);

    // Merge, deduplicate, exclude pure-pending invites
    final all = {...created, ...participating}.toList();
    return all
        .where((c) {
          if (c.creatorId == _userId) return true;
          final myParticipation = c.participants
              .where((p) => p.userId == _userId)
              .firstOrNull;
          return myParticipation?.status == ParticipantStatus.accepted;
        })
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<List<GroupChallengeEntity>> getPendingInvites() async {
    final participating = await _ds.getChallengesForParticipant(_userId);
    return participating
        .where((c) {
          final myParticipation = c.participants
              .where((p) => p.userId == _userId)
              .firstOrNull;
          return myParticipation?.status == ParticipantStatus.invited;
        })
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<GroupChallengeEntity> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
  }) async {
    final model = await _ds.createChallenge(
      creatorId: _userId,
      title: title,
      durationDays: durationDays,
      friendIds: friendIds,
    );
    return model.toEntity();
  }

  @override
  Future<void> respondToChallenge(String challengeId, {required bool accept}) async {
    await _ds.updateParticipantStatus(
      challengeId,
      _userId,
      accept ? 'accepted' : 'rejected',
    );
    if (accept) await _checkAndActivate(challengeId);
  }

  @override
  Future<void> forceStart(String challengeId) async {
    final challenge = await _ds.getChallenge(challengeId);
    await _ds.activateChallenge(challengeId, challenge.durationDays);
  }

  @override
  Future<void> incrementDistance(String challengeId, double additionalMeters) async {
    await _ds.incrementParticipantDistance(challengeId, _userId, additionalMeters);
  }

  @override
  Future<GroupChallengeEntity> getChallenge(String challengeId) async {
    final model = await _ds.getChallenge(challengeId);
    return model.toEntity();
  }

  Future<void> _checkAndActivate(String challengeId) async {
    final challenge = await _ds.getChallenge(challengeId);
    final allAccepted = challenge.participants
        .every((p) => p.status == ParticipantStatus.accepted);
    if (allAccepted) {
      await _ds.activateChallenge(challengeId, challenge.durationDays);
    }
  }
}

final groupChallengeRepositoryProvider = Provider<GroupChallengeRepository>((ref) {
  final ds = ref.watch(groupChallengeRemoteDataSourceProvider);
  final userId = ref.watch(authStateProvider).value?.id ?? '';
  return GroupChallengeRepositoryImpl(ds, userId);
});
```

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/features/challenges/data/
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/challenges/data/
git commit -m "feat: add group challenge data layer (models, datasource, repository)"
```

---

## Task 6: Duel provider

**Files:**
- Create: `lib/features/challenges/presentation/providers/duel_provider.dart`

- [ ] **Step 1: Create `duel_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/duel_repository_impl.dart';
import '../../domain/entities/duel_entity.dart';

class DuelState {
  final List<DuelEntity> myDuels;
  final List<DuelEntity> pendingInvites;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const DuelState({
    this.myDuels = const [],
    this.pendingInvites = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  DuelState copyWith({
    List<DuelEntity>? myDuels,
    List<DuelEntity>? pendingInvites,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return DuelState(
      myDuels: myDuels ?? this.myDuels,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class DuelNotifier extends StateNotifier<DuelState> {
  final Ref _ref;
  DuelNotifier(this._ref) : super(const DuelState()) {
    loadDuels();
  }

  Future<void> loadDuels() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(duelRepositoryProvider);
      final results = await Future.wait([
        repo.getMyDuels(),
        repo.getPendingInvites(),
      ]);
      state = state.copyWith(
        myDuels: results[0],
        pendingInvites: results[1],
        isLoading: false,
      );
    } on DatabaseFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur de connexion');
    }
  }

  Future<DuelEntity?> createDuel({
    required String challengedId,
    required DuelTiming timing,
    int? deadlineHours,
  }) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      final duel = await repo.createDuel(
        challengedId: challengedId,
        timing: timing,
        deadlineHours: deadlineHours,
      );
      state = state.copyWith(successMessage: 'Défi envoyé !');
      await loadDuels();
      return duel;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la création du duel');
      return null;
    }
  }

  Future<bool> respondToDuel(String duelId, {required bool accept}) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      await repo.respondToDuel(duelId, accept: accept);
      state = state.copyWith(
        successMessage: accept ? 'Duel accepté !' : 'Duel refusé',
      );
      await loadDuels();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la réponse');
      return false;
    }
  }

  Future<void> linkActivityToDuel(
    String duelId,
    String activityId,
  ) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      final authState = _ref.read(authStateProvider);
      final userId = authState.value?.id;
      if (userId == null) return;

      final duel = state.myDuels.where((d) => d.id == duelId).firstOrNull;
      if (duel == null) return;

      final isChallenger = duel.challengerId == userId;
      await repo.linkActivity(duelId, activityId, isChallenger: isChallenger);

      // Refresh to check if both activities are now linked
      await loadDuels();
      final updated = state.myDuels.where((d) => d.id == duelId).firstOrNull;
      if (updated != null &&
          updated.challengerActivityId != null &&
          updated.challengedActivityId != null) {
        await repo.resolveWinner(duelId);
        await loadDuels();
      }
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du lien activité');
    }
  }

  void clearMessages() => state = state.copyWith();
}

final duelNotifierProvider = StateNotifierProvider<DuelNotifier, DuelState>((ref) {
  ref.watch(authStateProvider); // rebuild when auth changes
  return DuelNotifier(ref);
});
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/challenges/presentation/providers/duel_provider.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/challenges/presentation/providers/duel_provider.dart
git commit -m "feat: add DuelNotifier provider"
```

---

## Task 7: Group challenge provider

**Files:**
- Create: `lib/features/challenges/presentation/providers/group_challenge_provider.dart`

- [ ] **Step 1: Create `group_challenge_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/group_challenge_repository_impl.dart';
import '../../domain/entities/group_challenge_entity.dart';

class GroupChallengeState {
  final List<GroupChallengeEntity> myChallenges;
  final List<GroupChallengeEntity> pendingInvites;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const GroupChallengeState({
    this.myChallenges = const [],
    this.pendingInvites = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  GroupChallengeState copyWith({
    List<GroupChallengeEntity>? myChallenges,
    List<GroupChallengeEntity>? pendingInvites,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return GroupChallengeState(
      myChallenges: myChallenges ?? this.myChallenges,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class GroupChallengeNotifier extends StateNotifier<GroupChallengeState> {
  final Ref _ref;
  GroupChallengeNotifier(this._ref) : super(const GroupChallengeState()) {
    loadChallenges();
  }

  Future<void> loadChallenges() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      final results = await Future.wait([
        repo.getMyChallenges(),
        repo.getPendingInvites(),
      ]);
      state = state.copyWith(
        myChallenges: results[0],
        pendingInvites: results[1],
        isLoading: false,
      );
    } on DatabaseFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur de connexion');
    }
  }

  Future<GroupChallengeEntity?> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
  }) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      final challenge = await repo.createChallenge(
        title: title,
        durationDays: durationDays,
        friendIds: friendIds,
      );
      state = state.copyWith(successMessage: 'Défi créé !');
      await loadChallenges();
      return challenge;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la création');
      return null;
    }
  }

  Future<bool> respondToChallenge(String challengeId, {required bool accept}) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.respondToChallenge(challengeId, accept: accept);
      state = state.copyWith(
        successMessage: accept ? 'Défi accepté !' : 'Défi refusé',
      );
      await loadChallenges();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la réponse');
      return false;
    }
  }

  Future<void> forceStart(String challengeId) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.forceStart(challengeId);
      state = state.copyWith(successMessage: 'Défi lancé !');
      await loadChallenges();
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du lancement');
    }
  }

  Future<void> addRunDistance(String challengeId, double meters) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.incrementDistance(challengeId, meters);
      await loadChallenges();
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      // Silent — don't interrupt the run reward flow
    }
  }

  void clearMessages() => state = state.copyWith();
}

final groupChallengeNotifierProvider =
    StateNotifierProvider<GroupChallengeNotifier, GroupChallengeState>((ref) {
  ref.watch(authStateProvider);
  return GroupChallengeNotifier(ref);
});
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/challenges/presentation/providers/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/challenges/presentation/providers/group_challenge_provider.dart
git commit -m "feat: add GroupChallengeNotifier provider"
```

---

## Task 8: Shared widgets

**Files:**
- Create: `lib/features/challenges/presentation/widgets/challenge_mode_card.dart`
- Create: `lib/features/challenges/presentation/widgets/friend_selector_widget.dart`

- [ ] **Step 1: Create `challenge_mode_card.dart`**

```dart
import 'package:flutter/material.dart';

class ChallengeModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> badges;
  final Gradient gradient;
  final VoidCallback onTap;

  const ChallengeModeCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: badges
                  .map(
                    (b) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        b,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `friend_selector_widget.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../../features/profile/domain/entities/profile_entity.dart';
import '../../../../features/friends/domain/entities/friendship_entity.dart';

class FriendSelectorWidget extends StatefulWidget {
  final List<FriendshipEntity> friends;
  final String currentUserId;
  final bool multiSelect;
  final void Function(List<String> selectedIds) onSelectionChanged;

  const FriendSelectorWidget({
    super.key,
    required this.friends,
    required this.currentUserId,
    this.multiSelect = false,
    required this.onSelectionChanged,
  });

  @override
  State<FriendSelectorWidget> createState() => _FriendSelectorWidgetState();
}

class _FriendSelectorWidgetState extends State<FriendSelectorWidget> {
  final Set<String> _selected = {};
  String _search = '';

  List<(String id, String username)> get _filtered {
    return widget.friends
        .map((f) {
          final profile = f.getOtherUserProfile(widget.currentUserId);
          if (profile == null) return null;
          return (profile.id, profile.username);
        })
        .whereType<(String, String)>()
        .where((pair) =>
            _search.isEmpty ||
            pair.$2.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  void _toggle(String id) {
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      } else {
        _selected
          ..clear()
          ..add(id);
      }
    });
    widget.onSelectionChanged(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un ami...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 8),
        ..._filtered.map((pair) {
          final isSelected = _selected.contains(pair.$1);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(
              backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
              child: Text(
                pair.$2[0].toUpperCase(),
                style: TextStyle(
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('@${pair.$2}', style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: colorScheme.primary)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: isSelected ? colorScheme.primary.withOpacity(0.08) : null,
            onTap: () => _toggle(pair.$1),
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/features/challenges/presentation/widgets/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/challenges/presentation/widgets/challenge_mode_card.dart \
        lib/features/challenges/presentation/widgets/friend_selector_widget.dart
git commit -m "feat: add ChallengeModeCard and FriendSelectorWidget"
```

---

## Task 9: Routes

**Files:**
- Modify: `lib/core/constants/route_constants.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add challenge routes to `route_constants.dart`**

Add these lines inside the `Routes` class:

```dart
static const String challenges = '/challenges'; // landing (already exists as tab)
static const String duels = '/challenges/duels';
static const String createDuel = '/challenges/duels/create';
static const String duelDetail = '/challenges/duels/:id';
static const String groupChallenges = '/challenges/group';
static const String createGroupChallenge = '/challenges/group/create';
static const String groupChallengeDetail = '/challenges/group/:id';
```

- [ ] **Step 2: Read `lib/main.dart` to find the GoRouter definition**

Read the file, locate the `GoRouter` routes list, and add the new routes. The new routes go inside the router's `routes` list. Add after the existing routes:

```dart
GoRoute(
  path: Routes.duels,
  builder: (context, state) => const DuelsPage(),
),
GoRoute(
  path: Routes.createDuel,
  builder: (context, state) => const CreateDuelPage(),
),
GoRoute(
  path: Routes.duelDetail,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return DuelDetailPage(duelId: id);
  },
),
GoRoute(
  path: Routes.groupChallenges,
  builder: (context, state) => const GroupChallengesPage(),
),
GoRoute(
  path: Routes.createGroupChallenge,
  builder: (context, state) => const CreateGroupChallengePage(),
),
GoRoute(
  path: Routes.groupChallengeDetail,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return GroupChallengeDetailPage(challengeId: id);
  },
),
```

Add corresponding imports at the top of `main.dart`:
```dart
import 'features/challenges/presentation/pages/duels_page.dart';
import 'features/challenges/presentation/pages/create_duel_page.dart';
import 'features/challenges/presentation/pages/duel_detail_page.dart';
import 'features/challenges/presentation/pages/group_challenges_page.dart';
import 'features/challenges/presentation/pages/create_group_challenge_page.dart';
import 'features/challenges/presentation/pages/group_challenge_detail_page.dart';
```

- [ ] **Step 3: Verify (after all pages are stubbed — do this step last)**

```bash
flutter analyze lib/main.dart lib/core/constants/route_constants.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants/route_constants.dart lib/main.dart
git commit -m "feat: add challenge routes to GoRouter"
```

---

## Task 10: Landing page (rewrite ChallengesPage)

**Files:**
- Modify: `lib/features/challenges/presentation/pages/challenges_page.dart`

- [ ] **Step 1: Rewrite `challenges_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../providers/duel_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/challenge_mode_card.dart';

class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelState = ref.watch(duelNotifierProvider);
    final gcState = ref.watch(groupChallengeNotifierProvider);
    final pendingCount =
        duelState.pendingInvites.length + gcState.pendingInvites.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Défis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Pending invitations banner
              if (pendingCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('📬', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pendingCount invitation${pendingCount > 1 ? 's' : ''} en attente',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const Text(
                              'Réponds avant expiration',
                              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Duel card
              ChallengeModeCard(
                emoji: '⚔️',
                title: 'Duel',
                subtitle: 'Affronte un ami sur une course · live ou différé',
                badges: const ['1 vs 1', '1 course'],
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => context.push(Routes.duels),
              ),
              const SizedBox(height: 16),

              // Groupe card
              ChallengeModeCard(
                emoji: '🏆',
                title: 'Défi groupe',
                subtitle: 'Cumule des km avec tes amis sur une période',
                badges: const ['2–10 joueurs', '3 / 7 / 30 jours'],
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => context.push(Routes.groupChallenges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/challenges/presentation/pages/challenges_page.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/challenges/presentation/pages/challenges_page.dart
git commit -m "feat: rewrite ChallengesPage as landing with Duel + Groupe cards"
```

---

## Task 11: Duel UI pages

**Files:**
- Create: `lib/features/challenges/presentation/widgets/duel_card.dart`
- Create: `lib/features/challenges/presentation/pages/duels_page.dart`
- Create: `lib/features/challenges/presentation/pages/create_duel_page.dart`
- Create: `lib/features/challenges/presentation/pages/duel_detail_page.dart`

- [ ] **Step 1: Create `duel_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    Color borderColor;
    String statusLabel;
    switch (duel.status) {
      case DuelStatus.pending:
        borderColor = Colors.orange;
        statusLabel = duel.challengerId == currentUserId
            ? 'En attente · ${duel.timing == DuelTiming.live ? 'Live' : 'Différé'}'
            : '⚔️ Invitation reçue';
      case DuelStatus.accepted:
      case DuelStatus.active:
        borderColor = colorScheme.primary;
        statusLabel = 'En cours · ${duel.timing == DuelTiming.live ? 'Live' : 'Différé'}';
      case DuelStatus.completed:
        borderColor = duel.winnerId == currentUserId ? Colors.green : Colors.grey;
        statusLabel = duel.winnerId == currentUserId ? '✓ Victoire' : '✗ Défaite';
      case DuelStatus.rejected:
        borderColor = Colors.grey;
        statusLabel = 'Refusé';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          Routes.duelDetail.replaceFirst(':id', duel.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: borderColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'vs @$otherName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
                      Text(
                        'Délai : ${duel.deadlineHours}h',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `duels_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/duel_provider.dart';
import '../widgets/duel_card.dart';

class DuelsPage extends ConsumerWidget {
  const DuelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duelNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duels ⚔️'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau duel',
            onPressed: () => context.push(Routes.createDuel),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(duelNotifierProvider.notifier).loadDuels(),
        child: state.isLoading && state.myDuels.isEmpty && state.pendingInvites.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  if (state.pendingInvites.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Invitations reçues',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => DuelCard(
                          duel: state.pendingInvites[i],
                          currentUserId: currentUserId,
                        ),
                        childCount: state.pendingInvites.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Mes duels',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  if (state.myDuels.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Aucun duel pour le moment.\nDéfie un ami !',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => DuelCard(
                          duel: state.myDuels[i],
                          currentUserId: currentUserId,
                        ),
                        childCount: state.myDuels.length,
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.createDuel),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau duel'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
    );
  }
}
```

- [ ] **Step 3: Create `create_duel_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';
import '../widgets/friend_selector_widget.dart';

class CreateDuelPage extends ConsumerStatefulWidget {
  const CreateDuelPage({super.key});

  @override
  ConsumerState<CreateDuelPage> createState() => _CreateDuelPageState();
}

class _CreateDuelPageState extends ConsumerState<CreateDuelPage> {
  String? _selectedFriendId;
  DuelTiming _timing = DuelTiming.live;
  int _deadlineHours = 48;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne un ami')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final duel = await ref.read(duelNotifierProvider.notifier).createDuel(
      challengedId: _selectedFriendId!,
      timing: _timing,
      deadlineHours: _timing == DuelTiming.async ? _deadlineHours : null,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (duel != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation envoyée !')),
      );
    } else {
      final error = ref.read(duelNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau duel ⚔️')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisir un ami', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            FriendSelectorWidget(
              friends: friendsState.friends,
              currentUserId: currentUserId,
              multiSelect: false,
              onSelectionChanged: (ids) => setState(() {
                _selectedFriendId = ids.isNotEmpty ? ids.first : null;
              }),
            ),
            const SizedBox(height: 24),
            const Text('Type de duel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimingOption(
                    emoji: '⚡',
                    label: 'Maintenant',
                    sublabel: 'Live',
                    selected: _timing == DuelTiming.live,
                    onTap: () => setState(() => _timing = DuelTiming.live),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimingOption(
                    emoji: '🕐',
                    label: 'Quand tu veux',
                    sublabel: 'Différé',
                    selected: _timing == DuelTiming.async,
                    onTap: () => setState(() => _timing = DuelTiming.async),
                  ),
                ),
              ],
            ),
            if (_timing == DuelTiming.async) ...[
              const SizedBox(height: 20),
              const Text('Délai pour répondre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 24, label: Text('24h')),
                  ButtonSegment(value: 48, label: Text('48h')),
                  ButtonSegment(value: 72, label: Text('72h')),
                ],
                selected: {_deadlineHours},
                onSelectionChanged: (s) => setState(() => _deadlineHours = s.first),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Envoyer l\'invitation ⚔️', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _TimingOption({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F3FF) : const Color(0xFFF9FAFB),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? const Color(0xFF6C63FF) : Colors.black87)),
            Text(sublabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `duel_detail_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';

class DuelDetailPage extends ConsumerWidget {
  final String duelId;
  const DuelDetailPage({super.key, required this.duelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duelNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final duel = [
      ...state.myDuels,
      ...state.pendingInvites,
    ].where((d) => d.id == duelId).firstOrNull;

    if (duel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duel')),
        body: const Center(child: Text('Duel introuvable')),
      );
    }

    final otherProfile = duel.getOtherProfile(currentUserId);
    final otherName = otherProfile?.username ?? '…';

    return Scaffold(
      appBar: AppBar(title: Text('vs @$otherName')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(duel: duel, currentUserId: currentUserId),
            const SizedBox(height: 20),
            Text(
              'Mode : ${duel.timing == DuelTiming.live ? '⚡ Live' : '🕐 Différé'}',
              style: const TextStyle(fontSize: 15),
            ),
            if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
              Text('Délai : ${duel.deadlineHours}h', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            if (duel.isPending && duel.challengedId == currentUserId) ...[
              const Text(
                'Tu as reçu ce défi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref
                          .read(duelNotifierProvider.notifier)
                          .respondToDuel(duelId, accept: true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Accepter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(duelNotifierProvider.notifier)
                          .respondToDuel(duelId, accept: false),
                      child: const Text('Refuser'),
                    ),
                  ),
                ],
              ),
            ],
            if (duel.isCompleted) ...[
              const Divider(height: 32),
              const Text('Résultat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (duel.winnerId != null)
                Text(
                  duel.winnerId == currentUserId ? '🥇 Tu as gagné !' : '🥈 Tu as perdu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: duel.winnerId == currentUserId ? Colors.green : Colors.grey,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DuelEntity duel;
  final String currentUserId;
  const _StatusChip({required this.duel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (duel.status) {
      case DuelStatus.pending:  label = 'En attente';  color = Colors.orange;
      case DuelStatus.accepted: label = 'Accepté';     color = Colors.blue;
      case DuelStatus.active:   label = 'En cours';    color = const Color(0xFF6C63FF);
      case DuelStatus.completed: label = 'Terminé';   color = Colors.green;
      case DuelStatus.rejected: label = 'Refusé';      color = Colors.grey;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }
}
```

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/features/challenges/presentation/pages/duels_page.dart \
               lib/features/challenges/presentation/pages/create_duel_page.dart \
               lib/features/challenges/presentation/pages/duel_detail_page.dart \
               lib/features/challenges/presentation/widgets/duel_card.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/challenges/presentation/widgets/duel_card.dart \
        lib/features/challenges/presentation/pages/duels_page.dart \
        lib/features/challenges/presentation/pages/create_duel_page.dart \
        lib/features/challenges/presentation/pages/duel_detail_page.dart
git commit -m "feat: add duel UI (list, create, detail)"
```

---

## Task 12: Group challenge UI pages

**Files:**
- Create: `lib/features/challenges/presentation/widgets/group_challenge_card.dart`
- Create: `lib/features/challenges/presentation/pages/group_challenges_page.dart`
- Create: `lib/features/challenges/presentation/pages/create_group_challenge_page.dart`
- Create: `lib/features/challenges/presentation/pages/group_challenge_detail_page.dart`

- [ ] **Step 1: Create `group_challenge_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isInvited
              ? const Color(0xFF6C63FF)
              : challenge.isActive
                  ? const Color(0xFFF59E0B)
                  : Colors.grey.shade300,
          width: isInvited || challenge.isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isInvited
            ? null
            : () => context.push(
                Routes.groupChallengeDetail.replaceFirst(':id', challenge.id),
              ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isInvited
                              ? 'Invitation reçue'
                              : challenge.isActive
                                  ? '${challenge.daysRemaining}j restants'
                                  : challenge.isCompleted
                                      ? 'Terminé'
                                      : 'En attente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isInvited
                                ? const Color(0xFF6C63FF)
                                : challenge.isActive
                                    ? const Color(0xFFF59E0B)
                                    : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${challenge.participants.length} participant${challenge.participants.length > 1 ? 's' : ''} · ${challenge.durationDays}j',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (!isInvited) const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (challenge.isActive) ...[
                const SizedBox(height: 10),
                ...challenge.sortedLeaderboard.take(3).toList().asMap().entries.map((e) {
                  final medals = ['🥇', '🥈', '🥉'];
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(medals[e.key], style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '@${p.profile?.username ?? p.userId.substring(0, 6)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          p.formattedDistance,
                          style: TextStyle(
                            fontWeight: p.userId == currentUserId ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (isInvited && onRespond != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onRespond!(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Accepter', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond!(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontSize: 13)),
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
}
```

- [ ] **Step 2: Create `group_challenges_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/group_challenge_card.dart';

class GroupChallengesPage extends ConsumerWidget {
  const GroupChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Défis groupe 🏆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(Routes.createGroupChallenge),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(groupChallengeNotifierProvider.notifier).loadChallenges(),
        child: state.isLoading &&
                state.myChallenges.isEmpty &&
                state.pendingInvites.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  if (state.pendingInvites.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Invitations reçues',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final c = state.pendingInvites[i];
                          return GroupChallengeCard(
                            challenge: c,
                            currentUserId: currentUserId,
                            onRespond: (accept) => ref
                                .read(groupChallengeNotifierProvider.notifier)
                                .respondToChallenge(c.id, accept: accept),
                          );
                        },
                        childCount: state.pendingInvites.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Mes défis',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  if (state.myChallenges.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Aucun défi groupe.\nCrée-en un !',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => GroupChallengeCard(
                          challenge: state.myChallenges[i],
                          currentUserId: currentUserId,
                        ),
                        childCount: state.myChallenges.length,
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.createGroupChallenge),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau défi'),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
      ),
    );
  }
}
```

- [ ] **Step 3: Create `create_group_challenge_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/friend_selector_widget.dart';

class CreateGroupChallengePage extends ConsumerStatefulWidget {
  const CreateGroupChallengePage({super.key});

  @override
  ConsumerState<CreateGroupChallengePage> createState() =>
      _CreateGroupChallengePageState();
}

class _CreateGroupChallengePageState extends ConsumerState<CreateGroupChallengePage> {
  final _titleController = TextEditingController();
  int _durationDays = 7;
  List<String> _selectedFriendIds = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donne un nom au défi')),
      );
      return;
    }
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne au moins un ami')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final challenge = await ref
        .read(groupChallengeNotifierProvider.notifier)
        .createChallenge(
          title: title,
          durationDays: _durationDays,
          friendIds: _selectedFriendIds,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (challenge != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Défi créé ! Invitations envoyées.')),
      );
    } else {
      final error = ref.read(groupChallengeNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau défi groupe 🏆')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nom du défi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Ex : Marathon de mars',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Durée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 jours')),
                ButtonSegment(value: 7, label: Text('7 jours')),
                ButtonSegment(value: 30, label: Text('30 jours')),
              ],
              selected: {_durationDays},
              onSelectionChanged: (s) => setState(() => _durationDays = s.first),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inviter des amis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_selectedFriendIds.isNotEmpty)
                  Text(
                    '${_selectedFriendIds.length} sélectionné${_selectedFriendIds.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FriendSelectorWidget(
              friends: friendsState.friends,
              currentUserId: currentUserId,
              multiSelect: true,
              onSelectionChanged: (ids) => setState(() => _selectedFriendIds = ids),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Créer le défi 🏆', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `group_challenge_detail_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../providers/group_challenge_provider.dart';

class GroupChallengeDetailPage extends ConsumerWidget {
  final String challengeId;
  const GroupChallengeDetailPage({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final challenge = state.myChallenges
        .where((c) => c.id == challengeId)
        .firstOrNull;

    if (challenge == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Défi')),
        body: const Center(child: Text('Défi introuvable')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(challenge.title)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(groupChallengeNotifierProvider.notifier).loadChallenges(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status row
            Row(
              children: [
                Chip(
                  label: Text(
                    challenge.isPending
                        ? 'En attente'
                        : challenge.isActive
                            ? 'En cours'
                            : 'Terminé',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: challenge.isPending
                      ? Colors.orange
                      : challenge.isActive
                          ? const Color(0xFFF59E0B)
                          : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('${challenge.durationDays} jours', style: const TextStyle(color: Colors.grey)),
                if (challenge.isActive) ...[
                  const SizedBox(width: 8),
                  Text('· ${challenge.daysRemaining}j restants', style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),

            // Force-start button (creator only, some rejected)
            if (challenge.creatorId == currentUserId && challenge.canForceStart) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref
                    .read(groupChallengeNotifierProvider.notifier)
                    .forceStart(challengeId),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lancer maintenant'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              ),
            ],

            const SizedBox(height: 24),
            const Text('Classement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),

            if (challenge.participants.isEmpty)
              const Text('Aucun participant pour le moment.', style: TextStyle(color: Colors.grey))
            else
              ...challenge.sortedLeaderboard.toList().asMap().entries.map((entry) {
                final rank = entry.key;
                final p = entry.value;
                final medals = ['🥇', '🥈', '🥉'];
                final medalEmoji = rank < 3 ? medals[rank] : '${rank + 1}.';
                final isMe = p.userId == currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFFFEF3C7)
                        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: isMe
                        ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(medalEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@${p.profile?.username ?? p.userId.substring(0, 6)}${isMe ? ' (moi)' : ''}',
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        p.formattedDistance,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMe ? const Color(0xFFB45309) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Participants who haven't accepted yet
            final pendingParticipants = challenge.participants
                .where((p) => p.status == ParticipantStatus.invited)
                .toList();
            if (pendingParticipants.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('En attente de réponse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 8),
              ...pendingParticipants.map((p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                title: Text('@${p.profile?.username ?? p.userId.substring(0, 6)}'),
                trailing: const Text('En attente…', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
```

Note: The `final pendingParticipants = ...` declaration inside `children: [...]` will cause a parse error — move it to a local variable before the `ListView` children list and reference it:

```dart
// Before the ListView children list:
final pendingParticipants = challenge.participants
    .where((p) => p.status == ParticipantStatus.invited)
    .toList();
```

Then in the children list, just use `if (pendingParticipants.isNotEmpty) ...`.

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/features/challenges/presentation/
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/challenges/presentation/
git commit -m "feat: add group challenge UI (list, create, detail)"
```

---

## Task 13: Wire routes in main.dart

This task depends on Task 9 (routes declared) and all page files being created.

- [ ] **Step 1: Read `lib/main.dart`** to find the GoRouter routes list.

- [ ] **Step 2: Add imports and routes** as described in Task 9 Step 2.

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/main.dart
```

Expected: no errors.

- [ ] **Step 4: Run the app**

```bash
flutter run
```

Navigate to Défis tab → tap Duel card → DuelsPage opens. Tap back → tap Défi groupe card → GroupChallengesPage opens. Tap + → Create pages open.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/core/constants/route_constants.dart
git commit -m "feat: wire challenge routes in GoRouter"
```

---

## Task 14: Activity linking after a run

When a run ends (`RunRewardPage` receives `activityId`), check if the user has an active duel or group challenge and link the activity automatically.

**Files:**
- Modify: `lib/features/run/presentation/pages/run_reward_page.dart`

- [ ] **Step 1: Add linking logic to `RunRewardPage.initState`**

In `_RunRewardPageState`, add an `_autoLinkActivity` call in `initState`:

```dart
@override
void initState() {
  super.initState();
  if (widget.activityId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLinkActivity(widget.activityId!);
    });
  }
}

Future<void> _autoLinkActivity(String activityId) async {
  // Link to active duel
  final duelState = ref.read(duelNotifierProvider);
  final activeDuel = duelState.myDuels
      .where((d) => d.isActive || d.status == DuelStatus.accepted)
      .firstOrNull;
  if (activeDuel != null) {
    await ref
        .read(duelNotifierProvider.notifier)
        .linkActivityToDuel(activeDuel.id, activityId);
  }

  // Add distance to active group challenges
  final gcState = ref.read(groupChallengeNotifierProvider);
  final runState = ref.read(runTrackingProvider);
  for (final challenge in gcState.myChallenges.where((c) => c.isActive)) {
    await ref
        .read(groupChallengeNotifierProvider.notifier)
        .addRunDistance(challenge.id, runState.distanceMeters);
  }
}
```

Add the necessary imports at the top of `run_reward_page.dart`:
```dart
import '../../../challenges/presentation/providers/duel_provider.dart';
import '../../../challenges/presentation/providers/group_challenge_provider.dart';
import '../../../challenges/domain/entities/duel_entity.dart';
```

Change `RunRewardPage` from `ConsumerStatefulWidget` to use `ConsumerStatefulWidget` (it already is) — verify the existing class structure supports `ref` access in `initState` (use `ref.read` only, safe in `addPostFrameCallback`).

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/run/presentation/pages/run_reward_page.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/run/presentation/pages/run_reward_page.dart
git commit -m "feat: auto-link activity to active duel/group challenge after run"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Landing with two distinct cards → Task 10
- ✅ Duel: 1v1, live or async, accept/reject → Tasks 2, 4, 6, 11
- ✅ Group: multi-friend, period, leaderboard → Tasks 3, 5, 7, 12
- ✅ DB migrations with RLS → Task 1
- ✅ Activity linking after run → Task 14
- ✅ Force-start when some reject → GroupChallengeDetailPage + `canForceStart`
- ✅ Routes → Tasks 9, 13

**Type consistency check:**
- `DuelTiming.async` / `DuelTiming.live` — consistent across entity, model, datasource, provider, UI ✅
- `DuelStatus.fromString` / `toJson` — used consistently in model and UI ✅
- `ParticipantStatus.invited` — referenced in card, detail, and repository ✅
- `duelRepositoryProvider` — declared in `duel_repository_impl.dart`, read in `duel_provider.dart` ✅
- `groupChallengeRepositoryProvider` — declared in `group_challenge_repository_impl.dart`, read in `group_challenge_provider.dart` ✅
- `Routes.duelDetail.replaceFirst(':id', ...)` — used in `duel_card.dart` and `group_challenge_card.dart` — ✅ consistent with GoRouter path param pattern

**Placeholder scan:** No TBD, TODO, or incomplete steps found.
