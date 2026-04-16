# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Envoyer des push notifications iOS hors-app pour tous les événements sociaux de Panar (course démarrée, interactions live, défis, duels, amis, rappels quotidiens).

**Architecture:** Firebase FCM reçoit les tokens iOS et délivre vers APNs. Des Supabase Edge Functions sont déclenchées par Database Webhooks sur chaque table concernée, récupèrent les tokens des destinataires depuis `device_tokens`, et appellent l'API FCM REST v1. Côté Flutter, `firebase_messaging` + `flutter_local_notifications` gèrent la réception et l'affichage.

**Tech Stack:** `firebase_messaging ^15.x`, `flutter_local_notifications ^18.x`, `firebase_core ^3.x`, Supabase Edge Functions (Deno/TypeScript), FCM REST API v1, pg_cron.

---

## Prérequis manuels — À faire AVANT toute tâche de code

Ces étapes nécessitent un accès aux consoles Firebase et Apple Developer.

- [ ] **Firebase Console** → Créer un projet (ou utiliser un existant) → activer "Cloud Messaging"
- [ ] **Firebase Console** → "Project settings" → "General" → "Your apps" → Ajouter une app iOS (bundle ID : celui de `ios/Runner.xcodeproj`) → Télécharger `GoogleService-Info.plist`
- [ ] **Placer** `GoogleService-Info.plist` dans `ios/Runner/` (à côté de `Info.plist`)
- [ ] **Apple Developer Console** → "Certificates, Identifiers & Profiles" → "Keys" → Créer une clé APNs (type: Apple Push Notifications service) → Télécharger le fichier `.p8`, noter le Key ID et Team ID
- [ ] **Firebase Console** → "Project settings" → "Cloud Messaging" → "Apple app configuration" → Uploader le `.p8`, renseigner Key ID et Team ID
- [ ] **Firebase Console** → "Project settings" → "Service accounts" → "Generate new private key" → Télécharger le JSON du service account
- [ ] **Supabase Dashboard** → "Settings" → "Edge Functions" → "Secrets" → Ajouter le secret `FCM_SERVICE_ACCOUNT` avec le contenu JSON du service account (en une seule ligne)

---

## Task 1 : Migration DB — table `device_tokens` + pg_cron

**Files:**
- Migration Supabase (via MCP `apply_migration`)

- [ ] **Step 1 : Appliquer la migration**

Via MCP `mcp__supabase__apply_migration` avec le nom `add_device_tokens_and_cron` et la requête suivante :

```sql
-- Table device_tokens
CREATE TABLE device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token   text NOT NULL,
  platform    text NOT NULL DEFAULT 'ios',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, fcm_token)
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY dt_select ON device_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY dt_insert ON device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY dt_update ON device_tokens FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY dt_delete ON device_tokens FOR DELETE USING (auth.uid() = user_id);

-- Index for lookups by user
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

-- pg_cron: planifier le rappel quotidien à 18h UTC
-- Le cron appelle notify-reminder via pg_net (le project_ref et service_role_key seront renseignés manuellement)
-- NOTE: exécuter la commande cron séparément après avoir déployé la fonction notify-reminder (Task 13)
```

- [ ] **Step 2 : Vérifier la table**

Via MCP `execute_sql` :
```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'device_tokens' ORDER BY ordinal_position;
```
Résultat attendu : 7 colonnes (id, user_id, fcm_token, platform, created_at, updated_at + contrainte unique).

- [ ] **Step 3 : Commit**
```bash
git add -A
git commit -m "feat: add device_tokens table with RLS"
```

---

## Task 2 : Flutter — Ajouter les packages

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1 : Ajouter les dépendances dans `pubspec.yaml`**

Dans la section `dependencies`, après `path_provider: ^2.1.4`, ajouter :
```yaml
  firebase_core: ^3.13.0
  firebase_messaging: ^15.2.5
  flutter_local_notifications: ^18.0.1
```

- [ ] **Step 2 : Installer**
```bash
flutter pub get
```
Attendu : pas d'erreur, les packages se téléchargent.

