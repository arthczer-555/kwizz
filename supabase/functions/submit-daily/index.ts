// Edge Function : submit-daily
// -----------------------------------------------------------------------------
// Système B de docs/PLAN_LIGUE.md. Reçoit les réponses du Défi du jour, REVÉRIFIE
// chaque réponse côté serveur contre la table `questions` (on ne fait jamais
// confiance à un score envoyé brut), calcule le nombre de bonnes réponses, et
// enregistre une ligne dans `daily_results` (1 tentative/jour, garantie par la PK).
//
// Le score du classement = nombre de bonnes réponses (entièrement vérifiable,
// aucun temps de réponse à arbitrer). Le classement mensuel somme les 25 meilleurs
// jours (vue monthly_challenge_leaderboard).
//
// Déploiement : `supabase functions deploy submit-daily`. SUPABASE_URL,
// SUPABASE_ANON_KEY et SUPABASE_SERVICE_ROLE_KEY sont injectés automatiquement.
// La "Verify JWT" par défaut convient : le client envoie le jeton de sa session
// (anonyme), qui porte son user id.
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

    // 1. Identifier l'appelant à partir de son jeton (session anonyme incluse).
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) return json({ error: "unauthorized" }, 401);

    // 2. Valider la charge utile.
    const body = await req.json().catch(() => null);
    const dayIndex = Number(body?.dayIndex);
    const answers = Array.isArray(body?.answers) ? body.answers : [];
    if (!Number.isInteger(dayIndex) || answers.length === 0 || answers.length > 10) {
      return json({ error: "bad_request" }, 400);
    }

    // Anti-backfill : on n'accepte qu'un jour proche du "today" serveur (tolérance
    // d'un jour pour absorber le décalage de fuseau horaire du client).
    if (Math.abs(epochDay(dayIndex) - epochDay(serverDayIndex())) > 1) {
      return json({ error: "stale_day" }, 400);
    }

    // 3. Revérifier les réponses contre les questions canoniques (service role).
    const admin = createClient(url, serviceKey);
    const ids = [...new Set(answers.map((a: { id: unknown }) => String(a.id)))];
    const { data: rows, error: qErr } = await admin
      .from("questions").select("id, answers, correct_index").in("id", ids);
    if (qErr) return json({ error: "db" }, 500);

    const byId = new Map((rows ?? []).map((q) => [q.id, q]));
    let correct = 0;
    for (const a of answers) {
      const q = byId.get(String(a.id));
      if (!q) continue; // id inconnu -> compté faux
      const right = q.answers?.[q.correct_index];
      if (a.choice != null && a.choice === right) correct++;
    }
    const score = correct; // métrique de classement = bonnes réponses

    // 4. Une tentative par jour : insert, et si déjà fait on renvoie l'existant.
    const { error: insErr } = await admin
      .from("daily_results").insert({ day_index: dayIndex, user_id: user.id, score });

    if (insErr) {
      if ((insErr as { code?: string }).code === "23505") { // unique_violation
        const { data: existing } = await admin
          .from("daily_results").select("score")
          .eq("day_index", dayIndex).eq("user_id", user.id).single();
        return json({ score: existing?.score ?? score, correct, alreadySubmitted: true });
      }
      return json({ error: "db" }, 500);
    }
    return json({ score, correct, alreadySubmitted: false });
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

// Date du serveur au format AAAAMMJJ (UTC), même format que DailyChallenge.day.
function serverDayIndex(): number {
  const d = new Date();
  return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
}

// Convertit un AAAAMMJJ en nombre de jours depuis l'epoch, pour comparer deux dates.
function epochDay(yyyymmdd: number): number {
  const y = Math.floor(yyyymmdd / 10000);
  const m = Math.floor((yyyymmdd % 10000) / 100);
  const d = yyyymmdd % 100;
  return Math.floor(Date.UTC(y, m - 1, d) / 86_400_000);
}
