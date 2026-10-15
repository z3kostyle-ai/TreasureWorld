-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — le créateur peut modifier ou supprimer sa chasse
--  À coller dans : Supabase > SQL Editor > New query > Run
-- ═══════════════════════════════════════════════════════════════

-- L'éditeur reçoit toute la chasse (position et rayon des étapes compris)
create or replace function public.tw_hunt_for_edit(p_hunt_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare h hunts;
begin
  select * into h from hunts where id = p_hunt_id and creator_id = tw__me();
  if h.id is null then raise exception 'chasse_introuvable'; end if;
  return jsonb_build_object(
    'hunt', jsonb_build_object('id', h.id, 'name', h.name, 'description', h.description, 'lang', h.lang,
              'access_code', h.access_code, 'country', h.country, 'country_code', h.country_code, 'city', h.city,
              'duration_min', h.duration_min, 'difficulty', h.difficulty),
    'steps', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'step_order', s.step_order,
                 'step_type', s.step_type, 'text', s.text, 'hint', s.hint, 'answer', s.answer,
                 'lat', s.lat, 'lng', s.lng, 'trigger_radius', s.trigger_radius) order by s.step_order)
               from hunt_steps s where s.hunt_id = h.id), '[]'::jsonb),
    'translations', coalesce((select jsonb_object_agg(t.lang, jsonb_build_object(
                 'name', t.name, 'description', t.description, 'auto', t.auto,
                 'steps', coalesce((select jsonb_object_agg(st.step_id, jsonb_build_object('text', st.text, 'hint', st.hint, 'answer', st.answer))
                                      from step_translations st join hunt_steps s2 on s2.id = st.step_id
                                     where s2.hunt_id = h.id and st.lang = t.lang), '{}'::jsonb)))
               from hunt_translations t where t.hunt_id = h.id), '{}'::jsonb)
  );
end;
$$;

-- Enregistrer les modifications.
-- p_data = {name, access_code, country, country_code, city, lang, duration_min, difficulty, description,
--           steps:[{id (absent = nouvelle étape), lat, lng, step_type, text, answer, hint, trigger_radius}]}
create or replace function public.tw_update_hunt(p_hunt_id uuid, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  h hunts;
  st jsonb;
  i int := 0;
  v_ids uuid[];
  v_total int;
  v_lang text := coalesce(nullif(p_data->>'lang',''), 'fr');
begin
  select * into h from hunts where id = p_hunt_id and creator_id = tw__me() for update;
  if h.id is null then raise exception 'chasse_introuvable'; end if;
  if coalesce(trim(p_data->>'name'),'') = '' or coalesce(trim(p_data->>'access_code'),'') = '' then raise exception 'nom_code_requis'; end if;
  if jsonb_array_length(coalesce(p_data->'steps','[]'::jsonb)) < 2 then raise exception 'deux_etapes_minimum'; end if;
  if v_lang !~ '^[a-z]{2}$' then raise exception 'langue_invalide'; end if;

  update hunts set
    name = trim(p_data->>'name'),
    access_code = upper(trim(p_data->>'access_code')),
    country = p_data->>'country', country_code = p_data->>'country_code',
    city = p_data->>'city', lang = v_lang,
    duration_min = nullif(p_data->>'duration_min','')::int,
    difficulty = p_data->>'difficulty', description = p_data->>'description',
    start_lat = (p_data->'steps'->0->>'lat')::float8,
    start_lng = (p_data->'steps'->0->>'lng')::float8
  where id = p_hunt_id;

  -- Étapes retirées : supprimées (avec leurs scores et traductions)
  select coalesce(array_agg((s->>'id')::uuid), '{}') into v_ids
    from jsonb_array_elements(p_data->'steps') s where coalesce(s->>'id','') <> '';
  delete from step_scores where step_id in (select id from hunt_steps where hunt_id = p_hunt_id and not (id = any(v_ids)));
  delete from hunt_steps where hunt_id = p_hunt_id and not (id = any(v_ids));

  -- Numéros provisoires pour pouvoir réordonner sans conflit
  update hunt_steps set step_order = step_order + 100000 where hunt_id = p_hunt_id;

  for st in select * from jsonb_array_elements(p_data->'steps') loop
    i := i + 1;
    if coalesce(st->>'id','') <> '' and exists (select 1 from hunt_steps where id = (st->>'id')::uuid and hunt_id = p_hunt_id) then
      update hunt_steps set
        step_order = i, lat = (st->>'lat')::float8, lng = (st->>'lng')::float8,
        step_type = st->>'step_type', text = st->>'text',
        answer = nullif(trim(coalesce(st->>'answer','')),''), hint = nullif(trim(coalesce(st->>'hint','')),''),
        trigger_radius = coalesce((st->>'trigger_radius')::int, 20)
      where id = (st->>'id')::uuid;
    else
      insert into hunt_steps(hunt_id, step_order, lat, lng, step_type, text, answer, hint, trigger_radius)
      values (p_hunt_id, i, (st->>'lat')::float8, (st->>'lng')::float8, st->>'step_type', st->>'text',
              nullif(trim(coalesce(st->>'answer','')),''), nullif(trim(coalesce(st->>'hint','')),''),
              coalesce((st->>'trigger_radius')::int, 20));
    end if;
  end loop;

  -- Traductions automatiques refaites à la demande ; une traduction dans la nouvelle langue d'origine n'a plus lieu d'être
  delete from step_translations where (auto or lang = v_lang)
     and step_id in (select id from hunt_steps where hunt_id = p_hunt_id);
  delete from hunt_translations where hunt_id = p_hunt_id and (auto or lang = v_lang);

  -- Parties en cours : l'étape courante reste dans les limites
  select count(*) into v_total from hunt_steps where hunt_id = p_hunt_id;
  update game_sessions set current_step = least(current_step, v_total - 1)
   where hunt_id = p_hunt_id and status = 'en_cours';
end;
$$;

-- Supprimer définitivement sa chasse (parties, scores et traductions compris)
create or replace function public.tw_delete_hunt(p_hunt_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := tw__me();
begin
  if not exists (select 1 from hunts where id = p_hunt_id and creator_id = v_me) then
    raise exception 'chasse_introuvable';
  end if;
  delete from step_scores where session_id in (select id from game_sessions where hunt_id = p_hunt_id)
                             or step_id in (select id from hunt_steps where hunt_id = p_hunt_id);
  delete from game_sessions where hunt_id = p_hunt_id;
  delete from step_translations where step_id in (select id from hunt_steps where hunt_id = p_hunt_id);
  delete from hunt_translations where hunt_id = p_hunt_id;
  delete from hunt_steps where hunt_id = p_hunt_id;
  delete from hunts where id = p_hunt_id;
  update players set created_hunts = (select count(*) from hunts where creator_id = v_me) where id = v_me;
end;
$$;

revoke all on function public.tw_update_hunt(uuid,jsonb) from public, anon;
revoke all on function public.tw_delete_hunt(uuid)       from public, anon;
grant execute on function public.tw_update_hunt(uuid,jsonb) to authenticated;
grant execute on function public.tw_delete_hunt(uuid)       to authenticated;