- [ ] **Step 3 : Commit**
```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add firebase_core, firebase_messaging, flutter_local_notifications"
```

---

## Task 3 : iOS — Configuration native

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1 : Mettre à jour `AppDelegate.swift`**

Remplacer le contenu par :
```swift
import Flutter
import UIKit
import flutter_foreground_task
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    FlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

- [ ] **Step 2 : Ajouter `remote-notification` aux background modes dans `Info.plist`**

Dans la clé `UIBackgroundModes` (qui contient déjà `location` et `fetch`), ajouter :
```xml
<string>remote-notification</string>
```

Le bloc complet doit être :
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

- [ ] **Step 3 : Vérifier que le build compile**
```bash
flutter build ios --simulator --no-codesign 2>&1 | tail -5
```
Attendu : `Build complete.` (pas d'erreur de compilation Swift).

- [ ] **Step 4 : Commit**
```bash
git add ios/Runner/AppDelegate.swift ios/Runner/Info.plist
git commit -m "feat(ios): configure Firebase and remote-notification background mode"
```

---

## Task 4 : Flutter — NotificationSetupService

**Files:**
- Create: `lib/features/notifications/notification_setup_service.dart`

- [ ] **Step 1 : Créer le fichier**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kPermissionDeniedKey = 'notification_permission_denied';

/// Initialise Firebase Messaging, demande la permission iOS, enregistre le token
/// dans device_tokens, et configure l'affichage foreground.
class NotificationSetupService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _initLocalNotifications();

    final prefs = await SharedPreferences.getInstance();
    final alreadyDenied = prefs.getBool(_kPermissionDeniedKey) ?? false;

    if (!alreadyDenied) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await prefs.setBool(_kPermissionDeniedKey, true);
        return;
      }
    } else {
      return;
    }

    await _registerToken();

    FirebaseMessaging.instance.onTokenRefresh.listen(_upsertToken);

    // Afficher les notifications en foreground
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  static Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(initSettings);
  }

  static Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _upsertToken(token);
  }

  static Future<void> _upsertToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert(
        {'user_id': userId, 'fcm_token': token, 'platform': 'ios', 'updated_at': DateTime.now().toIso8601String()},
        onConflict: 'user_id,fcm_token',
      );
      debugPrint('[Notifications] Token enregistré');
    } catch (e) {
      debugPrint('[Notifications] Erreur upsert token: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const notifDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notifDetails,
    );
  }
}
```

- [ ] **Step 2 : Vérifier l'analyse**
```bash
flutter analyze lib/features/notifications/notification_setup_service.dart
```
Attendu : `No issues found!`

- [ ] **Step 3 : Commit**
```bash
git add lib/features/notifications/notification_setup_service.dart
git commit -m "feat: add NotificationSetupService (token registration + foreground display)"
```

---

## Task 5 : Flutter — NotificationHandler (routing au tap)

**Files:**
- Create: `lib/features/notifications/notification_handler.dart`

- [ ] **Step 1 : Créer le fichier**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../core/constants/route_constants.dart';

/// Gère la navigation lorsque l'utilisateur tape sur une notification.
class NotificationHandler {
  static void initialize(Ref ref) {
    // App en arrière-plan → tap sur la notif
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _route(ref, message.data);
    });

    // App terminée → tap sur la notif au démarrage
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _route(ref, message.data);
    });
  }

  static void _route(Ref ref, Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final type = data['type'] as String?;

    switch (type) {
      case 'run_started':
        router.push(Routes.friendLiveRun, extra: {
          'sessionId': data['session_id'] as String? ?? '',
          'runnerId': data['runner_id'] as String? ?? '',
          'runnerName': '',
        });
      case 'duel_invite':
      case 'duel_result':
        final duelId = data['duel_id'] as String?;
        if (duelId != null) router.push('/challenges/duels/$duelId');
      case 'group_challenge_invite':
      case 'group_challenge_completed':
        final challengeId = data['challenge_id'] as String?;
        if (challengeId != null) router.push('/challenges/group/$challengeId');
      default:
        router.go(Routes.home);
    }
  }
}
```

- [ ] **Step 2 : Vérifier l'analyse**
```bash
flutter analyze lib/features/notifications/notification_handler.dart
```
Attendu : `No issues found!`

- [ ] **Step 3 : Commit**
```bash
git add lib/features/notifications/notification_handler.dart
git commit -m "feat: add NotificationHandler for notification tap routing"
```

---

## Task 6 : Flutter — Brancher sur app.dart + main.dart

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1 : Initialiser Firebase dans `main.dart`**

Dans `lib/main.dart`, ajouter l'import :
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
```

