-- =============================================================================
-- Kwizz - Historique des parties de duel (entre amis)
-- =============================================================================
-- À exécuter dans le SQL Editor de Supabase APRÈS schema.sql. Idempotent :
-- ré-exécutable sans casse.
--
-- POURQUOI "UN POINT DE VUE PAR JOUEUR"
-- Le duel entre amis n'a aucune table : la partie vit uniquement dans le canal
-- Realtime, et l'identité d'un participant y est un `clientID` (UUID de device,
-- UserDefaults « kwizz.clientID »), PAS un compte. Il n'existe donc AUCUN
-- identifiant partagé et fiable entre les participants d'une même partie : rien
-- ne permettrait à un client d'écrire une ligne « match » commune ni de la
-- rattacher aux comptes des autres.
--
-- On renonce donc à modéliser LA partie et on modélise MA partie : chaque client
-- enregistre son propre point de vue, dans une ligne qui lui appartient
-- (user_id = auth.uid()). Les adversaires ne sont pas des clés étrangères mais
-- un instantané JSONB (pseudo, points, rang) figé au moment de la partie.
--
-- Conséquences (toutes voulues) :
--  - aucune coordination entre clients, aucun doublon possible ;
--  - l'historique suit le COMPTE, donc il est synchronisé multi-device ;
--  - un joueur qui n'enregistre pas (hors ligne, vieille version) n'empêche
--    personne d'avoir le sien ;
--  - le pseudo d'un adversaire est celui du jour de la partie, il ne se
--    « met pas à jour » plus tard. C'est un historique, pas un annuaire.
-- =============================================================================

create table if not exists duel_history (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  played_at      timestamptz not null default now(),
  room_code      text not null,
  -- Règle de score de la partie (DuelScoring côté app).
  scoring        text not null check (scoring in ('fastest','all_correct')),
  question_count int  not null check (question_count > 0),
  -- NULL = mélange de thèmes (pas de catégorie unique). Pas de FK vers
  -- categories : un thème retiré du catalogue ne doit pas effacer l'historique.
  category_id    text,
  player_count   int  not null check (player_count >= 1),
  my_points      int  not null check (my_points >= 0),
  my_correct     int  not null check (my_correct >= 0),
  my_rank        int  not null check (my_rank >= 1),
  won            boolean not null,
  -- Instantané ORDONNÉ du classement final, moi inclus :
  -- [{"pseudo":..,"points":..,"correct":..,"rank":..,"isMe":bool}, ...]
  players        jsonb not null,

  -- Cohérence de bon sens : on ne peut pas avoir plus de bonnes réponses que de
  -- questions, ni un rang au-delà du nombre de joueurs, et « gagné » = 1er.
  constraint duel_history_correct_le_questions check (my_correct <= question_count),
  constraint duel_history_rank_le_players      check (my_rank <= player_count),
  constraint duel_history_won_is_first         check (won = (my_rank = 1)),
  constraint duel_history_players_is_array     check (jsonb_typeof(players) = 'array')
);

-- Seule requête de l'app : mes parties, les plus récentes d'abord.
create index if not exists idx_duel_history_user_played
  on duel_history(user_id, played_at desc);

-- RLS : chacun ne voit et n'écrit QUE ses propres lignes. Pas d'update ni de
-- delete : un historique ne se réécrit pas (la suppression du compte fait le
-- ménage via le on delete cascade).
alter table duel_history enable row level security;

drop policy if exists "duel_history : lecture du sien" on duel_history;
create policy "duel_history : lecture du sien"
  on duel_history for select using (auth.uid() = user_id);

drop policy if exists "duel_history : écriture du sien" on duel_history;
create policy "duel_history : écriture du sien"
  on duel_history for insert with check (auth.uid() = user_id);
