# Plan : Duel en ligne avec code de room (multijoueur)

Statut : plan d'implémentation, non commencé. Cible : phase backend du `PLAN.md`.

## 1. Objectif

Permettre à 2 à 6 joueurs de se retrouver dans une **room en ligne via un code**
(modèle Kahoot/Skribbl), de répondre **aux mêmes questions** chacun sur son
téléphone, **le plus vite possible**, en voyant le **score des autres en direct**,
puis d'arriver sur un **podium classé**.

Choix produit validés :

- **2 à 6 joueurs** par room (pas seulement 1v1).
- **Score adverse en live** : on voit la progression de chacun question par question.
- Le tout doit rester dans l'esprit "simple et épuré" : pas de gestion de compte,
  pas de nouvelle dépendance lourde, on réutilise au maximum l'existant.

## 2. Principe directeur

On ne construit **pas** un serveur de jeu autoritatif. Le réseau ne transporte que :

1. **qui est dans la room** (presence),
2. **le coup d'envoi + les questions** (un broadcast de l'host),
3. **la progression de chaque joueur** (un broadcast par réponse),
4. **les scores finaux** (un broadcast de fin).

Tout le quiz tourne **en local** sur chaque appareil via le `QuizSession` existant
(`Sources/KwizzCore`). On compare les **scores** (qui incluent déjà le bonus de
vitesse mesuré localement), donc **aucun arbitrage de latence** n'est nécessaire :
chaque joueur dispose de ses 15 s par question chez lui, et on classe sur le total.

C'est ce qui rend le projet faisable rapidement : la partie difficile habituelle
d'un quiz temps réel (un serveur qui distribue et synchronise les questions) est
remplacée par un simple relais de messages.

## 3. Stack technique

- **Supabase Realtime**, channels **Broadcast + Presence**, avec la clé `anon`
  uniquement.
- **Pas d'authentification** et **aucune nouvelle table** pour le MVP. L'identité
  d'un joueur = son `pseudo` local (déjà présent dans `PlayerProfile`) + un `UUID`
  client généré au lancement de l'app.
- Channel nommé `room:CODE` (ex. `room:K7QX`). Tous les joueurs d'une partie
  rejoignent le même channel.

Pourquoi pas de table : une partie est éphémère (quelques minutes). Presence +
Broadcast suffisent. Une table `rooms` resterait possible plus tard pour la
reconnexion robuste, mais c'est hors MVP.

## 4. Flux d'une partie

```
HOST                                      INVITÉS (1 à 5)
─────                                     ───────────────
crée la room → code "K7QX"
  join channel room:K7QX                  saisissent "K7QX"
  presence.track(pseudo, clientID)          join channel room:K7QX
                                            presence.track(pseudo, clientID)
  [lobby : liste des joueurs en live] ◄──► [lobby : liste des joueurs en live]
  tape "Lancer" (host uniquement)
  build N questions (seed) + lock room
  broadcast start{questions}            ──► reçoivent start{questions}
  ── countdown 3·2·1 (local) ─────────────  countdown 3·2·1 (local)
  joue les questions en local              jouent en local
   à chaque réponse :                       à chaque réponse :
   broadcast progress{score,index}       ◄─► broadcast progress{score,index}
   [mini-classement live à l'écran]          [mini-classement live à l'écran]
  broadcast finished{score}             ◄─► broadcast finished{score}
  → tous ont fini → podium classé           → podium classé
```

## 5. Protocole de messages (`DuelEvent`, pur, Codable)

Échangés en Broadcast sur le channel. `clientID` attribue le message à un joueur.

| Event | Émis par | Charge utile | Quand |
|---|---|---|---|
| `hello` | tous | `pseudo`, `clientID`, accent/avatar (option) | à l'entrée, pour enrichir la presence |
| `start` | host | `questions: [Question]`, `roundID` | au lancement, verrouille la room |
| `progress` | tous | `clientID`, `questionIndex`, `score`, `correct` | après **chaque** réponse |
| `finished` | tous | `clientID`, `score`, `correct` | à la fin des questions |

Notes :

- L'host **diffuse les questions résolues** (array `[Question]` avec réponses déjà
  mélangées), pas seulement un seed. C'est quelques Ko et ça garantit des questions
  identiques même si les `questions.json` locaux divergent entre versions d'app.
- `progress` permet le **classement en live**. Volume maîtrisé : N joueurs × N
  questions, soit quelques dizaines de petits messages par partie.