Dans `main()`, avant `await dotenv.load(...)`, ajouter :
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

> **Note :** `firebase_options.dart` est généré par `flutterfire configure` (voir Step 2).

- [ ] **Step 2 : Générer `firebase_options.dart`**

Installer FlutterFire CLI si nécessaire :
```bash
dart pub global activate flutterfire_cli
```
Puis lancer (nécessite d'être connecté à Firebase via `firebase login`) :
```bash
flutterfire configure
```
Sélectionner le projet Firebase créé dans les prérequis. Cela génère `lib/firebase_options.dart`.

- [ ] **Step 3 : Appeler NotificationSetupService et NotificationHandler dans `MyApp`**

Dans `lib/app.dart`, ajouter les imports :
```dart
import 'features/notifications/notification_setup_service.dart';
import 'features/notifications/notification_handler.dart';
```

Dans `MyApp.build`, ajouter un `ref.listen` sur `authStateProvider` pour déclencher le setup quand l'utilisateur se connecte. Modifier la méthode `build` :

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final router = ref.watch(routerProvider);

  // Initialiser les notifications dès que l'utilisateur est connecté
  ref.listen(authStateProvider, (previous, next) {
    final wasLoggedIn = previous?.valueOrNull != null;
    final isLoggedIn = next.valueOrNull != null;
    if (!wasLoggedIn && isLoggedIn) {
      NotificationSetupService.initialize();
      NotificationHandler.initialize(ref);
    }
  });

  return MaterialApp.router(
    title: 'Panar',
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    routerConfig: router,
    debugShowCheckedModeBanner: false,
  );
}
```

- [ ] **Step 4 : Vérifier l'analyse**
```bash
flutter analyze lib/main.dart lib/app.dart
```
Attendu : `No issues found!`

- [ ] **Step 5 : Tester sur device physique**

Lancer sur iPhone :
```bash
flutter run
```
Se connecter → vérifier dans les logs :
```
[Notifications] Token enregistré
```
Vérifier dans Supabase (table `device_tokens`) qu'une ligne est créée pour l'utilisateur.

- [ ] **Step 6 : Commit**
```bash
git add lib/main.dart lib/app.dart lib/firebase_options.dart
git commit -m "feat: initialize Firebase and wire NotificationSetupService on auth"
```

---

## Task 7 : Edge Functions — utilitaires partagés `_shared/`

**Files:**
- Create: `supabase/functions/_shared/fcm.ts`
- Create: `supabase/functions/_shared/db.ts`

- [ ] **Step 1 : Créer `supabase/functions/_shared/fcm.ts`**

```typescript
interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64url(data: string | Uint8Array): string {
  const bytes =
    typeof data === "string" ? new TextEncoder().encode(data) : data;
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );
  const signingInput = `${header}.${payload}`;

  const pemContents = sa.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) =>
    c.charCodeAt(0)
  );
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBytes = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signingInput)
  );
  const signature = base64url(new Uint8Array(signatureBytes));
  const jwt = `${signingInput}.${signature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  return json.access_token as string;
}

export async function sendFcmNotification(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  if (tokens.length === 0) return;

  const sa: ServiceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  const accessToken = await getAccessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  await Promise.all(
    tokens.map((token) =>
      fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
            data,
          },
        }),
      })
    )
  );
}
```

- [ ] **Step 2 : Créer `supabase/functions/_shared/db.ts`**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function serviceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
}

export async function getTokensForUsers(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];
  const { data } = await serviceClient()
    .from("device_tokens")
    .select("fcm_token")
    .in("user_id", userIds);
  return (data ?? []).map((r: { fcm_token: string }) => r.fcm_token);
}

