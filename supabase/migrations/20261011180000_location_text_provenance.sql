-- MAPFIX01: durable PUBLIC text provenance, independent of image visibility.
-- No legacy backfill and no private exact-place metadata in public projections.
create table private.location_text_origins (
  item_kind text not null check (item_kind in ('one_time','recurring','resource')),
  item_id uuid not null,
  fingerprint text not null check (fingerprint ~ '^[a-f0-9]{64}$'),
  source text not null check (source in ('manual','geoapify')),
  primary key (item_kind,item_id)
);
alter table private.location_text_origins enable row level security;
revoke all on table private.location_text_origins from public,anon,authenticated,service_role;
comment on table private.location_text_origins is
 'Current public-text fingerprint only. Absence/mismatch means unknown, never inferred manual from missing geometry. No exact place, actor or receipt data.';

create function private.location_text_fingerprint(country text,city text,region text,label text)
returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(jsonb_build_array(country,city,region,label)::text,'sha256'),'hex');
$$;
revoke all on function private.location_text_fingerprint(text,text,text,text) from public,anon,authenticated,service_role;

create function private.track_public_location_text_origin()
returns trigger language plpgsql security definer set search_path = '' as $$
declare kind text := case tg_table_name when 'proposals' then 'one_time'
  when 'recurring_activities' then 'recurring' else 'resource' end;
  fingerprint text; previous text;
begin
  if tg_op='DELETE' then
    delete from private.location_text_origins where item_kind=kind and item_id=old.id;
    return null;
  end if;
  fingerprint := private.location_text_fingerprint(new.country_code,new.locality,new.administrative_area,new.public_location_label);
  if tg_op='UPDATE' then
    previous := private.location_text_fingerprint(old.country_code,old.locality,old.administrative_area,old.public_location_label);
  end if;
  if new.selected_public_place is not null or
    (tg_op='UPDATE' and old.selected_public_place is not null and fingerprint=previous) then
    -- Clearing geometry alone does not turn retained provider text into manual.
    insert into private.location_text_origins values(kind,new.id,fingerprint,'geoapify')
      on conflict(item_kind,item_id) do update set fingerprint=excluded.fingerprint,source=excluded.source;
  elsif fingerprint is distinct from previous then
    -- Ordinary edits/template copies cannot attest manual authorship.
    delete from private.location_text_origins where item_kind=kind and item_id=new.id;
  end if;
  return null;
end;
$$;
revoke all on function private.track_public_location_text_origin() from public,anon,authenticated,service_role;
create trigger mapfix01_text_origin after insert or update or delete on public.proposals for each row execute function private.track_public_location_text_origin();
create trigger mapfix01_text_origin after insert or update or delete on public.recurring_activities for each row execute function private.track_public_location_text_origin();
create trigger mapfix01_text_origin after insert or update or delete on public.resource_listings for each row execute function private.track_public_location_text_origin();

create function private.public_location_text_source(p_kind text,p_item uuid)
returns text language plpgsql stable security definer set search_path = '' as $$
declare current_fingerprint text; selected jsonb; result text;
begin
  if p_kind='one_time' then
    select private.location_text_fingerprint(country_code,locality,administrative_area,public_location_label),selected_public_place
      into current_fingerprint,selected from public.proposals where id=p_item;
  elsif p_kind='recurring' then
    select private.location_text_fingerprint(country_code,locality,administrative_area,public_location_label),selected_public_place
      into current_fingerprint,selected from public.recurring_activities where id=p_item;
  elsif p_kind='resource' then
    select private.location_text_fingerprint(country_code,locality,administrative_area,public_location_label),selected_public_place
      into current_fingerprint,selected from public.resource_listings where id=p_item;
  end if;
  if selected is not null then return 'geoapify'; end if;
  select o.source into result from private.location_text_origins o
    where o.item_kind=p_kind and o.item_id=p_item and o.fingerprint=current_fingerprint;
  return coalesce(result,'unknown');
end;
$$;
revoke all on function private.public_location_text_source(text,uuid) from public,anon,authenticated,service_role;

-- Explicit manual fallback is attested only after the normal content save.
-- This adds no coordinates, changes no content/visibility/instructions and
-- reuses canonical organizer, identity and revision checks. Retry is idempotent.
create function public.confirm_manual_proposal_location_text_v1(
 p_expected_profile_id uuid,p_item uuid,p_expected_revision bigint,p_city text
)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.require_resource_listing_identity(p_expected_profile_id);
 revision bigint; p public.proposals%rowtype; city text := btrim(p_city);
begin
  revision := private.lock_location_item(actor,'one_time',p_item);
  if revision is distinct from p_expected_revision then
    raise exception using errcode='40001',message='Manual location revision changed.';
  end if;
  if city is null or char_length(city) not between 1 and 120 or city ~ '[0-9\n\r<>]'
    or city ~* '\m(via|viale|vicolo|piazza|corso|strada|street|road|avenue|lane|address|indirizzo)\M' then
    raise exception using errcode='22023',message='Manual location must be a broad city.';
  end if;
  select * into p from public.proposals where id=p_item;
  if p.public_location_label is distinct from city or p.locality is distinct from city
    or p.administrative_area is not null or p.selected_public_place is not null or p.approximate_location is not null
    or exists(select 1 from public.proposal_meeting_details where proposal_id=p_item and selected_exact_place is not null) then
    raise exception using errcode='40001',message='Save the manual city before confirming its provenance.';
  end if;
  if private.public_location_text_source('one_time',p_item)='manual' then return revision; end if;
  insert into private.location_text_origins values('one_time',p_item,
    private.location_text_fingerprint(p.country_code,p.locality,p.administrative_area,p.public_location_label),'manual')
    on conflict(item_kind,item_id) do update set fingerprint=excluded.fingerprint,source=excluded.source;
  update public.proposals set location_revision=location_revision+1 where id=p_item returning location_revision into revision;
  insert into private.audit_events(action,actor_user_id,target_type,target_id)
    values('location.updated',actor,'one_time',p_item);
  return revision;
