# Push Notifications — Design Spec
**Date:** 2026-04-16  
**Plateforme cible:** iOS (Android compatible sans changement d'architecture)  
**Stack:** Firebase FCM + Supabase Edge Functions + `firebase_messaging` Flutter

---

## 1. Architecture générale

```
[DB Event]
    │
    ▼
[Supabase Database Webhook]
    │  (HTTP POST on INSERT/UPDATE)
    ▼
[Supabase Edge Function]  ←── logique : qui notifier ? quel message ?
    │
    ▼
[FCM REST API v1]
    │
    ▼
[APNs]  ──►  [iPhone de l'utilisateur]
    │
    ▼
[Flutter app: firebase_messaging]
    ├── App en foreground → flutter_local_notifications (bannière in-app)
    └── App en background/fermée → bannière système iOS
```

---

## 2. Table `device_tokens`

```sql
CREATE TABLE device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token   text NOT NULL,
  platform    text NOT NULL DEFAULT 'ios',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, fcm_token)
);
```

**RLS :**
- `SELECT` : `auth.uid() = user_id`
- `INSERT` : `auth.uid() = user_id`
- `UPDATE` : `auth.uid() = user_id`
- Les Edge Functions lisent via `service_role` (bypass RLS)

---

## 3. Enregistrement du token côté Flutter

**Nouveau service :** `lib/features/notifications/notification_setup_service.dart`

Appelé une fois depuis `app.dart` après confirmation `authStateProvider` connecté.

Flux :
1. `FirebaseMessaging.instance.requestPermission()` — si déjà refusé (stocké dans `SharedPreferences`), ne pas re-demander
2. `FirebaseMessaging.instance.getToken()` → upsert dans `device_tokens`
3. `FirebaseMessaging.instance.onTokenRefresh.listen(...)` → re-upsert automatique

**Gestion des messages reçus :**
- App en foreground : `FirebaseMessaging.onMessage` → afficher via `flutter_local_notifications`
- App en background/terminée : iOS gère la bannière automatiquement via FCM

---

## 4. Contenu des notifications

| Événement | Titre | Corps | Destinataires |
|-----------|-------|-------|---------------|
| Ami commence une course | `🏃 {nom} court !` | `Va le supporter en direct sur Panar` | Tous les amis |
| Encouragement/emoji reçu | `💪 {nom} t'encourage !` | `{contenu}` | Le runner |
| Message vocal reçu | `🎤 {nom} t'a envoyé un vocal` | `Écoute-le pendant ta course` | Le runner |
| Invitation défi de groupe | `🏆 {nom} t'invite à un défi` | `{nom du défi}` | Participants invités |
| Invitation duel | `⚔️ {nom} te défie !` | `Accepte le duel et prouve ce que tu vaux` | Le challenged |
| Duel terminé — victoire | `🥇 Tu as gagné le duel !` | `Tu as battu {nom}` | Le gagnant |
| Duel terminé — défaite | `💀 Duel perdu` | `{nom} t'a battu cette fois` | Le perdant |
| Défi de groupe terminé | `🏁 Défi terminé !` | `{nom} a gagné le défi {nom_défi}` | Tous les participants |
| Ami accepte demande | `✅ {nom} a accepté ta demande` | `Vous êtes maintenant amis sur Panar` | L'expéditeur de la demande |
| Rappel quotidien | `👟 T'as pas couru aujourd'hui` | `Enfile tes Panar et va courir !` | Users actifs sans session du jour |

**Règles de déduplication :**
- Interactions live : max 1 push toutes les **30 secondes** par runner (les suivantes arrivent déjà en overlay in-app)
- Rappel quotidien : uniquement si l'utilisateur n'a pas de `run_sessions` créée aujourd'hui

---

## 5. Edge Functions

### Structure

```
supabase/functions/
├── _shared/
│   ├── fcm.ts          # sendFcmNotification(tokens[], title, body, data?)
│   └── db.ts           # getTokensForUsers(userIds[])
├── notify-run-started/
│   └── index.ts
├── notify-live-interaction/
│   └── index.ts
├── notify-challenge-event/
│   └── index.ts        # couvre group_challenges ET duels
├── notify-friendship/
│   └── index.ts
└── notify-reminder/
    └── index.ts        # déclenché par pg_cron
```

### `_shared/fcm.ts`
Appel à FCM REST API v1 :
```
POST https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send
Authorization: Bearer {OAuth2 token depuis Google service account}
```
Le service account JSON est stocké dans les **Supabase Secrets** (`FCM_SERVICE_ACCOUNT`).

### Database Webhooks

| Webhook | Table | Event(s) | Edge Function |
|---------|-------|----------|---------------|
| `run_started` | `run_sessions` | INSERT | `notify-run-started` |
| `live_interaction` | `run_interactions` | INSERT | `notify-live-interaction` |
| `challenge_event` | `group_challenges` | INSERT | `notify-challenge-event` |
| `duel_event` | `duels` | INSERT, UPDATE | `notify-challenge-event` |
| `friendship_accepted` | `friendships` | UPDATE | `notify-friendship` |

### Cron rappel (`notify-reminder`)
- Planifié via `pg_cron` : tous les jours à **18h00 UTC**
- Sélectionne les `user_id` sans `run_sessions` aujourd'hui + ayant un token enregistré
- Extensible : heure configurable par user dans `profiles` (future itération)

---

## 6. Configuration Firebase requise

1. Créer un projet Firebase → activer Cloud Messaging
2. Ajouter l'app iOS → télécharger `GoogleService-Info.plist` → placer dans `ios/Runner/`
3. Activer APNs dans Firebase : uploader le certificat `.p8` depuis Apple Developer Console
4. Créer un Service Account Firebase → télécharger le JSON → stocker dans Supabase Secrets

---

## 7. Nouveaux packages Flutter

```yaml
dependencies:
  firebase_core: ^3.x
  firebase_messaging: ^15.x
  flutter_local_notifications: ^18.x
```

---

## 8. Fichiers à créer / modifier

**Nouveaux :**
- `lib/features/notifications/notification_setup_service.dart`
- `lib/features/notifications/notification_handler.dart` (routing sur tap)
- `supabase/functions/_shared/fcm.ts`
- `supabase/functions/_shared/db.ts`
- `supabase/functions/notify-run-started/index.ts`
- `supabase/functions/notify-live-interaction/index.ts`
- `supabase/functions/notify-challenge-event/index.ts`
- `supabase/functions/notify-friendship/index.ts`
- `supabase/functions/notify-reminder/index.ts`
- Migration SQL : `device_tokens` table + RLS + `pg_cron` job

**Modifiés :**
- `pubspec.yaml` — ajout des 3 packages
- `lib/app.dart` — appel `NotificationSetupService` au démarrage
- `ios/Runner/AppDelegate.swift` — initialisation Firebase
- `ios/Runner/Info.plist` — permission notifications
