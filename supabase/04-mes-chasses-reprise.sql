-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — écran « Mes chasses » + reprise d'une partie
--  À coller dans : Supabase > SQL Editor > New query > Run
--  À déployer avec la version 6 de index.html
-- ═══════════════════════════════════════════════════════════════

-- Liste des chasses créées par le joueur connecté, avec statistiques
create or replace function public.tw_my_hunts()
returns table(id uuid, name text, access_code text, status text, city text,
              created_at timestamptz, play_count int, completions int,
              step_count int, qr_count int, best_time_sec int)
language sql stable security definer set search_path = public as $$
  select h.id, h.name::text, h.access_code::text, h.status::text, h.city::text,
         h.created_at, coalesce(h.play_count,0)::int,
         (select count(*) from game_sessions g where g.hunt_id = h.id and g.status = 'termine')::int,
         (select count(*) from hunt_steps s where s.hunt_id = h.id)::int,
         (select count(*) from hunt_steps s where s.hunt_id = h.id and s.step_type = 'qr')::int,
         (select min(g.duration_sec) from game_sessions g
           where g.hunt_id = h.id and g.status = 'termine' and g.duration_sec >= 60)::int
    from hunts h
   where h.creator_id = tw__me()
   order by h.created_at desc;
$$;

-- Contenus des QR d'une de SES chasses (pour réimprimer)
create or replace function public.tw_my_qr_codes(p_hunt_id uuid)
returns table(step_order int, text text, qr text)
language sql stable security definer set search_path = public as $$
  select s.step_order::int, s.text::text, s.answer::text
    from hunt_steps s join hunts h on h.id = s.hunt_id
   where s.hunt_id = p_hunt_id and s.step_type = 'qr'
     and coalesce(trim(s.answer),'') <> ''
     and h.creator_id = tw__me()
   order by s.step_order;
$$;

-- Démarrer une chasse : reprend la partie en cours s'il y en a une
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
  select id into v_id from game_sessions
   where player_id = v_me and hunt_id = p_hunt_id and status = 'en_cours'
   order by started_at desc limit 1;
  if v_id is not null then return v_id; end if;
  insert into game_sessions(player_id, hunt_id, status, current_step)
    values (v_me, p_hunt_id, 'en_cours', 0) returning id into v_id;
  update hunts set play_count = coalesce(play_count,0) + 1 where id = p_hunt_id;
  return v_id;
end;
$$;

revoke all on function public.tw_my_hunts()         from public, anon;
revoke all on function public.tw_my_qr_codes(uuid)  from public, anon;
grant execute on function public.tw_my_hunts()        to authenticated;
grant execute on function public.tw_my_qr_codes(uuid) to authenticated;
