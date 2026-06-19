# Kwizz - Plan de conception

> Document de travail. Premier jet complet, destiné à être retravaillé ensemble.
> Statut : brouillon v0.1 - rien n'est figé.

---

## 0. Sommaire

1. [Vision & concept](#1-vision--concept)
2. [La boucle de jeu (game loop)](#2-la-boucle-de-jeu-game-loop)
3. [Modes de jeu](#3-modes-de-jeu)
4. [Niveaux de difficulté](#4-niveaux-de-difficulté)
5. [Système économique (les pièces)](#5-système-économique-les-pièces)
6. [Système d'XP et de niveaux (1 à 20)](#6-système-dxp-et-de-niveaux-1-à-20)
7. [Personnalisation de l'avatar](#7-personnalisation-de-lavatar)
8. [Systèmes de rétention](#8-systèmes-de-rétention)
9. [Catégories & sous-catégories](#9-catégories--sous-catégories)
10. [Carte des écrans & navigation](#10-carte-des-écrans--navigation)
11. [Architecture technique](#11-architecture-technique)
12. [Structure du projet](#12-structure-du-projet)
13. [Propositions de design](#13-propositions-de-design)
14. [Roadmap par phases](#14-roadmap-par-phases)
15. [Décisions à trancher ensemble](#15-décisions-à-trancher-ensemble)

---

## 1. Vision & concept

**Kwizz** est une app de quiz iOS native, ludique et addictive. L'idée n'est pas seulement de répondre à des questions : c'est de **progresser**, **s'enrichir** (en pièces virtuelles) et **se construire une identité** (avatar personnalisable, titre de niveau).

Trois piliers de plaisir :

- **Le défi** : des questions variées, plusieurs modes, trois niveaux de difficulté.
- **La récompense** : on gagne des pièces à chaque bonne réponse et à chaque victoire.
- **La progression** : un système d'XP qui fait monter de "Américain moyen" à "Émilien, Questions pour un champion", et un avatar qu'on enrichit avec ses gains.

Le ton est léger et drôle (les titres de niveaux, les célébrations de victoire, les animations). On vise une app qu'on lance pour "une partie rapide" et dont on a du mal à décrocher.

**Plateforme cible** : iOS natif (SwiftUI). iPhone d'abord, iPad ensuite.

---

## 2. La boucle de jeu (game loop)

La boucle courte (une session de 2 à 4 minutes) :

```
   ┌──────────────────────────────────────────────────────┐
   │                                                        │
   ▼                                                        │
[Accueil] → [Choix mode] → [Choix catégorie] → [Choix       │
                                                difficulté]  │
                                                    │        │
                                                    ▼        │
                                              [PARTIE]        │
                                          (série de questions)│
                                                    │        │
                                                    ▼        │
                                        [Écran de résultats]  │
                                   (pièces gagnées + XP gagné) │
                                                    │        │
                          ┌─────────────────────────┼────────┘
                          ▼                          ▼
                  [Montée de niveau ?]      [Rejouer / Boutique]
                  (animation + récompense)
```

La boucle longue (rétention sur plusieurs jours/semaines) :

```
Jouer → gagner pièces + XP → monter de niveau → débloquer titres & items
   → dépenser en boutique (avatar, jokers) → revenir pour le défi du jour
   → entretenir sa série quotidienne → grimper au classement → recommencer
```

L'objectif de design : **chaque partie doit donner une raison de lancer la suivante** (presque monté de niveau, série à entretenir, item presque acheté, défi du jour pas encore fait).

---

## 3. Modes de jeu

On distingue **le mode de jeu** (la façon de jouer) de **la difficulté** (voir section 4). Voici les modes proposés.

| Mode | Principe | Format | Récompense |
|------|----------|--------|------------|
| ⭐ **Classique** | 15 questions sur une catégorie. Score 1/0 par question + bonus vitesse. Objectif : meilleur score | 15 questions, 4 choix | Selon le score |
| ⭐ **Contre-la-montre** | Maximum de bonnes réponses en 60 secondes | Chrono global, enchaînement rapide | Bonus rapidité |
| ⭐ **Survie** | On enchaîne jusqu'à la première erreur | Mort subite, difficulté croissante | Multiplicateur de série élevé |
| ⭐ **Marathon** | Long format, toutes catégories mélangées | 30+ questions, paliers de gains | Paliers cumulatifs |
| ⭐ **Libre** | Questions en continu, sans chrono ni game over | Flux infini, on arrête quand on veut | Réduite (anti-farm) |
| ⭐ **Duel** | 1 contre 1, contre un bot pour commencer (joueurs réels en phase 2) | Mêmes questions, le plus rapide marque | Mise + gain du vainqueur |
| ⭐ **Défi du jour** | Une grille du jour générée localement, identique pour une date donnée | 1 tentative / jour | Grosse récompense |

⭐ = inclus dans le MVP.

**MVP (décidé)** : les **7 modes** sont dans le MVP. Classique, Contre-la-montre, Survie, Marathon et Libre tournent hors-ligne. Le **Duel** démarre en 1v1 contre un **bot** (le PvP temps réel entre joueurs viendra en phase 2). Le **Défi du jour** est **généré localement de façon déterministe** : une graine basée sur la date donne la même grille à tout le monde pour un jour donné, sans serveur. Le **classement mondial** du défi et la synchronisation serveur arrivent en phase 2. Le **Mode Libre** reste une zone détente/entraînement (pas de chrono ni de game over, gains réduits pour éviter le farm).

> Conséquence : le **Duel vs bot** et le **Défi du jour local** ne nécessitent **pas** de backend, donc ils tiennent dans un MVP hors-ligne. Seules les versions sociales (PvP réel, classement mondial du défi) attendent la phase 2.

### 3.1 Scoring du mode Classique

Le mode Classique est un **chasseur de meilleur score** (high score). Chaque question rapporte :

- **Point de justesse** : `1` si la réponse est bonne, `0` sinon.
- **Bonus de vitesse** : points supplémentaires proportionnels au temps restant, accordés **uniquement si la réponse est bonne** (de `0` à `+1,0` point : répondre vite rapporte presque le double, répondre à la dernière seconde rapporte juste le point de justesse).

```
Score d'une question = point de justesse (0 ou 1) + bonus de vitesse (0 → ~1)
Score de la partie   = somme des 15 questions       (max ≈ 30)
```

Le joueur cherche à **battre son record** (par catégorie et par difficulté) et à grimper au **classement**. Les **pièces** et l'**XP** gagnés sont ensuite dérivés de ce score, multiplié par le coefficient de difficulté (section 4). Le score sert donc à la fois de performance affichée (record, classement) et de base de récompense.

> Idée à débattre : un mode **Thématique / Événement** (ex : "Spécial Noël", "Spécial JO") qui tourne et rapporte des items exclusifs.

---

## 4. Niveaux de difficulté

Trois niveaux, choisis avant chaque partie (selon la catégorie et le mode). La difficulté agit sur **la complexité des questions**, **le temps de réponse** et surtout **les récompenses**.

| Difficulté | Questions | Temps / question | Multiplicateur de gains | Multiplicateur d'XP |
|------------|-----------|------------------|-------------------------|---------------------|
| 🟢 **Facile** | Grand public, évidentes | 20 s | × 1 | × 1 |
| 🟡 **Normal** | Demandent de la culture | 15 s | × 1,5 | × 1,5 |
| 🔴 **Difficile** | Pointues, pièges | 10 s | × 2,5 | × 2,5 |

Principe de design : le mode Difficile rapporte beaucoup plus, mais le risque d'erreur (donc de perdre la série et les bonus) est réel. Cela crée une vraie décision : jouer la sécurité ou viser gros.

> Option avancée (plus tard) : un 4e palier **Expert / Légende** débloqué à partir d'un certain niveau de joueur, avec des récompenses en gemmes.

---

## 5. Système économique (les pièces)

### 5.1 Les deux monnaies

| Monnaie | Symbole | Comment l'obtenir | À quoi ça sert |
|---------|---------|-------------------|----------------|
| **Pièces** | 🪙 | Bonnes réponses, victoires, défis, série quotidienne | Acheter les items d'avatar |
| **Gemmes** | 💎 | Rares : montées de niveau, gros paliers de série, succès (et achat réel plus tard) | Items premium et cosmétiques exclusifs |

> **Décidé : une seule monnaie (pièces) pour le MVP.** Les gemmes arriveront en phase 2 avec la monétisation. Les mentions de 💎 plus bas dans ce document concernent donc la phase 2.

### 5.2 Score (arcade) vs pièces

Deux choses distinctes, à ne pas confondre :

- Le **score** est une performance façon borne d'arcade, affichée en gros, qui sert aux **records** et au **classement**. Il ne s'achète pas, ne se dépense pas.
- Les **pièces** sont la **monnaie** : volontairement **rares**, gagnées en petite quantité, dépensées dans l'avatar et les jokers.

**Barème de score (mode Classique)** : chaque question vaut `100` points si la réponse est bonne (`0` sinon), plus un **bonus de vitesse** de `0` à `+100` selon le temps restant. Soit max `200` par question, donc **3 000** pour une partie parfaite de 15 questions. Les autres modes ont leur propre barème (série, paliers, etc.).

### 5.3 Gains de pièces par mode (équilibrage)

Les pièces sont **réduites** : un bon joueur gagne de l'ordre de **8 à 14 pièces par minute** sur les modes actifs. Objectif : qu'aucun mode ne devienne une « ferme à pièces » et que chaque achat reste un vrai objectif.

> Base commune : **1 pièce par bonne réponse**, multipliée par la difficulté (× 1 / × 1,5 / × 2,5). Les bonus ci-dessous s'ajoutent. Valeurs données en **Normal (× 1,5)**, arrondies.

| Mode | Comment on gagne | Gain moyen / partie | Durée ~ | Pièces / min | Plafond | Rôle dans l'éco |
|------|------------------|:-------------------:|:-------:|:------------:|:-------:|-----------------|
| **Classique** | 1 / bonne + 1 si rapide + 5 si partie parfaite | ~25 | 2,5 min | ~10 | ~50 | Référence régulière |
| **Contre-la-montre** | 1 / bonne (≈14 en 60 s) | ~21 | 1,5 min | ~14 | borné par les 60 s | Efficace mais plafonné par le temps |
| **Survie** | 1 / bonne + 1 par palier de 5 d'affilée | ~18 | 2 min | ~9 | illimité | Gros plafond, grosse variance (risque) |
| **Marathon** | 1 / bonne + 5 par palier de 10 | ~50 | 5 min | ~75 | ~75 | Endurance, peu de variance |
| **Duel (vs bot)** | mise 15, le vainqueur empoche 30 | +15 / -15 (≈ +3 en moyenne) | 2 min | ~1,5 | mise réglable | Compétition, pas du farm |
| **Défi du jour** | 30 (réussite) + jusqu'à +30 (score) + bonus de série quotidienne | ~50 | 1×/jour | burst | 1×/jour | Rendez-vous quotidien |
| **Libre** | **1 pièce / 10 bonnes réponses**, plafonné | ~5 | libre | ~1 | **20 / jour** | Entraînement, gains quasi nuls |

Lecture : les modes actifs convergent autour de **9 à 14 pièces/min**. Le **Libre** est volontairement quasi nul (anti-farm, comme décidé). Le **Duel** rapporte peu (c'est de la compétition), le **Défi** est un gros gain unique une fois par jour.

### 5.4 Comment on dépense des pièces

Les pièces servent **uniquement à la personnalisation de l'avatar** (cosmétique, voir section 7). Pas de jokers ni d'aides payantes en jeu : le skill prime, la monnaie ne touche jamais au gameplay.

Repères de prix des items (à affiner) : **commun** 50 à 150, **rare** 200 à 400, **épique** 500 à 900, **légendaire** 1 000+ (souvent débloqué par niveau ou succès plutôt qu'acheté).

### 5.5 Équilibrage & inflation

Avec ~600 pièces / heure de jeu actif : un item commun se gagne en ~10 min, un légendaire en plusieurs heures. Cela garde **chaque achat désirable**. Comme l'unique poste de dépense est l'avatar, il faut proposer assez de cosmétiques pour absorber les pièces gagnées. On tiendra ce tableau gains/heure vs prix à jour en remplissant la boutique.

---

## 6. Système d'XP et de niveaux (1 à 20)

### 6.1 Principe

On gagne de l'**XP** indépendamment des pièces (les pièces s'achètent/se dépensent, l'XP ne se dépense jamais : c'est la progression pure). L'XP fait monter du **niveau 1 au niveau 20**, chaque niveau ayant un **titre humoristique** affiché sur le profil et à côté du pseudo.

XP gagné : 5 (Facile) / 10 (Normal) / 20 (Difficile) par bonne réponse, plus un petit bonus de fin de partie. Chaque montée de niveau déclenche une **animation + une récompense** (pièces et, sur certains paliers, un item exclusif). La courbe est volontairement **exigeante** : atteindre le niveau 20 demande des dizaines d'heures de jeu (voir 6.3).

### 6.2 Les 20 titres (du nul au génie)

| Niveau | Titre | Vibe |
|:------:|-------|------|
| 1 | 🇺🇸 Américain moyen | Le point de départ, ne sait rien |
| 2 | Le pilier gauche | |
| 3 | Le mec au fond de la classe | |
| 4 | Roi du quiz de comptoir | |
| 5 | Bachelier (mention pas de mention) | Premier vrai palier |
| 6 | Pilier de PMU cultivé | |
| 7 | Le gars qui a appris toutes les capitales | |
| 8 | Tête de classe | |
| 9 | Crack du Trivial Pursuit | |
| 10 | Cerveau de la bande | Mi-parcours |
| 11 | Bac +5 en culture G | |
| 12 | Bête de concours | |
| 13 | Encyclopédie ambulante | |
| 14 | Champion de Burger Quiz | |
| 15 | Mentaliste | |
| 16 | Génie incompris | |
| 17 | Membre du Mensa | |
| 18 | La daronne au jeu des mille euros | |
| 19 | Wikipedia | |
| 20 | 👑 Émilien | Le sommet |

> Tous les titres sont modifiables, c'est de la blague à affiner ensemble. On peut aussi en débloquer certains comme titres "alternatifs" via les succès.

### 6.3 Courbe d'XP (durcie)

Montée rapide au tout début (on accroche le joueur), puis **de plus en plus dure** : les derniers niveaux sont un vrai marathon, réservés aux acharnés.

| Niveau | XP pour le niveau suivant | Récompense de passage |
|:------:|:-------------------------:|-----------------------|
| 1 → 2 | 150 | 20 🪙 |
| 2 → 3 | 300 | 30 🪙 |
| 3 → 4 | 500 | 40 🪙 |
| 4 → 5 | 800 | 60 🪙 + 1 item |
| 5 → 6 | 1 200 | 80 🪙 |
| 6 → 7 | 1 700 | 100 🪙 |
| 7 → 8 | 2 400 | 120 🪙 |
| 8 → 9 | 3 300 | 150 🪙 |
| 9 → 10 | 4 500 | 200 🪙 + item rare |
| 10 → 11 | 6 000 | 250 🪙 |
| 11 → 12 | 8 000 | 300 🪙 |
| 12 → 13 | 10 500 | 400 🪙 |
| 13 → 14 | 13 500 | 500 🪙 |
| 14 → 15 | 17 000 | 600 🪙 + item épique |
| 15 → 16 | 21 000 | 800 🪙 |
| 16 → 17 | 26 000 | 1 000 🪙 |
| 17 → 18 | 32 000 | 1 200 🪙 |
| 18 → 19 | 40 000 | 1 500 🪙 |
| 19 → 20 | 50 000 | item légendaire + titre doré |

Total pour atteindre le niveau 20 : environ **239 000 XP** (soit ~4× la version précédente). À ~60 XP/min en Normal, cela représente plusieurs dizaines d'heures de jeu : le niveau 20 (« Émilien ») doit rester un accomplissement rare. Chiffres ajustables selon le rythme réel observé.

---

## 7. Personnalisation de l'avatar

C'est le cœur de la dépense des pièces et l'expression de l'identité du joueur. L'avatar est composé **par couches** (layers), ce qui permet de mélanger les items.

> **Décidé : style humain stylisé** (personnages illustrés type cartoon). Très flexible pour les cosmétiques (coiffures, tenues, accessoires) et facile à décliner.

### 7.1 Les emplacements (slots)

| Slot | Exemples |
|------|----------|
| Corps / teint | couleurs de peau, formes |
| Visage / expression | sourire, sérieux, clin d'œil |
| Cheveux / coiffure | styles, couleurs |
| Yeux | formes, couleurs |
| Accessoire de tête | chapeaux, couronnes, casques, casquettes |
| Lunettes | vue, soleil, masques |
| Tenue / vêtements | hauts, costumes, déguisements |
| Arrière-plan | décors, dégradés, scènes |
| Cadre de profil | bordures (du basique au doré animé) |
| Émote de victoire | animation jouée quand on gagne |

### 7.2 Raretés

| Rareté | Couleur | Obtention |
|--------|---------|-----------|
| Commun | gris | Pièces, peu cher |
| Rare | bleu | Pièces, plus cher |
| Épique | violet | Pièces (cher) ou gemmes |
| Légendaire | or | Gemmes, succès, niveau 20, événements |

### 7.3 La boutique

- **Catalogue permanent** : tout ce qu'on peut acheter à tout moment.
- **Boutique tournante** : une sélection qui change chaque jour/semaine (crée l'envie de revenir).
- **Déblocages** : certains items ne s'achètent pas, ils se gagnent (montée de niveau, succès, classement, événement).

Principe : **cosmétique uniquement, zéro pay-to-win**. L'avatar n'affecte jamais le gameplay, seulement le style.

---

## 8. Systèmes de rétention

Ce qui fait revenir le joueur jour après jour :

- **Série quotidienne (daily streak)** : se connecter et jouer chaque jour fait grimper un compteur, avec des récompenses croissantes (J1, J2, ..., J7 = gros lot, puis ça repart).
- **Défi du jour** : une grille unique, une tentative, grosse récompense.
- **Succès / badges** : objectifs à débloquer ("100 bonnes réponses en Histoire", "10 parties parfaites", "série de 20"). Chaque succès donne pièces/gemmes/items.
- **Classements** : par amis, mondial, et par catégorie. Saison qui se réinitialise (plus tard).
- **Notifications** (avec parcimonie) : "Ton défi du jour t'attend", "Ta série va expirer dans 3h".
- **Passe Kwizz / saison** (phase ultérieure) : une progression saisonnière avec paliers de récompenses, gratuit + premium.

> Pas de système d'énergie/vies qui bloque le jeu pour le MVP : on veut que ce soit généreux et qu'on puisse jouer autant qu'on veut. À rediscuter si on veut un levier de monétisation.

---

## 9. Catégories & sous-catégories

Proposition de **13 grandes catégories**, chacune avec des sous-catégories. Large pour commencer, on pourra élaguer ou ajouter.

1. **Histoire**
   - Antiquité, Moyen Âge, Époque moderne, Époque contemporaine, Guerres mondiales, Histoire de France
2. **Géographie**
   - Capitales, Drapeaux, Pays du monde, Fleuves & reliefs, Mers & océans, Géographie de France
3. **Sciences**
   - Biologie, Physique, Chimie, Astronomie, Corps humain, Mathématiques
4. **Sport**
   - Football, Tennis, Rugby, Jeux Olympiques, Sports US, Cyclisme, Auto/Moto
5. **Cinéma & Séries**
   - Films cultes, Acteurs & actrices, Disney/Pixar, Marvel/DC, Séries TV, Récompenses (Oscars/César)
6. **Musique**
   - Variété française, Pop internationale, Rap/Hip-hop, Rock, Classique, Blind test (audio, plus tard)
7. **Arts & Littérature**
   - Peinture, Littérature classique, BD & Manga, Poésie, Sculpture & architecture
8. **Actualité & Société**
   - Politique, Économie, Faits de société, Événements récents
9. **Nature & Animaux**
   - Faune, Flore, Écologie, Dinosaures, Vie marine
10. **Tech & Jeux vidéo**
    - Internet & informatique, Jeux vidéo, Inventions, Intelligence artificielle, Marques tech
11. **Gastronomie**
    - Cuisine française, Cuisines du monde, Vins & boissons, Pâtisserie
12. **Pop culture & Divertissement**
    - Célébrités, TV & télé-réalité, Mèmes & Internet, Logos & marques
13. **Mythologies & Religions**
    - Mythologie grecque & romaine, Mythologies nordique/égyptienne, Religions du monde, Légendes & croyances

> Une catégorie **"Mélange / Tout"** (questions toutes catégories) est utile pour le mode Marathon et le Défi du jour.

---

## 10. Carte des écrans & navigation

Navigation principale par **barre d'onglets (tab bar)** à 4 ou 5 entrées :

```
┌─────────────────────────────────────────────────────────────┐
│                        TAB BAR                                │
├──────────┬──────────┬───────────┬──────────┬─────────────────┤
│ 🏠 Accueil│ 🎮 Jouer │ 🛍️ Boutique│ 🏆 Classmt│ 👤 Profil       │
└──────────┴──────────┴───────────┴──────────┴─────────────────┘
```

Liste des écrans :

| Écran | Rôle |
|-------|------|
| **Onboarding** | Première ouverture : pseudo, avatar de départ, tuto rapide |
| **Accueil** | Tableau de bord : niveau & XP, pièces, défi du jour, bouton Jouer, série |
| **Sélection du mode** | Classique / Contre-la-montre / Survie / ... |
| **Sélection de catégorie** | Grille des 13 catégories puis sous-catégories |
| **Sélection de difficulté** | Facile / Normal / Difficile (+ aperçu des gains) |
| **Partie (gameplay)** | Question, réponses, chrono, jokers, série en cours |
| **Résultats** | Score, pièces gagnées, XP gagné, bonus, rejouer |
| **Montée de niveau** | Plein écran festif quand on change de niveau |
| **Boutique** | Catalogue + boutique tournante + onglets par slot |
| **Avatar / Vestiaire** | Habiller l'avatar avec les items possédés |
| **Classement** | Amis / Monde / Par catégorie |
| **Profil** | Avatar, titre, stats, succès, historique |
| **Réglages** | Son, notifications, compte, mentions légales |

Wireframe rapide de l'**écran de partie** :

```
┌─────────────────────────────┐
│  ⏱ 00:12        Série: 🔥 4  │
│  ████████████░░░░  Q 6/10    │
│                             │
│   Quelle est la capitale     │
│   de l'Australie ?           │
│                             │
│  ┌───────────┐ ┌───────────┐ │
│  │  Sydney   │ │ Canberra  │ │
│  └───────────┘ └───────────┘ │
│  ┌───────────┐ ┌───────────┐ │
│  │ Melbourne │ │  Perth    │ │
│  └───────────┘ └───────────┘ │
│                             │
│   [50/50]  [+Temps]  [Passer]│
└─────────────────────────────┘
```

---

## 11. Architecture technique

### 11.1 Stack

| Couche | Choix | Pourquoi |
|--------|-------|----------|
| Langage | **Swift 6** | Standard iOS natif |
| UI | **SwiftUI** | Moderne, animations faciles, productif |
| État | **Observation** (`@Observable`, iOS 17+) + MVVM | Simple, sans dépendance lourde |
| Persistance locale | **SwiftData** | Profil, pièces, items, progression hors-ligne |
| Navigation | `NavigationStack` + routeur central | Flux clair entre écrans |
| Backend (phase 2) | **Supabase** ou **Firebase** | Questions, comptes, classements, duels |
| Données questions (MVP) | **JSON local** (bundle) | On code le jeu sans dépendre d'un serveur |

### 11.2 Principe d'architecture

- **MVVM** : chaque écran a une `View` (SwiftUI) et un `ViewModel` (`@Observable`) qui détient la logique.
- **Couche Service** abstraite derrière des protocoles : `QuestionService`, `EconomyService`, `ProgressionService`, `AvatarService`. En MVP ils lisent du JSON local ; en phase 2 on remplace l'implémentation par des appels backend sans toucher aux écrans.
- **Design System** centralisé : couleurs, typographies, espacements, composants réutilisables (boutons, cartes, badges) pour garder une cohérence et changer de thème facilement.
- **Le moteur de jeu** (`GameEngine`) est isolé de l'UI : il gère le déroulé d'une partie (questions, score, série, calcul des gains) et est testable unitairement.

### 11.3 Modèles de données principaux (esquisse)

```
User           : id, pseudo, niveau, xp, pièces, gemmes, série, avatarConfig
Category       : id, nom, icône, couleur, sousCatégories[]
Question       : id, catégorie, sousCatégorie, difficulté, intitulé,
                 réponses[], indexBonneRéponse, indice
GameSession    : mode, difficulté, catégorie, questions[], score, gains, xpGagné
AvatarItem     : id, slot, rareté, prix, monnaie, image, conditionDéblocage
AvatarConfig   : itemParSlot{}
Achievement    : id, titre, description, condition, récompense
```

### 11.4 Aperçu pendant le développement (la question « localhost »)

Une app **iOS native (SwiftUI)** ne se voit pas dans un navigateur via localhost. Les équivalents :

- **Simulateur iOS (Xcode)** : lance l'app sur un iPhone simulé directement sur le Mac. C'est l'outil principal, gratuit.
- **Xcode Previews** (`#Preview`) : aperçu en direct d'un écran dans le canvas pendant qu'on code, sans relancer l'app.
- **Sur un vrai iPhone** : déploiement via Xcode (câble ou Wi-Fi).
- **Dans un navigateur** : pas nativement. Il faut un service type **Appetize.io** (fait tourner une app iOS dans le navigateur, payant) pour partager une démo web.

Si un **aperçu navigateur + serveur local** est important (itérer vite, partager des liens), l'alternative est **React Native + Expo** : serveur de dev local, app de test **Expo Go**, et même un **mode web**. Compromis : ce n'est pas du 100 % Swift natif, mais c'est très proche et multiplateforme (iOS + Android + web).

En attendant, **ces maquettes HTML servies sur localhost jouent exactement ce rôle d'aperçu** pour valider le design avant de coder.

> **Décidé : SwiftUI natif.** L'aperçu se fera via le simulateur Xcode et Xcode Previews. Ces maquettes HTML restent l'aperçu design en attendant le code.

---

## 12. Structure du projet

Arborescence proposée (organisation par fonctionnalité) :

```
Kwizz/
├── App/
│   ├── KwizzApp.swift            # point d'entrée
│   └── AppRouter.swift           # navigation centrale
├── Core/
│   ├── Models/                   # User, Question, Category, ...
│   ├── Services/                 # protocoles + implémentations (local/backend)
│   ├── GameEngine/               # logique de partie, calcul gains/XP
│   └── Persistence/              # SwiftData
├── Features/
│   ├── Onboarding/
│   ├── Home/
│   ├── Quiz/                     # sélection mode/catégorie/difficulté + partie + résultats
│   ├── Shop/
│   ├── Avatar/
│   ├── Leaderboard/
│   └── Profile/
├── DesignSystem/
│   ├── Theme.swift               # couleurs, typo, espacements
│   ├── Components/               # boutons, cartes, badges réutilisables
│   └── Animations/
├── Resources/
│   ├── Questions/                # JSON des questions (MVP)
│   ├── Assets.xcassets           # images, icônes, items d'avatar
│   └── Localizable.strings       # textes (FR d'abord)
└── Tests/
    ├── GameEngineTests/
    └── EconomyTests/
```

---

## 13. Propositions de design

> **Décision : direction ARCADE MINIMAL retenue.** Fond sombre quasi monochrome, **une seule couleur d'accent** (vert par défaut, sélecteur ambre/cyan/mono), typo monospace, gros **score façon arcade** en pixel, beaucoup de vide. Inspiration : interface terminal sobre (moins de couleur que les 4 pistes ci-dessous). Maquette complète des 13 écrans dans `mockups/retro.html` (http://localhost:8765/retro.html).
>
> Les 4 directions ci-dessous sont conservées comme archive de la réflexion initiale.

Quatre directions explorées au départ. Pour chacune : une ambiance, une palette (codes hex) et un mini-wireframe de l'accueil.

### Option A - "Néon Arcade" (sombre, gamer, punchy)

Ambiance : fond très sombre, accents néon qui "glow", sensation de jeu d'arcade. Moderne et énergique.

| Rôle | Couleur | Hex |
|------|---------|-----|
| Fond | noir bleuté | `#0E0B1F` |
| Surface (cartes) | violet nuit | `#1B1635` |
| Primaire | magenta néon | `#FF2E97` |
| Secondaire | cyan néon | `#00E5FF` |
| Accent / succès | vert acide | `#39FF14` |
| Texte | blanc cassé | `#F5F3FF` |

```
┌─────────────────────────────┐  fond #0E0B1F
│ 🪙 1 240      💎 12      ⚙️  │
│                             │
│   Niv. 7 · Abonné à Wikipédia│
│   ██████████░░░░  XP         │  barre néon #FF2E97
│                             │
│   ┌───────────────────────┐  │
│   │   ▶  JOUER             │  │  bouton glow magenta
│   └───────────────────────┘  │
│                             │
│   Défi du jour 🔥  +100🪙    │  carte #1B1635
│                             │
│  [Classique][Contre-montre] │  accents cyan #00E5FF
└─────────────────────────────┘
```

### Option B - "Candy Pop" (clair, fun, coloré)

Ambiance : lumineux, rond, joyeux, très "grand public" (proche Trivia Crack / Duolingo). Rassurant et addictif.

| Rôle | Couleur | Hex |
|------|---------|-----|
| Fond | crème | `#FFF8F0` |
| Surface | blanc | `#FFFFFF` |
| Primaire | corail | `#FF6B6B` |
| Secondaire | turquoise | `#4ECDC4` |
| Accent | jaune soleil | `#FFD93D` |
| Texte | gris ardoise | `#2D3142` |

```
┌─────────────────────────────┐  fond #FFF8F0
│ 🪙 1 240      💎 12      ⚙️  │
│                             │
│   Niv. 7 · Abonné à Wikipédia│
│   ██████████░░░░  XP         │  barre corail #FF6B6B
│                             │
│   ╭───────────────────────╮  │
│   │   ▶  JOUER             │  │  gros bouton corail arrondi
│   ╰───────────────────────╯  │
│                             │
│   Défi du jour ☀️  +100🪙    │  carte blanche, ombre douce
│                             │
│  (Classique)(Contre-montre) │  pastilles turquoise
└─────────────────────────────┘
```

### Option C - "Premium Minimal" (épuré, chic, une couleur d'accent)

Ambiance : sobre, beaucoup d'espace, une seule couleur forte. Donne un côté qualitatif et "app sérieuse mais élégante".

| Rôle | Couleur | Hex |
|------|---------|-----|
| Fond | blanc cassé | `#FAFAFA` |
| Surface | blanc | `#FFFFFF` |
| Primaire (accent) | indigo profond | `#4F46E5` |
| Secondaire | gris doux | `#E5E7EB` |
| Accent succès | émeraude | `#10B981` |
| Texte | quasi noir | `#111827` |

```
┌─────────────────────────────┐  fond #FAFAFA
│ 🪙 1 240          💎 12   ⚙️ │
│                             │
│  Abonné à Wikipédia · Niv. 7 │
│  ───────────●──────  XP      │  trait fin, point indigo
│                             │
│   ┌───────────────────────┐  │
│   │        Jouer          │  │  bouton indigo plein, net
│   └───────────────────────┘  │
│                             │
│   Défi du jour      +100 🪙  │  ligne discrète
│                             │
│   Classique   Contre-montre  │  texte simple, soulignement
└─────────────────────────────┘
```

### Option D - "Rétro Quiz TV" (clin d'œil aux jeux télé)

Ambiance : inspiré des plateaux de jeu télé (Questions pour un champion, Burger Quiz), bleu nuit + or, sérieux mais joueur. Colle parfaitement au thème "Émilien".

| Rôle | Couleur | Hex |
|------|---------|-----|
| Fond | bleu nuit | `#0B1D3A` |
| Surface | bleu roi | `#13315C` |
| Primaire | or | `#FFC93C` |
| Secondaire | rouge plateau | `#E63946` |
| Accent | blanc | `#FFFFFF` |
| Texte | blanc cassé | `#EAF0FF` |

```
┌─────────────────────────────┐  fond #0B1D3A
│ 🪙 1 240      💎 12      ⚙️  │
│                             │
│   Niv. 7 · Abonné à Wikipédia│
│   ██████████░░░░  XP         │  barre or #FFC93C
│                             │
│   ╔═══════════════════════╗  │
│   ║      J O U E R        ║  │  bouton or, bordure nette
│   ╚═══════════════════════╝  │
│                             │
│   Défi du jour 🏆  +100🪙    │  carte bleu roi #13315C
│                             │
│  [Classique][Contre-montre] │  liserés or
└─────────────────────────────┘
```

> On pourra **mixer** : par exemple la structure rassurante de "Candy Pop" avec l'identité "Quiz TV", ou un mode clair + un mode sombre dérivés de la même palette.

---

## 14. Roadmap par phases

### Phase 0 - Fondations (cette étape)
- Valider ce plan, choisir le design, figer les règles d'économie/XP.
- Créer le projet Xcode, le Design System, les modèles de données.

### Phase 1 - MVP jouable (local, hors-ligne)
- Les 7 modes : Classique, Contre-la-montre, Survie, Marathon, Libre, Duel (vs bot), Défi du jour (grille locale déterministe).
- 3 difficultés, calcul des gains + XP, 20 niveaux.
- Questions en JSON local (quelques catégories pour tester).
- Boutique + avatar basiques, profil, série quotidienne.
- Persistance SwiftData.

### Phase 2 - En ligne & social
- Backend (comptes, questions servies à distance, classements).
- Duel PvP temps réel (vrais joueurs) et classement mondial du Défi du jour.
- Succès, classements amis/monde.

### Phase 3 - Rétention & monétisation
- Gemmes, achats intégrés, boutique tournante avancée.
- Passe Kwizz / saisons, événements thématiques.
- Notifications intelligentes, partages sociaux.

### Phase 4 - Contenu & polish
- Banque de questions étoffée (toutes catégories/sous-catégories).
- Blind test audio, questions imagées.
- iPad, widgets, peaufinage des animations.

---

## 15. Décisions à trancher ensemble

**Déjà décidé :**
- ✅ **Nom** : **Kwizz** (gardé).
- ✅ **Stack** : **SwiftUI natif** (aperçu via simulateur Xcode + Xcode Previews).
- ✅ **Monnaie** : pièces seules pour le MVP (gemmes en phase 2), économie volontairement **serrée**.
- ✅ **Modes MVP** : les 7 modes (Classique 15Q, Contre-la-montre, Survie, Marathon, Libre, Duel vs bot, Défi du jour local). PvP réel et classement mondial du défi en phase 2.
- ✅ **Score Classique** : façon **arcade** (100 / bonne réponse + jusqu'à +100 de bonus vitesse, max 3 000).
- ✅ **Mode Libre** : pièces **très réduites** (1 pièce / 10 bonnes réponses, plafond 20/jour).
- ✅ **Énergie/vies** : **aucune limite**, on joue autant qu'on veut.
- ✅ **Titres des 20 niveaux** : liste actuelle gardée (à peaufiner plus tard).
- ✅ **XP** : courbe **durcie** (~239 000 XP pour le niveau 20).
- ✅ **Avatar** : humain stylisé, **central sur l'accueil** (avec ombre au sol). Les 20 avatars et les items seront créés plus tard.
- ✅ **Direction de design** : **arcade minimal** (fond sombre, monochrome, accent unique, monospace, gros score pixel). Maquettes : `mockups/retro.html` (galerie) + `mockups/prototype.html` (interactif).

**Encore à trancher :**
1. **Couleur d'accent** : vert (défaut), ambre, cyan, ou mono (blanc) ? (sélecteur en haut de la maquette)
2. **Détails avatar** : look précis des personnages, à définir au moment de créer les visuels.
3. **Logo / mascotte** : à créer.

---

*Fin du brouillon v0.1. On retravaille tout ça ensemble.*