- Anti-triche léger : tout `score` reçu est borné par le max théorique
  (`questionCount × 200`) avant affichage.

## 6. Déterminisme des questions

L'host construit les questions une seule fois, puis les diffuse :

```swift
let questions = store.bank.query(
    categoryID: nil, subcategoryID: nil, difficulty: nil,
    count: GameMode.duel.questionCount ?? 7,   // 7 aujourd'hui
    seed: someSeed                              // SeededGenerator existant
)
```

Le seed sert surtout à la reproductibilité côté tests. Comme les questions sont
ensuite **diffusées telles quelles**, les invités n'ont rien à régénérer : ils
décodent l'array reçu et le passent à un `QuizSession`. Zéro dépendance à un
contenu local identique.

## 7. Temps réel : classement en live

- À chaque réponse, le `GameController` appelle un callback `onProgress(score,
  index, correct)`. Le `DuelController` le relaie en `broadcast(progress)`.
- Le `DuelController` maintient `liveScores: [clientID: LiveState]` (pseudo, score,
  question courante, terminé ou non).
- Un overlay "mini-classement" dans l'écran de jeu lit cet état (via environment)
  et affiche les joueurs triés par score, mis à jour en direct.
- Comme le classement final se joue sur le **score total**, la latence d'un
  `progress` n'affecte que l'affichage live, jamais l'équité du résultat.

## 8. Découpage KwizzCore (pur, testable) vs App (SwiftUI + réseau)

On respecte la frontière du projet : toute logique sans réseau va dans `KwizzCore`
et passe par `swift run KwizzCoreCheck`.

### Nouveau dans `Sources/KwizzCore/`

| Fichier | Rôle | Tests |
|---|---|---|
| `RoomCode.swift` | génération/validation d'un code (5 chars, alphabet sans O/0/I/1), `generate(using:)` seedable | format, unicité, round-trip |
| `DuelProtocol.swift` | `enum DuelEvent` (cf. §5), tout `Codable` | encode/decode round-trip |
| `DuelMatch.swift` | machine à états pure (cf. §10) + `ranking(scores:) -> [Standing]` avec gestion des égalités | toutes transitions + ex aequo |

### Nouveau dans `App/`

| Fichier | Rôle |
|---|---|
| `App/Multiplayer/RealtimeService.swift` | seul fichier qui importe le SDK Supabase. `connect(roomCode:)`, `track(presence:)`, `send(DuelEvent)`, `events: AsyncStream<DuelEvent>`, `presence: [Player]` |
| `App/Multiplayer/DuelController.swift` | `@Observable @MainActor`, équivalent multijoueur du `GameController`. Détient le `RealtimeService` + la `DuelMatch` + le `liveScores`, instancie le `GameController` existant au coup d'envoi, calcule le classement final |
| `App/Features/Duel/DuelEntryView.swift` | "Créer une partie" / "Rejoindre avec un code" |
| `App/Features/Duel/DuelLobbyView.swift` | salon : code partageable, liste des 2 à 6 joueurs en live, bouton "Lancer" (host) |
| `App/Features/Duel/LiveScoreboardView.swift` | overlay mini-classement affiché pendant la partie |
| `App/Features/Duel/DuelResultsView.swift` | podium classé N joueurs (réutilise des composants de `ResultsView`) |

### Modifications sur l'existant (chirurgicales)

- `Sources/KwizzCore/GameMode.swift` : `comingSoon` → `false` pour `.duel`,
  `subtitle` → "2 à 6 joueurs en ligne".
- `App/Navigation/Router.swift` : routes `.duelEntry`, `.duelLobby(code, isHost)`,
  et `activeDuel: DuelController?`. Au coup d'envoi, le `DuelController` pose
  l'`activeGame` (le `fullScreenCover` existant rejoue le quiz tel quel).
- `App/Features/Play/ModeSelectView.swift` : le mode Duel route vers
  `DuelEntryView` au lieu d'être grisé.
- `App/GameController.swift` :
  - aujourd'hui `finishGame()` calcule `duelWon` contre `duelBotScore` (le bot).
    En vrai duel, on n'utilise plus le bot : ajouter `opponent: OpponentSource`
    (`.bot` / `.remote`) pour que `finishGame` n'applique pas la logique bot en
    `.remote` ; le classement est décidé par le `DuelController` via
    `DuelMatch.ranking`.
  - ajouter le callback `onProgress` invoqué dans `answer()` pour le live.