export async function getUsernameById(userId: string): Promise<string> {
  const { data } = await serviceClient()
    .from("profiles")
    .select("username")
    .eq("id", userId)
    .single();
  return (data?.username as string | null) ?? "Quelqu'un";
}

export async function getFriendIds(userId: string): Promise<string[]> {
  const { data } = await serviceClient()
    .from("friendships")
    .select("requester_id, addressee_id")
    .or(`requester_id.eq.${userId},addressee_id.eq.${userId}`)
    .eq("status", "accepted");
  if (!data) return [];
  return data.map((f: { requester_id: string; addressee_id: string }) =>
    f.requester_id === userId ? f.addressee_id : f.requester_id
  );
}

export { serviceClient };
```

- [ ] **Step 3 : Commit**
```bash
git add supabase/
git commit -m "feat: add Edge Functions shared utilities (fcm.ts, db.ts)"
```

---

## Task 8 : Edge Function — `notify-run-started`

**Files:**
- Create: `supabase/functions/notify-run-started/index.ts`

- [ ] **Step 1 : Créer le fichier**

```typescript
import { sendFcmNotification } from "../_shared/fcm.ts";
import {
  getTokensForUsers,
  getUsernameById,
  getFriendIds,
} from "../_shared/db.ts";

// Déclenché sur INSERT dans run_sessions
Deno.serve(async (req) => {
  const { record } = await req.json();
  // record: { id, user_id, status, ... }

  // N'envoyer que quand la session devient active
  if (record.status !== "active") return new Response("skipped");

  const [runnerName, friendIds] = await Promise.all([
    getUsernameById(record.user_id),
    getFriendIds(record.user_id),
  ]);

  const tokens = await getTokensForUsers(friendIds);

  await sendFcmNotification(
    tokens,
    `🏃 ${runnerName} court !`,
    "Va le supporter en direct sur Panar",
    {
      type: "run_started",
      session_id: record.id,
      runner_id: record.user_id,
    }
  );

  return new Response("ok");
});
```

- [ ] **Step 2 : Déployer via MCP**

Via `mcp__supabase__deploy_edge_function` avec `name: "notify-run-started"` et le contenu ci-dessus.

- [ ] **Step 3 : Commit**
```bash
git add supabase/functions/notify-run-started/
git commit -m "feat: add notify-run-started edge function"
```

---

## Task 9 : Edge Function — `notify-live-interaction`

**Files:**
- Create: `supabase/functions/notify-live-interaction/index.ts`

- [ ] **Step 1 : Créer le fichier**

```typescript
import { sendFcmNotification } from "../_shared/fcm.ts";
import {
  getTokensForUsers,
  getUsernameById,
  serviceClient,
} from "../_shared/db.ts";

const DEDUP_SECONDS = 30;

// Déclenché sur INSERT dans run_interactions
Deno.serve(async (req) => {
  const { record } = await req.json();
  // record: { id, session_id, sender_id, runner_id, type, content, audio_url, created_at }

  // Déduplication : max 1 push/30s par runner
  const cutoff = new Date(Date.now() - DEDUP_SECONDS * 1000).toISOString();
  const { data: recent } = await serviceClient()
    .from("run_interactions")
    .select("id")
    .eq("runner_id", record.runner_id)
    .gt("created_at", cutoff)
    .neq("id", record.id)
    .limit(1);

  if (recent && recent.length > 0) return new Response("dedup");

  const senderName = await getUsernameById(record.sender_id);
  const tokens = await getTokensForUsers([record.runner_id]);

  const isVoice = record.type === "voice_message";
  const title = isVoice
    ? `🎤 ${senderName} t'a envoyé un vocal`
    : `💪 ${senderName} t'encourage !`;
  const body = isVoice
    ? "Écoute-le pendant ta course"
    : (record.content as string | null) ?? "Continue, t'es le meilleur !";

  await sendFcmNotification(tokens, title, body, {
    type: record.type,
    session_id: record.session_id,
  });

  return new Response("ok");
});
```

- [ ] **Step 2 : Déployer via MCP**

Via `mcp__supabase__deploy_edge_function` avec `name: "notify-live-interaction"`.

- [ ] **Step 3 : Commit**
```bash
git add supabase/functions/notify-live-interaction/
git commit -m "feat: add notify-live-interaction edge function with 30s dedup"
```

---

## Task 10 : Edge Function — `notify-challenge-event`

**Files:**
- Create: `supabase/functions/notify-challenge-event/index.ts`

- [ ] **Step 1 : Créer le fichier**

```typescript
import { sendFcmNotification } from "../_shared/fcm.ts";
import {
  getTokensForUsers,
  getUsernameById,
  serviceClient,
} from "../_shared/db.ts";

