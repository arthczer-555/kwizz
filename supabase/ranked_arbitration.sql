-- =============================================================================
-- Kwizz - Ligue 1v1 classée : arbitrage serveur (Système A)
-- =============================================================================
-- À exécuter APRÈS schema.sql + league.sql. Idempotent.
-- Le matchmaking et l'arbitrage des questions vivent ici (plpgsql) ; les Edge
-- Functions ranked-enqueue / ranked-answer ne font qu'authentifier l'appelant,
-- choisir/mélanger les questions, et appeler ces fonctions. Tout l'ELO et le
-- gagnant de chaque question sont décidés côté serveur. Voir docs/PLAN_LIGUE.md.
-- =============================================================================

-- Identité d'affichage dans la file et le match (fournie par le client, comme le
-- DuelPlayer du duel entre amis ; les profiles n'ont pas l'accent côté serveur).
alter table ranked_queue   add column if not exists pseudo     text;
alter table ranked_queue   add column if not exists accent_hex text;
alter table ranked_matches add column if not exists pseudo_a   text;
alter table ranked_matches add column if not exists pseudo_b   text;
alter table ranked_matches add column if not exists accent_a   text;
alter table ranked_matches add column if not exists accent_b   text;

-- Le client mesure jusqu'à 15 s par question : la borne d'elapsed_ms doit suivre,
-- sinon les bonnes réponses lentes (>10 s) s'écrasent toutes à 10 s et le
-- départage "le plus rapide" devient faux.
alter table ranked_answers drop constraint if exists ranked_answers_elapsed_ms_check;
alter table ranked_answers add constraint ranked_answers_elapsed_ms_check
  check (elapsed_ms between 0 and 15000);

-- -----------------------------------------------------------------------------
-- Constantes de cadence (s). Le client mesure 15 s/question (GameMode), montre un
-- reveal ~3,5 s ; le serveur laisse une marge pour que la deadline ne coupe pas
-- pendant le reveal du client.
--   première question : countdown(3) + question(15) = 18 s
--   suivantes        : reveal(4) + question(15)    = 19 s
-- -----------------------------------------------------------------------------

-- =============================================================================
-- finalize_ranked : clôt un match, calcule l'ELO, met à jour ranked_stats.
-- =============================================================================
create or replace function finalize_ranked(
  p_match_id uuid, p_a uuid, p_b uuid, p_score_a int, p_score_b int, p_status text
) returns void as $$
declare
  ra int; rb int; expected_a numeric; s_a numeric;
  da int; db int; win uuid;
begin
  insert into ranked_stats(user_id) values (p_a) on conflict do nothing;
  insert into ranked_stats(user_id) values (p_b) on conflict do nothing;
  select rating into ra from ranked_stats where user_id = p_a for update;
  select rating into rb from ranked_stats where user_id = p_b for update;

  if p_score_a = p_score_b then
    -- Nul : aucun changement d'ELO, aucun vainqueur.
    update ranked_matches set status = p_status, winner = null, delta_a = 0, delta_b = 0,
           score_a = p_score_a, score_b = p_score_b, finished_at = now()
     where id = p_match_id;
    return;
  end if;

  win := case when p_score_a > p_score_b then p_a else p_b end;
  s_a := case when p_score_a > p_score_b then 1 else 0 end;
  expected_a := 1.0 / (1.0 + power(10.0, (rb - ra) / 400.0));
  -- K=20 : +10/-10 à niveau égal, variable selon l'écart (cf. Elo.kFactor).
  da := round(20 * (s_a - expected_a));
  db := round(20 * ((1 - s_a) - (1 - expected_a)));

  update ranked_stats
     set rating = greatest(0, ra + da),
         peak_rating = greatest(peak_rating, greatest(0, ra + da)),
         wins   = wins   + (case when win = p_a then 1 else 0 end),
         losses = losses + (case when win = p_a then 0 else 1 end)
   where user_id = p_a;
  update ranked_stats
     set rating = greatest(0, rb + db),
         peak_rating = greatest(peak_rating, greatest(0, rb + db)),
         wins   = wins   + (case when win = p_b then 1 else 0 end),
         losses = losses + (case when win = p_b then 0 else 1 end)
   where user_id = p_b;

  update ranked_matches
     set status = p_status, winner = win, delta_a = da, delta_b = db,
         score_a = p_score_a, score_b = p_score_b, finished_at = now()
   where id = p_match_id;
