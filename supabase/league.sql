-- =============================================================================
-- Kwizz - Ligue classée 1v1 + Classement mensuel des défis
-- =============================================================================
-- À exécuter dans le SQL Editor de Supabase APRÈS schema.sql (qui crée profiles,
-- avatar_items, daily_results, etc.). Idempotent : ré-exécutable sans casse.
-- Voir docs/PLAN_LIGUE.md pour le détail du modèle.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Saisons (partagées : ladder classé + classement mensuel)
-- -----------------------------------------------------------------------------
create table if not exists seasons (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('ranked','monthly')),
  label      text not null,                       -- "Juin 2026"
  starts_at  timestamptz not null,
  ends_at    timestamptz not null,
  closed     boolean not null default false
);

-- =============================================================================
-- A. LIGUE CLASSÉE 1v1
-- =============================================================================

-- A.1 Rating persistant par joueur (ELO ; les paliers Bronze..Grand Master sont
--     dérivés du rating côté app, cf. EloRating.swift).
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

drop trigger if exists trg_ranked_stats_updated_at on ranked_stats;
create trigger trg_ranked_stats_updated_at
  before update on ranked_stats
  for each row execute function set_updated_at();

-- A.2 File d'attente du matchmaking.
create table if not exists ranked_queue (
  user_id     uuid primary key references profiles(id) on delete cascade,
  rating      int not null,
  enqueued_at timestamptz not null default now()
);

create index if not exists idx_ranked_queue_rating on ranked_queue(rating, enqueued_at);

-- A.3 Un match 1v1. Les questions sont stockées résolues (réponses déjà mélangées) ;
--     l'Edge Function ne révèle au client que la question d'index courant.
create table if not exists ranked_matches (
  id            uuid primary key default gen_random_uuid(),
  player_a      uuid not null references profiles(id),
  player_b      uuid not null references profiles(id),
  questions     jsonb not null,
  current_index int  not null default 0,
  deadline      timestamptz,
  status        text not null default 'playing'
                  check (status in ('playing','finished','forfeit')),
  score_a       int not null default 0,
  score_b       int not null default 0,
  winner        uuid,
  delta_a       int,
  delta_b       int,
  created_at    timestamptz not null default now(),
  finished_at   timestamptz
);

create index if not exists idx_ranked_matches_open
  on ranked_matches(status, deadline) where status = 'playing';
create index if not exists idx_ranked_matches_players
  on ranked_matches(player_a, player_b);

-- A.4 Réponses par question (1 par joueur). elapsed_ms borné côté serveur.
create table if not exists ranked_answers (
  match_id       uuid not null references ranked_matches(id) on delete cascade,
  question_index int not null,
  user_id        uuid not null references profiles(id),
  answer_index   int,                             -- NULL = timeout
  correct        boolean not null,
  elapsed_ms     int not null check (elapsed_ms between 0 and 15000),
  received_at    timestamptz not null default now(),
  primary key (match_id, question_index, user_id)
);

-- A.5 RLS : un joueur LIT ses stats et ses matchs ; il n'ÉCRIT jamais.
--     Toute écriture passe par les Edge Functions (clé service_role, qui bypass RLS).
alter table ranked_stats   enable row level security;
alter table ranked_matches enable row level security;
alter table ranked_answers enable row level security;
alter table ranked_queue   enable row level security;

drop policy if exists "ranked_stats : lecture du sien" on ranked_stats;
create policy "ranked_stats : lecture du sien"
  on ranked_stats for select using (auth.uid() = user_id);

drop policy if exists "ranked_queue : lecture du sien" on ranked_queue;
create policy "ranked_queue : lecture du sien"
  on ranked_queue for select using (auth.uid() = user_id);

drop policy if exists "ranked_matches : lecture de mes matchs" on ranked_matches;
create policy "ranked_matches : lecture de mes matchs"
  on ranked_matches for select using (auth.uid() = player_a or auth.uid() = player_b);

drop policy if exists "ranked_answers : lecture de mes matchs" on ranked_answers;
create policy "ranked_answers : lecture de mes matchs"
  on ranked_answers for select using (exists (
    select 1 from ranked_matches m
    where m.id = match_id and (m.player_a = auth.uid() or m.player_b = auth.uid())
  ));

-- A.6 Classement public des paliers.
create or replace view ranked_leaderboard as
  select p.id as user_id, p.pseudo, rs.rating, rs.wins, rs.losses,
         rank() over (order by rs.rating desc) as rank
  from ranked_stats rs
  join profiles p on p.id = rs.user_id;

grant select on ranked_leaderboard to anon, authenticated;

-- =============================================================================
-- B. CLASSEMENT MENSUEL DES DÉFIS DU JOUR
-- =============================================================================
-- daily_results existe déjà (schema.sql) avec PK (day_index, user_id) = 1
-- tentative/jour/joueur. day_index est au format AAAAMMJJ (DailyChallenge.day),
-- donc le mois = day_index / 100 (ex. 20260618 -> 202606).

-- B.1 Classement mensuel mondial = somme des 25 meilleurs jours du mois.
--     Inclut le pseudo (join profiles) et le rang, pour un affichage direct.
--     DROP + CREATE (et pas CREATE OR REPLACE) car les colonnes ont changé d'ordre.
drop view if exists monthly_challenge_leaderboard;
create view monthly_challenge_leaderboard as
  with ranked_days as (
    select user_id,
           day_index / 100 as month,
           score,
           row_number() over (
             partition by user_id, day_index / 100 order by score desc
           ) as day_rank
    from daily_results
  ),
  totals as (
    select month, user_id, sum(score) as total, count(*) as days_counted
    from ranked_days
    where day_rank <= 25
    group by month, user_id
  )
  select t.month, t.user_id, p.pseudo, t.total, t.days_counted,
         rank() over (partition by t.month order by t.total desc) as rank
  from totals t
  join profiles p on p.id = t.user_id;

