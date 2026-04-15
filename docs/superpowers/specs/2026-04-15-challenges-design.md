# Challenges System Design

**Date:** 2026-04-15  
**Status:** Approved  

---

## Overview

Two distinct social challenge modes for the Panar running app:

- **Duel** — 1v1 between two friends on a single run, live or async
- **Défi groupe** — multi-friend distance accumulation over a defined period (no persistent group)

Both modes are accessible from a unified `ChallengesPage` landing that presents them as two distinct entry points.

---

## User Stories

### Duel
- As a user, I can challenge one friend to a duel on distance over a single run
- I can choose between a **live** duel (we both run at the same time) or an **async** duel (they run whenever they want within a deadline)
- My friend receives a notification and must accept or reject before the duel starts
- Once both activities are completed, the one with the greater distance wins
- I can see active, pending, and past duels in a dedicated sub-view

### Défi groupe
- As a user, I can create a group challenge with a title and a duration (3, 7, or 30 days)
- I select multiple friends (no permanent group is created)
- Each invited friend receives a notification and must accept or reject
- The challenge starts when all invited friends have accepted
- During the challenge period, every completed run automatically adds to a participant's cumulated distance
- A live leaderboard shows the current ranking
- At the end of the period, the participant with the most total distance wins
- I can see active, pending invites, and past group challenges in a dedicated sub-view

---

## Navigation Structure

```
ChallengesPage (landing)
├── → DuelsPage
│   ├── → CreateDuelPage
│   └── → DuelDetailPage
└── → GroupChallengesPage
    ├── → CreateGroupChallengePage
    └── → GroupChallengeDetailPage
```

**Landing** (`ChallengesPage`): Two large distinct cards:
- **⚔️ Duel** (violet gradient) — badge "1 vs 1 · 1 course"
- **🏆 Défi groupe** (orange gradient) — badge "2–10 joueurs · 3/7/30 jours"
- A warning banner if there are pending invitations across either mode

---

## Database Schema

### Table `duels`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `challenger_id` | uuid FK → profiles | User who creates the duel |
| `challenged_id` | uuid FK → profiles | User who is invited |
| `status` | enum | `pending \| accepted \| rejected \| active \| completed` |
| `timing` | enum | `live \| async` |
| `deadline_hours` | int? | Async only — how long the challenged user has to run |
| `challenger_activity_id` | uuid? FK → activities | Linked after run completes |
| `challenged_activity_id` | uuid? FK → activities | Linked after run completes |
| `winner_id` | uuid? FK → profiles | Set when both activities are linked |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

### Table `group_challenges`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `creator_id` | uuid FK → profiles | |
| `title` | text | User-defined name |
| `duration_days` | int | `3 \| 7 \| 30` |
| `status` | enum | `pending \| active \| completed` |
| `starts_at` | timestamptz? | Set when all participants accept |
| `ends_at` | timestamptz? | `starts_at + duration_days` |
| `created_at` | timestamptz | |

### Table `group_challenge_participants`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `challenge_id` | uuid FK → group_challenges | |
| `user_id` | uuid FK → profiles | |
| `status` | enum | `invited \| accepted \| rejected` |
| `total_distance_meters` | float | Incremented on each completed activity |
| `joined_at` | timestamptz? | Set when status → accepted |

**Activity linking:**
- Duels: `challenger_activity_id` / `challenged_activity_id` are set from the app after a run completes, then winner is computed client-side and written to `winner_id`.
- Group challenges: after each run completes, the app increments `total_distance_meters` for the matching participant row.

---

## Flutter Architecture

All code lives inside `lib/features/challenges/` following the existing Clean Architecture pattern.

### Files to create

```
lib/features/challenges/
├── data/
│   ├── datasources/
│   │   ├── duel_remote_datasource.dart
│   │   └── group_challenge_remote_datasource.dart
│   ├── models/
│   │   ├── duel_model.dart
│   │   ├── group_challenge_model.dart
│   │   └── group_challenge_participant_model.dart
│   └── repositories/
│       ├── duel_repository_impl.dart
│       └── group_challenge_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── duel_entity.dart
│   │   ├── group_challenge_entity.dart
│   │   └── group_challenge_participant_entity.dart
│   └── repositories/
│       ├── duel_repository.dart
│       └── group_challenge_repository.dart
└── presentation/
    ├── pages/
    │   ├── challenges_page.dart          ← rewrite existing placeholder
    │   ├── duels_page.dart
    │   ├── group_challenges_page.dart
    │   ├── create_duel_page.dart
    │   ├── create_group_challenge_page.dart
    │   ├── duel_detail_page.dart
    │   └── group_challenge_detail_page.dart
    ├── providers/
    │   ├── duel_provider.dart
    │   └── group_challenge_provider.dart
    └── widgets/
        ├── challenge_mode_card.dart      ← landing card (reusable)
        ├── duel_card.dart
        ├── group_challenge_card.dart
        └── friend_selector_widget.dart   ← single-select (duel) or multi-select (group)
```