end;
$$ language plpgsql security definer set search_path = public;

-- =============================================================================
-- resolve_ranked_match : résout les questions terminées (les deux ont répondu OU
-- deadline dépassée), attribue le point au plus rapide correct, avance/clôt.
-- Appelée par ranked-answer (après chaque réponse) et par le sweeper pg_cron.
-- Idempotente : si la question courante n'est pas terminée, ne fait rien.
-- =============================================================================
create or replace function resolve_ranked_match(p_match_id uuid) returns void as $$
declare
  m record; i int; ans_count int; win_uid uuid;
begin
  select * into m from ranked_matches where id = p_match_id for update;
  if not found or m.status <> 'playing' then return; end if;

  loop
    i := m.current_index;
    select count(*) into ans_count
      from ranked_answers where match_id = p_match_id and question_index = i;

    -- Pas terminée : on s'arrête (cas normal pendant le jeu).
    if ans_count < 2 and now() <= m.deadline then exit; end if;

    -- Gagnant = bonne réponse la plus rapide (égalité -> plus petit user_id).
    select user_id into win_uid
      from ranked_answers
     where match_id = p_match_id and question_index = i and correct
     order by elapsed_ms asc, user_id asc
     limit 1;

    if win_uid = m.player_a then m.score_a := m.score_a + 1;
    elsif win_uid = m.player_b then m.score_b := m.score_b + 1;
    end if;

    -- Fin : premier à 4, ou 7e question (index 6) résolue.
    if m.score_a >= 4 or m.score_b >= 4 or i >= 6 then
      perform finalize_ranked(p_match_id, m.player_a, m.player_b, m.score_a, m.score_b, 'finished');
      return;
    end if;

    -- Sinon, question suivante avec une nouvelle deadline (reveal + question).
    m.current_index := i + 1;
    m.deadline := now() + interval '19 seconds';
    update ranked_matches
       set current_index = m.current_index, deadline = m.deadline,
           score_a = m.score_a, score_b = m.score_b
     where id = p_match_id;
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- =============================================================================
-- shuffle_question : renvoie une question en JSON camelCase (clés du modèle Swift
-- Question) avec les réponses mélangées et le correctIndex recalculé.
-- =============================================================================
create or replace function shuffle_question(q questions) returns jsonb as $$
declare
  idx int[]; shuffled text[]; new_ci int := 0; i int;
begin
  select array_agg(p order by random()) into idx from generate_subscripts(q.answers, 1) p;
  shuffled := array(select q.answers[idx[i]] from generate_subscripts(idx, 1) i);
  for i in 1 .. array_length(idx, 1) loop
    if idx[i] = q.correct_index + 1 then new_ci := i - 1; end if;
  end loop;
  return jsonb_build_object(
    'id', q.id, 'categoryID', q.category_id, 'subcategoryID', q.subcategory_id,
    'difficulty', q.difficulty, 'text', q.text, 'answers', to_jsonb(shuffled),
    'correctIndex', new_ci, 'explanation', q.explanation
  );
end;
$$ language plpgsql;

-- =============================================================================
-- enqueue_ranked : file d'attente + appariement atomique + création du match.
-- Choisit et mélange les 7 questions côté serveur quand un appariement a lieu.
-- Retourne {status:'matched',matchId,role} ou {status:'queued'}.
-- =============================================================================
create or replace function enqueue_ranked(
  p_user uuid, p_pseudo text, p_accent text
) returns jsonb as $$
declare
  my_rating int; opp record; existing record; new_id uuid; v_questions jsonb;
