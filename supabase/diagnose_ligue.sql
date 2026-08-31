-- =============================================================================
-- Kwizz - Diagnostic du matchmaking classé (à coller dans le SQL Editor Supabase)
-- Lecture seule : aucune écriture, aucun effet de bord.
-- =============================================================================

-- 1. Les fonctions d'arbitrage sont-elles bien en base ?
--    (si enqueue_ranked manque, ranked_arbitration.sql n'a jamais été exécuté)
select proname, pronargs
  from pg_proc
 where proname in ('enqueue_ranked','resolve_ranked_match','finalize_ranked',
                   'shuffle_question','forfeit_ranked','sweep_ranked')
 order by proname;

-- 2. Qui attend dans la file, depuis quand, avec quel rating ?
select user_id, pseudo, rating, enqueued_at, now() - enqueued_at as attente
  from ranked_queue order by enqueued_at;

-- 3. Matchs "zombies" : status 'playing' avec une deadline dépassée.
--    Tant qu'il en reste un, le joueur concerné est renvoyé vers CE match à
--    chaque recherche (cf. le bloc "existing" de enqueue_ranked) et ne rejoint
--    donc JAMAIS la file : deux joueurs peuvent chercher sans jamais s'apparier.
select id, player_a, player_b, current_index, status, deadline,
       now() - deadline as retard, created_at
  from ranked_matches
 where status = 'playing'
 order by created_at desc limit 20;

-- 4. Le balayage automatique est-il planifié ? (attendu : 'sweep-ranked')
--    Si pg_cron n'est pas installé, cette requête échoue : c'est la réponse.
select jobname, schedule, active from cron.job;

-- 5. Y a-t-il assez de questions publiées pour créer un match (7 requises) ?
--    Si < 7, jsonb_agg renvoie trop peu / NULL et l'INSERT du match échoue.
select count(*) as questions_publiees from questions where status = 'published';
