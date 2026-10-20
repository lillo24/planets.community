-- D-R03: synthetic, transaction-only pagination evidence, NOT real Auth evidence.
-- Direct fixtures deliberately give unrelated domains the same UUIDs and activity
-- time. The immutable legacy membership trigger chooses Project group-chat IDs;
-- those anchors are captured below, never rewritten or obtained from a list RPC.
-- Four rows per kind exercise multiple pages at both limits. C is not installed.
begin;
select no_plan();

create function pg_temp.fixture_id(n integer) returns uuid language sql immutable as $$
  select ('d1440000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid;
$$;
create function pg_temp.activity_time() returns timestamptz language sql immutable as $$
  select '2026-10-14 10:00:00+00'::timestamptz;
$$;

insert into auth.users(id, email)
select pg_temp.fixture_id(n), 'pagination-' || n || '@planets.invalid'
from unnest(array[1, 2, 3, 4, 9, 11, 12, 13, 14]) n;
insert into public.profiles(id, display_name)
select pg_temp.fixture_id(n), 'Synthetic pagination person ' || n
from unnest(array[1, 2, 3, 4, 9, 11, 12, 13, 14]) n;

-- Actor 1 is a Project creator / Resource owner / named representative and an
-- ordinary member of four distinct origins. Actor 3 manages only those origins.
insert into public.proposals(
  id, creator_profile_id, lifecycle_state, title, starts_at, ends_at, published_at
)
select pg_temp.fixture_id(300 + n), pg_temp.fixture_id(1), 'published',
  'Pagination Project ' || n, '2098-01-01 10:00+00'::timestamptz,
  '2098-01-01 12:00+00'::timestamptz, pg_temp.activity_time() - interval '1 day'
from generate_series(1, 4) n;
-- Preseed the canonical pair so the request trigger associates a deterministic
-- chat ID. Distinct counterparties prevent the durable pair model collapsing it.
insert into public.participation_conversations(id, lower_profile_id, upper_profile_id, activated_at)
select pg_temp.fixture_id(200 + n), pg_temp.fixture_id(1), pg_temp.fixture_id(10 + n),
  pg_temp.activity_time() - interval '1 hour'
from generate_series(1, 4) n;
insert into public.project_join_requests(
  id, project_id, requester_profile_id, status, request_message,
  created_at, resolved_at, resolved_by_profile_id
)
select pg_temp.fixture_id(100 + n), pg_temp.fixture_id(300 + n), pg_temp.fixture_id(10 + n),
  'accepted', 'Synthetic Project request', pg_temp.activity_time() - interval '1 hour',
  pg_temp.activity_time(), pg_temp.fixture_id(1)
from generate_series(1, 4) n;
insert into public.project_memberships(
  id, project_id, participant_profile_id, originating_request_id, joined_at
)
select pg_temp.fixture_id(1200 + n), pg_temp.fixture_id(300 + n),
  pg_temp.fixture_id(10 + n), pg_temp.fixture_id(100 + n), pg_temp.activity_time()
from generate_series(1, 4) n;

insert into public.resource_listings(
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, published_at
)
select pg_temp.fixture_id(400 + n), pg_temp.fixture_id(1), 'exchange', 'published',
  'Pagination Resource ' || n, 'Synthetic pagination Resource description.',
  'IT', 'Trento', 'Trento', pg_temp.activity_time() - interval '1 day'
from generate_series(1, 4) n;
insert into public.resource_listing_requests(
  id, listing_id, requester_profile_id, status, request_message,
  created_at, resolved_at, resolved_by_profile_id
)
select pg_temp.fixture_id(100 + n), pg_temp.fixture_id(400 + n), pg_temp.fixture_id(2),
  'accepted', 'Synthetic Resource request', pg_temp.activity_time() - interval '1 hour',
  pg_temp.activity_time(), pg_temp.fixture_id(1)
from generate_series(1, 4) n;
insert into public.resource_exchange_agreements(id, request_id, created_at)
select pg_temp.fixture_id(1300 + n), pg_temp.fixture_id(100 + n), pg_temp.activity_time()
from generate_series(1, 4) n;
insert into public.resource_request_chats(id, request_id, activated_at)
select pg_temp.fixture_id(200 + n), pg_temp.fixture_id(100 + n), pg_temp.activity_time()
from generate_series(1, 4) n;

insert into private.community_groups(
  id, name, description, group_kind, volunteering_focus, publication_state, original_actor_id
)
select pg_temp.fixture_id(base + n), 'Pagination Group ' || (base + n),
  'Synthetic transaction-only pagination Group.', 'informal', false, 'published',
  pg_temp.fixture_id(actor)
from (values (500, 1), (600, 2), (700, 4), (800, 3)) family(base, actor)
cross join generate_series(1, 4) n;
insert into private.community_group_managers(group_id, profile_id, appointed_by_actor_id)
select id, original_actor_id, original_actor_id from private.community_groups
where id between pg_temp.fixture_id(501) and pg_temp.fixture_id(804);
insert into private.group_memberships(id, group_id, profile_id, admitted_by, joined_at)
select pg_temp.fixture_id(1400 + n * 10 + actor), pg_temp.fixture_id(800 + n),
  pg_temp.fixture_id(actor), pg_temp.fixture_id(3), pg_temp.activity_time() - interval '1 day'
from generate_series(1, 4) n cross join generate_series(1, 2) actor;

insert into private.group_contact_requests(
  id, source_group_id, target_group_id, submitter_id, purpose, title, note, status,
  created_at, expires_at, resolved_at, resolved_by
)
select pg_temp.fixture_id(100 + n), pg_temp.fixture_id(500 + n), pg_temp.fixture_id(600 + n),
  pg_temp.fixture_id(1), 'collaboration', 'Pagination bilateral ' || n,
  'Synthetic representative invitation', 'accepted', pg_temp.activity_time() - interval '1 hour',
  pg_temp.activity_time() + interval '7 days', pg_temp.activity_time(), pg_temp.fixture_id(2)
from generate_series(1, 4) n;
insert into private.group_contact_conversations(id, request_id, title, summary, created_at)
select pg_temp.fixture_id(200 + n), pg_temp.fixture_id(100 + n), 'Pagination bilateral ' || n,
  'Synthetic representative conversation', pg_temp.activity_time()
from generate_series(1, 4) n;
insert into private.group_contact_admissions(id, conversation_id, profile_id, group_id, admitted_at)
select pg_temp.fixture_id(1500 + n * 10 + actor), pg_temp.fixture_id(200 + n), pg_temp.fixture_id(actor),
  pg_temp.fixture_id(case actor when 1 then 500 else 600 end + n), pg_temp.activity_time()
from generate_series(1, 4) n cross join generate_series(1, 2) actor;

insert into private.group_coordination_proposals(
  id, source_chat_id, initiator_id, title, note, created_at, activity_at, expires_at
)
select pg_temp.fixture_id(100 + n), pg_temp.fixture_id(200 + n), pg_temp.fixture_id(1),
  'Pagination coordination ' || n, 'Synthetic exact audience invitation',
  pg_temp.activity_time(), pg_temp.activity_time(), pg_temp.activity_time() + interval '7 days'
from generate_series(1, 4) n;
insert into private.group_coordination_seats(
  id, proposal_id, group_id, source_admission_id, profile_id, claimed_at, confirmed_version
)
select pg_temp.fixture_id(1600 + n * 10 + actor), pg_temp.fixture_id(100 + n),
  pg_temp.fixture_id(case actor when 1 then 500 when 2 then 600 else 700 end + n),
  case when actor in (1, 2) then pg_temp.fixture_id(1500 + n * 10 + actor) end,
  pg_temp.fixture_id(actor), pg_temp.activity_time(), 1
from generate_series(1, 4) n cross join unnest(array[1, 2, 4]) actor;
insert into private.group_contact_conversations(
  id, coordination_proposal_id, conversation_kind, title, summary, created_at
)
select pg_temp.fixture_id(900 + n), pg_temp.fixture_id(100 + n), 'coordination',
  'Pagination coordination ' || n, 'Synthetic fresh coordination room', pg_temp.activity_time()
from generate_series(1, 4) n;
insert into private.group_contact_admissions(id, conversation_id, profile_id, group_id, admitted_at)
select pg_temp.fixture_id(1700 + n * 10 + actor), pg_temp.fixture_id(900 + n), pg_temp.fixture_id(actor),
  pg_temp.fixture_id(case actor when 1 then 500 when 2 then 600 else 700 end + n), pg_temp.activity_time()
from generate_series(1, 4) n cross join unnest(array[1, 2, 4]) actor;
update private.group_coordination_proposals p set status = 'active',
  ended_at = pg_temp.activity_time(), ended_by = pg_temp.fixture_id(4),
  room_id = pg_temp.fixture_id(900 + n)
from generate_series(1, 4) n where p.id = pg_temp.fixture_id(100 + n);
-- End states occur after coordination activation; closing retains this reader,
-- while the peer leaving also makes the bilateral conversation read-only.
update private.group_contact_conversations set closed_at = pg_temp.activity_time() + interval '1 hour',
  closed_by = pg_temp.fixture_id(1) where id = pg_temp.fixture_id(201);
update private.group_contact_admissions set left_at = pg_temp.activity_time() + interval '1 hour'
where id = pg_temp.fixture_id(1522);

insert into private.member_contact_pairs(id, group_id, low_profile_id, high_profile_id, created_at)
select pg_temp.fixture_id(200 + n), pg_temp.fixture_id(800 + n),
  pg_temp.fixture_id(1), pg_temp.fixture_id(2), pg_temp.activity_time() - interval '1 hour'
from generate_series(1, 4) n;
insert into private.member_contact_requests(
  id, pair_id, sender_profile_id, recipient_profile_id, group_name,
  sender_display_name, recipient_display_name, note, status,
  created_at, activity_at, expires_at, resolved_at, resolved_by
)
select pg_temp.fixture_id(100 + n), pg_temp.fixture_id(200 + n), pg_temp.fixture_id(1),
  pg_temp.fixture_id(2), 'Pagination Group ' || (800 + n), 'Synthetic pagination person 1',
  'Synthetic pagination person 2', 'Synthetic personal invitation', 'accepted',
  pg_temp.activity_time() - interval '1 hour', pg_temp.activity_time(),
  pg_temp.activity_time() + interval '7 days', pg_temp.activity_time(), pg_temp.fixture_id(2)
from generate_series(1, 4) n;
insert into private.member_contact_episodes(
  id, pair_id, request_id, accepted_at, first_ordinal, ended_at, end_ordinal, ended_reason, ended_by
)
select pg_temp.fixture_id(1000 + n), pg_temp.fixture_id(200 + n), pg_temp.fixture_id(100 + n),
  pg_temp.activity_time(), 1,
  case when n <= 2 then pg_temp.activity_time() + interval '1 hour' end,
  case when n <= 2 then 0 end,
  case n when 1 then 'closed' when 2 then 'left' end,
  case when n <= 2 then pg_temp.fixture_id(1) end
from generate_series(1, 4) n;

-- Expectations are fixture-owned, independent of the APIs being checked. Rank is
-- stated here rather than calling the production rank function under test.
create temporary table expected_items(
  surface text, item_kind text, object_id uuid, kind_rank integer, variant text,
  primary key(surface, item_kind, object_id)
);
insert into expected_items
select 'requests', kind, pg_temp.fixture_id(100 + n), rank, kind
from (values ('participation_request', 0), ('resource_request', 1),
  ('group_contact_request', 2), ('group_coordination_proposal', 3),
  ('member_contact_request', 4)) kinds(kind, rank)
cross join generate_series(1, 4) n;
insert into expected_items
select 'private', kind, pg_temp.fixture_id(200 + n), rank, kind
from (values ('resource_chat', 1), ('project_request_chat', 2), ('member_contact_chat', 4)) kinds(kind, rank)
cross join generate_series(1, 4) n;
insert into expected_items
select 'groups', 'group_contact_chat', pg_temp.fixture_id(base + n), 3, variant
from (values (200, 'bilateral'), (900, 'coordination')) kinds(base, variant)
cross join generate_series(1, 4) n;
insert into expected_items
select 'groups', 'project_chat', id, 0, 'project_chat' from public.project_group_chats
where project_id between pg_temp.fixture_id(301) and pg_temp.fixture_id(304);

-- The pager uses only public RPCs as SECURITY INVOKER. Each continuation is the
-- exact final row of the prior page, including kind; an extra call proves EOF.
create function pg_temp.pages(p_actor uuid, p_surface text, p_version integer, p_limit integer)
returns table(page_number integer, item_number integer, item jsonb)
language plpgsql as $$
declare batch jsonb; tail jsonb; cursor_time timestamptz; cursor_kind text; cursor_id uuid;
begin
  page_number := 0;
  loop
    if page_number > 50 then raise exception 'Pagination did not reach an empty terminal page'; end if;
    if p_surface = 'requests' then
      case p_version
        when 1 then select coalesce(jsonb_agg(to_jsonb(r) - 'ordinality' order by r.ordinality), '[]'::jsonb) into batch
          from public.list_own_structured_request_message_items(p_actor, p_limit, cursor_time, cursor_kind, cursor_id) with ordinality r;
        when 2 then batch := public.list_own_structured_request_message_items_v2(p_actor, p_limit, cursor_time, cursor_kind, cursor_id);
        when 3 then batch := public.list_own_structured_request_message_items_v3(p_actor, p_limit, cursor_time, cursor_kind, cursor_id);
        when 4 then batch := public.list_own_structured_request_message_items_v4(p_actor, p_limit, cursor_time, cursor_kind, cursor_id);
        else raise exception 'Unsupported fixture Requests version';
      end case;
    else
      case p_version
        when 5 then batch := public.list_own_scoped_conversation_items_v5(p_actor, p_surface, p_limit, cursor_time, cursor_kind, cursor_id);
        when 6 then batch := public.list_own_scoped_conversation_items_v6(p_actor, p_surface, p_limit, cursor_time, cursor_kind, cursor_id);
        when 7 then batch := public.list_own_scoped_conversation_items_v7(p_actor, p_surface, p_limit, cursor_time, cursor_kind, cursor_id);
        else raise exception 'Unsupported fixture Chats version';
      end case;
    end if;
    if batch is null or jsonb_typeof(batch) <> 'array' then raise exception 'Expected a JSON page array'; end if;
    exit when jsonb_array_length(batch) = 0;
    page_number := page_number + 1;
    item_number := 0;
    for item in select value from jsonb_array_elements(batch) loop
      item_number := item_number + 1;
      return next;
    end loop;
    tail := batch -> (jsonb_array_length(batch) - 1);
    cursor_time := (tail ->> 'activity_at')::timestamptz;
    cursor_kind := tail ->> 'item_kind';
    cursor_id := coalesce(tail ->> 'proposal_id', tail ->> 'request_id', tail ->> 'chat_id')::uuid;
    -- Chat projections may also contain a request context. Chat cursors always
    -- use chat_id, while Requests v3/v4 use proposal_id for coordination only.
    if p_surface <> 'requests' then cursor_id := (tail ->> 'chat_id')::uuid; end if;
  end loop;
end;
$$;
create function pg_temp.item_key(item jsonb, surface text) returns text language sql immutable as $$
  select (item ->> 'item_kind') || ':' || case when surface = 'requests'
    then coalesce(item ->> 'proposal_id', item ->> 'request_id') else item ->> 'chat_id' end;
$$;
create temporary table runs(surface text, version integer, page_size integer, max_rank integer);
insert into runs select 'requests', v, size, v from generate_series(1, 4) v cross join unnest(array[2, 3]) size;
insert into runs select surface, v, size, case v when 5 then 2 when 6 then 3 else 4 end
from unnest(array['private', 'groups']) surface cross join generate_series(5, 7) v cross join unnest(array[2, 3]) size;
create temporary table actual_pages(surface text, version integer, page_size integer, page_number integer, item_number integer, item jsonb);
grant select on expected_items, runs to authenticated;
grant all on actual_pages to authenticated;
grant execute on function pg_temp.fixture_id(integer), pg_temp.activity_time(),
  pg_temp.pages(uuid, text, integer, integer), pg_temp.item_key(jsonb, text) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(1)::text, true);
