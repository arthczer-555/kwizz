// Edge Function : ranked-answer
// -----------------------------------------------------------------------------
// Ligue 1v1 classée (Système A). Enregistre la réponse de l'appelant pour la
// question courante, REVÉRIFIE sa justesse côté serveur (contre la question
// mélangée stockée dans le match), puis appelle resolve_ranked_match qui décide
// le gagnant de la question, avance, et finalise l'ELO. L'état autoritatif
// revient au client via Realtime (UPDATE de ranked_matches), pas par la réponse
// HTTP. Gère aussi l'abandon explicite ({forfeit:true}).
//
// Déploiement : supabase functions deploy ranked-answer
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => null);
    const matchId = body?.matchId;
    if (!matchId) return json({ error: "bad_request" }, 400);

    const admin = createClient(url, serviceKey);
    const { data: m, error: mErr } = await admin
      .from("ranked_matches").select("*").eq("id", matchId).single();
    if (mErr || !m) return json({ error: "not_found" }, 404);
    if (m.player_a !== user.id && m.player_b !== user.id) return json({ error: "forbidden" }, 403);
    if (m.status !== "playing") return json({ ok: true }); // already finished

    // Abandon : l'adversaire gagne, ELO appliqué.
    if (body?.forfeit) {
      await admin.rpc("forfeit_ranked", { p_match_id: matchId, p_user: user.id });
      return json({ ok: true });
    }

    const qi = Number(body?.questionIndex);
    if (!Number.isInteger(qi) || qi !== m.current_index) return json({ ok: true }); // stale, ignore

    const question = Array.isArray(m.questions) ? m.questions[qi] : null;
    if (!question) return json({ error: "bad_question" }, 400);

    const rawAnswer = body?.answerIndex;
    const answerIndex = (rawAnswer === null || rawAnswer === undefined) ? null : Number(rawAnswer);
    const correct = answerIndex !== null && answerIndex === Number(question.correctIndex);
    const elapsed = Math.max(0, Math.min(15000, Math.floor(Number(body?.elapsedMs) || 15000)));

    const { error: insErr } = await admin.from("ranked_answers").insert({
      match_id: matchId, question_index: qi, user_id: user.id,
      answer_index: answerIndex, correct, elapsed_ms: elapsed,
    });
    // 23505 = already answered this question (idempotent), not an error.
    if (insErr && (insErr as { code?: string }).code !== "23505") {
      return json({ error: "db" }, 500);
    }

    await admin.rpc("resolve_ranked_match", { p_match_id: matchId });
    return json({ ok: true });
  } catch (_e) {
    return json({ error: "server" }, 500);
  }
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
