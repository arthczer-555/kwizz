// Edge Function : ranked-enqueue
// -----------------------------------------------------------------------------
// Ligue 1v1 classée (Système A). Met l'appelant dans la file ; si un adversaire
// de rating proche attend, crée le match (questions choisies + mélangées côté
// serveur) de façon atomique via la fonction SQL enqueue_ranked. Le client
// re-appelle cette fonction (poll) tant qu'il reçoit {status:'queued'} ; quand il
// est apparié il reçoit {status:'matched', matchId, role}.
//
// Déploiement : supabase functions deploy ranked-enqueue
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

    const body = await req.json().catch(() => ({}));
    const admin = createClient(url, serviceKey);

    // Annulation de la recherche.
    if (body?.leave) {
      await admin.from("ranked_queue").delete().eq("user_id", user.id);
      return json({ status: "left" });
    }

    const pseudo = String(body?.pseudo ?? "RetroKid").slice(0, 24);
    const accent = body?.accentHex ? String(body.accentHex) : null;

    const { data, error } = await admin.rpc("enqueue_ranked", {
      p_user: user.id, p_pseudo: pseudo, p_accent: accent,
    });
    // Une erreur SQL ici (fonction absente, contrainte violée, banque de questions
    // vide...) ne DOIT PAS être maquillée en 'queued' : les deux joueurs
    // resteraient en recherche jusqu'au timeout sans que rien ne le signale, ce
    // qui rend la panne indiagnosticable. On loggue et on remonte le code PG.
    if (error) {
      console.error("enqueue_ranked a échoué", error);
      return json({ error: "enqueue_failed", code: error.code ?? null,
                    message: error.message ?? String(error) }, 500);
    }
    return json(data); // {status:'matched',matchId,role} | {status:'queued'}
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