insert into actual_pages
select r.surface, r.version, r.page_size, p.page_number, p.item_number, p.item
from runs r cross join lateral pg_temp.pages(pg_temp.fixture_id(1), r.surface, r.version, r.page_size) p;

-- Every adapter version must exhaust exactly its supported canonical set. This
-- simultaneously checks order, domain ties, exclusions before LIMIT, omissions,
-- duplicates and the terminal page, rather than merely checking a first row.
select is(
  array(select pg_temp.item_key(a.item, a.surface) from actual_pages a
    where (a.surface, a.version, a.page_size) = (r.surface, r.version, r.page_size)
    order by a.page_number, a.item_number),
  array(select e.item_kind || ':' || e.object_id from expected_items e
    where e.surface = r.surface and e.kind_rank <= r.max_rank order by e.kind_rank desc, e.object_id desc),
  format('%s v%s size %s exhausts the supported canonical set in domain-aware order', r.surface, r.version, r.page_size)
) from runs r order by r.surface, r.version, r.page_size;
select ok(
  (select max(a.item_number) <= r.page_size from actual_pages a
    where (a.surface, a.version, a.page_size) = (r.surface, r.version, r.page_size)),
  format('%s v%s honors page size %s', r.surface, r.version, r.page_size)
) from runs r order by r.surface, r.version, r.page_size;
select is((select count(distinct (item ->> 'activity_at')::timestamptz) from actual_pages), 1::bigint,
  'every domain and historical state participates in the same activity-time tie');
