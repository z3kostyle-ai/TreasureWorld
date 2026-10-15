-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — comptes (email, Google, empreinte), pays, langues
--  À coller dans : Supabase > SQL Editor > New query > Run
--  À déployer avec la version 7 (index.html + i18n.js)
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Langue et pays des chasses ───────────────────────────────
alter table public.hunts add column if not exists lang text not null default 'fr';
alter table public.hunts add column if not exists country_code text;
grant insert (lang, country_code) on public.hunts to authenticated;

-- La chasse d'Eaucourt : pays = France (la ville reste dans "city")
update public.hunts set country = '🇫🇷 France', country_code = 'FR'
 where id = 'ba0c6680-e938-4208-a73b-b3b5c59d8f1a' and country_code is null;

-- ─── 2. Traductions des chasses ──────────────────────────────────
create table if not exists public.hunt_translations (
  hunt_id     uuid not null references public.hunts(id) on delete cascade,
  lang        text not null check (lang ~ '^[a-z]{2}$'),
  name        text,
  description text,
  updated_at  timestamptz not null default now(),
  primary key (hunt_id, lang)
);
create table if not exists public.step_translations (
  step_id uuid not null references public.hunt_steps(id) on delete cascade,
  lang    text not null check (lang ~ '^[a-z]{2}$'),
  text    text,
  hint    text,
  answer  text,
  primary key (step_id, lang)
);
alter table public.hunt_translations enable row level security;
alter table public.step_translations enable row level security;
drop policy if exists tw_read on public.hunt_translations;
drop policy if exists tw_read on public.step_translations;
create policy tw_read on public.hunt_translations for select using (true);
create policy tw_read on public.step_translations for select using (true);
revoke all on public.hunt_translations, public.step_translations from anon, authenticated;
grant select on public.hunt_translations to anon, authenticated;
-- les réponses traduites restent secrètes, comme les réponses d'origine
grant select (step_id, lang, text, hint) on public.step_translations to anon, authenticated;

-- Réponse acceptée : celle d'origine OU celle d'une traduction
create or replace function public.tw_submit_answer(p_session uuid, p_answer text, p_hint boolean default false)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  g game_sessions := tw__my_session(p_session);
  s hunt_steps;
  v text := lower(unaccent(trim(coalesce(p_answer,''))));
begin
  select * into s from hunt_steps where hunt_id = g.hunt_id order by step_order offset g.current_step limit 1;
  if s.step_type not in ('enigme','qr') then raise exception 'mauvais_type_etape'; end if;
  if s.step_type = 'qr' and coalesce(trim(s.answer),'') = '' then raise exception 'mauvais_type_etape'; end if;
  if v = '' or not (
       lower(unaccent(trim(coalesce(s.answer,'')))) = v
       or exists (select 1 from step_translations t
                   where t.step_id = s.id and coalesce(trim(t.answer),'') <> ''
                     and lower(unaccent(trim(t.answer))) = v)
     ) then
    return jsonb_build_object('correct', false);
  end if;
  return tw__advance(p_session, 20, p_hint);
end;
$$;

-- Le créateur charge sa chasse (avec réponses) pour la traduire
create or replace function public.tw_hunt_for_edit(p_hunt_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare h hunts;
begin
  select * into h from hunts where id = p_hunt_id and creator_id = tw__me();
  if h.id is null then raise exception 'chasse_introuvable'; end if;
  return jsonb_build_object(
    'hunt', jsonb_build_object('id', h.id, 'name', h.name, 'description', h.description, 'lang', h.lang),
    'steps', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'step_order', s.step_order,
                 'step_type', s.step_type, 'text', s.text, 'hint', s.hint, 'answer', s.answer) order by s.step_order)
               from hunt_steps s where s.hunt_id = h.id), '[]'::jsonb),
    'translations', coalesce((select jsonb_object_agg(t.lang, jsonb_build_object(
                 'name', t.name, 'description', t.description,
                 'steps', coalesce((select jsonb_object_agg(st.step_id, jsonb_build_object('text', st.text, 'hint', st.hint, 'answer', st.answer))
                                      from step_translations st join hunt_steps s2 on s2.id = st.step_id
                                     where s2.hunt_id = h.id and st.lang = t.lang), '{}'::jsonb)))
               from hunt_translations t where t.hunt_id = h.id), '{}'::jsonb)
  );
