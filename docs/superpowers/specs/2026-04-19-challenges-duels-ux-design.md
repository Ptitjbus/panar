# Design Spec — Challenges & Duels UX/UI + Cancel + Live Waiting Room

**Date:** 2026-04-19  
**Status:** Approved  
**Scope:** Three parallel axes delivered together for visual consistency

---

## 1. Objectives

1. **UX/UI** — Refonte visuelle minimaliste (style Apple Fitness) des écrans duels et défis de groupe : meilleure hiérarchie, statuts clairs, identité cohérente.
2. **Cancel/Leave** — Permettre l'annulation de duels (tout participant, tout moment) et la suppression/quitter d'un défi de groupe (créateur = supprime, participant = quitte).
3. **Live Duel Waiting Room** — Bloquer le lancement d'un duel live tant que les deux joueurs ne sont pas prêts. Écran de salle d'attente avec countdown simultané.

---

## 2. Design System

### Palette
| Token | Valeur | Usage |
|-------|--------|-------|
| `background` | `#F2F2F7` | Fond des pages |
| `surface` | `#FFFFFF` | Cartes, dialogs |
| `accent` | `#007AFF` | Actions primaires, chips actives |
| `success` | `#34C759` | Victoire, défi complété |
| `danger` | `#FF3B30` | Annulation, défaite, quitter |
| `textPrimary` | `#000000` | Titres, valeurs clés |
| `textSecondary` | `#6C6C70` | Labels, métadonnées |
| `border` | `#E5E5EA` | Borders de cartes |

### Composants
- **Cards** : fond blanc, `borderRadius: 16`, border `1px #E5E5EA`, elevation 0, padding `16px`
- **Status chips** : pill arrondie, fond coloré à 15% d'opacité, texte coloré `fontWeight: 600`
- **Typography** : system font (déjà SF Pro sur iOS), titres `w700`, secondary `w400 + textSecondary`
- **Buttons** : primaire plein `accent`, destructif plein `danger`, secondaire outlined

### Chips de statut duels
| Statut | Fond | Texte |
|--------|------|-------|
| `pending` | `#E5E5EA` | "En attente" |
| `accepted` | `#007AFF1A` | "Accepté" (bleu) |
| `active` | `#007AFF` | "En cours" (blanc) |
| `completed` + gagné | `#34C7591A` | "Victoire ✓" (vert) |
| `completed` + perdu | `#FF3B301A` | "Défaite" (rouge) |
| `cancelled` | `#E5E5EA` | "Annulé" (gris) |

---

## 3. Annulation / Suppression / Quitter

### 3.1 Duels — Annulation par n'importe quel participant

**Règle :** Tout participant (challenger ou challenged) peut annuler un duel à tout moment, sauf s'il est `completed`.

**Changements Supabase :**
- Ajouter colonne `cancelled_by_id UUID REFERENCES profiles(id)` sur table `duels`
- Ajouter valeur `cancelled` au type enum `duel_status` (ou contrainte CHECK)

**Changements code :**
- `DuelStatus` enum : ajouter `cancelled`
- `DuelModel` / `DuelEntity` : ajouter champ `cancelledById`
- `DuelRemoteDataSource.cancelDuel(duelId, cancelledById)` : UPDATE status='cancelled', cancelled_by_id
- `DuelRepositoryImpl.cancelDuel(duelId)` : récupère userId courant, délègue datasource
- `DuelNotifier.cancelDuel(duelId)` : appelle repo, reload, message succès
- `DuelDetailPage` : bouton "Annuler le duel" (rouge, outlined) visible si statut ≠ `completed` et ≠ `cancelled`
- Confirmation dialog avant annulation

### 3.2 Défis de groupe — Créateur supprime, participant quitte

**Règles :**
- Créateur : peut supprimer le défi à tout moment (sauf `completed`) → suppression cascade (participants inclus)
- Participant : peut quitter si son statut est `invited` ou `accepted` → statut devient `left`

**Changements Supabase :**
- Ajouter valeur `left` au type enum `participant_status`
- S'assurer que la suppression du défi cascade sur `group_challenge_participants`

**Changements code :**
- `ParticipantStatus` enum : ajouter `left`
- `GroupChallengeRemoteDataSource.deleteChallenge(challengeId)` : DELETE sur `group_challenges`
- `GroupChallengeRemoteDataSource.leaveChallenge(challengeId, userId)` : UPDATE participant status='left'
- `GroupChallengeRepositoryImpl.deleteChallenge(challengeId)` / `leaveChallenge(challengeId)`
- `GroupChallengeNotifier.deleteChallenge(challengeId)` / `leaveChallenge(challengeId)`
- `GroupChallengeDetailPage` :
  - Si créateur + statut ≠ `completed` → bouton "Supprimer le défi" (rouge)
  - Si participant accepté/invité → bouton "Quitter le défi" (rouge outlined)
- Confirmations dialog systématiques

---

## 4. Live Duel — Salle d'attente

### 4.1 Flow utilisateur

