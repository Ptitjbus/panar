# Friend System Design

**Date:** 2026-04-14
**Feature:** Système d'amis complet avec recherche, demandes, acceptation et liste d'amis
**Status:** Design approved

## Overview

Implémentation d'un système d'amis permettant aux utilisateurs de :
- Rechercher d'autres utilisateurs par nom d'utilisateur (username)
- Envoyer des demandes d'ami
- Accepter ou refuser des demandes reçues
- Voir leur liste d'amis
- Recevoir des mises à jour en temps réel via Supabase Realtime

## Requirements

### Fonctionnalités
1. Recherche d'utilisateurs par username (partiel ou exact)
2. Envoi de demande d'ami
3. Réception de demandes avec notification temps réel
4. Acceptation/refus de demandes
5. Affichage de la liste d'amis (username uniquement)
6. Demandes en attente affichées en section au-dessus de la liste d'amis

### Contraintes
- Un utilisateur ne peut pas s'ajouter lui-même
- Une seule demande par paire d'utilisateurs
- Les demandes refusées sont supprimées (l'expéditeur peut renvoyer)
- Relations bidirectionnelles après acceptation
- Mises à jour en temps réel pour tous les changements
- Respect de la Clean Architecture déjà établie

## Database Schema

### Table: `friendships`

```sql
CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'rejected');

CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status friendship_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Contraintes
  UNIQUE(requester_id, addressee_id),
  CHECK(requester_id != addressee_id)
);

-- Index pour performances
CREATE INDEX idx_friendships_requester ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee ON friendships(addressee_id);
CREATE INDEX idx_friendships_status ON friendships(status);
```

### Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Policy: Voir ses propres relations
CREATE POLICY "Users can view their own friendships"
  ON friendships FOR SELECT
  USING (
    auth.uid() = requester_id OR
    auth.uid() = addressee_id
  );

-- Policy: Créer des demandes
CREATE POLICY "Users can send friend requests"
  ON friendships FOR INSERT
  WITH CHECK (
    auth.uid() = requester_id AND
    status = 'pending'
  );

-- Policy: Mettre à jour le statut (accepter/refuser)
CREATE POLICY "Users can update received requests"
  ON friendships FOR UPDATE
  USING (auth.uid() = addressee_id);

-- Policy: Supprimer ses propres demandes
CREATE POLICY "Users can delete their friendships"
  ON friendships FOR DELETE
  USING (
    auth.uid() = requester_id OR
    auth.uid() = addressee_id
  );
```

### Trigger: Auto-update timestamp

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_friendships_updated_at
  BEFORE UPDATE ON friendships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

## Flutter Architecture

Suivant la Clean Architecture déjà établie dans le projet.

### Directory Structure

```
lib/features/friends/
├── domain/
│   ├── entities/
│   │   └── friendship_entity.dart
│   └── repositories/
│       └── friends_repository.dart
├── data/
│   ├── models/
│   │   └── friendship_model.dart
│   ├── datasources/
│   │   └── friends_remote_datasource.dart
│   └── repositories/
│       └── friends_repository_impl.dart
└── presentation/
    ├── providers/
    │   └── friends_provider.dart
    ├── pages/
    │   └── friends_page.dart (already exists - will be updated)
    └── widgets/
        ├── friend_list_item.dart
        ├── friend_request_item.dart
        └── friend_search_dialog.dart
```

### Domain Layer

#### Entity: `FriendshipEntity`

```dart
class FriendshipEntity {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Helper methods
  String getOtherUserId(String currentUserId);
  bool isPending();
  bool isAccepted();
}

enum FriendshipStatus { pending, accepted, rejected }
```

#### Repository Interface: `FriendsRepository`

```dart
abstract class FriendsRepository {
  Future<Either<Failure, List<ProfileEntity>>> searchUsers(String username);
  Future<Either<Failure, void>> sendFriendRequest(String addresseeId);
  Future<Either<Failure, void>> acceptFriendRequest(String friendshipId);
  Future<Either<Failure, void>> rejectFriendRequest(String friendshipId);
  Future<Either<Failure, void>> removeFriend(String friendshipId);
  Future<Either<Failure, List<FriendshipEntity>>> getMyFriends();
  Future<Either<Failure, List<FriendshipEntity>>> getReceivedRequests();
  Future<Either<Failure, List<FriendshipEntity>>> getSentRequests();
  Stream<FriendshipEntity> watchFriendships(); // Realtime
}
```

### Data Layer

#### Model: `FriendshipModel`

```dart
class FriendshipModel extends FriendshipEntity {
  factory FriendshipModel.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  FriendshipEntity toEntity();
}
```

#### Remote Datasource: `FriendsRemoteDatasource`

Méthodes principales:
- `searchUsersByUsername(String username)` - Query profiles table
- `sendFriendRequest(String requesterId, String addresseeId)` - Insert pending
- `acceptFriendRequest(String friendshipId)` - Update status + create inverse relation
- `rejectFriendRequest(String friendshipId)` - Delete row
- `removeFriend(String friendshipId)` - Delete both rows (original + inverse)
- `getFriendships(String userId, FriendshipStatus? status)` - Get list
- `subscribeFriendships(String userId)` - Realtime channel

#### Repository Implementation: `FriendsRepositoryImpl`

Implémente `FriendsRepository`, délègue au datasource, convertit exceptions en Failures.

### Presentation Layer

#### Provider: `FriendsProvider` (StateNotifier)

**State:**
```dart
class FriendsState {
  final List<FriendshipEntity> friends; // status = accepted
  final List<FriendshipEntity> receivedRequests; // status = pending, I'm addressee
  final List<FriendshipEntity> sentRequests; // status = pending, I'm requester
  final bool isLoading;
  final String? error;
}
```

**Methods:**
- `loadFriends()` - Charge les données initiales
- `searchUsers(String username)` - Recherche avec filtrage
- `sendFriendRequest(String userId)` - Envoie demande
- `acceptRequest(String friendshipId)` - Accepte
- `rejectRequest(String friendshipId)` - Refuse
- `removeFriend(String friendshipId)` - Supprime ami
- `_setupRealtimeSubscription()` - Initialise Realtime
- `_handleRealtimeEvent(PostgresChangePayload)` - Traite events

**Realtime Setup:**
```dart
void _setupRealtimeSubscription() {
  final currentUserId = ref.read(authProvider).user?.id;

  _subscription = supabase
    .channel('friendships:user_$currentUserId')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilterType.or(
        'requester_id=eq.$currentUserId,addressee_id=eq.$currentUserId'
      ),
      callback: _handleRealtimeEvent,
    )
    .subscribe();
}
```

#### UI: `FriendsPage`

**Layout:**
```
┌─────────────────────────────┐
│ AppBar: "Amis"              │
│   [Search Icon]             │
├─────────────────────────────┤
│ DEMANDES REÇUES (if any)    │
│ ┌─────────────────────────┐ │
│ │ @username               │ │
│ │ [Accepter] [Refuser]    │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ MES AMIS                    │
│ ┌─────────────────────────┐ │
│ │ @username               │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ @username               │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