grant select on monthly_challenge_leaderboard to anon, authenticated;

-- B.2 Cosmétique exclusif de saison : avatar_items autorise aujourd'hui price>0
--     OU unlock_level. On ajoute un 3e cas "récompense seule".
alter table avatar_items add column if not exists reward_only boolean not null default false;
alter table avatar_items drop constraint if exists buy_or_unlock;
alter table avatar_items add constraint buy_or_unlock
  check (price > 0 or unlock_level is not null or reward_only);

-- B.3 Lots distribués à la clôture du mois (appliqués côté app quand granted=false).
create table if not exists monthly_rewards (
  month       int  not null,                      -- AAAAMM
  user_id     uuid not null references profiles(id) on delete cascade,
  rank        int  not null,
  coins       int  not null default 0,
  chests      int  not null default 0,
  cosmetic_id text references avatar_items(id),
  granted     boolean not null default false,
  created_at  timestamptz not null default now(),
  primary key (month, user_id)
);

alter table monthly_rewards enable row level security;

drop policy if exists "monthly_rewards : lecture du sien" on monthly_rewards;
create policy "monthly_rewards : lecture du sien"
  on monthly_rewards for select using (auth.uid() = user_id);
-- L'app marque granted=true après avoir appliqué le lot ; elle ne touche à rien d'autre.
drop policy if exists "monthly_rewards : marquage du sien" on monthly_rewards;
create policy "monthly_rewards : marquage du sien"
  on monthly_rewards for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =============================================================================
-- C. CLÔTURE MENSUELLE (récompenses)
-- =============================================================================
-- Fige le classement d'un mois (AAAAMM) et écrit les lots dans monthly_rewards.
-- Idempotent (on conflict do nothing). L'app applique ensuite les lots non
-- réclamés (granted=false) côté client, puis les marque granted=true.
create or replace function close_month(p_month int) returns void as $$
begin
  insert into monthly_rewards (month, user_id, rank, coins, chests)
  select month, user_id, rank,
         case when rank = 1 then 5000 when rank <= 10 then 2000 when rank <= 100 then 500 else 0 end as coins,
         case when rank = 1 then 5    when rank <= 10 then 3    when rank <= 100 then 1   else 0 end as chests
  from monthly_challenge_leaderboard
  where month = p_month and rank <= 100
  on conflict (month, user_id) do nothing;
end;
$$ language plpgsql security definer set search_path = public;

-- Test manuel : select close_month(202606);
-- Planification (le 1er de chaque mois à 00:05 UTC, clôture le mois précédent).
-- Prérequis : activer l'extension pg_cron (Database > Extensions), puis lancer 1x :
-- select cron.schedule(
--   'close-monthly-leaderboard', '5 0 1 * *',
--   $$ select close_month(
--        (extract(year  from (now() - interval '1 month'))*100
--       + extract(month from (now() - interval '1 month')))::int ); $$
-- );

-- =============================================================================
-- NOTE : les fonctions d'arbitrage du 1v1 classé (matchmaking, gagnant de
-- question, ELO) vivront dans des Edge Functions (phases A2/A3), pas ici. Le
-- balayage des matchs expirés (sweep_ranked) viendra en phase A5.
-- =============================================================================

-- =============================================================================
-- D. PROFIL PUBLIC (cliquer un joueur du classement -> voir son profil)
-- =============================================================================
-- Objectif : depuis le classement mensuel, ouvrir le profil d'un autre joueur
-- avec ses scores ET son perso (avatar + accent). Le RLS restreint profiles /
-- equipped_items / best_scores au propriétaire ; plutôt que de l'ouvrir, on
-- expose une RPC SECURITY DEFINER qui ne renvoie QUE des champs publics.

-- D.1 Couleur d'accent du joueur (Theme.Accent : vert/ambre/cyan/mono). Purement
--     local jusqu'ici ; on la stocke pour rendre le perso avec la bonne couleur.
alter table profiles add column if not exists accent text;

-- D.2 L'enum avatar_slot ne couvrait que 6 slots ; l'app en a 9 (AvatarSlot).
--     On ajoute les 3 manquants pour pouvoir synchroniser tout l'équipement.
--     (ADD VALUE ne peut pas être utilisé dans la même transaction que son usage.)
alter type avatar_slot add value if not exists 'cou';
alter type avatar_slot add value if not exists 'main';
alter type avatar_slot add value if not exists 'dos';

-- D.3 Profil public en lecture seule : whitelist de champs, contourne le RLS des
--     tables de base sans l'affaiblir. best_score = meilleur score tous modes.
create or replace function get_public_profile(p_user_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'user_id', p.id,
    'pseudo', p.pseudo,
    'total_xp', p.total_xp,
    'accent', p.accent,
    'games_played', p.games_played,
    'total_correct', p.total_correct,
    'total_answered', p.total_answered,
    'best_streak_ever', p.best_streak_ever,
    'best_score', coalesce((select max(score) from best_scores b where b.user_id = p.id), 0),
    'equipped', coalesce((select jsonb_agg(jsonb_build_object('slot', e.slot, 'item_id', e.item_id))
                          from equipped_items e where e.user_id = p.id), '[]'::jsonb)
  )
  from profiles p
  where p.id = p_user_id;
$$;

grant execute on function get_public_profile(uuid) to anon, authenticated;