select is((select min((item ->> 'activity_at')::timestamptz) from actual_pages), pg_temp.activity_time(),
  'the equal activity timestamp is the deliberate fixture timestamp');
select is(count(*)::integer, 4, format('%s / %s contains four canonical rows', surface, variant))
from expected_items group by surface, variant order by surface, variant;
select ok(count(distinct a.page_number) > 1,
  format('%s / %s traverses more than one page at size %s', e.surface, e.variant, a.page_size))
from actual_pages a join expected_items e on e.surface = a.surface
  and pg_temp.item_key(a.item, a.surface) = e.item_kind || ':' || e.object_id
where a.version = case a.surface when 'requests' then 4 else 7 end
group by e.surface, e.variant, a.page_size order by e.surface, e.variant, a.page_size;

-- Compare both small-page traversals to one independently checked full RPC page.
select is(
  array(select pg_temp.item_key(p.item, surface) from pg_temp.pages(pg_temp.fixture_id(1), surface, version, 50) p
    order by p.page_number, p.item_number),
  array(select e.item_kind || ':' || e.object_id from expected_items e where e.surface = scope.surface
    order by e.kind_rank desc, e.object_id desc),
  surface || ' full canonical page agrees with the independently enumerated fixture'
) from (values ('requests', 4), ('private', 7), ('groups', 7)) scope(surface, version);

