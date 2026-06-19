# Plan : Ligue classée 1v1 + Classement mensuel des défis

Statut : plan d'implémentation, non commencé. Cible : phase backend du `PLAN.md`,
au-dessus de l'infra Realtime décrite dans `PLAN_MULTIJOUEUR.md`.

## 1. Objectif

Deux systèmes compétitifs **distincts**, demandés produit :

- **A. Ligue classée 1v1** : matchmaking, duels synchronisés, montée en paliers
  **Bronze → Argent → Or → Platine → Diamant → Master → Grand Master**. Ladder
  persistant avec soft reset léger par saison.
- **B. Classement mensuel des défis du jour** : classement **mondial** basé
  **uniquement** sur le Défi du jour, avec **récompenses** de fin de mois.

Les deux partagent un seul prérequis : une identité durable (comptes).

## 2. Décisions produit validées

- **Auth anonyme** (Supabase) : connexion automatique, sans email ni mot de passe.
  L'identité reste stable et multi-appareils ; on pourra relier un compte
  Apple/email plus tard. Reste "simple et épuré".
- **Ligue A** : 1v1 uniquement, rating persistant, soft reset mensuel.
- **Mensuel B** : classement mondial, somme des **meilleurs jours du mois**,
  récompenses = coffres + coins par palier + **un cosmétique exclusif de saison**.
- Réutilisation maximale de l'existant : `DuelMatch` (modèle synchronisé "premier
  bon = 1 point"), `DailyChallenge` (déterministe), le schéma `supabase/schema.sql`.

## 3. Prérequis commun : auth anonyme + sync profil

Aujourd'hui l'identité d'un joueur est un `clientID` (UUID local) + `pseudo`
(`DuelPlayer` dans `Sources/KwizzCore/DuelProtocol.swift`), sans persistance
serveur. Une ligue a besoin de l'inverse.

1. **Auth** : au premier lancement, `supabase.auth.signInAnonymously()`. L'`UUID`
   Auth (`auth.users.id`) devient l'identité de référence. Le trigger
   `handle_new_user()` (déjà au schéma) crée la ligne `profiles` automatiquement.
2. **Sync profil** : pousser `PlayerProfile` (pseudo, total_xp, coins, stats) vers
   `profiles`. Le schéma reflète déjà 1:1 le modèle Swift. Sync à l'ouverture et
   après chaque partie (upsert PostgREST).
3. **Frontière de projet** : la logique pure (rating, agrégation, paliers) va dans
   `Sources/KwizzCore` et passe par `swift run KwizzCoreCheck`. Le réseau et l'auth
   restent dans `App/` et dans les Edge Functions.

---

## A. Ligue classée 1v1

### A.1 Le mode de jeu : "Duel Éclair classé"

Match synchronisé qui réutilise le modèle de `DuelMatch` (`Sources/KwizzCore/DuelMatch.swift`,
règle "la bonne réponse la plus rapide prend 1 point") :

- **Premier à 4 points** (best of 7 questions max).
- Même question affichée aux deux joueurs **en même temps** ; 10 s par question.
- La **bonne réponse la plus rapide** prend le point ; si les deux se trompent ou
  timeout, personne ne marque.
- Égalité 3-3 → question de **mort subite**.
- À la fin : gagnant **+rating**, perdant **-rating** (cf. A.3).

La différence avec le duel entre amis : ici l'arbitrage **ne peut pas** être confié
à un client (host), parce que les adversaires sont des inconnus. D'où le serveur
autoritatif (A.4).

### A.2 Paliers

Un seul **rating ELO** côté serveur ; les paliers sont des tranches de rating.
L'UI affiche le palier + une barre de progression dans la tranche.

| Palier | Rating |
|---|---|
| Bronze | 0 - 1199 |
| Argent | 1200 - 1399 |
| Or | 1400 - 1599 |
| Platine | 1600 - 1799 |
| Diamant | 1800 - 1999 |
| Master | 2000 - 2199 |
| Grand Master | 2200 + |

- Départ : **1000** (Bronze), après **5 matchs de placement** non comptés en palier
  affiché.
