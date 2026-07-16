-- =============================================================================
-- Kwizz - Schéma Supabase (PostgreSQL)
-- =============================================================================
-- Ce schéma reflète 1:1 les modèles Swift de Sources/KwizzCore (Question,
-- Category, PlayerProfile, AvatarItem, GameResult...). Objectif : pouvoir
-- exporter Supabase -> Resources/questions.json et inversement sans changer
-- le code de l'app.
--
-- Ordre conseillé : exécuter ce fichier, puis seed.sql.
-- À lancer dans le SQL Editor de Supabase (ou `supabase db push`).
-- =============================================================================

-- Extensions utiles (uuid + recherche texte insensible aux accents plus tard).
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "unaccent";    -- recherche FR sans accents (option)

-- -----------------------------------------------------------------------------
-- 1. Types énumérés (calqués sur les enums Swift)
-- -----------------------------------------------------------------------------
do $$ begin
  create type difficulty as enum ('facile', 'normal', 'difficile');
exception when duplicate_object then null; end $$;

do $$ begin
  create type game_mode as enum
    ('classique', 'contreLaMontre', 'survie', 'marathon', 'libre', 'duel', 'defi');
exception when duplicate_object then null; end $$;

do $$ begin
  create type avatar_slot as enum ('tete', 'cheveux', 'lunettes', 'haut', 'fond', 'cadre');
exception when duplicate_object then null; end $$;

do $$ begin
  create type rarity as enum ('commun', 'rare', 'epique', 'legendaire');
exception when duplicate_object then null; end $$;

-- Workflow de relecture des questions : on ne sert que les 'published'.
do $$ begin
  create type question_status as enum ('draft', 'review', 'published', 'archived');
exception when duplicate_object then null; end $$;

-- -----------------------------------------------------------------------------
-- Helper : maintien automatique de updated_at
-- -----------------------------------------------------------------------------
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