select is((select count(*) from actual_pages where surface = 'private' and version = 7 and page_size = 2
  and item ->> 'item_kind' = 'member_contact_chat' and (item ->> 'is_read_only')::boolean), 2::bigint,
  'closed and left personal histories both remain in Private pagination');
select is(array(select item ->> 'ended_reason' from actual_pages where surface = 'private' and version = 7
  and page_size = 2 and item ->> 'item_kind' = 'member_contact_chat' and item ->> 'ended_reason' is not null order by item ->> 'ended_reason'),
  array['closed', 'left'], 'personal end reasons survive mixed projection');
select is((select count(distinct item ->> 'group_id') from actual_pages where surface = 'private' and version = 7
  and page_size = 2 and item ->> 'item_kind' = 'member_contact_chat'), 4::bigint,
  'the same named personal pair has four separate origin-Group conversations');
select is((select count(*) from actual_pages where surface = 'groups' and version = 7 and page_size = 2
  and item ->> 'conversation_kind' = 'bilateral' and (item ->> 'is_read_only')::boolean), 2::bigint,
  'closed and peer-left representative conversations remain visible read-only');

select throws_ok($$select public.list_own_structured_request_message_items_v4(pg_temp.fixture_id(2), 2)$$,
  '42501', null, 'Requests v4 rejects a foreign expected actor');