- Soft reset par saison (mensuel) : `nouveau = round(1000 + (rating - 1000) * 0,5)`
  (on resserre vers la moyenne sans tout effacer).

### A.3 Calcul du rating (ELO, pur, testable)

Dans `Sources/KwizzCore/EloRating.swift` (nouveau, pur) :

```swift
public enum EloRating {
    public static let start = 1000
    public static let k = 32

    /// Espérance de victoire de A contre B.
    public static func expected(_ a: Int, _ b: Int) -> Double {
        1.0 / (1.0 + pow(10.0, Double(b - a) / 400.0))
    }

    /// Nouveau rating de A après un résultat (scoreA = 1 victoire, 0 défaite, 0.5 nul).
    public static func updated(_ a: Int, against b: Int, scoreA: Double) -> Int {
        a + Int((Double(k) * (scoreA - expected(a, b))).rounded())
    }

    public static func tier(_ rating: Int) -> Tier { /* tranches du tableau A.2 */ }
}
```

Tests `KwizzCoreCheck` : symétrie des deltas, bornes de palier, monotonie, nul.

### A.4 Infra : matchmaking + match autoritatif

On ne fait **pas** tourner un serveur de jeu permanent. On combine :

- **État du match en base** (table `ranked_matches`), poussé aux deux clients par
  **Realtime Postgres Changes** (le client s'abonne à sa ligne de match).
- **Actions via Edge Functions** (Deno/TS) stateless, seules autorisées à écrire la
  logique sensible (questions, scores, rating). Le client n'écrit jamais directement
  ces tables (RLS en lecture seule sur sa propre ligne).

Flux :

```
File d'attente            Edge Function                 Realtime (Postgres Changes)
──────────────            ─────────────                 ───────────────────────────
client → ranked-enqueue ─► insère ranked_queue
                          matcher apparie 2 ratings proches
                          crée ranked_matches{questions, idx:0, deadline}
                                                        ─► les 2 clients reçoivent le match
client → ranked-answer ──► valide, borne elapsedMs [0,10000], écrit ranked_answers
                          si les 2 ont répondu (ou deadline passée) :
                            calcule le gagnant de la question, avance idx + deadline
                                                        ─► les 2 clients voient le reveal + score
                          quand 4 points atteints ou 7 questions jouées :
                            finalise, calcule deltas ELO, écrit ranked_stats
                                                        ─► podium classé
```

Points clés :
- **Questions servies serveur** : `ranked-enqueue`/le matcher tire les questions
  depuis la table `questions` (`status='published'`) et les stocke dans
  `ranked_matches.questions` (jsonb). Le client ne les reçoit qu'une par une (la
  fonction ne révèle que la question d'index courant) → anti-triche.
- **Timing** : le client envoie `elapsed_ms` (temps entre l'affichage et le tap),
  borné serveur. Compromis assumé identique à `PLAN_MULTIJOUEUR.md` §14 (latence
  locale). La règle "plus rapide correct gagne" est celle de `DuelMatch.computeWinner`,
  réimplémentée en TS côté Edge Function.
- **Timeout / abandon** : un balayage `pg_cron` (toutes les minutes) résout les
  matchs dont la `deadline` est dépassée et marque forfait les inactifs.

### A.5 Découpage

**KwizzCore (pur, testé)**
| Fichier | Rôle |
|---|---|
| `EloRating.swift` | calcul ELO + paliers (A.3) |
| `RankedMatch.swift` | (optionnel) machine à états client réutilisant `DuelMatch` pour l'affichage live |

**App (SwiftUI + réseau)**
| Fichier | Rôle |
|---|---|
| `App/Multiplayer/RankedService.swift` | `enqueue()`, `submitAnswer()`, abonnement Realtime à la ligne de match |
| `App/Features/Ranked/RankedHomeView.swift` | palier actuel, barre de progression, bouton "Trouver un adversaire" |
| `App/Features/Ranked/MatchmakingView.swift` | recherche d'adversaire (file d'attente) |
| `App/Features/Ranked/RankedGameView.swift` | duel synchronisé (réutilise `DuelGameView`) |
| `App/Features/Ranked/RankedResultView.swift` | victoire/défaite + delta de rating + nouveau palier |

**Backend (Supabase)** : tables A.6, Edge Functions A.7, cron de balayage + reset.

### A.6 Schéma SQL (à ajouter à `supabase/schema.sql`)

```sql
-- Saisons (partagées A et B). kind distingue ladder vs mensuel.
create table if not exists seasons (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('ranked','monthly')),
  label      text not null,                       -- "Juin 2026"
  starts_at  timestamptz not null,
  ends_at    timestamptz not null,
  closed     boolean not null default false
);

-- Rating persistant par joueur.
create table if not exists ranked_stats (
  user_id          uuid primary key references profiles(id) on delete cascade,
  rating           int not null default 1000 check (rating >= 0),
  peak_rating      int not null default 1000,
  wins             int not null default 0,
  losses           int not null default 0,
  placement_played int not null default 0,
  season_id        uuid references seasons(id),
  updated_at       timestamptz not null default now()
);

-- File d'attente du matchmaking.
create table if not exists ranked_queue (
  user_id     uuid primary key references profiles(id) on delete cascade,
  rating      int not null,
  enqueued_at timestamptz not null default now()
);

-- Un match 1v1.
create table if not exists ranked_matches (
  id            uuid primary key default gen_random_uuid(),
  player_a      uuid not null references profiles(id),
  player_b      uuid not null references profiles(id),
  questions     jsonb not null,                   -- [Question] résolues (réponses mélangées)
  current_index int  not null default 0,
  deadline      timestamptz,                      -- fin de la question courante
  status        text not null default 'playing'   -- 'playing' | 'finished' | 'forfeit'
                  check (status in ('playing','finished','forfeit')),
  score_a       int not null default 0,
  score_b       int not null default 0,
  winner        uuid,                             -- NULL tant que non fini ; égalité impossible (mort subite)
  delta_a       int,
  delta_b       int,
  created_at    timestamptz not null default now(),
  finished_at   timestamptz
);

create index if not exists idx_ranked_matches_open
  on ranked_matches(status, deadline) where status = 'playing';

-- Réponses par question (1 par joueur).
create table if not exists ranked_answers (
  match_id       uuid not null references ranked_matches(id) on delete cascade,
  question_index int not null,
  user_id        uuid not null references profiles(id),
  answer_index   int,                             -- NULL = timeout
  correct        boolean not null,
  elapsed_ms     int not null check (elapsed_ms between 0 and 10000),
  received_at    timestamptz not null default now(),
  primary key (match_id, question_index, user_id)
);

-- RLS : un joueur LIT ses stats et ses matchs ; il n'ÉCRIT jamais (tout passe
-- par les Edge Functions en service_role).
alter table ranked_stats   enable row level security;
alter table ranked_matches enable row level security;
alter table ranked_answers enable row level security;

create policy "ranked_stats : lecture du sien"
  on ranked_stats for select using (auth.uid() = user_id);
create policy "ranked_matches : lecture de mes matchs"
  on ranked_matches for select using (auth.uid() = player_a or auth.uid() = player_b);
create policy "ranked_answers : lecture de mes matchs"
  on ranked_answers for select using (exists (
    select 1 from ranked_matches m where m.id = match_id
      and (m.player_a = auth.uid() or m.player_b = auth.uid())
  ));
-- Le classement des paliers (lecture publique) :
create or replace view ranked_leaderboard as
  select p.id as user_id, p.pseudo, rs.rating, rs.wins, rs.losses,
         rank() over (order by rs.rating desc) as rank
  from ranked_stats rs join profiles p on p.id = rs.user_id;
grant select on ranked_leaderboard to anon, authenticated;
```

> Activer **Realtime** (Postgres Changes) sur `ranked_matches` dans le dashboard,
> pour que les clients reçoivent l'avancement de leur ligne.

### A.7 Edge Functions (Deno/TS)

```
supabase/functions/ranked-enqueue/index.ts
  POST {}  (auth requis)
  → met le joueur en file ; si un adversaire de rating proche attend,
    crée le match (tire N questions, mélange les réponses) et renvoie {matchId}.
    Sinon renvoie {queued:true}. Service_role pour écrire.

supabase/functions/ranked-answer/index.ts
  POST { matchId, questionIndex, answerIndex|null, elapsedMs }
  → vérifie que l'appelant est un joueur du match et que questionIndex == current_index,
    borne elapsedMs, calcule correct côté serveur (la bonne réponse n'est jamais
    envoyée au client), écrit ranked_answers.
    Si les 2 ont répondu OU deadline passée :
      - décide le point (plus rapide correct),
      - avance current_index + nouvelle deadline, OU finalise (4 pts / 7 questions
        / mort subite) : calcule deltas ELO (EloRating en TS), met à jour
        ranked_stats des deux, status='finished', winner.
    Renvoie l'état courant (sans la question suivante).

(balayage) pg_cron toutes les minutes :
  → matchs 'playing' à deadline dépassée et sans réponse : forfait / résolution.
```

Le client n'a **que** deux appels (`enqueue`, `answer`) ; tout le reste arrive par
Realtime. C'est ce qui rend le mode "vrai multijoueur" sans serveur permanent.

### A.8 Anti-triche (ligue)

- Questions jamais envoyées d'avance (révélées une par une par `ranked-answer`).
- `correct` recalculé serveur ; `elapsed_ms` borné [0, 10000].
- Rating écrit uniquement par Edge Function service_role (RLS interdit l'écriture
  client).
- Détection de collusion / déconnexions répétées : à surveiller en phase 2 (log
  `ranked_matches`/`ranked_answers` suffisant pour auditer plus tard).

---

## B. Classement mensuel des Défis du jour

Beaucoup moins cher : la déterminisme et la table existent déjà.

### B.1 Principe

- Le **Défi du jour** est déjà identique pour tous (`DailyChallenge.questions(from:day:)`,
  10 questions, seed = la date). Une **seule tentative/jour** est déjà garantie par
  la PK de `daily_results (day_index, user_id)`.
- Classement mensuel **mondial** = **somme des meilleurs jours du mois** (défaut :
  les **25 meilleurs jours** sur 30, pour ne pas punir un jour manqué).
- `day_index` suit le format compact `AAAAMMJJ` de `DailyChallenge.day(...)` (ex.
  20260618) que renvoie `store.today()` (vérifié : `PlayerStore.today()` ligne 53-55),
  donc **le mois = `day_index / 100`** (202606).

### B.2 Scoring serveur (anti-triche)

Edge Function `submit-daily` :

```
supabase/functions/submit-daily/index.ts
  POST { dayIndex, answers: [int|null] }   (auth requis, 10 réponses)
  → recharge le set déterministe du jour côté serveur (mêmes questions + seed),
    recalcule le nombre d'erreurs et le score (barème Economy.defiReward / scoring
    arcade), upsert daily_results (PK = 1 tentative/jour). Refuse un 2e envoi.
```

Le client affiche le score localement ; le **score officiel** du classement est
celui que le serveur recalcule. On ne fait confiance à aucun score envoyé brut.

### B.3 Schéma SQL (ajouts ; `daily_results` existe déjà)

```sql
-- Classement mensuel = somme des N meilleurs jours par joueur.
create or replace view monthly_challenge_leaderboard as
  with ranked_days as (
    select user_id,
           day_index / 100 as month,             -- AAAAMM
           score,
           row_number() over (
             partition by user_id, day_index / 100 order by score desc
           ) as day_rank
    from daily_results
  )
  select month, user_id, sum(score) as total, count(*) as days_counted
  from ranked_days
  where day_rank <= 25                            -- meilleurs 25 jours
  group by month, user_id;

-- Lots distribués à la clôture du mois.
create table if not exists monthly_rewards (
  month       int  not null,                      -- AAAAMM
  user_id     uuid not null references profiles(id) on delete cascade,
  rank        int  not null,
  coins       int  not null default 0,
  chests      int  not null default 0,
  cosmetic_id text references avatar_items(id),   -- cosmétique exclusif (top palier)
  granted     boolean not null default false,     -- appliqué côté app ?
  created_at  timestamptz not null default now(),
  primary key (month, user_id)
);

alter table monthly_rewards enable row level security;
create policy "monthly_rewards : lecture du sien"
  on monthly_rewards for select using (auth.uid() = user_id);
grant select on monthly_challenge_leaderboard to anon, authenticated;
```

> Le cosmétique exclusif viole l'actuel `check (price > 0 or unlock_level is not null)`
> de `avatar_items`. Ajouter un drapeau `reward_only boolean default false` et
> assouplir la contrainte en `price > 0 or unlock_level is not null or reward_only`.

### B.4 Clôture mensuelle (cron)

`pg_cron`, le 1er du mois à 00:05 :

```
1. fige le classement du mois écoulé (monthly_challenge_leaderboard) ;
2. écrit monthly_rewards par palier de rang :
     rang 1        → cosmétique de saison + 3 coffres + 2000 coins
     rang 2-10     → 2 coffres + 1000 coins
     rang 11-100   → 1 coffre + 300 coins
     (barème indicatif, cohérent avec l'économie serrée du jeu) ;
3. (option) crée la season 'monthly' suivante.
```

Côté app : au lancement, lire `monthly_rewards` non `granted`, appliquer les gains
via `PlayerStore`, marquer `granted=true`. Affichage d'un écran "Récompenses de
saison".

### B.5 App

| Fichier | Rôle |
|---|---|
| `App/Features/Ranked/MonthlyChallengeView.swift` | classement mondial du mois (top + ta position), envoi du score via `submit-daily` |
| écran récompenses de saison | applique `monthly_rewards` non distribués |

---

## C. Phases & effort estimé

| Phase | Contenu | Effort |
|---|---|---|
| 0 | Auth anonyme + sync `PlayerProfile` → `profiles` | ~1 j |
| B1 | Mensuel : `submit-daily`, vue + classement, écran | ~1 j |
| B2 | Cron de clôture + récompenses + cosmétique exclusif | ~1,5 j |
| A1 | `EloRating` + tests, `ranked_*` tables, RLS | ~1 j |
| A2 | `ranked-enqueue` + matchmaking + écran file d'attente | ~2 j |
| A3 | `ranked-answer` (arbitrage, avancement, ELO) + balayage cron | ~2,5 j |
| A4 | Écrans duel classé (réutilise `DuelGameView`) + résultat/palier | ~2 j |
| A5 | Soft reset de saison + robustesse (forfaits, reconnexion) | ~1,5 j |

**Total : ~12-13 jours.** On livre **B avant A** : rapide, prouve la boucle
compétitive et l'auth, sans le risque réseau du 1v1.

## D. Tests

- **KwizzCore** (`swift run KwizzCoreCheck` + Swift Testing) : `EloRating`
  (symétrie, paliers, nul, monotonie), agrégation "meilleurs N jours" si portée en
  pur.
- **Edge Functions** : tests Deno (arbitrage du gagnant, bornage `elapsed_ms`,
  refus de double soumission, calcul ELO identique à Swift).
- **Manuel** : 2 simulateurs pour un duel classé complet ; vérifier la clôture
  mensuelle sur une saison de test.

## E. Risques / points d'attention

- **`project.pbxproj` à la main** : ajouter le SDK Supabase est le seul vrai point
  pénible (cf. `PLAN_MULTIJOUEUR.md` §13/§16).
- **Realtime Postgres Changes** à activer sur `ranked_matches` ; vérifier le débit
  (une poignée d'updates par match, négligeable).
- **Cohérence `day_index`** : vérifié, `store.today()` renvoie `AAAAMMJJ`, donc
  `day_index / 100` donne bien le mois (`AAAAMM`). Ne pas changer ce format sans
  adapter la vue B.3.
- **Latence du "plus rapide"** : arbitrage sur temps local borné, acceptable mais
  pas parfait sur très mauvaise connexion (compromis déjà acté §14 du plan duel).
- **Auth différée → reliée** : démarrer en anonyme, prévoir la liaison vers un
  compte Apple/email plus tard sans casser `ranked_stats`/`daily_results`.
