# Firebase A/B Testing (Panar)

Ce document explique comment utiliser l'infra A/B déjà branchée dans l'app Flutter.

## Ce qui est en place dans le code

- Remote Config initialisé au démarrage de l'app.
- Analytics activé avec:
  - tracking d'exposition d'expérience (`ab_exposure`)
  - tracking de clic feature (`feature_click`)
  - `userId` synchronisé avec l'utilisateur connecté.
- Première expérience branchée:
  - clé Remote Config: `exp_duels_cta_variant_v1`
  - variants supportés côté app:
    - `control` (défaut): `Nouveau duel`
    - `icon_only`: `Créer`
    - `challenge_now`: `Défier maintenant`

## Étapes Firebase Console

1. Ouvrir **Firebase Console** > votre projet > **Remote Config**.
2. Créer le paramètre `exp_duels_cta_variant_v1` avec valeur par défaut `control`.
3. Ouvrir **A/B Testing** > **Create experiment**.
4. Choisir Remote Config experiment sur le paramètre `exp_duels_cta_variant_v1`.
5. Ajouter les variantes (par ex. `icon_only`, `challenge_now`).
6. Définir le ciblage (plateforme, pays, version app, etc.).
7. Choisir les objectifs:
  - primaire: `feature_click` filtré sur `feature = open_create_duel`
  - secondaire: métriques business (ex: sessions, rétention, conversion duel créé).
8. Lancer l'expérience.

## Vérification locale

- Les fetchs Remote Config utilisent un intervalle mini de 1 heure.
- Pour tester rapidement, vous pouvez temporairement réduire `minimumFetchInterval`
  en local dans `RemoteConfigService`.
- Vérifier dans DebugView Firebase Analytics:
  - event `ab_exposure` avec `experiment_key` et `variant`
  - event `feature_click` avec `feature`, `variant`, `source`.

## Fichiers concernés

- `lib/core/services/remote_config_service.dart`
- `lib/core/services/analytics_service.dart`
- `lib/features/challenges/presentation/pages/duels_page.dart`
- `lib/app.dart`