// Déclenché sur INSERT/UPDATE dans group_challenges ET duels
Deno.serve(async (req) => {
  const { record, old_record, table } = await req.json();

  if (table === "duels") {
    await handleDuel(record, old_record);
  } else if (table === "group_challenges") {
    await handleGroupChallenge(record, old_record);
  }

  return new Response("ok");
});

async function handleDuel(record: Record<string, unknown>, oldRecord: Record<string, unknown> | null) {
  const challengerId = record.challenger_id as string;
  const challengedId = record.challenged_id as string;
  const status = record.status as string;
  const winnerId = record.winner_id as string | null;

  // Nouveau duel → notifier le challenged
  if (!oldRecord) {
    const challengerName = await getUsernameById(challengerId);
    const tokens = await getTokensForUsers([challengedId]);
    await sendFcmNotification(
      tokens,
      `⚔️ ${challengerName} te défie !`,
      "Accepte le duel et prouve ce que tu vaux",
      { type: "duel_invite", duel_id: record.id as string }
    );
    return;
  }

  // Duel terminé → notifier gagnant et perdant
  const oldStatus = oldRecord.status as string;
  if (oldStatus !== "completed" && status === "completed" && winnerId) {
    const loserId = challengerId === winnerId ? challengedId : challengerId;
    const [winnerName, loserName, winnerTokens, loserTokens] =
      await Promise.all([
        getUsernameById(winnerId),
        getUsernameById(loserId),
        getTokensForUsers([winnerId]),
        getTokensForUsers([loserId]),
      ]);

    await Promise.all([
      sendFcmNotification(
        winnerTokens,
        "🥇 Tu as gagné le duel !",
        `Tu as battu ${loserName}`,
        { type: "duel_result", duel_id: record.id as string, result: "win" }
      ),
      sendFcmNotification(
        loserTokens,
        "💀 Duel perdu",
        `${winnerName} t'a battu cette fois`,
        { type: "duel_result", duel_id: record.id as string, result: "loss" }
      ),
    ]);
  }
}

async function handleGroupChallenge(record: Record<string, unknown>, oldRecord: Record<string, unknown> | null) {
  const challengeId = record.id as string;
  const creatorId = record.creator_id as string;
  const status = record.status as string;

  // Nouveau défi → notifier les participants (sauf le créateur)
  if (!oldRecord) {
    const { data: participants } = await serviceClient()
      .from("group_challenge_participants")
      .select("user_id")
      .eq("challenge_id", challengeId)
      .neq("user_id", creatorId);

    const participantIds = (participants ?? []).map(
      (p: { user_id: string }) => p.user_id
    );
    const [creatorName, tokens] = await Promise.all([
      getUsernameById(creatorId),
      getTokensForUsers(participantIds),
    ]);

    await sendFcmNotification(
      tokens,
      `🏆 ${creatorName} t'invite à un défi`,
      record.title as string,
      { type: "group_challenge_invite", challenge_id: challengeId }
    );
    return;
  }

  // Défi terminé → trouver le gagnant (max total_distance_meters) et notifier tous
  const oldStatus = oldRecord.status as string;
  if (oldStatus !== "completed" && status === "completed") {
    const { data: participants } = await serviceClient()
      .from("group_challenge_participants")
      .select("user_id, total_distance_meters")
      .eq("challenge_id", challengeId);

    if (!participants || participants.length === 0) return;

    const winner = participants.reduce(
      (best: { user_id: string; total_distance_meters: number }, p: { user_id: string; total_distance_meters: number }) =>
        p.total_distance_meters > best.total_distance_meters ? p : best
    );

    const [winnerName, allTokens] = await Promise.all([
      getUsernameById(winner.user_id),
      getTokensForUsers(participants.map((p: { user_id: string }) => p.user_id)),
    ]);

    await sendFcmNotification(
      allTokens,
      "🏁 Défi terminé !",
      `${winnerName} a gagné le défi ${record.title as string}`,
      { type: "group_challenge_completed", challenge_id: challengeId }
    );
  }
}
```

- [ ] **Step 2 : Déployer via MCP**

Via `mcp__supabase__deploy_edge_function` avec `name: "notify-challenge-event"`.

- [ ] **Step 3 : Commit**
```bash
git add supabase/functions/notify-challenge-event/
git commit -m "feat: add notify-challenge-event edge function (duels + group challenges)"
```

---

## Task 11 : Edge Function — `notify-friendship`

**Files:**
- Create: `supabase/functions/notify-friendship/index.ts`

- [ ] **Step 1 : Créer le fichier**

```typescript
import { sendFcmNotification } from "../_shared/fcm.ts";
import { getTokensForUsers, getUsernameById } from "../_shared/db.ts";