**Features:**
- FloatingActionButton ou IconButton pour ouvrir le search dialog
- Section "Demandes reçues" avec `FriendRequestItem` widgets
- Section "Mes amis" avec `FriendListItem` widgets
- Pull-to-refresh (en complément du temps réel)
- Empty states avec messages appropriés

#### Widget: `FriendSearchDialog`

- TextField avec debounce (300ms)
- Liste de résultats filtrés
- Bouton "Ajouter" pour chaque résultat
- Loading indicator pendant la recherche
- Empty state si aucun résultat

#### Widget: `FriendRequestItem`

- Affiche username de l'expéditeur
- Boutons "Accepter" (vert) et "Refuser" (rouge)
- Loading state pendant l'action
- Gestion des erreurs

#### Widget: `FriendListItem`

- Affiche username de l'ami
- Option de suppression (swipe-to-delete ou menu)
- Confirmation avant suppression

## Data Flow

### 1. Envoi de demande d'ami

```
User opens search dialog
  → Types username
  → Provider.searchUsers()
  → Repository.searchUsers()
  → Datasource queries profiles table
  → Filter results (exclude self, existing friends, pending requests)
  → Display results

User clicks "Ajouter"
  → Provider.sendFriendRequest(userId)
  → Repository.sendFriendRequest()
  → Datasource inserts {requester_id, addressee_id, status='pending'}
  → Success
  → Realtime event triggers for both users
  → Sender's "sent requests" updates
  → Receiver's "received requests" updates
```