select throws_ok($$select public.list_own_scoped_conversation_items_v7(pg_temp.fixture_id(2), 'private', 3)$$,
  '42501', null, 'Chats v7 rejects a foreign expected actor');

-- Actor 11 owns only one Project request/pair and its Project group chat. Even
-- with exactly colliding IDs, no Resource, representative or member row leaks.
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(11)::text, true);
select is(array(select pg_temp.item_key(item, 'requests') from pg_temp.pages(pg_temp.fixture_id(11), 'requests', 4, 2)),
  array['participation_request:' || pg_temp.fixture_id(101)], 'Requests v4 filters other actors before pagination');
select is(array(select pg_temp.item_key(item, 'private') from pg_temp.pages(pg_temp.fixture_id(11), 'private', 7, 2)),
  array['project_request_chat:' || pg_temp.fixture_id(201)], 'Private v7 isolates one named Project pair despite UUID collisions');
select is(array(select pg_temp.item_key(item, 'groups') from pg_temp.pages(pg_temp.fixture_id(11), 'groups', 7, 3)),
  array(select item_kind || ':' || object_id from expected_items where surface = 'groups'
    and item_kind = 'project_chat' and object_id = (select item.accepted_project_group_chat_id
      from public.get_own_participation_conversation(pg_temp.fixture_id(11), pg_temp.fixture_id(101)) item)),
  'Groups v7 isolates the actor-owned Project membership');

