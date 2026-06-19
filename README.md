# Kwizz

App de quiz iOS native (SwiftUI), arcade-minimal. Sept modes de jeu, score façon
arcade, économie de pièces équilibrée, progression XP sur 20 niveaux, avatar
personnalisable. Construite selon `PLAN.md`, design d'après `mockups/prototype.html`.

## Lancer l'app

1. Ouvre **`Kwizz.xcodeproj`** dans Xcode (16 ou plus récent).
2. Choisis un simulateur iPhone (iOS 17+).
3. **Cmd+R** pour lancer.

> Le projet utilise les *synchronized file groups* d'Xcode 16 : tout fichier ajouté
> dans `App/`, `Sources/KwizzCore/` ou `Resources/` est inclus automatiquement, sans
> manipulation dans Xcode.

### Si le projet ne s'ouvre pas (secours)
Le `project.pbxproj` a été écrit à la main (aucun Xcode n'était disponible sur la
machine de build). En cas de souci : crée un nouveau projet *App* SwiftUI nommé
`Kwizz`, puis glisse les dossiers `App/`, `Sources/KwizzCore/` et `Resources/`
dedans (cible l'app), règle `IPHONEOS_DEPLOYMENT_TARGET = 17.0`. Tout le code est
prêt, c'est juste l'enveloppe projet.

## Architecture

Séparation nette entre **logique pure** et **UI** :

- **`Sources/KwizzCore/`** — Swift pur, sans SwiftUI/UIKit. Toute la logique de jeu :
  scoring arcade, économie par mode, courbe d'XP/niveaux, défi du jour déterministe,
  banque de questions, profil joueur. **Testable sur n'importe quelle plateforme.**
- **`App/`** — la couche SwiftUI (compilée dans le même module que le noyau par Xcode) :
  - `DesignSystem/` — `Theme` (palette + accent + polices), composants réutilisables,
    avatar `MannequinView`.
  - `Navigation/` — `Router` + `Route` + `RootView` (TabView à 5 onglets, `NavigationStack`,
    cover de jeu plein écran).
  - `PlayerStore` — état observable (`@Observable`), persistance disque JSON, application
    des résultats (pièces, XP, niveaux, records, défi quotidien).
  - `GameController` — pilote une partie : chrono fluide (une `Task` async + animation
    SwiftUI, pas de churn par frame), bot de duel, haptique.
  - `Features/` — un dossier par écran (18 écrans).

Pourquoi ce découpage : la partie qui doit être **correcte et équilibrée** (économie,
score, XP) est isolée et **vérifiée par des tests**, indépendamment de l'UI.

## Vérifier la logique du noyau

Deux façons :

```bash
# 1) Sans Xcode, depuis la racine du repo (75 assertions) :
swift run KwizzCoreCheck

# 2) Dans Xcode : la cible de tests Swift Testing (Tests/KwizzCoreTests) tourne avec Cmd+U.
```

Le runner `KwizzCoreCheck` couvre : table des 20 niveaux (~239 000 XP au total),
scoring arcade (100 + bonus vitesse), gains de pièces par mode, cap quotidien du mode
Libre, plancher du portefeuille (Duel), session de quiz, défi du jour déterministe,
banque de questions. **Statut actuel : 75/75.**

## Ce qui est implémenté (MVP)

- **7 modes** : Classique (15 questions, meilleur score), Contre-la-montre (60 s),
  Survie (mort subite), Marathon (30+), Libre (sans chrono), Duel (vs bot),
  Défi du jour (grille locale déterministe).
- **3 difficultés** (×1 / ×1,5 / ×2,5 sur les gains, temps 20/15/10 s).
- **Score arcade** : 100 par bonne réponse + jusqu'à +100 de bonus de vitesse.
- **Économie serrée** (pièces uniquement) + **XP durcie** (niveau 1 → 20).
- **Avatar central** sur l'accueil (silhouette + ombre, placeholder), **boutique** et
  **vestiaire** cosmétiques, **classement local** (démo), **profil**, **succès**, **réglages**.
- **Personnalisation de l'accent** (vert / ambre / cyan / mono) dans les réglages.
- Persistance locale (profil, pièces, items, records, séries).

## Limites connues / suite

- Tout le code (noyau + SwiftUI) **type-check sans erreur** contre le SDK iOS 26.5
  Simulator (`swiftc -typecheck`), et le **noyau** est couvert par 75 tests. Pour
  *lancer* l'app il faut installer le **runtime du simulateur iOS** (Xcode → Settings →
  Components), pas encore présent sur la machine.
- Avatars et items sont des **placeholders** (visuels à créer plus tard).
- Classement, Duel PvP réel et synchronisation du Défi → **phase 2** (backend).

## Structure

```
Kwizz/
├── Kwizz.xcodeproj/          # projet app (synchronized groups)
├── App/                      # SwiftUI : DesignSystem, Navigation, PlayerStore, GameController, Features/
├── Sources/KwizzCore/        # logique pure (testée)
├── Tests/KwizzCoreTests/     # Swift Testing (Xcode)
├── Dev/Check/                # runner de vérif CLI (swift run KwizzCoreCheck)
├── Resources/                # questions.json, Fonts/, Assets.xcassets
├── docs/BUILD_CONTRACT.md    # contrat d'API utilisé pour générer les vues
├── PLAN.md                   # plan produit
└── mockups/                  # maquettes HTML (référence design)
```
