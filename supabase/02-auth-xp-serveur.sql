-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — comptes anonymes + XP calculé par le serveur
--  À coller dans : Supabase > SQL Editor > New query > Run
--  À déployer EN MÊME TEMPS que treasureworld (4).html
--  (treasureworld (3).html ne pourra plus écrire après ce script)
--
--  Pré-requis : Authentication > Sign In / Providers >
--               "Allow anonymous sign-ins" = activé
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Lien joueur ↔ compte Supabase ────────────────────────────
alter table public.players
  add column if not exists auth_id uuid unique references auth.users(id) on delete set null;

-- ─── 2. Fonctions internes (non appelables depuis le navigateur) ─
create or replace function public.tw__me()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.players where auth_id = auth.uid();
$$;

create or replace function public.tw__add_xp(p_player uuid, p_xp int)
returns void language sql security definer set search_path = public as $$
  update public.players
     set xp = coalesce(xp,0) + p_xp,   -- "level" est une colonne générée à partir de xp
         last_seen = now()
   where id = p_player;
$$;

-- Attribue les trophées mérités (calculés à partir des données de la base)
create or replace function public.tw__award_trophies(p_player uuid)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  v_new text[] := '{}';
  v_round int;
  t record;
  s record;
begin
  for v_round in 1..3 loop  -- plusieurs passes : un trophée peut en débloquer un autre
    select coalesce(p.chasses_done,0) as chasses,
           coalesce(p.xp,0) as xp,
           coalesce(cardinality(p.countries_played),0) as countries,
           (select count(*) from hunts h where h.creator_id = p.id) as created,
           (select count(*) from game_sessions g where g.player_id = p.id
              and g.status = 'termine' and g.duration_sec between 60 and 599) as fast,
           (select count(*) from player_trophies pt where pt.player_id = p.id) as trophies
      into s from players p where p.id = p_player;

    for t in
      select * from (values
        ('first',     50, s.chasses >= 1),
        ('explorer', 100, s.chasses >= 3),
        ('globe',    150, s.countries >= 2),
        ('legend',   200, s.xp >= 1000),
        ('creator',  120, s.created >= 1),
        ('speedy',    80, s.fast >= 1),
        ('pirate',   250, s.countries >= 3),
        ('collector',300, s.trophies >= 4)
      ) as x(id, xp, ok)
      where ok and not exists (select 1 from player_trophies pt
                               where pt.player_id = p_player and pt.trophy_id = x.id)
    loop
      insert into player_trophies(player_id, trophy_id, xp_gained) values (p_player, t.id, t.xp);
      perform tw__add_xp(p_player, t.xp);
      v_new := v_new || t.id;
    end loop;
  end loop;
  return v_new;
end;
$$;

