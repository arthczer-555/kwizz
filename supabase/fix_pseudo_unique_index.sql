-- Fix : la création de comptes anonymes échouait (500 "Database error creating
-- anonymous user") => l'app restait "Hors ligne".
--
-- Cause : le trigger handle_new_user insère un profil avec le pseudo par défaut
-- "RetroKid", mais idx_profiles_pseudo_lower était un index UNIQUE sur
-- lower(pseudo). Dès le 2e joueur anonyme, collision sur "RetroKid" => l'INSERT
-- échoue => le INSERT sur auth.users échoue => 500 à l'auth.
--
-- Les pseudos ne sont pas réservés dans l'app (aucun écran ne vérifie l'unicité),
-- donc on remplace l'index UNIQUE par un index simple, et on rend le trigger
-- tolérant aux erreurs pour ne jamais bloquer l'authentification.
--
-- À exécuter une fois dans le SQL Editor Supabase (ou via le CLI).

begin;

-- 1. Index pseudo : passe de UNIQUE à non unique.
drop index if exists idx_profiles_pseudo_lower;
create index if not exists idx_profiles_pseudo_lower on public.profiles(lower(pseudo));

-- 2. Trigger d'auto-création de profil : ne doit jamais faire échouer l'auth.
create or replace function handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, pseudo)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'pseudo', 'RetroKid')
  )
  on conflict (id) do nothing;
  return new;
exception
  when others then
    return new;
end;
$$ language plpgsql security definer set search_path = public;

commit;