-- =============================================================================
-- 2. CONTENU : catégories, sous-catégories, questions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 Catégories (13 réelles ; le "Mélange" reste virtuel côté app)
-- -----------------------------------------------------------------------------
create table if not exists categories (
  id          text primary key,                 -- "histoire", "geographie"...
  name        text not null,
  color_hex   text not null check (color_hex ~ '^#[0-9a-fA-F]{6}$'),
  symbol      text not null,                     -- SF Symbol
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2.2 Sous-catégories (id au format "categorie.index", ex "histoire.3")
-- -----------------------------------------------------------------------------
create table if not exists subcategories (
  id          text primary key,                  -- "histoire.0"
  category_id text not null references categories(id) on delete cascade,
  name        text not null,
  sort_order  int  not null default 0,
  -- Indispensable : permet la clé étrangère composite depuis questions, qui
  -- garantit qu'une sous-catégorie appartient bien à la catégorie de la question.
  unique (category_id, id)
);

create index if not exists idx_subcategories_category on subcategories(category_id);

-- -----------------------------------------------------------------------------
-- 2.3 QUESTIONS  (table critique - intégrité verrouillée)
-- -----------------------------------------------------------------------------
-- Choix : answers en text[] + correct_index, exactement comme le modèle Swift
-- `Question` et questions.json. Avantage : import/export JSON sans transformation.
-- L'intégrité (bonne réponse valide, pas de doublon, pas de vide) est garantie
-- par des CHECK déclaratifs + un trigger de validation (voir plus bas).
create table if not exists questions (
  id              text primary key,              -- "his1" (slug stable, round-trip JSON)
  category_id     text not null references categories(id),
  subcategory_id  text,                          -- nullable (questions "générales")
  difficulty      difficulty not null,
  text            text not null,
  answers         text[] not null,
  correct_index   int  not null,
  explanation     text,

  -- Métadonnées banque de questions
  lang            text not null default 'fr',
  status          question_status not null default 'published',
  source          text,                          -- provenance / vérif éditoriale
  tags            text[] not null default '{}',

  -- Statistiques d'usage (calibrage de la difficulté, phase 2)
  times_served    bigint not null default 0,
  times_correct   bigint not null default 0,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  -- === Garde-fous d'intégrité (le coeur de la vigilance demandée) ===
  -- 2 à 6 réponses (l'app en affiche 4 ; le moteur exige au moins 2).
  constraint answers_count_ok check (cardinality(answers) between 2 and 6),
  -- L'index de la bonne réponse pointe forcément sur une réponse existante.
  constraint correct_index_in_range
    check (correct_index >= 0 and correct_index < cardinality(answers)),
  -- Texte non vide.
  constraint text_not_blank check (length(btrim(text)) > 0),

  -- La sous-catégorie (si fournie) appartient bien à la catégorie de la question.
  -- MATCH SIMPLE (défaut) : non vérifié quand subcategory_id est NULL -> OK.
  constraint fk_question_subcategory
    foreign key (category_id, subcategory_id)
    references subcategories(category_id, id)
);

-- Trigger de validation : ce que les CHECK ne peuvent pas exprimer
-- (pas de réponse vide, pas de doublon entre réponses, trim automatique).
create or replace function validate_question() returns trigger as $$
declare
  trimmed text[];
  distinct_count int;
begin
  -- Trim du texte et de chaque réponse.
  new.text := btrim(new.text);
  trimmed := array(select btrim(a) from unnest(new.answers) a);
  new.answers := trimmed;

  -- Aucune réponse vide.
  if exists (select 1 from unnest(trimmed) a where length(a) = 0) then
    raise exception 'Question %, une réponse est vide.', new.id;
  end if;

  -- Aucun doublon entre les réponses (sinon plusieurs "bonnes" possibles).
  select count(*) into distinct_count from (select distinct unnest(trimmed)) d;
  if distinct_count <> cardinality(trimmed) then
    raise exception 'Question %, réponses en double : %', new.id, trimmed;
  end if;

  -- times_correct ne peut pas dépasser times_served.
  if new.times_correct > new.times_served then
    raise exception 'Question %, times_correct (%) > times_served (%).',
      new.id, new.times_correct, new.times_served;
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_validate_question on questions;
create trigger trg_validate_question
  before insert or update on questions
  for each row execute function validate_question();

drop trigger if exists trg_questions_updated_at on questions;
create trigger trg_questions_updated_at
  before update on questions
  for each row execute function set_updated_at();

-- Index pour les requêtes du moteur (QuestionBank.filtered) :
-- filtrage par catégorie + difficulté, et par sous-catégorie. On indexe
-- uniquement les questions servies (status = 'published').
create index if not exists idx_questions_cat_diff
  on questions(category_id, difficulty) where status = 'published';
create index if not exists idx_questions_subcat
  on questions(subcategory_id) where status = 'published';
create index if not exists idx_questions_status on questions(status);

-- Vue d'export : mêmes clés (camelCase) que questions.json / le modèle Swift.
-- Pour régénérer le JSON local :
--   select json_agg(row_to_json(a) order by a.id) from app_questions a;
create or replace view app_questions as
  select
    id,
    category_id    as "categoryID",
    subcategory_id as "subcategoryID",
    difficulty,
    text,
    answers,
    correct_index  as "correctIndex",
    explanation
  from questions
  where status = 'published';

-- =============================================================================
-- 3. AVATAR : catalogue cosmétique (calqué sur AvatarItem.catalog)
-- =============================================================================
create table if not exists avatar_items (
  id           text primary key,                 -- "tete.casquette"
  name         text not null,
  slot         avatar_slot not null,
  rarity       rarity not null,
  price        int not null default 0 check (price >= 0),
  unlock_level int check (unlock_level is null or unlock_level between 1 and 20),
  -- Un item est soit achetable (price > 0), soit débloqué par niveau (unlock_level).
  constraint buy_or_unlock check (price > 0 or unlock_level is not null),
  created_at   timestamptz not null default now()
);

-- =============================================================================
-- 4. JOUEUR : profil + données dérivées de PlayerProfile
-- =============================================================================
-- Un profil = un utilisateur Supabase Auth. Les champs purement locaux/MVP
-- (libreCoinsDay, soundOn...) restent côté SwiftData ; on ne stocke ici que ce
-- qui est utile en ligne (sync multi-appareils, classements, social).
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  pseudo        text not null check (length(btrim(pseudo)) between 2 and 24),
  total_xp      bigint not null default 0 check (total_xp >= 0),
  coins         bigint not null default 0 check (coins >= 0),
  games_played  bigint not null default 0,
  total_correct bigint not null default 0,
  total_answered bigint not null default 0,
  best_streak_ever int not null default 0,
  daily_streak  int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint correct_le_answered check (total_correct <= total_answered)
);

-- Les pseudos sont réservés : un seul joueur par pseudo (à la casse près).
-- L'unicité n'est tenable que parce que le pseudo par défaut est libre et non
-- constant (cf. unique_pseudo plus bas) : avec "RetroKid" en dur pour tout le
-- monde, la création du 2e compte anonyme échouait (collision -> 500 à l'auth).
drop index if exists idx_profiles_pseudo_lower;
create unique index if not exists idx_profiles_pseudo_lower on profiles(lower(pseudo));

drop trigger if exists trg_profiles_updated_at on profiles;
create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

-- 4.1 Items possédés (PlayerProfile.ownedItemIDs : Set<String>)
create table if not exists owned_items (
  user_id    uuid not null references profiles(id) on delete cascade,
  item_id    text not null references avatar_items(id),
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- 4.2 Items équipés (PlayerProfile.equipped : [slot : item_id])
--     Un seul item équipé par slot -> PK (user_id, slot).
create table if not exists equipped_items (
  user_id uuid not null references profiles(id) on delete cascade,
  slot    avatar_slot not null,
  item_id text not null references avatar_items(id),
  primary key (user_id, slot)
);

-- 4.3 Meilleurs scores (PlayerProfile.bestScores : [recordKey : score])
--     recordKey décomposé en (mode, category_id, difficulty) pour les classements.
--     Le mode Libre ne track pas de record (GameMode.tracksRecord) -> exclu via trigger.
create table if not exists best_scores (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  mode        game_mode not null check (mode <> 'libre'),  -- Libre ne track pas de record
  category_id text,                              -- NULL = "toutes" (marathon/défi)
  difficulty  difficulty not null,
  score       int not null check (score >= 0),
  achieved_at timestamptz not null default now()
);

-- Un seul record par (user, mode, catégorie, difficulté). coalesce neutralise le
-- category_id NULL (NULL n'étant pas "distinct" dans un index unique classique).
-- C'est aussi la cible d'upsert PostgREST (on_conflict).
create unique index if not exists idx_best_scores_unique
  on best_scores (user_id, mode, coalesce(category_id, '*'), difficulty);

-- 4.4 Historique des parties (GameResult) - utile pour stats & anti-triche
create table if not exists game_results (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  mode         game_mode not null,
  difficulty   difficulty not null,
  category_id  text references categories(id),
  score        int not null,
  max_score    int not null,
  correct_count int not null,
  total        int not null,
  best_streak  int not null,
  coins_earned int not null,
  xp_earned    int not null,
  duel_won     boolean,                          -- NULL hors mode Duel
  played_at    timestamptz not null default now()
);

create index if not exists idx_game_results_user on game_results(user_id, played_at desc);

-- =============================================================================
-- 5. CLASSEMENTS (phase 2)
-- =============================================================================
-- Vue classement par (mode, catégorie, difficulté). Comme c'est une vue
-- "definer" (sans security_invoker), elle ignore le RLS des best_scores et
-- expose donc bien le top de tout le monde - c'est l'objet d'un classement.
create or replace view leaderboard as
  select
    bs.mode,
    coalesce(bs.category_id, '*') as category_id,   -- '*' = toutes catégories
    bs.difficulty,
    p.id   as user_id,
    p.pseudo,
    bs.score,
    bs.achieved_at,
    rank() over (
      partition by bs.mode, coalesce(bs.category_id, '*'), bs.difficulty
      order by bs.score desc
    ) as rank
  from best_scores bs
  join profiles p on p.id = bs.user_id;

-- Défi du jour (grille identique pour tous une date donnée). Le classement
-- mondial du défi arrive en phase 2 ; la table est prête.
create table if not exists daily_results (
  day_index  int not null,                       -- jour epoch (cohérent avec l'app)
  user_id    uuid not null references profiles(id) on delete cascade,
  score      int not null check (score >= 0),
  played_at  timestamptz not null default now(),
  primary key (day_index, user_id)               -- 1 tentative / jour / joueur
);

create index if not exists idx_daily_results_day on daily_results(day_index, score desc);

-- =============================================================================
-- 6. SÉCURITÉ : Row Level Security
-- =============================================================================
-- Principe : le CONTENU (catégories, questions, items) est lisible par tout le
-- monde mais écrit seulement par le service_role (admin/import). Les DONNÉES
-- JOUEUR ne sont accessibles que par leur propriétaire.

-- 6.1 Contenu : lecture publique, écriture réservée au service_role.
alter table categories    enable row level security;
alter table subcategories enable row level security;
alter table questions     enable row level security;
alter table avatar_items  enable row level security;

create policy "categories lisibles par tous"
  on categories for select using (true);
create policy "subcategories lisibles par tous"
  on subcategories for select using (true);
create policy "avatar_items lisibles par tous"
  on avatar_items for select using (true);
-- On ne sert que les questions publiées.
create policy "questions publiées lisibles par tous"
  on questions for select using (status = 'published');
-- (Pas de policy insert/update/delete : seules les clés service_role, qui
--  contournent le RLS, peuvent écrire. L'import de questions passe par là.)

-- 6.2 Profil : chacun lit/écrit le sien.
alter table profiles enable row level security;
create policy "profil : lecture du sien"
  on profiles for select using (auth.uid() = id);
create policy "profil : création du sien"
  on profiles for insert with check (auth.uid() = id);
create policy "profil : mise à jour du sien"
  on profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- 6.3 Données joueur : possession liée à user_id = auth.uid().
alter table owned_items    enable row level security;
alter table equipped_items enable row level security;
alter table best_scores    enable row level security;
alter table game_results   enable row level security;
alter table daily_results  enable row level security;

-- Une policy "ALL" (select/insert/update/delete) par table, restreinte au propriétaire.
create policy "owned_items : propriétaire"
  on owned_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "equipped_items : propriétaire"
  on equipped_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "best_scores : propriétaire"
  on best_scores for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "game_results : propriétaire"
  on game_results for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "daily_results : propriétaire"
  on daily_results for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Le classement (vue) est lisible publiquement.
grant select on leaderboard to anon, authenticated;
grant select on app_questions to anon, authenticated;

-- =============================================================================
-- 7. Pseudos : unicité, réservation, auto-création du profil
-- =============================================================================

-- Premier pseudo libre à partir d'une base ("RetroKid" -> "RetroKid2"...). C'est
-- ce qui rend l'index UNIQUE viable : un nouveau compte ne peut pas naître sur un
-- pseudo déjà pris. Le résultat respecte toujours le CHECK (2..24 caractères).
create or replace function public.unique_pseudo(base text)
returns text as $$
declare
  clean     text;
  candidate text;
  suffix    text;
  n         int := 1;
begin
  clean := btrim(coalesce(base, ''));
  if length(clean) < 2 then clean := 'RetroKid'; end if;
  clean := left(clean, 24);
  candidate := clean;

  while exists (select 1 from public.profiles where lower(pseudo) = lower(candidate)) loop
    n := n + 1;
    suffix := n::text;
    -- On tronque la base pour que base+suffixe tienne dans les 24 caractères.
    candidate := left(clean, 24 - length(suffix)) || suffix;
  end loop;

  return candidate;
end;
$$ language plpgsql security definer set search_path = public;

-- Réservation d'un pseudo par le joueur courant : 'ok' | 'taken' | 'invalid'.
-- security definer car RLS n'autorise la lecture que de SON profil : l'app ne
-- peut pas tester l'unicité elle-même.
create or replace function public.claim_pseudo(p_pseudo text)
returns text as $$
declare
  uid   uuid := auth.uid();
  clean text;
begin
  if uid is null then return 'invalid'; end if;

  clean := btrim(coalesce(p_pseudo, ''));
  if length(clean) < 2 or length(clean) > 24 then return 'invalid'; end if;

  if exists (
    select 1 from public.profiles where lower(pseudo) = lower(clean) and id <> uid
  ) then
    return 'taken';
  end if;

  insert into public.profiles (id, pseudo) values (uid, clean)
  on conflict (id) do update set pseudo = excluded.pseudo;

  return 'ok';
exception
  -- Course entre deux joueurs sur le même pseudo : le perdant reçoit 'taken'.
  when unique_violation then
    return 'taken';
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function public.claim_pseudo(text) to anon, authenticated;

-- Test de disponibilité (feedback pendant la frappe). Son propre pseudo est
-- disponible : re-valider sans changer ne doit pas afficher "déjà pris".
create or replace function public.pseudo_available(p_pseudo text)
returns boolean as $$
  select not exists (
    select 1 from public.profiles
    where lower(pseudo) = lower(btrim(p_pseudo))
      and id is distinct from auth.uid()
  );
$$ language sql stable security definer set search_path = public;

grant execute on function public.pseudo_available(text) to anon, authenticated;

create or replace function handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, pseudo)
  values (
    new.id,
    public.unique_pseudo(coalesce(new.raw_user_meta_data->>'pseudo', 'RetroKid'))
  )
  on conflict (id) do nothing;
  return new;
exception
  -- La création du profil ne doit JAMAIS bloquer l'authentification : si l'insert
  -- échoue (contrainte, etc.), on laisse passer l'auth et le profil sera créé
  -- plus tard par syncProfile (upsert). Sinon l'app reste coincée "Hors ligne".
  when others then
    return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