-- Valide l'étape courante d'une session et passe à la suivante
create or replace function public.tw__advance(p_session uuid, p_xp int, p_hint boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g game_sessions;
  v_step uuid;
  v_total int;
  v_hunt hunts;
  v_dur int;
  v_hunt_xp int;
  v_trophies text[] := '{}';
begin
  select * into g from game_sessions where id = p_session for update;
  select count(*) into v_total from hunt_steps where hunt_id = g.hunt_id;
  select id into v_step from hunt_steps where hunt_id = g.hunt_id
    order by step_order offset g.current_step limit 1;

  insert into step_scores(session_id, step_id, xp_earned, attempts, hint_used)
    values (p_session, v_step, p_xp, 1, coalesce(p_hint,false));
  if p_xp > 0 then perform tw__add_xp(g.player_id, p_xp); end if;

  if g.current_step + 1 < v_total then
    update game_sessions set current_step = g.current_step + 1 where id = p_session;
    return jsonb_build_object('correct', true, 'finished', false, 'current_step', g.current_step + 1);
  end if;

  -- Fin de chasse
  select * into v_hunt from hunts where id = g.hunt_id;
  v_dur := extract(epoch from now() - g.started_at)::int;
  select coalesce(sum(xp_earned),0) + 150 into v_hunt_xp from step_scores where session_id = p_session;
  update game_sessions
     set status = 'termine', finished_at = now(), duration_sec = v_dur,
         xp_earned = v_hunt_xp, current_step = v_total
   where id = p_session;
  update players
     set chasses_done = coalesce(chasses_done,0) + 1,
         countries_played = case
           when coalesce(v_hunt.country,'') = '' or v_hunt.country = any(coalesce(countries_played,'{}'))
             then countries_played
           else array_append(coalesce(countries_played,'{}'), v_hunt.country) end
   where id = g.player_id;
  perform tw__add_xp(g.player_id, 150);
  v_trophies := tw__award_trophies(g.player_id);

  return jsonb_build_object('correct', true, 'finished', true, 'current_step', v_total,
                            'hunt_xp', v_hunt_xp, 'duration_sec', v_dur, 'trophies', to_jsonb(v_trophies));
end;
$$;

-- Session en cours du joueur connecté, verrouillée
create or replace function public.tw__my_session(p_session uuid)
returns game_sessions language plpgsql security definer set search_path = public as $$
declare g game_sessions;
begin
  select * into g from game_sessions
   where id = p_session and player_id = tw__me() and status = 'en_cours'
   for update;
  if g.id is null then raise exception 'session_invalide'; end if;
  return g;
end;
$$;

revoke all on function public.tw__me()                         from public, anon, authenticated;
revoke all on function public.tw__add_xp(uuid,int)             from public, anon, authenticated;
revoke all on function public.tw__award_trophies(uuid)         from public, anon, authenticated;
revoke all on function public.tw__advance(uuid,int,boolean)    from public, anon, authenticated;
revoke all on function public.tw__my_session(uuid)             from public, anon, authenticated;

-- ─── 3. Fonctions appelées par l'app ─────────────────────────────

-- Créer / modifier son profil. Un ancien profil sans compte peut être
-- récupéré une seule fois avec son pseudo exact.
create or replace function public.tw_save_profile(p_pseudo text, p_emoji text, p_country text)
returns public.players language plpgsql security definer set search_path = public as $$
declare
  me players;
  other players;
begin
  if auth.uid() is null then raise exception 'non_connecte'; end if;
  p_pseudo := trim(p_pseudo);
  if p_pseudo = '' or length(p_pseudo) > 30 then raise exception 'pseudo_invalide'; end if;
  if length(coalesce(p_emoji,'')) > 16 or length(coalesce(p_country,'')) > 60 then raise exception 'donnees_invalides'; end if;

  select * into me from players where auth_id = auth.uid();
  select * into other from players where pseudo = p_pseudo;

  if other.id is not null and other.id is distinct from me.id then
    if other.auth_id is null and me.id is null then
      update players set auth_id = auth.uid(), emoji = p_emoji, country = p_country, last_seen = now()
       where id = other.id returning * into me;
      return me;
    end if;
    raise exception 'pseudo_pris';
  end if;

  if me.id is null then
    insert into players(pseudo, emoji, country, auth_id, xp, chasses_done, countries_played, created_hunts, last_seen)
    values (p_pseudo, p_emoji, p_country, auth.uid(), 0, 0, '{}', 0, now())
    returning * into me;
  else
    update players set pseudo = p_pseudo, emoji = p_emoji, country = p_country, last_seen = now()
     where id = me.id returning * into me;
  end if;
  return me;
end;
$$;

create or replace function public.tw_start_session(p_hunt_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := tw__me();
  v_id uuid;
begin
  if v_me is null then raise exception 'profil_requis'; end if;
  if not exists (select 1 from hunts where id = p_hunt_id and status = 'publiee') then
    raise exception 'chasse_introuvable';
  end if;
  insert into game_sessions(player_id, hunt_id, status, current_step)
    values (v_me, p_hunt_id, 'en_cours', 0) returning id into v_id;
  update hunts set play_count = coalesce(play_count,0) + 1 where id = p_hunt_id;
  return v_id;
end;
$$;

-- Étape « énigme » : vérifie la réponse
create or replace function public.tw_submit_answer(p_session uuid, p_answer text, p_hint boolean default false)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  g game_sessions := tw__my_session(p_session);
  s hunt_steps;
begin
  select * into s from hunt_steps where hunt_id = g.hunt_id order by step_order offset g.current_step limit 1;
  if s.step_type is distinct from 'enigme' then raise exception 'mauvais_type_etape'; end if;
  if lower(unaccent(trim(coalesce(s.answer,'')))) <> lower(unaccent(trim(coalesce(p_answer,'')))) then
    return jsonb_build_object('correct', false);
  end if;
  return tw__advance(p_session, 20, p_hint);
end;
$$;

-- Étape « arrivée au point » ou « QR » : vérifie la position (marge 15 m).
-- Le créateur de la chasse peut valider sans position (pour tester chez lui).
create or replace function public.tw_reach_step(p_session uuid, p_lat float8, p_lng float8)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g game_sessions := tw__my_session(p_session);
  s hunt_steps;
  v_dist float8;
  v_creator boolean;
begin
  select * into s from hunt_steps where hunt_id = g.hunt_id order by step_order offset g.current_step limit 1;
  if s.step_type not in ('prox','qr') then raise exception 'mauvais_type_etape'; end if;
  select creator_id = g.player_id into v_creator from hunts where id = g.hunt_id;
  if not coalesce(v_creator,false) then
    if p_lat is null or p_lng is null then raise exception 'position_requise'; end if;
    v_dist := 6371000 * 2 * asin(sqrt(
      power(sin(radians(s.lat - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(s.lat)) * power(sin(radians(s.lng - p_lng) / 2), 2)));
    if v_dist > coalesce(s.trigger_radius,20) + 15 then
      return jsonb_build_object('correct', false, 'distance', round(v_dist));
    end if;
  end if;
  return tw__advance(p_session, case when s.step_type = 'qr' then 20 else 0 end, false);
end;
$$;

-- Après publication d'une chasse : met à jour le compteur et les trophées
create or replace function public.tw_after_publish()
returns text[] language plpgsql security definer set search_path = public as $$
declare v_me uuid := tw__me();
begin
  if v_me is null then raise exception 'profil_requis'; end if;
  update players set created_hunts = (select count(*) from hunts where creator_id = v_me) where id = v_me;
  return tw__award_trophies(v_me);
end;
$$;

revoke all on function public.tw_save_profile(text,text,text)          from public, anon;
revoke all on function public.tw_start_session(uuid)                   from public, anon;
revoke all on function public.tw_submit_answer(uuid,text,boolean)      from public, anon;
revoke all on function public.tw_reach_step(uuid,float8,float8)        from public, anon;
revoke all on function public.tw_after_publish()                       from public, anon;
grant execute on function public.tw_save_profile(text,text,text)       to authenticated;
grant execute on function public.tw_start_session(uuid)                to authenticated;
grant execute on function public.tw_submit_answer(uuid,text,boolean)   to authenticated;
grant execute on function public.tw_reach_step(uuid,float8,float8)     to authenticated;
grant execute on function public.tw_after_publish()                    to authenticated;
-- Remplacée par tw_submit_answer (sinon elle permettrait de tester des réponses en boucle)
revoke all on function public.check_answer(uuid,text) from public, anon, authenticated;

-- ─── 4. Droits d'accès directs aux tables ────────────────────────
revoke all on public.players, public.player_trophies, public.hunts,
              public.hunt_steps, public.game_sessions, public.step_scores
  from anon, authenticated;

grant select on public.players, public.player_trophies, public.hunts to anon, authenticated;
grant select (id, hunt_id, step_order, lat, lng, step_type, text, hint, trigger_radius)
  on public.hunt_steps to anon, authenticated;
grant select on public.game_sessions, public.step_scores to authenticated;

-- Seules écritures directes autorisées : position GPS, et création de chasses
grant update (gps_lat, gps_lng, gps_updated, last_seen) on public.players to authenticated;
grant update (current_lat, current_lng, gps_updated) on public.game_sessions to authenticated;
grant insert (creator_id, name, access_code, country, city, duration_min, difficulty,
              description, status, start_lat, start_lng) on public.hunts to authenticated;
grant insert (hunt_id, step_order, lat, lng, step_type, text, answer, hint, trigger_radius)
  on public.hunt_steps to authenticated;

-- Les vues publiques (liste des chasses, classement) lisent avec les droits de leur propriétaire
alter view public.hunts_public set (security_invoker = false);
alter view public.leaderboard  set (security_invoker = false);
grant select on public.hunts_public, public.leaderboard to anon, authenticated;

-- ─── 5. Règles par ligne (RLS) ───────────────────────────────────
-- Supprime les anciennes règles de ces tables pour repartir propre
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public'
             and tablename in ('players','player_trophies','hunts','hunt_steps','game_sessions','step_scores')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.players         enable row level security;
alter table public.player_trophies enable row level security;
alter table public.hunts           enable row level security;
alter table public.hunt_steps      enable row level security;
alter table public.game_sessions   enable row level security;
alter table public.step_scores     enable row level security;

create policy tw_read on public.players         for select using (true);
create policy tw_read on public.player_trophies for select using (true);
create policy tw_read on public.hunts           for select using (true);
create policy tw_read on public.hunt_steps      for select using (true);

create policy tw_own_gps on public.players for update to authenticated
  using (auth_id = auth.uid()) with check (auth_id = auth.uid());

create policy tw_own_read on public.game_sessions for select to authenticated
  using (player_id in (select id from public.players where auth_id = auth.uid()));
create policy tw_own_gps on public.game_sessions for update to authenticated
  using (player_id in (select id from public.players where auth_id = auth.uid()))
  with check (player_id in (select id from public.players where auth_id = auth.uid()));

create policy tw_own_read on public.step_scores for select to authenticated
  using (session_id in (select g.id from public.game_sessions g
                        join public.players p on p.id = g.player_id
                        where p.auth_id = auth.uid()));

create policy tw_create on public.hunts for insert to authenticated
  with check (creator_id in (select id from public.players where auth_id = auth.uid()));
create policy tw_create on public.hunt_steps for insert to authenticated
  with check (exists (select 1 from public.hunts h join public.players p on p.id = h.creator_id
                      where h.id = hunt_steps.hunt_id and p.auth_id = auth.uid()));