select set_config('request.jwt.claim.sub', pg_temp.fixture_id(3)::text, true);
select is(public.list_own_structured_request_message_items_v4(pg_temp.fixture_id(3), 2), '[]'::jsonb,
  'origin Group manager receives no personal requests');
select is(public.list_own_scoped_conversation_items_v7(pg_temp.fixture_id(3), 'private', 3), '[]'::jsonb,
  'origin Group manager receives no personal chats');
select throws_ok($$select public.get_own_member_contact_request(pg_temp.fixture_id(3), pg_temp.fixture_id(101))$$,
  '42501', null, 'origin Group management grants no exact personal request access');
select throws_ok($$select public.get_own_member_contact_conversation(pg_temp.fixture_id(3), pg_temp.fixture_id(201))$$,
  '42501', null, 'origin Group management grants no exact personal chat access');
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(9)::text, true);
select is(public.list_own_structured_request_message_items_v4(pg_temp.fixture_id(9), 3), '[]'::jsonb,
  'unrelated actor has no Requests items');
select is(public.list_own_scoped_conversation_items_v7(pg_temp.fixture_id(9), 'private', 2), '[]'::jsonb,
  'unrelated actor has no Private items');
select is(public.list_own_scoped_conversation_items_v7(pg_temp.fixture_id(9), 'groups', 3), '[]'::jsonb,
  'unrelated actor has no Groups items');

-- A synthetic own-representative departure removes that D chat before LIMIT.
-- This differs deliberately from retained closed/left personal M histories.
reset role;
update private.group_contact_admissions set left_at = pg_temp.activity_time() + interval '2 hours'
where id = pg_temp.fixture_id(1511);
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.fixture_id(1)::text, true);
select is(
  array(select pg_temp.item_key(item, 'groups') from pg_temp.pages(pg_temp.fixture_id(1), 'groups', 7, size)
    order by page_number, item_number),
  array(select item_kind || ':' || object_id from expected_items where surface = 'groups'
    and not (item_kind = 'group_contact_chat' and object_id = pg_temp.fixture_id(201))
    order by kind_rank desc, object_id desc),
  format('own representative leave removes only that chat before LIMIT at size %s', size)
) from unnest(array[2, 3]) size;
select throws_ok($$select public.get_own_group_contact_conversation(pg_temp.fixture_id(1), pg_temp.fixture_id(201))$$,
  '42501', null, 'a left representative admission grants no exact conversation access');
reset role;
select * from finish();
rollback;