end;
$$;
revoke all on function public.confirm_manual_proposal_location_text_v1(uuid,uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.confirm_manual_proposal_location_text_v1(uuid,uuid,bigint,text) to authenticated;
comment on function public.confirm_manual_proposal_location_text_v1(uuid,uuid,bigint,text) is
 'MAPFIX01 explicit broad-city authorship after ordinary save; canonical identity/organizer/revision checks, no geometry or protected metadata.';


-- Additive JSON metadata; existing signatures and grants remain unchanged.
create or replace function public.get_authorized_item_location_v1(p_expected_profile_id uuid,p_kind text,p_item uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_resource_listing_identity(p_expected_profile_id); result jsonb;
begin
  if p_kind='resource' then
    if not exists(select 1 from public.get_own_resource_listing(actor,p_item)) then
      raise exception using errcode='42501',message='Location read unavailable.';
    end if;
    select jsonb_build_object('revision',location_revision,'public_place',selected_public_place,'exact_place',null)
      into result from public.resource_listings where id=p_item;
  elsif p_kind in ('one_time','recurring') then
    -- Reuse effective canonical membership/manager rules, including revocation.
    perform * from public.get_project_participant_meeting_details(actor,p_item);
    if p_kind='one_time' then
      select jsonb_build_object('revision',p.location_revision,'public_place',p.selected_public_place,'exact_place',m.selected_exact_place,
          'public_label',p.public_location_label,'locality',p.locality,'country_code',p.country_code,
          'administrative_area',p.administrative_area,'exact_is_public',m.exact_location_visibility='public')
        into result from public.proposals p join public.proposal_meeting_details m on m.proposal_id=p.id where p.id=p_item;
    else
      select jsonb_build_object('revision',p.location_revision,'public_place',p.selected_public_place,'exact_place',m.selected_exact_place)
        into result from public.recurring_activities p join public.recurring_activity_meeting_details m on m.recurring_activity_id=p.id where p.id=p_item;
    end if;
    if result is null then raise exception using errcode='22023',message='Location item kind mismatch.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return result || jsonb_build_object('public_text_source',private.public_location_text_source(p_kind,p_item));
end;
$$;

create or replace function public.get_location_preview_v1(p_kind text,p_item uuid,p_view text,p_expected_profile_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare source jsonb; place jsonb; revision bigint; scope text; audience text := 'public';
 city text; country text; public_label text;
begin
 if p_view not in ('card','public_detail','protected_detail') or p_view is null then
  raise exception using errcode='22023',message='Invalid preview view.';
 end if;
 if p_view='protected_detail' then
  if p_kind not in ('one_time','recurring') or p_expected_profile_id is null then
   raise exception using errcode='42501',message='Protected preview unavailable.';
  end if;
  source := public.get_authorized_item_location_v1(p_expected_profile_id,p_kind,p_item);
  audience := 'protected';
 else
  if p_expected_profile_id is not null then
   raise exception using errcode='22023',message='Public preview has no actor scope.';
  end if;
  source := public.get_public_item_location_v1(p_kind,p_item);
 end if;
 if source is null then return null; end if;
 if p_kind='one_time' then select location_revision,locality,country_code,public_location_label into revision,city,country,public_label from public.proposals where id=p_item;
 elsif p_kind='recurring' then select location_revision,locality,country_code,public_location_label into revision,city,country,public_label from public.recurring_activities where id=p_item;
 elsif p_kind='resource' then select location_revision,locality,country_code,public_location_label into revision,city,country,public_label from public.resource_listings where id=p_item;
 else raise exception using errcode='22023',message='Invalid preview kind.'; end if;
 -- Cards NEVER select Project exact data, including explicitly public exact.
 place := case when p_view<>'card' and p_kind<>'resource' then
  coalesce(source->'exact_place',source->'public_place') else source->'public_place' end;
 -- JSON null must not mask a non-null independent public place.
 if place='null'::jsonb then place := source->'public_place'; end if;
 if place='null'::jsonb then place := null; end if;
 place := private.location_preview_place(place);
 scope := case when place->>'kind' in ('address','amenity') then 'exact' else 'area' end;
 return jsonb_build_object('item_kind',p_kind,'item_id',p_item,'revision',revision,
  'scope',scope,'audience',audience,'place',place,'public_label',public_label,
  'text_source',case when place is not null then 'geoapify' else private.public_location_text_source(p_kind,p_item) end,'legacy',jsonb_build_object('locality',city,'country_code',country),'image_key',
  case when place is null then null else encode(extensions.digest(
   jsonb_build_array('osm-carto:512x256:scale1:pitch0:bearing0:v1',scope,
    place->'latitude',place->'longitude')::text,'sha256'),'hex') end);
end;
$$;
