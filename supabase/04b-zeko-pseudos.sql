-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — chasse d'Eaucourt rattachée à « Zeko l'explorateur »
--  + pseudos uniques sans tenir compte des majuscules
--  À coller dans : Supabase > SQL Editor > New query > Run
-- ═══════════════════════════════════════════════════════════════

-- 1) La chasse appartient désormais au profil « Zeko l'explorateur » (créé à 12:16)
update public.hunts
   set creator_id = '42294fd5-fe59-4328-8008-583207e23973'
 where id = 'ba0c6680-e938-4208-a73b-b3b5c59d8f1a';

update public.players p
   set created_hunts = (select count(*) from public.hunts h where h.creator_id = p.id)
 where p.id in ('42294fd5-fe59-4328-8008-583207e23973', 'f4120a52-270d-45b0-8c74-f1224f005317');

-- Trophée « Créateur » (+120 XP) pour le nouveau propriétaire
select public.tw__award_trophies('42294fd5-fe59-4328-8008-583207e23973');

-- 2) Désormais, « Zeko » et « zeko » sont considérés comme le même pseudo
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

-- Verrou en base (créé seulement s'il ne reste aucun doublon de pseudo)
do $$
begin
  if not exists (select 1 from public.players group by lower(pseudo) having count(*) > 1) then
    create unique index if not exists players_pseudo_ci on public.players (lower(pseudo));
  else
    raise notice 'Doublons de pseudo présents : index non créé (voir étape 3).';
  end if;
end $$;

-- 3) OPTIONNEL — supprimer les deux autres profils Zeko (doublons).
--    Retire les "--" devant les lignes ci-dessous seulement si tu le veux,
--    puis relance aussi le bloc "Verrou en base" ci-dessus.
--    83f065fe… = « Zeko L'explorateur » (ancien, 5000 XP, sans compte)
--    f4120a52… = « Zeko l'Explorateur » (1er navigateur, 0 XP)
-- delete from public.step_scores where session_id in (select id from public.game_sessions where player_id in ('83f065fe-d309-4f34-b1ec-4e0246123431','f4120a52-270d-45b0-8c74-f1224f005317'));
-- delete from public.game_sessions   where player_id in ('83f065fe-d309-4f34-b1ec-4e0246123431','f4120a52-270d-45b0-8c74-f1224f005317');
-- delete from public.player_trophies where player_id in ('83f065fe-d309-4f34-b1ec-4e0246123431','f4120a52-270d-45b0-8c74-f1224f005317');
-- delete from public.players         where id        in ('83f065fe-d309-4f34-b1ec-4e0246123431','f4120a52-270d-45b0-8c74-f1224f005317');