end;
$$;

-- Enregistrer une traduction : {name, description, steps:[{step_id, text, hint, answer}]}
create or replace function public.tw_save_translation(p_hunt_id uuid, p_lang text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  h hunts;
  st jsonb;
begin
  select * into h from hunts where id = p_hunt_id and creator_id = tw__me();
  if h.id is null then raise exception 'chasse_introuvable'; end if;
  if p_lang !~ '^[a-z]{2}$' or p_lang = h.lang then raise exception 'langue_invalide'; end if;

  insert into hunt_translations(hunt_id, lang, name, description, updated_at)
  values (p_hunt_id, p_lang, nullif(trim(p_data->>'name'),''), nullif(trim(p_data->>'description'),''), now())
  on conflict (hunt_id, lang) do update
    set name = excluded.name, description = excluded.description, updated_at = now();

  for st in select * from jsonb_array_elements(coalesce(p_data->'steps','[]'::jsonb)) loop
    if exists (select 1 from hunt_steps where id = (st->>'step_id')::uuid and hunt_id = p_hunt_id) then
      insert into step_translations(step_id, lang, text, hint, answer)
      values ((st->>'step_id')::uuid, p_lang, nullif(trim(st->>'text'),''), nullif(trim(st->>'hint'),''), nullif(trim(st->>'answer'),''))
      on conflict (step_id, lang) do update
        set text = excluded.text, hint = excluded.hint, answer = excluded.answer;
    end if;
  end loop;
end;
$$;

create or replace function public.tw_delete_translation(p_hunt_id uuid, p_lang text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from hunts where id = p_hunt_id and creator_id = tw__me()) then
    raise exception 'chasse_introuvable';
  end if;
  delete from step_translations where lang = p_lang
     and step_id in (select id from hunt_steps where hunt_id = p_hunt_id);
  delete from hunt_translations where hunt_id = p_hunt_id and lang = p_lang;
end;
$$;

-- « Mes chasses » : ajoute la langue d'origine et les langues traduites
drop function if exists public.tw_my_hunts();
create function public.tw_my_hunts()
returns table(id uuid, name text, access_code text, status text, city text,
              created_at timestamptz, play_count int, completions int,
              step_count int, qr_count int, best_time_sec int,
              lang text, langs text[])
language sql stable security definer set search_path = public as $$
  select h.id, h.name::text, h.access_code::text, h.status::text, h.city::text,
         h.created_at, coalesce(h.play_count,0)::int,
         (select count(*) from game_sessions g where g.hunt_id = h.id and g.status = 'termine')::int,
         (select count(*) from hunt_steps s where s.hunt_id = h.id)::int,
         (select count(*) from hunt_steps s where s.hunt_id = h.id and s.step_type = 'qr')::int,
         (select min(g.duration_sec) from game_sessions g
           where g.hunt_id = h.id and g.status = 'termine' and g.duration_sec >= 60)::int,
         h.lang,
         coalesce((select array_agg(t.lang order by t.lang) from hunt_translations t where t.hunt_id = h.id), '{}')
    from hunts h
   where h.creator_id = tw__me()
   order by h.created_at desc;
$$;

-- ─── 3. Passage invité → compte : fusion de la progression ───────
--  Avant de se connecter à un compte existant, l'invité obtient un jeton
--  à usage unique ; une fois connecté, ce jeton rapatrie sa progression.
create table if not exists public.guest_handoffs (
  token      text primary key,
  player_id  uuid not null references public.players(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.guest_handoffs enable row level security;
revoke all on public.guest_handoffs from anon, authenticated;

create or replace function public.tw_guest_handoff()
returns text language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := tw__me();
  v_token text;
begin
  if v_me is null then return null; end if;
  if not exists (select 1 from auth.users where id = auth.uid() and is_anonymous) then return null; end if;
  delete from guest_handoffs where player_id = v_me or created_at < now() - interval '1 day';
  v_token := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  insert into guest_handoffs(token, player_id) values (v_token, v_me);
  return v_token;
end;
$$;

create or replace function public.tw_merge_guest(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_guest uuid;
  v_me uuid := tw__me();
  g players;
  v_dup_xp int;
begin
  if auth.uid() is null then raise exception 'non_connecte'; end if;
  delete from guest_handoffs
   where token = p_token and created_at > now() - interval '30 minutes'
  returning player_id into v_guest;
  if v_guest is null or v_guest = v_me then return jsonb_build_object('merged', false); end if;

  select * into g from players where id = v_guest;
  -- seul un profil invité (compte anonyme) peut être fusionné
  if g.id is null or not exists (select 1 from auth.users where id = g.auth_id and is_anonymous) then
    return jsonb_build_object('merged', false);
  end if;

  if v_me is null then
    -- le compte n'a pas encore de profil : il adopte celui de l'invité
    update players set auth_id = auth.uid(), last_seen = now() where id = v_guest;
    return jsonb_build_object('merged', true, 'adopted', true);
  end if;

  -- trophées que les deux possèdent : leur bonus XP ne doit compter qu'une fois
  select coalesce(sum(t.xp_gained),0) into v_dup_xp from player_trophies t
   where t.player_id = v_guest
     and exists (select 1 from player_trophies m where m.player_id = v_me and m.trophy_id = t.trophy_id);

  update players p set
    xp = coalesce(p.xp,0) + greatest(coalesce(g.xp,0) - v_dup_xp, 0),
    chasses_done = coalesce(p.chasses_done,0) + coalesce(g.chasses_done,0),
    countries_played = array(select distinct c from unnest(coalesce(p.countries_played,'{}') || coalesce(g.countries_played,'{}')) c),
    last_seen = now()
  where p.id = v_me;

  update game_sessions set player_id = v_me where player_id = v_guest;
  update hunts set creator_id = v_me where creator_id = v_guest;
  insert into player_trophies(player_id, trophy_id, xp_gained)
    select v_me, t.trophy_id, t.xp_gained from player_trophies t
     where t.player_id = v_guest
       and not exists (select 1 from player_trophies m where m.player_id = v_me and m.trophy_id = t.trophy_id);
  delete from player_trophies where player_id = v_guest;
  delete from players where id = v_guest;
  update players set created_hunts = (select count(*) from hunts where creator_id = v_me) where id = v_me;
  perform tw__award_trophies(v_me);
  return jsonb_build_object('merged', true, 'adopted', false);
end;
$$;

-- ─── 4. Pseudos uniques sans tenir compte des majuscules ─────────
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
  select * into other from players
   where lower(pseudo) = lower(p_pseudo) and id is distinct from me.id
   limit 1;

  if other.id is not null then
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

-- ─── 5. Droits d'exécution ───────────────────────────────────────
revoke all on function public.tw_hunt_for_edit(uuid)              from public, anon;
revoke all on function public.tw_save_translation(uuid,text,jsonb) from public, anon;
revoke all on function public.tw_delete_translation(uuid,text)    from public, anon;
revoke all on function public.tw_my_hunts()                       from public, anon;
revoke all on function public.tw_guest_handoff()                  from public, anon;
revoke all on function public.tw_merge_guest(text)                from public, anon;
grant execute on function public.tw_hunt_for_edit(uuid)              to authenticated;
grant execute on function public.tw_save_translation(uuid,text,jsonb) to authenticated;
grant execute on function public.tw_delete_translation(uuid,text)    to authenticated;
grant execute on function public.tw_my_hunts()                       to authenticated;
grant execute on function public.tw_guest_handoff()                  to authenticated;
grant execute on function public.tw_merge_guest(text)                to authenticated;
