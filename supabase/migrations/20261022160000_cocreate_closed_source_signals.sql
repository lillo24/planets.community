-- A closed accepted contact no longer offers group-source consent. Retained
-- actor sockets must not infer later capacity/lifecycle changes via that link.
-- Keep the original function identity/ACL and identifier-only payload contract.
create or replace function private.cocreate_post_group_signal(p_room uuid) returns void
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 for person in
  select p.author_id from private.cocreate_post_groups s
   join private.cocreate_posts p on p.id=s.post_id where s.room_id=p_room
  union
  select c.requester_id from private.cocreate_post_groups s
   join private.cocreate_contacts c on c.post_id=s.post_id
   where s.room_id=p_room and c.closed_at is null
 loop perform private.cocreate_signal(person);end loop;
end; $$;
