# Kwizz - Plan de production du contenu

> Plan d'attaque pour produire **les avatars + tous les objets cosmétiques** et **la banque de questions**.
> Aligné sur le code existant (`Sources/KwizzCore`, `App/DesignSystem`) et la direction **arcade minimal**.
> Statut : v0.1, à valider ensemble.

---

## Sommaire

- [Partie A - Avatars & objets (le visuel)](#partie-a---avatars--objets-le-visuel)
  - [A.0 Ce que "20 avatars" veut dire](#a0-ce-que-20-avatars-veut-dire-à-trancher)
  - [A.1 Le style est déjà imposé par l'app](#a1-le-style-est-déjà-imposé-par-lapp)
  - [A.2 Quel outil ? (comparatif + reco)](#a2-quel-outil--comparatif--reco)
  - [A.3 Puis-je le faire, moi (Claude) ?](#a3-puis-je-le-faire-moi-claude-)
  - [A.4 Le contrat d'asset (specs techniques)](#a4-le-contrat-dasset-specs-techniques)
  - [A.5 L'inventaire complet à produire](#a5-linventaire-complet-à-produire)
  - [A.6 Pipeline de production, étape par étape](#a6-pipeline-de-production-étape-par-étape)
  - [A.7 Budget temps / coût](#a7-budget-temps--coût)
- [Partie B - Les questions](#partie-b---les-questions)
  - [B.1 Combien il en faut vraiment](#b1-combien-il-en-faut-vraiment)
  - [B.2 Comment les répartir](#b2-comment-les-répartir-la-matrice)
  - [B.3 Anatomie d'une bonne question](#b3-anatomie-dune-bonne-question)
  - [B.4 Le schéma JSON et les règles de validation](#b4-le-schéma-json-et-les-règles-de-validation)
  - [B.5 Le pipeline de rédaction](#b5-le-pipeline-de-rédaction-génération--qa)
  - [B.6 Puis-je le faire, moi (Claude) ?](#b6-puis-je-le-faire-moi-claude-)
- [Partie C - Ordre d'attaque global](#partie-c---ordre-dattaque-global)
- [Décisions à trancher](#décisions-à-trancher)

---

# Partie A - Avatars & objets (le visuel)

## A.0 Ce que "20 avatars" veut dire (à trancher)

Le mot "avatar" peut désigner deux choses dans Kwizz. Il faut choisir, car ça change toute la production.

| Interprétation | Ce que c'est | Volume | Reco |
|---|---|---|---|
| **(1) 20 personnages de base** | 20 "corps + visages" complets et distincts. Le joueur en choisit un comme identité de départ (puis l'habille avec les objets). | 20 sprites de base + le catalogue d'objets | ✅ **Recommandé** |
| **(2) 1 look par niveau** | Le même avatar qui évolue visuellement du niveau 1 ("Américain moyen", l'air ahuri) au niveau 20 ("Émilien", l'air génial). | 20 variantes d'un même personnage | Sympa en **complément**, pas en base |
| **(3) 20 = total d'objets** | Tu comptais juste le nombre d'items cosmétiques. | voir A.5 | Peu probable vu la formulation |

> **✅ DÉCIDÉ : interprétation (2) - 1 look par niveau.** Le personnage de base **évolue visuellement** du niveau 1 ("Américain moyen", l'air ahuri) au niveau 20 ("Émilien", l'air génial). C'est une récompense de prestige : ton niveau se lit sur ton avatar.
> Les 6 slots cosmétiques (`AvatarSlot` = `tete, cheveux, lunettes, haut, fond, cadre`) restent par-dessus pour la personnalisation. Donc : **20 corps progressifs (pilotés par le niveau) + objets cosmétiques empilés**. Le `MannequinView` actuel sert de fallback pendant la production.
> Conséquence production : les 20 looks partagent les mêmes proportions/ancrages (on part d'un perso "maître" et on le fait vieillir/se sophistiquer palier par palier), ce qui simplifie l'empilement des objets.

---

## A.1 Le style est déjà imposé par l'app

Bonne nouvelle : tu n'as presque pas de décision de style à prendre, le code la dicte déjà.

- **Direction** : arcade minimal (cf. `PLAN.md` section 13, `mockups/retro.html`).
- **Polices** : `Press Start 2P` (pixel) + `Space Mono`. C'est un univers **pixel / borne d'arcade**.
- **Palette verrouillée** (`App/DesignSystem/Theme.swift`) :

| Rôle | Hex |
|---|---|
| Fond | `#161616` |
| Fond 2 | `#101010` |
| Surface | `#1b1b1b` |
| Surface 2 | `#202020` |
| Bordure | `#2a2a2a` |
| Texte | `#f0f0f0` |
| Atténué | `#6b6b6b` |
| Mauvais | `#ff5066` |
| Accent Vert | `#00ff88` |
| Accent Ambre | `#ffb000` |
| Accent Cyan | `#38d6ff` |
| Rareté Commun | `#9aa0a6` |
| Rareté Rare | `#38d6ff` |
| Rareté Épique | `#c084fc` |
| Rareté Légendaire | `#ffb000` |

**Conclusion : le style à produire, c'est du pixel art, monochrome sombre, avec une touche d'accent.** C'est le format le plus simple à produire de façon cohérente et le plus raccord avec le reste. (Un style "cartoon vectoriel lisse" jurerait avec les polices pixel et les coins nets `radius: 0`.)

---

## A.2 Quel outil ? (comparatif + reco)

| Outil | Pour quoi | Prix | Avantages | Limites |
|---|---|---|---|---|
| **Aseprite** | Pixel art (le standard) | ~20 € une fois | Fait pour le pixel + l'animation (émotes de victoire), export PNG/sprite-sheet propre, calques = nos slots | Petite courbe d'apprentissage |
| **Piskel** | Pixel art web gratuit | Gratuit | Zéro install, navigateur, simple | Moins puissant qu'Aseprite |
| **Pixaki / Procreate** | Pixel art sur iPad | ~15-25 € | Au doigt/stylet, confortable | iPad requis |
| **Scenario.gg / Leonardo.ai** | Génération IA d'assets de jeu | Freemium | Entraîne un modèle sur **ton** style, produit en masse, variations rapides | Cohérence des calques à recadrer à la main |
| **Midjourney / DALL·E** | Génération IA d'images | Abonnement | Qualité visuelle, rapide pour explorer | Pas pensé "calques alignés", retouche obligatoire |
| **Figma / Illustrator / Inkscape** | Vectoriel | Gratuit (Inkscape/Figma) à payant | Net, redimensionnable, calques | Look vectoriel lisse, moins raccord pixel |
| **Canva** (connecté ici en MCP) | Génération + montage rapide | Freemium | Je peux le piloter directement, export PNG | Pas spécialisé pixel/jeu |

**Recommandation (par ordre de préférence) :**

1. **Pour un premier jeu entièrement "habillé" tout de suite** : je génère un set complet **procédural** (voir A.3), sur la palette, parfaitement aligné aux slots. L'app n'a plus aucun trou visuel.
2. **Pour la version "léchée" qui restera** : **Aseprite**, par toi ou un pixel artist, en suivant le contrat d'asset (A.4). Chaque asset produit remplace son équivalent procédural sans toucher au code.
3. **Pour produire vite beaucoup de variantes** : **Scenario.gg** (modèle entraîné sur 5-10 de tes sprites validés), je te fournis les prompts et je gère l'intégration.

> En clair : on ne choisit pas UN outil, on fait un **relais**. Procédural d'abord (jouable immédiatement), pixel art léché ensuite (qualité), IA en accélérateur si besoin de volume.

---

## A.3 Puis-je le faire, moi (Claude) ?

Soyons honnête sur ce que je peux et ne peux pas faire.

**Ce que je PEUX produire directement, maintenant :**

- ✅ **Des avatars/objets procéduraux en SwiftUI** (comme `MannequinView`), dessinés au code (formes, pixels, dégradés) sur la palette. Avantage : zéro fichier image, ça compile, c'est net à toutes les tailles, ça se recolore avec l'accent. Idéal pour un **premier set jouable** et pour les fonds/cadres.
- ✅ **Du pixel art en SVG** (grille de carrés colorés) que j'écris à la main, exportable en PNG @1x/@2x/@3x. Bon pour des objets simples (lunettes, chapeaux, cadres).
- ✅ **Tout le câblage** : le contrat d'asset, la structure `Assets.xcassets`, le catalogue (`AvatarItem.swift`), la vue de rendu en couches qui empile les slots, la nomenclature.
- ✅ **Piloter Canva** (connecté) pour générer/exporter des visuels.

**Ce que je ne peux PAS faire :**

- ❌ Peindre une illustration raster "à la main" (je n'ai pas de pinceau). Pour un rendu artistique riche, il faut un humain (Aseprite) ou un outil IA d'image (Scenario/Midjourney).

**Donc le plan réaliste :** je livre un **set complet procédural** (l'app est jouable et cohérente tout de suite), puis on **upgrade** slot par slot avec du pixel art léché, sans jamais casser le jeu.

---

## A.4 Le contrat d'asset (specs techniques)

Pour que tout s'empile parfaitement, chaque image suit les **mêmes règles**.

### Canevas partagé

- **Grille de référence : 64 × 64 px** (pixel art). Tous les slots et tous les personnages de base sont dessinés sur ce même canevas transparent, aux **mêmes points d'ancrage** (zone tête, zone torse), pour que les calques se superposent au pixel près.
- Le `MannequinView` actuel occupe **160 × 166 pt** (tête Ø42, torse 66×72). On garde ce cadre d'affichage : un sprite 64×64 affiché à ~2,5x tombe juste.
- **Export** : PNG **transparent** (alpha), en `@1x / @2x / @3x` (donc sources nettes : 64, 128, 192 px), ou en **vectoriel/SVG** pour les éléments géométriques (cadres, fonds unis).
- **Fond toujours transparent** sauf pour le slot `fond` (lui EST le fond).

### Ordre d'empilement (z-order), de l'arrière vers l'avant

```
[cadre]      ← bordure de profil, dessinée par-dessus tout (overlay)
   ▲
[tete]       ← chapeau/casquette/couronne (au-dessus des cheveux)
[lunettes]   ← sur le visage
[cheveux]    ← coiffure
[haut]       ← vêtement sur le torse
[CORPS]      ← le personnage de base (un des 20)
[fond]       ← décor, tout au fond
```

Mapping exact sur `AvatarSlot` (déjà dans le code) : `fond → (corps) → haut → cheveux → lunettes → tete`, et `cadre` en overlay. Le "corps" est l'avatar de base (A.0 interprétation 1), pas un slot d'objet.

### Nomenclature (à respecter à la lettre)

Les IDs existent déjà dans `AvatarItem.swift`. **Le nom du fichier = l'ID.**

```
tete.casquette.png          haut.pull.png           fond.crt.png
tete.couronne.png           haut.costume.png        cadre.or.png
cheveux.afro.png            lunettes.neon.png       base.01.png ... base.20.png
```

Rangement : un dossier d'imageset par item dans `Resources/Assets.xcassets/Avatar/<slot>/<id>.imageset/`. Je génère le `Contents.json` de chacun.

### Côté code (ce que je branche)

- Une `AvatarLayeredView` qui prend un `AvatarConfig` (un item par slot + le personnage de base) et empile les images dans le z-order ci-dessus. Elle remplace `MannequinView` partout.
- Le `MannequinView` reste comme **fallback** quand un slot est vide ou l'asset manquant (pas de trou visuel pendant la production).

---

## A.5 L'inventaire complet à produire

Le catalogue actuel (`AvatarItem.swift`) compte **17 objets**. Voici la cible MVP, slot par slot. Les **raretés sont des métadonnées** (couleur + prix), pas du dessin en plus.

| Slot | Existant | Cible MVP | Exemples à produire |
|---|:---:|:---:|---|
| **Personnage de base** | 0 (mannequin) | **20** | les 20 "corps + visages" (interprétation A.0-1) |
| **tete** (couvre-chef) | 4 | **10** | casquette, bonnet, haut-de-forme, couronne, casque arcade, béret, bob, cornes, auréole, chapeau de paille |
| **cheveux** | 2 | **10** | afro, mohawk, court, long, chauve, banane, couettes, undercut, dégradé néon, cheveux blancs |
| **lunettes** | 3 | **8** | rondes, néon, masque arcade, aviateur, 3D, monocle, bandeau, soleil |
| **haut** | 3 | **10** | pull pixel, veste arcade, costume, marcel, hoodie, blouse labo, maillot foot, smoking, pull moche de Noël, t-shirt logo |
| **fond** | 3 | **8** | uni, CRT, synthwave, grille néon, ciel étoilé, plateau TV, dégradé accent, scanlines |
| **cadre** | 2 | **6** | vert, or, néon animé, pixel, double trait, doré animé (niv. 20) |
| **émote de victoire** (option) | 0 | 4-6 | petit pixel animé joué à la victoire (plus tard) |
| **TOTAL** | **17** | **~72** | |

### Plan par paliers

| Palier | Personnages | Objets | Total sprites | Objectif |
|---|:---:|:---:|:---:|---|
| **Démo** | 3 | ~12 | ~15 | Montrer le système en couches |
| **MVP** | **20** | **~52** | **~72** | Boutique + vestiaire crédibles |
| **Lancement** | 20 | ~90 | ~110 | De quoi absorber les pièces (cf. inflation, PLAN 5.5) |
| **Mature** | 30+ | 150+ | 180+ | Boutique tournante, saisons, événements |

> Répartition des raretés conseillée (MVP) : ~50 % commun, ~30 % rare, ~15 % épique, ~5 % légendaire (les légendaires = déblocages par niveau/succès, pas à vendre, cf. `unlockLevel`).

---

## A.6 Pipeline de production, étape par étape

1. **Verrouiller le canevas + la palette** (A.1, A.4). Choisir l'accent par défaut (vert / ambre / cyan / mono). → *décision rapide.*
2. **Dessiner 1 personnage de base "maître"** sur la grille 64×64. Le valider dans l'app (taille, ombre au sol, lisibilité sur `#161616`).
3. **Brancher `AvatarLayeredView`** + le fallback mannequin (je m'en occupe).
4. **Décliner les 19 autres personnages** à partir du maître (mêmes proportions, on change teint / visage / silhouette).
5. **Produire les objets slot par slot**, dans l'ordre d'impact : `haut` → `tete` → `cheveux` → `lunettes` → `fond` → `cadre`. Chaque objet est dessiné sur le canevas partagé aux ancrages fixes.
6. **Câbler le catalogue** : compléter `AvatarItem.catalog` (id, slot, rareté, prix, `unlockLevel`), brancher la boutique et le vestiaire.
7. **Itérer** : remplacer les sprites procéduraux par les versions léchées, un à un, sans toucher au code (même id = même fichier).

> Règle d'or : **personnage maître validé en premier**. Tant que les proportions et les ancrages ne sont pas figés, on ne produit pas en série (sinon tout est à refaire).

---

## A.7 Budget temps / coût

Ordres de grandeur (très variables selon le niveau de finition) :

| Voie | Coût | Délai pour le set MVP (~72) |
|---|---|---|
| **Procédural (moi)** | 0 € | quelques heures de câblage, set "correct" tout de suite |
| **Toi sur Aseprite** | ~20 € (licence) | 1 à 3 semaines en pixel art soigné |
| **Pixel artist freelance** | ~5-15 € / sprite (~400-1000 € le set) | 1 à 3 semaines |
| **IA (Scenario/Leonardo)** | ~10-30 € / mois | quelques jours + retouche d'alignement |

**Reco budget-malin :** procédural (moi) pour être jouable à 0 €, puis Aseprite (toi) ou IA pour la passe "qualité" sur les sprites les plus visibles (personnages de base + `haut` + `tete`).

---

# Partie B - Les questions

## B.1 Combien il en faut vraiment

Le besoin se calcule à partir de ce que **consomment les modes** et du **risque de répétition**.

Ce que tire une partie (cf. `PLAN.md` section 3) :

- Classique : **15** questions (1 catégorie, 1 difficulté)
- Marathon : **30+** (mélange, toutes catégories)
- Contre-la-montre : ~20-30
- Survie : **illimité** (jusqu'à l'erreur)
- Défi du jour : ~10-15 (mélange)
- Duel : ~7

**Unité de mesure : le "bucket" = 1 catégorie × 1 difficulté.** Il y en a **13 × 3 = 39**.

Règle anti-répétition : pour qu'un joueur ne retombe pas vite sur les mêmes questions, il faut un pool **≥ 3× le plus gros tirage** par bucket. Le plus gros tirage mono-catégorie, c'est Classique (15) ou une longue Survie. Donc :

- **Plancher pour "jouable"** : ~30 questions / bucket.
- **Confortable ("ça reste frais")** : ~45-60 / bucket.

| Palier | Q / bucket | Total (~39 buckets) | Ressenti |
|---|:---:|:---:|---|
| **Prototype (actuel)** | 6-8 | ~250-300 (il y en a ~45 aujourd'hui) | démo, on voit vite le fond |
| **MVP jouable** | **30-40** | **~1 200-1 500** | on enchaîne plusieurs parties sans lassitude |
| **Lancement confortable** | 70-100 | ~3 000-4 000 | tient des semaines de jeu |
| **Mature (réf. Trivia Crack ~20k)** | 150+ | 6 000-10 000+ | rejouabilité quasi infinie |

> **Cible recommandée pour le MVP : ~1 300 questions.** C'est le bon compromis effort/ressenti. Le mode Mélange (Marathon, Défi) ne demande **aucune** question en plus : il pioche dans les 13 catégories.

---

## B.2 Comment les répartir (la matrice)

Trois axes à équilibrer :

1. **Par catégorie** : viser l'équilibre entre les 13, mais accepter que les catégories "grand public" (Histoire, Géo, Ciné, Sport, Pop culture) soient plus fournies, car plus sollicitées.
2. **Par difficulté** (dans chaque catégorie) : répartition conseillée **40 % facile / 40 % normal / 20 % difficile**. Le difficile est plus long à écrire (et plus risqué côté justesse), on en met moins.
3. **Par sous-catégorie** : ~70 sous-catégories existent (`Category.swift`). Pour le MVP, viser **au moins 5-8 questions par sous-catégorie** pour que chacune "existe", sans chercher l'exhaustivité.

Exemple concret pour **Histoire** (cible MVP ~100 questions, 6 sous-catégories) :

| Sous-catégorie | Facile | Normal | Difficile | Total |
|---|:---:|:---:|:---:|:---:|
| Antiquité | 6 | 6 | 3 | 15 |
| Moyen Âge | 6 | 6 | 3 | 15 |
| Époque moderne | 7 | 7 | 4 | 18 |
| Époque contemporaine | 7 | 7 | 4 | 18 |
| Guerres mondiales | 7 | 7 | 4 | 18 |
| Histoire de France | 7 | 6 | 3 | 16 |
| **Total** | **40** | **39** | **21** | **100** |

> On réplique ce gabarit sur les 13 catégories, en ajustant le total selon la popularité.

---

## B.3 Anatomie d'une bonne question

Le format est fixé par le code : **énoncé + 4 réponses + 1 seule bonne** (la 4ᵉ réponse est attendue par l'UI). Une bonne question de quiz respecte :

- **Une seule réponse incontestablement juste.** Le piège n°1 : une 2ᵉ réponse "techniquement vraie aussi". À bannir.
- **3 distracteurs plausibles.** Du même registre que la bonne réponse (mêmes ordres de grandeur, même famille). Mauvais : `["Paris", "Lyon", "42", "Une banane"]`. Bon : 4 villes crédibles.
- **Difficulté calibrée** :
  - *Facile* : grand public, connu de presque tous (capitale de l'Italie).
  - *Normal* : demande un peu de culture (capitale du Canada).
  - *Difficile* : pointu ou piégeux (premier empereur romain : Auguste, pas César).
- **Énoncé court et sans ambiguïté.** Lisible en une ligne ou deux sur mobile. Pas de double négation.
- **Pas de question "périssable".** Éviter "actuellement", "le record du monde", "le président en poste" : ça se démode. Si daté, ancrer ("en 2018", "au 1er janvier 2025").
- **Neutralité.** Pas de sujets clivants/sensibles présentés comme tranchés (religion, politique partisane).
- **Réponses de longueur homogène.** Une réponse beaucoup plus longue que les autres trahit souvent la bonne.
- **Champ `explanation` (OBLIGATOIRE)** : une phrase courte qui apprend quelque chose ("Canberra, pas Sydney."). Elle s'affiche **en jeu dès qu'on a répondu**, juste au-dessus du bouton "Suivant" (déjà branché dans `GameView.swift`). Donc chaque question DOIT en avoir une, exacte et concise.
- **Vérifiabilité.** Chaque réponse doit être sourçable (encyclopédie, référence solide). Pas de "on dit que".

---

## B.4 Le schéma JSON et les règles de validation

Le schéma existe déjà (`Resources/questions.json`, modèle `Question.swift`) :

```json
{
  "id": "geo7",
  "categoryID": "geographie",
  "subcategoryID": "geographie.0",
  "difficulty": "facile",
  "text": "Quelle est la capitale de l'Espagne ?",
  "answers": ["Madrid", "Barcelone", "Séville", "Valence"],
  "correctIndex": 0,
  "explanation": "Madrid, au centre du pays."
}
```

Règles à faire respecter (au-delà du `isValid` du code, qui ne vérifie que le minimum) :

- `id` **unique**, court, préfixé par la catégorie (`his`, `geo`, `sci`, `spo`, `cin`, `mus`, `art`, `act`, `nat`, `tec`, `gas`, `pop`, `myt`).
- `categoryID` et `subcategoryID` **valides** (existent dans `Category.swift`, format `cat.N`).
- `difficulty` ∈ `facile | normal | difficile`.
- `answers` : **exactement 4**, toutes **distinctes**, non vides.
- `correctIndex` ∈ `0...3`.
- **Pas de doublon de `text`** (même question posée deux fois).
- `text` non vide, raisonnablement court.

> Je peux écrire un **petit validateur** (Swift dans `Dev/Check`, ou un script) qui passe tout `questions.json` au crible et liste les erreurs. À brancher dans `swift run KwizzCoreCheck` pour ne jamais committer une banque cassée.

---

## B.5 Le pipeline de rédaction (génération + QA)

Écrire 1 300 bonnes questions à la main est un travail énorme. Le pipeline réaliste :

1. **Génération par lots (IA, moi)** : je produis les questions directement au schéma JSON, catégorie par catégorie, en respectant la matrice (B.2) et la grille qualité (B.3).
2. **Validation automatique** : le validateur (B.4) rejette les doublons, mauvais index, sous-catégories invalides, réponses non distinctes.
3. **Passe de fact-check** : une relecture "adversariale" (un 2ᵉ passage qui cherche à prendre en défaut chaque réponse) pour éliminer les erreurs factuelles et les "2 bonnes réponses". C'est l'étape critique pour la crédibilité.
4. **Revue humaine par sondage** : tu relis un échantillon par catégorie (ex. 10 %) pour le ton et la justesse. Tu gardes la main sur l'humour des explications.
5. **Fusion + commit** : merge dans `questions.json`, le validateur tourne, on archive.

> Pour produire vite et bien à grande échelle, c'est typiquement un cas d'orchestration multi-agents (générer par catégorie en parallèle, puis vérifier chaque question par un agent sceptique). Je peux te le proposer en **workflow** si tu veux lancer la production en masse, c'est exactement le genre de tâche que ça accélère. Dis-le moi et je le mets en place (ça consomme plus de budget, donc c'est ton appel).

---

## B.6 Puis-je le faire, moi (Claude) ?

**Oui, et c'est même la partie où je suis le plus utile.**

- ✅ Générer les questions **au schéma exact**, par lots, équilibrées par catégorie/difficulté/sous-catégorie.
- ✅ Écrire le **validateur** et la **passe de fact-check** automatique.
- ✅ Dédupliquer, renuméroter les `id`, garder le JSON propre.

**Proposition de démarrage** : je génère **un lot pilote** (par ex. Histoire complète, ~100 questions validées) pour qu'on cale ensemble le **ton**, la **difficulté** et le **format des explications**. Une fois ce gabarit validé par toi, je déroule les 12 autres catégories au même standard.

---

# Partie C - Ordre d'attaque global

Les deux chantiers (visuel et questions) sont **indépendants** et peuvent avancer en parallèle. Ordre conseillé :

| # | Chantier | Action | Qui |
|---|---|---|---|
| 1 | Visuel | Trancher A.0 (sens de "20 avatars") + l'accent par défaut | Toi |
| 2 | Questions | Je génère le **lot pilote Histoire** (~100), tu valides le ton | Moi → Toi |
| 3 | Visuel | Je branche `AvatarLayeredView` + fallback, je livre le **set procédural démo** (3 persos + ~12 objets) | Moi |
| 4 | Questions | Je déroule les **12 catégories restantes** au standard validé (cible ~1 300) | Moi |
| 5 | Visuel | Passe "qualité" pixel art (toi/Aseprite ou IA) sur les sprites les plus visibles, swap progressif | Toi / artiste |
| 6 | Les deux | Validateur questions branché au build + catalogue d'items complété | Moi |

---

# Décisions prises

- ✅ **Avatars** : 1 look par niveau (20 corps progressifs) + objets cosmétiques par-dessus (A.0).
- ✅ **Voie visuelle** : set **procédural d'abord** (jouable à 0 €), upgrade pixel art ensuite (A.2/A.3).
- ✅ **Questions** : **au moins 100 par catégorie** (cible ~1 300+), produites en **workflow multi-agents** (génération sonnet + fact-check adversarial), exportées en **JSON + CSV**.
- ✅ **Explication obligatoire** par question, affichée en jeu au moment de "Suivant" (branché dans `GameView.swift`).

## Reste à trancher

1. **Accent par défaut** : vert `#00ff88`, ambre `#ffb000`, cyan `#38d6ff`, ou mono ? (A.1)
2. **Passe qualité visuelle** : toi sur Aseprite, un freelance, ou IA (Scenario) ? (A.2/A.3)
3. **Look des 20 paliers** : à quoi ressemble la progression "Américain moyen → Émilien" (accessoires, posture, couleur d'aura par palier) ?

---

## État d'avancement

| Tâche | Statut |
|---|---|
| Plan de contenu (ce doc) | ✅ fait |
| Affichage explication en jeu (au "Suivant") | ✅ fait (build OK) |
| Workflow de génération des questions (>=100/cat) | ⏳ en cours (tâche de fond) |
| Écriture `questions.json` + `questions.csv` | ⏳ à la fin du workflow |
| Validateur de banque (anti-doublon/schéma) | ✅ fait (`Dev/Check`, 95/95) |
| Système d'avatars procéduraux (layered + 20 looks) | ✅ fait (`App/DesignSystem/AvatarKit.swift`, build + rendu vérifiés) |
| Rendu des 17 objets du catalogue (6 slots) | ✅ fait (boutique + vestiaire branchés) |

---

*v0.2. On ajuste au fil de l'eau.*