begin
  -- Sérialise les appariements concurrents : évite l'interblocage de deux joueurs
  -- qui s'apparient en même temps, et toute double création / file résiduelle.
  perform pg_advisory_xact_lock(727274);
  insert into ranked_stats(user_id) values (p_user) on conflict do nothing;
  select rating into my_rating from ranked_stats where user_id = p_user;

  -- Déjà dans un match en cours ? (cas du joueur en attente qui re-poll)
  select * into existing
    from ranked_matches
   where status = 'playing' and (player_a = p_user or player_b = p_user)
   order by created_at desc limit 1;
  if found then
    return jsonb_build_object('status','matched','matchId',existing.id,
      'role', case when existing.player_a = p_user then 'a' else 'b' end);
  end if;

  -- Cherche un adversaire de rating proche (bande qui s'élargit avec l'attente).
  select * into opp
    from ranked_queue
   where user_id <> p_user
     and abs(rating - my_rating) <= 100 + floor(extract(epoch from (now() - enqueued_at)) / 5) * 50
   order by abs(rating - my_rating), enqueued_at
   limit 1
   for update skip locked;

  if found then
    delete from ranked_queue where user_id in (p_user, opp.user_id);
    select jsonb_agg(shuffle_question(q)) into v_questions
      from (select * from questions where status = 'published' order by random() limit 7) q;
    new_id := gen_random_uuid();
    insert into ranked_matches
      (id, player_a, player_b, pseudo_a, pseudo_b, accent_a, accent_b,
       questions, current_index, deadline, status, score_a, score_b)
    values
      (new_id, p_user, opp.user_id, p_pseudo, opp.pseudo, p_accent, opp.accent_hex,
       v_questions, 0, now() + interval '18 seconds', 'playing', 0, 0);
    return jsonb_build_object('status','matched','matchId',new_id,'role','a');
  end if;

  -- enqueued_at n'est PAS réinitialisé en cas de conflit : sinon le re-poll
  -- toutes les 2 s remettrait le compteur d'attente à zéro et la bande de rating
  -- ne s'élargirait jamais (deux joueurs à plus de 100 d'écart ne matcheraient pas).
  insert into ranked_queue (user_id, rating, pseudo, accent_hex, enqueued_at)
  values (p_user, my_rating, p_pseudo, p_accent, now())
  on conflict (user_id) do update
    set rating = excluded.rating, pseudo = excluded.pseudo, accent_hex = excluded.accent_hex;
  return jsonb_build_object('status','queued');
end;
$$ language plpgsql security definer set search_path = public;

-- =============================================================================
-- forfeit_ranked : abandon explicite. L'adversaire gagne, ELO appliqué.
-- =============================================================================
create or replace function forfeit_ranked(p_match_id uuid, p_user uuid) returns void as $$
declare m record; sa int; sb int;
begin
  select * into m from ranked_matches where id = p_match_id for update;
  if not found or m.status <> 'playing' then return; end if;
  -- Donne la victoire à l'adversaire (4-0 symbolique pour marquer le forfait).
  if p_user = m.player_a then sa := 0; sb := 4; else sa := 4; sb := 0; end if;
  perform finalize_ranked(p_match_id, m.player_a, m.player_b, sa, sb, 'forfeit');
end;
$$ language plpgsql security definer set search_path = public;

-- =============================================================================
-- sweep_ranked : filet de sécurité pour les matchs dont la deadline est passée
-- (un joueur déconnecté). À planifier via pg_cron.
-- =============================================================================
create or replace function sweep_ranked() returns void as $$
declare m record;
begin
  for m in select id from ranked_matches where status = 'playing' and deadline < now() loop
    perform resolve_ranked_match(m.id);
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

-- Planification (prérequis : extension pg_cron activée). À lancer une fois :
-- select cron.schedule('sweep-ranked', '* * * * *', $$ select sweep_ranked(); $$);
-- (granularité minute, universelle ; la fermeture opportuniste dans ranked-answer
--  résout déjà la plupart des questions instantanément.)

-- =============================================================================
-- Realtime : les clients réagissent aux UPDATE de leur ligne ranked_matches.
-- =============================================================================
do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ranked_matches'
  ) then
    alter publication supabase_realtime add table ranked_matches;
  end if;
end $$;