### 2. Acceptation de demande

```
User sees request in "Demandes reçues"
  → User clicks "Accepter"
  → Provider.acceptRequest(friendshipId)
  → Repository.acceptFriendRequest()
  → Datasource:
      1. Update original row: status = 'accepted'
      2. Insert inverse row: {
           requester_id: original.addressee_id,
           addressee_id: original.requester_id,
           status: 'accepted'
         }
  → Success
  → Realtime events (UPDATE + INSERT) trigger
  → Both users see each other in "Mes amis"
```

### 3. Refus de demande

```
User clicks "Refuser"
  → Provider.rejectRequest(friendshipId)
  → Repository.rejectFriendRequest()
  → Datasource deletes the row
  → Success
  → Realtime DELETE event triggers
  → Request disappears from UI
```

### 4. Suppression d'ami

```
User swipes or clicks delete on friend
  → Confirmation dialog
  → Provider.removeFriend(friendshipId)
  → Repository.removeFriend()
  → Datasource:
      1. Delete original row
      2. Delete inverse row
  → Success
  → Realtime DELETE events trigger
  → Friend removed from both users' lists
```

### 5. Realtime Updates

```
Postgres event (INSERT/UPDATE/DELETE)
  → Supabase broadcasts to subscribed clients
  → Provider._handleRealtimeEvent(payload)
  → Switch on event type:
      - INSERT: Add to appropriate list
      - UPDATE: Update status, move between lists if needed
      - DELETE: Remove from lists
  → State updated
  → UI rebuilds automatically (Riverpod)
```

## Error Handling

### Error Types

1. **Duplicate Request (UNIQUE constraint violation)**
   - Code: '23505'
   - Message: "Vous avez déjà envoyé une demande à cet utilisateur"

2. **Self-Friend (CHECK constraint violation)**
   - Code: '23514'
   - Message: "Vous ne pouvez pas vous ajouter vous-même"

3. **User Not Found**
   - Empty search results
   - Message: "Aucun utilisateur trouvé"

4. **Network Error**
   - Generic exception
   - Message: "Erreur de connexion. Veuillez réessayer"
   - Retry option

5. **Permission Denied (RLS)**
   - Code: '42501'
   - Message: "Action non autorisée"

### Error Display

- SnackBar pour les erreurs ponctuelles (envoi, acceptation, refus)
- Dialog pour les erreurs critiques nécessitant l'attention de l'utilisateur
- Loading states pour éviter les actions multiples
- Disable buttons pendant les opérations

### Datasource Error Handling

```dart
try {
  final response = await supabase.from('friendships').insert(...);
  return Right(response);
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    return Left(DuplicateRequestFailure());
  } else if (e.code == '23514') {
    return Left(InvalidRequestFailure());
  } else if (e.code == '42501') {
    return Left(PermissionDeniedFailure());
  }
  return Left(DatabaseFailure(e.message));
} catch (e) {
  return Left(NetworkFailure());
}
```

## Validation

### Search Validation

- Minimum 3 caractères (aligné avec contrainte username DB)
- Trim whitespace
- Non-empty après trim

### Business Logic Validation

- **Filtrage des résultats de recherche:**
  - Exclure l'utilisateur actuel
  - Exclure les amis existants (status='accepted')
  - Exclure les demandes pending (dans les deux sens)

- **Actions:**
  - Disable bouton pendant l'opération (éviter double-click)
  - Vérification locale avant envoi au serveur (meilleure UX)

## Testing Strategy

### Manual Testing Scenarios

1. **Scénario basique complet:**
   - User A recherche User B par username
   - User A envoie une demande
   - Vérifier: User B voit la demande instantanément (temps réel)
   - User B accepte la demande
   - Vérifier: Les deux users voient l'autre dans "Mes amis"

