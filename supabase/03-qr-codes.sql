-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — vrais QR codes
--  À coller dans : Supabase > SQL Editor > New query > Run
--  À déployer avec treasureworld (5).html
--
--  Une étape « QR » se valide en scannant le QR imprimé par le créateur :
--  le contenu du QR est la « réponse » de l'étape, vérifiée par le serveur.
--  (Ancienne étape QR sans réponse → validée par la position GPS, comme avant.)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.tw_submit_answer(p_session uuid, p_answer text, p_hint boolean default false)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  g game_sessions := tw__my_session(p_session);
  s hunt_steps;
begin
  select * into s from hunt_steps where hunt_id = g.hunt_id order by step_order offset g.current_step limit 1;
  if s.step_type not in ('enigme','qr') then raise exception 'mauvais_type_etape'; end if;
  if s.step_type = 'qr' and coalesce(trim(s.answer),'') = '' then raise exception 'mauvais_type_etape'; end if;
  if lower(unaccent(trim(coalesce(s.answer,'')))) <> lower(unaccent(trim(coalesce(p_answer,'')))) then
    return jsonb_build_object('correct', false);
  end if;
  return tw__advance(p_session, 20, p_hint);
end;
$$;

create or replace function public.tw_reach_step(p_session uuid, p_lat float8, p_lng float8)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g game_sessions := tw__my_session(p_session);
  s hunt_steps;
  v_dist float8;
  v_creator boolean;
begin
  select * into s from hunt_steps where hunt_id = g.hunt_id order by step_order offset g.current_step limit 1;
  -- « prox », ou ancienne étape QR créée sans contenu de QR
  if not (s.step_type = 'prox' or (s.step_type = 'qr' and coalesce(trim(s.answer),'') = '')) then
    raise exception 'mauvais_type_etape';
  end if;
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