- `App/PlayerStore.swift` : `makeSession` accepte une variante qui prend des
  questions **déjà fournies** (celles reçues de l'host) au lieu de les tirer.

## 9. Machine à états (`DuelMatch`)

```
.idle
  └─ join → .lobby(players:[Player])           // presence join/leave met à jour la liste
       └─ start (host) → .countdown            // room verrouillée, questions reçues
            └─ 3·2·1 → .playing(live:[LiveState])
                 └─ tous finished → .finished(standings:[Standing])
```

Cas annexes gérés dans la même machine : un joueur qui `leave` en `.lobby`
(retiré de la liste), en `.playing` (marqué "parti", exclu du classement ou laissé
avec son dernier score selon le réglage), et timeout si un joueur ne renvoie jamais
`finished`.

## 10. Robustesse / cas limites

- **Room pleine** (6 joueurs) : refuser le join, message clair.
- **Code introuvable** : aucune presence après un court délai → "room introuvable".
- **Collision de code** : à la création, l'host lit la presence du channel ; si
  occupé, régénère un code.
- **Joueur qui quitte** (presence leave) en lobby ou en partie : message, le reste
  continue. Pas de blocage si l'host part en lobby (promotion d'un autre joueur en
  host, ou fin de room).
- **Join pendant la partie** : interdit, la room est verrouillée au `start`.
- **Réseau coupé / reconnexion** : tentative de re-subscribe ; au-delà d'un délai,
  retour au lobby avec message.
- **Double "Lancer"** : ignoré si déjà en `.countdown`/`.playing`.

## 11. Phases & effort estimé

| Phase | Contenu | Effort |
|---|---|---|
| 0 | Plomberie : SPM `supabase-swift`, config URL/clé `anon` en `.xcconfig`, smoke test channel | ~0,5 j |
| 1 | `RoomCode` + tests, `RealtimeService` (connect/track/presence), `DuelEntryView`, `DuelLobbyView` multi (2-6) | ~1,5 j |
| 2 | Coup d'envoi : build + broadcast `start`, countdown, `QuizSession` à partir des questions reçues | ~0,5 j |
| 3 | Partie via `GameController`, broadcast `progress`, `LiveScoreboardView`, broadcast `finished` | ~1,5 j |
| 4 | Podium classé `DuelResultsView`, application des récompenses (pièces/XP + bonus) | ~0,5 j |
| 5 | Robustesse (déconnexions, timeouts, room pleine, collisions) | ~1 j |
| 6 | Polish (partage du code, haptique, anti-triche léger, "en attente de X...") | ~0,5 j |

**Total : ~6 à 7 jours** pour une version multijoueur solide avec classement live.

## 12. Tests

- **KwizzCore** (`swift run KwizzCoreCheck` + Swift Testing) : `RoomCode`
  (format/unicité), `DuelEvent` (round-trip Codable), `DuelMatch` (transitions,
  classement, ex aequo, joueur parti).
- **Manuel** : 2 à 3 simulateurs / appareils en parallèle pour le flux Realtime
  (lobby, live, podium, déconnexion).

## 13. Risques / points d'attention

- **`project.pbxproj` écrit à la main** : ajouter la dépendance SPM
  `supabase-swift` demande soit une édition manuelle du pbxproj
  (`XCRemoteSwiftPackageReference` + `packageProductDependencies`), soit une
  ouverture unique dans Xcode. Seul vrai point pénible du chantier.
- **Realtime à activer** côté dashboard Supabase ; vérifier que le Broadcast
  fonctionne avec la clé `anon` (channels publics pour le MVP ; channels
  "autorisés" possibles plus tard si abus).
- **Versions de contenu** : neutralisé par la diffusion des questions par l'host
  (cf. §6), mais garder en tête si on revient un jour au partage de seed seul.
- **Auth différée** : pas de compte pour le MVP ; relier au système de
  profils/`auth.users` (déjà prévu dans `supabase/schema.sql`) reste une phase
  ultérieure.

## 14. Modèle de score (révisé) : synchronisé, premier bon = 1 point

Le modèle "chacun à son rythme, on compare les scores" a été remplacé par un mode
**synchronisé facon Kahoot**, à la demande produit :

- Tout le monde voit la **même question en même temps** (l'hôte l'ouvre via
  `beginQuestion`).
- Chaque joueur répond une fois ; le client mesure son **temps de réponse** (ms).
- La question se ferme quand **tout le monde a répondu** ou au bout de **15 s**.
- L'hôte calcule le gagnant = **la bonne réponse la plus rapide** → **1 point**,
  tous les autres **0**. Il diffuse le résultat + le snapshot des réponses
  (`reveal`), donc tout le monde voit la même chose et le même classement.