// Déclenché sur UPDATE dans friendships
Deno.serve(async (req) => {
  const { record, old_record } = await req.json();
  // record: { id, requester_id, addressee_id, status, ... }

  // Notifier uniquement quand le status passe à 'accepted'
  if (old_record?.status === "accepted" || record.status !== "accepted") {
    return new Response("skipped");
  }

  const addresseeName = await getUsernameById(record.addressee_id);
  const tokens = await getTokensForUsers([record.requester_id]);

  await sendFcmNotification(
    tokens,
    `✅ ${addresseeName} a accepté ta demande`,
    "Vous êtes maintenant amis sur Panar",
    { type: "friendship_accepted" }
  );

  return new Response("ok");
});
```

- [ ] **Step 2 : Déployer via MCP**

Via `mcp__supabase__deploy_edge_function` avec `name: "notify-friendship"`.

- [ ] **Step 3 : Commit**
```bash
git add supabase/functions/notify-friendship/
git commit -m "feat: add notify-friendship edge function"
```

---

## Task 12 : Edge Function — `notify-reminder` + cron

**Files:**
- Create: `supabase/functions/notify-reminder/index.ts`

- [ ] **Step 1 : Créer le fichier**

```typescript
import { sendFcmNotification } from "../_shared/fcm.ts";
import { serviceClient } from "../_shared/db.ts";

