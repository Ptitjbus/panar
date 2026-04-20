# Firebase A/B Testing (Panar)

Ce document décrit l’instrumentation en place pour les tests utilisateurs via
Firebase Remote Config + Firebase A/B Testing.

## Ce qui est en place dans le code

- Remote Config initialisé au démarrage de l’app.
- Analytics activé avec:
  - tracking d’exposition (`ab_exposure`)
  - tracking de funnels (`funnel_step`)
  - tracking d’actions génériques (`feature_click`)
  - `userId` synchronisé avec l’utilisateur connecté.
- Toutes les expériences ont une valeur par défaut `control`.

## Clés Remote Config (expériences)

- `exp_onboarding_variant_v1`
- `exp_peton_customization_variant_v1`
- `exp_run_launch_live_variant_v1`
- `exp_interactive_map_duel_variant_v1`
- `exp_challenge_creation_variant_v1`
- `exp_stats_consultation_variant_v1`
- `exp_shop_engagement_variant_v1`

## Événements instrumentés (principaux)

- Onboarding:
  - `funnel_step` avec `funnel=onboarding`
  - steps: `onboarding_opened`, `username_setup_opened`, `wizard_completed`, permissions, etc.
- Personnalisation peton:
  - `funnel_step` avec `funnel=peton_customization`
  - steps: `peton_name_confirmed`, `avatar_color_selected`, `avatar_color_confirmed`, `edit_avatar_saved`
- Lancement course + live:
  - `funnel_step` avec `funnel=run_launch` / `funnel=live_interaction`
  - steps: `open_run_launch`, `start_free_run_tapped`, `run_completed`, `friend_live_run_opened`, `interaction_sent`
- Carte interactive (défi/duel):
  - `funnel_step` avec `funnel=interactive_map`
  - steps: `challenge_friend_from_map`, `open_friend_search`
- Création de défi:
  - `funnel_step` avec `funnel=challenge_creation`
  - steps: `create_duel_opened`, `step_validated`, `duel_created`, `create_group_challenge_opened`, `group_challenge_created`
- Consultation stats:
  - `funnel_step` avec `funnel=run_stats`
  - steps: `view_stats_tapped`, `stats_page_opened`, `stats_tab_switched`
- Boutique:
  - `funnel_step` avec `funnel=shop`
  - steps: `shop_page_opened`, `shop_tab_selected`, `purchase_attempt`, `purchase_success`, `purchase_failed`

## Procédure Firebase Console (par expérience)

1. Ouvrir **Firebase Console** > **Remote Config**.
2. Créer le paramètre (clé ci-dessus) avec valeur par défaut `control`.
3. Ouvrir **A/B Testing** > **Create experiment**.
4. Choisir un test Remote Config sur le paramètre voulu.
5. Ajouter les variantes (ex: `control`, `v1`, `v2`).
6. Définir le ciblage (plateforme, pays, version).
7. Définir l’objectif primaire avec l’event `funnel_step` + filtres sur
   `funnel`, `step`, et `variant`.
8. Lancer l’expérience.

## Vérification locale

- En DebugView Firebase Analytics, vérifier:
  - `ab_exposure` avec `experiment_key` + `variant`
  - `funnel_step` avec `funnel` + `step` + `variant`

## Fichiers concernés

- `lib/core/experiments/app_experiments.dart`
- `lib/core/services/remote_config_service.dart`
- `lib/core/services/analytics_service.dart`
- `lib/features/onboarding/presentation/pages/onboarding_page.dart`
- `lib/features/auth/presentation/pages/username_setup_page.dart`
- `lib/features/profile/presentation/pages/edit_avatar_page.dart`
- `lib/features/run/presentation/pages/run_launch_page.dart`
- `lib/features/run/presentation/pages/run_tracking_page.dart`
- `lib/features/live_interactions/presentation/pages/friend_live_run_page.dart`
- `lib/features/home/presentation/pages/place_screen.dart`
- `lib/features/challenges/presentation/pages/create_duel_page.dart`
- `lib/features/challenges/presentation/pages/create_group_challenge_page.dart`
- `lib/features/run/presentation/pages/run_reward_page.dart`
- `lib/features/run/presentation/pages/run_stats_page.dart`
- `lib/features/shop/presentation/pages/shop_page.dart`