```
User A accepte duel live
        │
        ▼
DuelWaitingRoomPage ◄─── User B accepte duel live (notification)
        │
   [Bouton "Je suis prêt"]
        │
   Supabase: duel_ready_states INSERT/UPDATE ready_at
        │
   Stream détecte les deux ready_at non-null
        │
   Countdown animé : 3...2...1...Go!
        │
   Navigation → /run/tracking?duelId=xxx
```

**Timeout :** Si l'autre joueur ne rejoint pas en 5 minutes → dialog "Adversaire absent" → annuler ou attendre.

**Navigation arrière :** Quitter la salle d'attente (back button) n'annule pas le duel ni l'état `ready_at`. L'utilisateur peut revenir via `DuelDetailPage` → bouton "Rejoindre la salle d'attente".

### 4.2 Nouvelle table Supabase `duel_ready_states`

```sql
CREATE TABLE duel_ready_states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  duel_id UUID NOT NULL REFERENCES duels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ready_at TIMESTAMPTZ,
  UNIQUE(duel_id, user_id)
);
ALTER TABLE duel_ready_states ENABLE ROW LEVEL SECURITY;
-- Policy : les participants du duel peuvent lire/écrire leur propre ligne
```

### 4.3 Changements code

**Datasource** `DuelRemoteDataSource` :
- `Future<void> setReady(String duelId, String userId)` : UPSERT dans `duel_ready_states`
- `Stream<List<Map>> watchReadyStates(String duelId)` : `.stream(primaryKey: ['id']).eq('duel_id', duelId)`

**Repository** `DuelRepositoryImpl` :
- `Future<void> setReady(String duelId)` : délègue datasource avec userId courant
- `Stream<List<DuelReadyState>> watchReadyStates(String duelId)`

**Provider** (nouveau StreamProvider) :
```dart
final duelReadyStatesProvider = StreamProvider.family<List<DuelReadyState>, String>(
  (ref, duelId) => ref.watch(duelRepositoryProvider).watchReadyStates(duelId),
);
```

**Nouveau screen** `DuelWaitingRoomPage` :
- Consomme `duelReadyStatesProvider(duelId)`
- Affiche les deux joueurs avec avatar + indicateur "Prêt ✓" / "En attente..."
- Bouton "Je suis prêt" → appelle `setReady`
- Quand les deux ready → lance `AnimationController` countdown 3s → route `/run/tracking`
- Timer 5min → dialog timeout

**Navigation :**
- `DuelDetailPage` : bouton "Rejoindre la salle d'attente" remplace "Start Live Duel" pour les duels `timing == live` et `status == accepted`

---

## 5. Fichiers impactés (résumé)

### Nouveaux fichiers
| Fichier | Description |
|---------|-------------|
| `lib/features/challenges/domain/entities/duel_ready_state_entity.dart` | Entité représentant l'état "prêt" d'un joueur |
| `lib/features/challenges/presentation/pages/duel_waiting_room_page.dart` | Écran salle d'attente |

### Fichiers modifiés
| Fichier | Changements |
|---------|-------------|
| `lib/features/challenges/domain/entities/duel_entity.dart` | + `cancelledById`, + enum `cancelled` |
| `lib/features/challenges/data/models/duel_model.dart` | + sérialisation `cancelledById` |
| `lib/features/challenges/domain/entities/group_challenge_participant_entity.dart` | + enum `left` |
| `lib/features/challenges/data/datasources/duel_remote_datasource.dart` | + `cancelDuel`, `setReady`, `watchReadyStates` |
| `lib/features/challenges/data/datasources/group_challenge_remote_datasource.dart` | + `deleteChallenge`, `leaveChallenge` |
| `lib/features/challenges/data/repositories/duel_repository_impl.dart` | + `cancelDuel`, `setReady`, `watchReadyStates` |
| `lib/features/challenges/data/repositories/group_challenge_repository_impl.dart` | + `deleteChallenge`, `leaveChallenge` |
| `lib/features/challenges/domain/repositories/duel_repository.dart` | + signatures |
| `lib/features/challenges/domain/repositories/group_challenge_repository.dart` | + signatures |
| `lib/features/challenges/presentation/providers/duel_provider.dart` | + `cancelDuel`, `duelReadyStatesProvider` |
| `lib/features/challenges/presentation/providers/group_challenge_provider.dart` | + `deleteChallenge`, `leaveChallenge` |
| `lib/features/challenges/presentation/pages/duel_detail_page.dart` | Refonte UI + bouton annuler + route waiting room |
| `lib/features/challenges/presentation/pages/group_challenge_detail_page.dart` | Refonte UI + bouton supprimer/quitter |
| `lib/features/challenges/presentation/widgets/duel_card.dart` | Refonte visuelle |
| `lib/features/challenges/presentation/widgets/group_challenge_card.dart` | Refonte visuelle |

### Migrations Supabase
1. Ajouter `cancelled_by_id` + valeur `cancelled` sur `duels`
2. Ajouter valeur `left` sur `group_challenge_participants.status`
3. Créer table `duel_ready_states`

---

## 6. Hors périmètre

- Run tracking, auth, profils, activités
- Notifications push (mentionné mais non implémenté dans ce plan)
- Android/Web platform-specific adaptations
- Tests unitaires (à couvrir séparément)
