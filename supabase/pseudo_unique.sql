-- Unicité des pseudos.
--
-- Historique : idx_profiles_pseudo_lower était UNIQUE, mais le pseudo par défaut
-- était "RetroKid" pour TOUT LE MONDE (trigger handle_new_user + champ
-- pré-rempli dans OnboardingView). Dès le 2e joueur anonyme : collision =>
-- l'INSERT profil échouait => l'INSERT auth.users échouait => 500 à l'auth =>
-- l'app restait "Hors ligne". Le correctif de l'époque (fix_pseudo_unique_index)
-- a retiré l'unicité, d'où une base pleine de "RetroKid" indistinguables.
--
-- Ici on traite la CAUSE au lieu du symptôme : le défaut n'est plus une
-- constante mais un pseudo libre ("RetroKid", "RetroKid2", ...), ce qui permet
-- de rétablir l'index UNIQUE sans jamais casser la création de compte.
--
-- À exécuter une fois : supabase db query --linked -f supabase/pseudo_unique.sql

begin;

-- 1. Premier pseudo libre à partir d'une base ("RetroKid" -> "RetroKid2"...).
--    Le résultat respecte toujours le CHECK de profiles (2..24 caractères).
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

  -- Chaque itération relit profiles : dans une boucle ligne à ligne (cf. §2) les
  -- renommages déjà faits sont visibles, donc pas de doublon entre itérations.
  while exists (select 1 from public.profiles where lower(pseudo) = lower(candidate)) loop
    n := n + 1;
    suffix := n::text;
    -- On tronque la base pour que base+suffixe tienne dans les 24 caractères.
    candidate := left(clean, 24 - length(suffix)) || suffix;
  end loop;

  return candidate;
end;
$$ language plpgsql security definer set search_path = public;

-- 2. Dédoublonnage de l'existant : le plus ancien de chaque groupe garde son
--    pseudo, les suivants sont suffixés. Boucle ligne à ligne (et non un UPDATE
--    ensembliste) : sinon toutes les lignes d'un même groupe verraient le même
--    snapshot et recevraient le MÊME nouveau pseudo.
do $$
declare r record;
begin
  for r in
    select id, pseudo from (
      select id, pseudo,
             row_number() over (partition by lower(pseudo) order by created_at, id) as rn
      from public.profiles
    ) t where t.rn > 1
  loop
    update public.profiles set pseudo = public.unique_pseudo(r.pseudo) where id = r.id;
  end loop;
end $$;

-- 3. L'unicité peut revenir : plus aucun doublon, et le défaut est désormais libre.
drop index if exists idx_profiles_pseudo_lower;
create unique index idx_profiles_pseudo_lower on public.profiles(lower(pseudo));

-- 4. Auto-création du profil : pseudo par défaut unique.
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
  -- La création du profil ne doit JAMAIS bloquer l'authentification (deux
  -- inscriptions simultanées peuvent encore se disputer un pseudo) : on laisse
  -- passer l'auth, syncProfile/claim_pseudo créeront le profil ensuite.
  when others then
    return new;
end;
$$ language plpgsql security definer set search_path = public;

-- 5. Réservation d'un pseudo par le joueur courant.
--    security definer : RLS n'autorise la lecture que de SON profil, donc l'app
--    ne peut pas tester l'unicité elle-même.
--    Renvoie 'ok' | 'taken' | 'invalid'.
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

-- 6. Test de disponibilité (feedback pendant la frappe). Son propre pseudo est
--    considéré disponible : re-valider sans changer ne doit pas afficher "pris".
create or replace function public.pseudo_available(p_pseudo text)
returns boolean as $$
  select not exists (
    select 1 from public.profiles
    where lower(pseudo) = lower(btrim(p_pseudo))
      and id is distinct from auth.uid()
  );
$$ language sql stable security definer set search_path = public;

grant execute on function public.pseudo_available(text) to anon, authenticated;

commit;