// Déclenché par pg_cron tous les jours à 18h UTC
Deno.serve(async (_req) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayIso = today.toISOString();

  // Trouver les users qui ont un token ET n'ont pas couru aujourd'hui
  const { data: tokens } = await serviceClient()
    .from("device_tokens")
    .select("user_id, fcm_token");

  if (!tokens || tokens.length === 0) return new Response("no tokens");

  const userIds = [...new Set(tokens.map((t: { user_id: string }) => t.user_id))];

  // Récupérer les users ayant couru aujourd'hui
  const { data: runnersToday } = await serviceClient()
    .from("run_sessions")
    .select("user_id")
    .in("user_id", userIds)
    .gte("started_at", todayIso);

  const runnerIdSet = new Set(
    (runnersToday ?? []).map((r: { user_id: string }) => r.user_id)
  );

  // Garder uniquement les tokens des users n'ayant pas couru
  const eligibleTokens = tokens
    .filter((t: { user_id: string; fcm_token: string }) => !runnerIdSet.has(t.user_id))
    .map((t: { user_id: string; fcm_token: string }) => t.fcm_token);

  await sendFcmNotification(
    eligibleTokens,
    "👟 T'as pas couru aujourd'hui",
    "Enfile tes Panar et va courir !",
    { type: "reminder" }
  );

  return new Response(`ok: ${eligibleTokens.length} notified`);
});
```

- [ ] **Step 2 : Déployer via MCP**

Via `mcp__supabase__deploy_edge_function` avec `name: "notify-reminder"`.

- [ ] **Step 3 : Configurer le cron pg_cron**

Via `mcp__supabase__apply_migration` avec le nom `setup_reminder_cron` :

```sql
-- Remplacer <PROJECT_REF> par la ref de ton projet Supabase (ex: abcdefghijklm)
-- Remplacer <SERVICE_ROLE_KEY> par la clé service_role de ton projet
SELECT cron.schedule(
  'daily-reminder-notification',
  '0 18 * * *',
  $cron$
    SELECT net.http_post(
      url := 'https://<PROJECT_REF>.supabase.co/functions/v1/notify-reminder',
      headers := '{"Authorization": "Bearer <SERVICE_ROLE_KEY>", "Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    );
  $cron$
);
```

> **Note :** Remplacer `<PROJECT_REF>` et `<SERVICE_ROLE_KEY>` (disponibles dans Supabase Dashboard → Settings → API) avant d'exécuter.

- [ ] **Step 4 : Commit**
```bash
git add supabase/functions/notify-reminder/
git commit -m "feat: add notify-reminder edge function with daily cron"
```

---

## Task 13 : Supabase — Configurer les Database Webhooks

Ces 5 webhooks se configurent dans le **Supabase Dashboard → Database → Webhooks**.

Pour chaque webhook :
- **HTTP Method :** POST
- **HTTP Headers :** `Content-Type: application/json` + `Authorization: Bearer <SERVICE_ROLE_KEY>`

| Nom | Table | Events | URL |
|-----|-------|--------|-----|
| `run_started` | `run_sessions` | INSERT | `https://<PROJECT_REF>.supabase.co/functions/v1/notify-run-started` |
| `live_interaction` | `run_interactions` | INSERT | `https://<PROJECT_REF>.supabase.co/functions/v1/notify-live-interaction` |
| `challenge_group_event` | `group_challenges` | INSERT, UPDATE | `https://<PROJECT_REF>.supabase.co/functions/v1/notify-challenge-event` |
| `challenge_duel_event` | `duels` | INSERT, UPDATE | `https://<PROJECT_REF>.supabase.co/functions/v1/notify-challenge-event` |
| `friendship_event` | `friendships` | UPDATE | `https://<PROJECT_REF>.supabase.co/functions/v1/notify-friendship` |

- [ ] **Step 1 :** Créer le webhook `run_started`
- [ ] **Step 2 :** Créer le webhook `live_interaction`
- [ ] **Step 3 :** Créer le webhook `challenge_group_event`
- [ ] **Step 4 :** Créer le webhook `challenge_duel_event`
- [ ] **Step 5 :** Créer le webhook `friendship_event`

- [ ] **Step 6 : Commit final**
```bash
git add -A
git commit -m "feat: push notifications — complete implementation"
```

---

## Résumé des fichiers créés/modifiés

| Fichier | Action |
|---------|--------|
| `pubspec.yaml` | +3 packages Firebase |
| `lib/firebase_options.dart` | Généré par flutterfire CLI |
| `lib/main.dart` | Init Firebase |
| `lib/app.dart` | Setup notifications au login |
| `lib/features/notifications/notification_setup_service.dart` | Nouveau |
| `lib/features/notifications/notification_handler.dart` | Nouveau |
| `ios/Runner/AppDelegate.swift` | FirebaseApp.configure() |
| `ios/Runner/Info.plist` | remote-notification background mode |
| `ios/Runner/GoogleService-Info.plist` | Ajouté manuellement |
| `supabase/functions/_shared/fcm.ts` | Nouveau |
| `supabase/functions/_shared/db.ts` | Nouveau |
| `supabase/functions/notify-run-started/index.ts` | Nouveau |
| `supabase/functions/notify-live-interaction/index.ts` | Nouveau |
| `supabase/functions/notify-challenge-event/index.ts` | Nouveau |
| `supabase/functions/notify-friendship/index.ts` | Nouveau |
| `supabase/functions/notify-reminder/index.ts` | Nouveau |