### Domain Entities

**`DuelEntity`**
```dart
class DuelEntity {
  final String id;
  final String challengerId;
  final String challengedId;
  final DuelStatus status;       // pending | accepted | rejected | active | completed
  final DuelTiming timing;       // live | async
  final int? deadlineHours;
  final String? challengerActivityId;
  final String? challengedActivityId;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Optional eager-loaded profiles
  final ProfileEntity? challengerProfile;
  final ProfileEntity? challengedProfile;
}
```

**`GroupChallengeEntity`**
```dart
class GroupChallengeEntity {
  final String id;
  final String creatorId;
  final String title;
  final int durationDays;        // 3 | 7 | 30
  final GroupChallengeStatus status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final List<GroupChallengeParticipantEntity> participants;
}
```

**`GroupChallengeParticipantEntity`**
```dart
class GroupChallengeParticipantEntity {
  final String id;
  final String challengeId;
  final String userId;
  final ParticipantStatus status; // invited | accepted | rejected
  final double totalDistanceMeters;
  final DateTime? joinedAt;
  final ProfileEntity? profile;
}
```

### Providers (Riverpod `StateNotifier`)

**`duelNotifierProvider`**
- State: `{ List<DuelEntity> myDuels, List<DuelEntity> pendingInvites, bool isLoading, String? error }`
- Actions: `loadDuels()`, `createDuel(challengedId, timing, deadlineHours?)`, `respondToDuel(duelId, accept)`, `linkActivity(duelId, activityId)`

**`groupChallengeNotifierProvider`**
- State: `{ List<GroupChallengeEntity> myChallenges, List<GroupChallengeEntity> pendingInvites, bool isLoading, String? error }`
- Actions: `loadChallenges()`, `createChallenge(title, durationDays, friendIds)`, `respondToChallenge(challengeId, accept)`, `refreshLeaderboard(challengeId)`

---

## Key Flows

### Duel creation
1. User opens **CreateDuelPage** → selects 1 friend (single-select)
2. Picks timing: **Live** or **Différé**
3. If async: picks deadline (24h / 48h)
4. App inserts row in `duels` with `status: pending`
5. Friend is notified → accepts or rejects
6. On accept: `status → active`
7. Each user completes a run → app writes the `activity_id` to the duel row
8. When both activity IDs are present: compare `distance_meters`, set `winner_id`, `status → completed`

### Group challenge creation
1. User opens **CreateGroupChallengePage**
2. Sets title + duration (3 / 7 / 30 days)
3. Multi-selects friends (minimum 1, maximum 9)
4. App inserts `group_challenges` row (`status: pending`) + one `group_challenge_participants` row per invited friend (`status: invited`)
5. Each friend accepts/rejects via notification
6. When **all** friends have accepted: `status → active`, `starts_at = now()`, `ends_at = starts_at + duration_days`. If some friends rejected but at least 2 participants (creator + 1) accepted, the creator sees a **force-start** button to begin with whoever accepted.
7. As participants complete runs: app increments their `total_distance_meters`
8. When `ends_at` is reached: `status → completed`, leaderboard is frozen

---

## Error Handling

- Wrap all Supabase calls in try/catch, surfacing `PostgrestException`
- Friend offline / no response before deadline: show expiry warning in UI, duel auto-cancels via status check on load
- Group challenge: if some friends reject, creator sees who declined and can still start with those who accepted (force-start button)
- No push notification infra yet — app uses polling (refresh on focus) for status updates

---

## Out of Scope

- Push notifications (to be added later)
- Real-time leaderboard via Supabase Realtime subscription (polling on focus for now)
- Spectator mode for live duels (live_interactions feature already handles this separately)
- Duel on pace/time metric (distance only for now)
- Rematch / challenge history beyond the list view
