-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — sécurisation Supabase
--  À coller dans : Supabase > SQL Editor > New query > Run
--  Compatible avec treasureworld (3).html
-- ═══════════════════════════════════════════════════════════════

-- 1) Vérification des réponses côté serveur
--    Le navigateur envoie la réponse du joueur, le serveur répond vrai/faux.
--    La bonne réponse ne quitte jamais la base.
create extension if not exists unaccent;

create or replace function public.check_answer(p_step_id uuid, p_answer text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce(
    lower(unaccent(trim(answer))) = lower(unaccent(trim(p_answer))),
    false
  )
  from public.hunt_steps
  where id = p_step_id;
$$;

revoke all on function public.check_answer(uuid, text) from public;
grant execute on function public.check_answer(uuid, text) to anon, authenticated;

-- 2) Cacher la colonne "answer" de hunt_steps aux joueurs
--    (les créateurs peuvent toujours insérer des étapes avec réponse)
revoke select on public.hunt_steps from anon, authenticated;
grant select (id, hunt_id, step_order, lat, lng, step_type, text, hint, trigger_radius)
  on public.hunt_steps to anon, authenticated;

-- 3) Vie privée : arrondir à ~1 km les positions déjà stockées des joueurs
--    (le nouveau code n'envoie plus que des positions arrondies)
update public.players
set gps_lat = round(gps_lat::numeric, 2),
    gps_lng = round(gps_lng::numeric, 2)
where gps_lat is not null;

-- Vérification : doit renvoyer une erreur "permission denied" en rôle anon
-- set role anon; select answer from public.hunt_steps limit 1; reset role;