2. **Scénario de refus:**
   - User A envoie une demande à User C
   - User C refuse
   - Vérifier: La demande disparaît
   - User A peut renvoyer une demande immédiatement

3. **Temps réel multi-device:**
   - Ouvrir l'app sur 2 émulateurs/devices différents
   - User 1 envoie une demande
   - Vérifier: User 2 la reçoit instantanément
   - User 2 accepte
   - Vérifier: User 1 voit l'acceptation instantanément

4. **Gestion d'erreurs:**
   - Tenter de rechercher son propre username
   - Tenter d'envoyer une demande à quelqu'un qui a déjà une demande pending
   - Tester sans connexion internet
   - Vérifier les messages d'erreur appropriés

5. **RLS (Row Level Security):**
   - Avec 3 users (A, B, C):
     - A et B sont amis
     - Vérifier que C ne peut pas voir la relation A-B
     - Vérifier que A ne peut pas accepter une demande qu'il a envoyée

6. **Suppression:**
   - User A supprime User B de ses amis
   - Vérifier: User B ne voit plus User A
   - Vérifier: User A peut renvoyer une demande

### SQL Test Queries

```sql
-- Vérifier les relations bidirectionnelles
SELECT * FROM friendships
WHERE (requester_id = 'user_a_id' AND addressee_id = 'user_b_id')
   OR (requester_id = 'user_b_id' AND addressee_id = 'user_a_id');

-- Compter les amis d'un user
SELECT COUNT(*) FROM friendships
WHERE (requester_id = 'user_id' OR addressee_id = 'user_id')
  AND status = 'accepted';

-- Lister les demandes reçues
SELECT * FROM friendships
WHERE addressee_id = 'user_id' AND status = 'pending';
```

## Implementation Notes

### Realtime Subscription Lifecycle

- **Initialize:** Dans `initState` du provider ou après login
- **Cleanup:** Dans `dispose` du provider ou au logout
- **Reconnection:** Supabase gère automatiquement les reconnexions
- **Error handling:** Gérer les erreurs de subscription

### Performance Considerations

- **Debounce search:** 300ms pour éviter trop de requêtes
- **Pagination:** Si nombre d'amis > 100, considérer la pagination
- **Cache:** Les listes sont en mémoire (state du provider)
- **Indexes:** DB indexes sur requester_id, addressee_id, status

### Future Enhancements (Out of Scope)

- Notifications push pour les nouvelles demandes
- Système de blocage d'utilisateurs
- Suggestions d'amis (mutual friends, etc.)
- Statut en ligne/hors ligne
- Dernière activité
- Groupes d'amis

## Critical Files to Modify/Create

### Database Migration
- `supabase/migrations/YYYYMMDDHHMMSS_create_friendships_table.sql`

### Domain Layer (New)
- `lib/features/friends/domain/entities/friendship_entity.dart`
- `lib/features/friends/domain/repositories/friends_repository.dart`

### Data Layer (New)
- `lib/features/friends/data/models/friendship_model.dart`
- `lib/features/friends/data/datasources/friends_remote_datasource.dart`
- `lib/features/friends/data/repositories/friends_repository_impl.dart`

### Presentation Layer (New & Modified)
- `lib/features/friends/presentation/providers/friends_provider.dart` (new)
- `lib/features/friends/presentation/pages/friends_page.dart` (modify existing)
- `lib/features/friends/presentation/widgets/friend_list_item.dart` (new)
- `lib/features/friends/presentation/widgets/friend_request_item.dart` (new)
- `lib/features/friends/presentation/widgets/friend_search_dialog.dart` (new)

### Shared/Core (If needed)
- `lib/core/errors/failures.dart` - Add friend-specific failures if needed

## Success Criteria

- ✅ Users can search for other users by username
- ✅ Users can send friend requests
- ✅ Users receive friend requests in real-time
- ✅ Users can accept/reject requests
- ✅ Accepted friends appear in both users' friend lists
- ✅ Rejected requests are deleted and can be resent
- ✅ All actions trigger real-time updates
- ✅ RLS prevents unauthorized access
- ✅ Appropriate error messages for all error cases
- ✅ No duplicate requests allowed
- ✅ Clean Architecture maintained
- ✅ Code follows existing project patterns and conventions