- À la fin : **podium par points**, **gains** du joueur, et **récap question par
  question** (bonne réponse, explication, ce que chacun a répondu, qui a pris le
  point).

Compromis assumé : l'arbitrage du "premier" se fait sur le temps mesuré localement,
donc une grosse latence peut désavantager un peu. Acceptable entre amis.

## 15. État d'implémentation (2026-06-18)

Logique pure : `swift run KwizzCoreCheck` à **201/201**. La couche App n'a pas pu
être compilée hors Xcode (SwiftUI + pas de runtime simulateur) : prévoir une passe
de compilation Xcode.

KwizzCore (pur, testé) :
- `RoomCode.swift`, `DuelProtocol.swift` (`DuelPlayer`, `DuelAnswer`, `DuelEvent`:
  `hello`/`start`/`beginQuestion`/`answer`/`reveal`/`finish`),
  `DuelMatch.swift` (machine à états synchronisée 2-6, réponses par joueur, gagnant
  au plus rapide, points, classement, données de récap, presence, forfait).
- `GameMode.duel` activé (`comingSoon = false`).

App :
- `App/Multiplayer/` : `DuelTransport` (protocole + factory), `MockDuelTransport`
  (adversaires simulés répondant par question), `SupabaseConfig`,
  `SupabaseRealtimeTransport` (gaté `#if canImport(Supabase)`), `DuelController`
  (coordination hôte : timers question/reveal, calcul du gagnant, récompenses).
- `App/Features/Duel/` : `DuelEntryView`, `DuelRoomView` (conteneur qui switche par
  phase), `DuelLobbyView`, `DuelGameView` (question + révélation), `LiveScoreboardView`,
  `DuelResultsView` (podium + récap).
- Modifs : `PlayerStore` (`clientID`, `duelPlayer`, `makeDuelQuestions`),
  `Router` (`activeDuel`, `createDuel`/`joinDuel`, nettoyage `goHome`),
  `Route.duelEntry`, `ModeSelectView`, `Theme.Accent.hex`.
  `GameController` est resté inchangé (le duel n'utilise plus le flux solo).
- Secrets : `.env` (référence, service_role), `App/Secrets.xcconfig` (lu par l'app, versionné).

Tant que `Secrets.xcconfig` n'est pas branché dans l'Info.plist, ou que le package
Supabase n'est pas ajouté, l'app tourne automatiquement sur le `MockDuelTransport`
(adversaires simulés), donc tout le flux est testable immédiatement.

## 16. Étapes Xcode (à faire une fois) - ✅ faites

1. **Ouvrir le projet** dans Xcode 16+. Les nouveaux fichiers sous `App/` et
   `Sources/KwizzCore/` sont inclus automatiquement (synchronized groups), rien à
   glisser.
2. **Ajouter le package Supabase** : File > Add Package Dependencies >
   `https://github.com/supabase/supabase-swift` > Add Package > cocher le produit
   **Supabase** pour la cible Kwizz. (Cela modifie le `project.pbxproj`, normal.)
3. **Brancher le `.xcconfig`** : le fichier vit en `App/Secrets.xcconfig` (sans cible
   de compilation) et est affecté aux 4 configurations, projet Kwizz > onglet **Info**
   > **Configurations**.
4. **Exposer les clés dans l'Info.plist** : dans les "Custom iOS Target Properties"
   (ou l'Info.plist), ajouter deux String :
   - `SUPABASE_URL` = `$(SUPABASE_HOST)`
   - `SUPABASE_ANON_KEY` = `$(SUPABASE_ANON_KEY)`
5. **Realtime** : rien à activer. Le duel utilise Broadcast + Presence, actifs par
   défaut avec la clé `anon` (la section "Database > Replication" ne concerne que
   les "Postgres Changes" par table, qu'on n'utilise pas). Le panneau **Realtime**
   de la barre latérale est juste un inspecteur pour observer le channel `room:CODE`.
6. **Lancer** sur un simulateur. Pour tester un vrai duel : lancer sur **deux
   simulateurs** (ou deux appareils), l'un crée la room, l'autre rejoint avec le code.

Vérification de l'API SDK : `SupabaseRealtimeTransport` cible supabase-swift v2.x.
Si la compilation accroche, les 3 points à ajuster sont `broadcastStream`,
`presenceChange`, et `channel.track(state:)` (commentés dans le fichier).
