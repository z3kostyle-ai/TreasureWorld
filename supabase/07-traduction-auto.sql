-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — traduction automatique (DeepL) à la demande
--  À coller dans : Supabase > SQL Editor > New query > Run
--  Puis déployer l'Edge Function « translate-hunt »
-- ═══════════════════════════════════════════════════════════════

-- Une traduction est « automatique » tant que le créateur ne l'a pas validée
alter table public.hunt_translations add column if not exists auto boolean not null default false;
alter table public.step_translations add column if not exists auto boolean not null default false;
grant select (auto) on public.step_translations to anon, authenticated;

-- Enregistrement par l'Edge Function (rôle service uniquement).
-- Ne remplace jamais une traduction validée par le créateur.
create or replace function public.tw_store_auto_translation(p_hunt_id uuid, p_lang text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare st jsonb;
begin
  if p_lang !~ '^[a-z]{2}$' then raise exception 'langue_invalide'; end if;

  insert into hunt_translations(hunt_id, lang, name, description, auto, updated_at)
  values (p_hunt_id, p_lang, nullif(p_data->>'name',''), nullif(p_data->>'description',''), true, now())
  on conflict (hunt_id, lang) do update
    set name = excluded.name, description = excluded.description, updated_at = now()
    where hunt_translations.auto;

  for st in select * from jsonb_array_elements(coalesce(p_data->'steps','[]'::jsonb)) loop
    if exists (select 1 from hunt_steps where id = (st->>'step_id')::uuid and hunt_id = p_hunt_id) then
      insert into step_translations(step_id, lang, text, hint, answer, auto)
      values ((st->>'step_id')::uuid, p_lang, nullif(st->>'text',''), nullif(st->>'hint',''), nullif(st->>'answer',''), true)
      on conflict (step_id, lang) do update
        set text = excluded.text, hint = excluded.hint, answer = excluded.answer
        where step_translations.auto;
    end if;
  end loop;
end;
$$;
revoke all on function public.tw_store_auto_translation(uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.tw_store_auto_translation(uuid,text,jsonb) to service_role;

-- Une correction du créateur « valide » la traduction (elle n'est plus automatique)
create or replace function public.tw_save_translation(p_hunt_id uuid, p_lang text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  h hunts;
  st jsonb;
begin
  select * into h from hunts where id = p_hunt_id and creator_id = tw__me();
  if h.id is null then raise exception 'chasse_introuvable'; end if;
  if p_lang !~ '^[a-z]{2}$' or p_lang = h.lang then raise exception 'langue_invalide'; end if;

  insert into hunt_translations(hunt_id, lang, name, description, auto, updated_at)
  values (p_hunt_id, p_lang, nullif(trim(p_data->>'name'),''), nullif(trim(p_data->>'description'),''), false, now())
  on conflict (hunt_id, lang) do update
    set name = excluded.name, description = excluded.description, auto = false, updated_at = now();

  for st in select * from jsonb_array_elements(coalesce(p_data->'steps','[]'::jsonb)) loop
    if exists (select 1 from hunt_steps where id = (st->>'step_id')::uuid and hunt_id = p_hunt_id) then
      insert into step_translations(step_id, lang, text, hint, answer, auto)
      values ((st->>'step_id')::uuid, p_lang, nullif(trim(st->>'text'),''), nullif(trim(st->>'hint'),''), nullif(trim(st->>'answer'),''), false)
      on conflict (step_id, lang) do update
        set text = excluded.text, hint = excluded.hint, answer = excluded.answer, auto = false;
    end if;
  end loop;
end;
$$;

-- L'éditeur du créateur reçoit aussi l'indicateur « auto »
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
                 'name', t.name, 'description', t.description, 'auto', t.auto,
                 'steps', coalesce((select jsonb_object_agg(st.step_id, jsonb_build_object('text', st.text, 'hint', st.hint, 'answer', st.answer))
                                      from step_translations st join hunt_steps s2 on s2.id = st.step_id
                                     where s2.hunt_id = h.id and st.lang = t.lang), '{}'::jsonb)))
               from hunt_translations t where t.hunt_id = h.id), '{}'::jsonb)
  );
end;
$$;
