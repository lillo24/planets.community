alter table public.profiles
  add column display_name text,
  add column bio text,
  add column updated_at timestamptz not null default now(),
  add constraint profiles_display_name_valid check (
    display_name is null
    or (
      display_name = btrim(display_name)
      and char_length(display_name) between 2 and 60
    )
  ),
  add constraint profiles_bio_valid check (
    bio is null
    or (
      bio = btrim(bio)
      and char_length(bio) between 1 and 500
    )
  );

comment on column public.profiles.display_name is
  'Required user-facing name once profile setup is complete; casing is preserved.';
comment on column public.profiles.bio is
  'Optional short owner-authored profile biography.';
comment on column public.profiles.updated_at is
  'Database-maintained timestamp for the latest scalar profile change.';

create function private.set_profile_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function private.set_profile_updated_at();

create table public.skill_categories (
  id uuid primary key,
  slug text not null unique
    constraint skill_categories_slug_valid check (
      slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    ),
  label text not null
    constraint skill_categories_label_valid check (
      label = btrim(label)
      and char_length(label) between 2 and 60
    ),
  sort_order smallint not null unique
    constraint skill_categories_sort_order_positive check (sort_order > 0)
);

comment on table public.skill_categories is
  'System-managed broad groupings for the deliberately small starter skill catalog.';

create table public.skills (
  id uuid primary key,
  category_id uuid not null
    constraint skills_category_id_fkey
      references public.skill_categories (id) on delete restrict,
  slug text not null unique
    constraint skills_slug_valid check (
      slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    ),
  label text not null
    constraint skills_label_valid check (
      label = btrim(label)
      and char_length(label) between 2 and 80
    ),
  sort_order smallint not null
    constraint skills_sort_order_positive check (sort_order > 0),
  constraint skills_category_sort_order_key unique (category_id, sort_order)
);

comment on table public.skills is
  'System-managed selectable capabilities shared by profiles and later proposal requirements.';

create table public.profile_skills (
  profile_id uuid not null
    constraint profile_skills_profile_id_fkey
      references public.profiles (id) on delete cascade,
  skill_id uuid not null
    constraint profile_skills_skill_id_fkey
      references public.skills (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (profile_id, skill_id)
);

comment on table public.profile_skills is
  'Owner-selected capabilities from the canonical controlled skill catalog.';

create index profile_skills_skill_id_profile_id_idx
  on public.profile_skills (skill_id, profile_id);

create table public.profile_field_visibility (
  profile_id uuid not null
    constraint profile_field_visibility_profile_id_fkey
      references public.profiles (id) on delete cascade,
  field_key text not null
    constraint profile_field_visibility_field_key_valid check (
      field_key in ('display_name', 'bio', 'skills')
    ),
  audience text not null default 'public'
    constraint profile_field_visibility_audience_valid check (
      audience in ('public', 'private')
    ),
  primary key (profile_id, field_key)
);

comment on table public.profile_field_visibility is
  'One future-extensible audience decision per supported profile field.';

create function private.initialize_profile_visibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profile_field_visibility (profile_id, field_key, audience)
  values
    (new.id, 'display_name', 'public'),
    (new.id, 'bio', 'public'),
    (new.id, 'skills', 'public');
  return new;
end;
$$;

create trigger profiles_initialize_visibility
after insert on public.profiles
for each row
execute function private.initialize_profile_visibility();

insert into public.profile_field_visibility (profile_id, field_key, audience)
select profiles.id, fields.field_key, 'public'
from public.profiles as profiles
cross join (
  values ('display_name'), ('bio'), ('skills')
) as fields(field_key)
on conflict (profile_id, field_key) do nothing;

insert into public.skill_categories (id, slug, label, sort_order)
values
  ('c0000000-0000-4000-8000-000000000001', 'art-creativity', 'Art & Creativity', 1),
  ('c0000000-0000-4000-8000-000000000002', 'music', 'Music', 2),
  ('c0000000-0000-4000-8000-000000000003', 'diy-practical', 'DIY & Practical', 3),
  ('c0000000-0000-4000-8000-000000000004', 'gardening-nature', 'Gardening & Nature', 4),
  ('c0000000-0000-4000-8000-000000000005', 'cooking-food', 'Cooking & Food', 5),
  ('c0000000-0000-4000-8000-000000000006', 'technology', 'Technology', 6),
  ('c0000000-0000-4000-8000-000000000007', 'organization-community', 'Organization & Community', 7);

insert into public.skills (id, category_id, slug, label, sort_order)
values
  ('d0000000-0000-4000-8001-000000000001', 'c0000000-0000-4000-8000-000000000001', 'mural-painting', 'Mural painting', 1),
  ('d0000000-0000-4000-8001-000000000002', 'c0000000-0000-4000-8000-000000000001', 'drawing-illustration', 'Drawing & illustration', 2),
  ('d0000000-0000-4000-8001-000000000003', 'c0000000-0000-4000-8000-000000000001', 'photography', 'Photography', 3),
  ('d0000000-0000-4000-8001-000000000004', 'c0000000-0000-4000-8000-000000000001', 'graphic-design', 'Graphic design', 4),
  ('d0000000-0000-4000-8002-000000000001', 'c0000000-0000-4000-8000-000000000002', 'musician', 'Musician', 1),
  ('d0000000-0000-4000-8002-000000000002', 'c0000000-0000-4000-8000-000000000002', 'singing', 'Singing', 2),
  ('d0000000-0000-4000-8002-000000000003', 'c0000000-0000-4000-8000-000000000002', 'audio-sound-setup', 'Audio & sound setup', 3),
  ('d0000000-0000-4000-8003-000000000001', 'c0000000-0000-4000-8000-000000000003', 'practical-making', 'Practical making', 1),
  ('d0000000-0000-4000-8003-000000000002', 'c0000000-0000-4000-8000-000000000003', 'woodworking', 'Woodworking', 2),
  ('d0000000-0000-4000-8003-000000000003', 'c0000000-0000-4000-8000-000000000003', 'basic-repairs', 'Basic repairs', 3),
  ('d0000000-0000-4000-8003-000000000004', 'c0000000-0000-4000-8000-000000000003', 'painting-decorating', 'Painting & decorating', 4),
  ('d0000000-0000-4000-8004-000000000001', 'c0000000-0000-4000-8000-000000000004', 'gardening', 'Gardening', 1),
  ('d0000000-0000-4000-8004-000000000002', 'c0000000-0000-4000-8000-000000000004', 'plant-care', 'Plant care', 2),
  ('d0000000-0000-4000-8004-000000000003', 'c0000000-0000-4000-8000-000000000004', 'urban-gardening', 'Urban gardening', 3),
  ('d0000000-0000-4000-8005-000000000001', 'c0000000-0000-4000-8000-000000000005', 'cooking', 'Cooking', 1),
  ('d0000000-0000-4000-8005-000000000002', 'c0000000-0000-4000-8000-000000000005', 'baking', 'Baking', 2),
  ('d0000000-0000-4000-8005-000000000003', 'c0000000-0000-4000-8000-000000000005', 'food-event-support', 'Food-event support', 3),
  ('d0000000-0000-4000-8006-000000000001', 'c0000000-0000-4000-8000-000000000006', 'programming', 'Programming', 1),
  ('d0000000-0000-4000-8006-000000000002', 'c0000000-0000-4000-8000-000000000006', 'electronics', 'Electronics', 2),
  ('d0000000-0000-4000-8006-000000000003', 'c0000000-0000-4000-8000-000000000006', 'web-design-tools', 'Web & design tools', 3),
  ('d0000000-0000-4000-8007-000000000001', 'c0000000-0000-4000-8000-000000000007', 'event-organization', 'Event organization', 1),
  ('d0000000-0000-4000-8007-000000000002', 'c0000000-0000-4000-8000-000000000007', 'facilitation', 'Facilitation', 2),
  ('d0000000-0000-4000-8007-000000000003', 'c0000000-0000-4000-8000-000000000007', 'communication-social-media', 'Communication & social media', 3),
  ('d0000000-0000-4000-8007-000000000004', 'c0000000-0000-4000-8000-000000000007', 'fundraising-community-outreach', 'Fundraising & community outreach', 4);

alter table public.skill_categories enable row level security;
alter table public.skills enable row level security;
alter table public.profile_skills enable row level security;
alter table public.profile_field_visibility enable row level security;

create policy "Catalog categories are publicly readable"
on public.skill_categories
for select
to anon, authenticated
using (true);

create policy "Catalog skills are publicly readable"
on public.skills
for select
to anon, authenticated
using (true);

create policy "Authenticated users can read their own skills"
on public.profile_skills
for select
to authenticated
using ((select auth.uid()) = profile_id);

create policy "Authenticated users can add their own skills"
on public.profile_skills
for insert
to authenticated
with check ((select auth.uid()) = profile_id);

create policy "Authenticated users can remove their own skills"
on public.profile_skills
for delete
to authenticated
using ((select auth.uid()) = profile_id);

create policy "Authenticated users can read their own profile visibility"
on public.profile_field_visibility
for select
to authenticated
using ((select auth.uid()) = profile_id);

create policy "Authenticated users can initialize their own profile visibility"
on public.profile_field_visibility
for insert
to authenticated
with check ((select auth.uid()) = profile_id);

create policy "Authenticated users can update their own profile visibility"
on public.profile_field_visibility
for update
to authenticated
using ((select auth.uid()) = profile_id)
with check ((select auth.uid()) = profile_id);

create policy "Authenticated users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

grant select on table public.skill_categories to anon, authenticated;
grant select on table public.skills to anon, authenticated;
grant select, delete on table public.profile_skills to authenticated;
grant insert (profile_id, skill_id) on table public.profile_skills to authenticated;
grant select, insert on table public.profile_field_visibility to authenticated;
grant update (audience) on table public.profile_field_visibility to authenticated;
grant update (display_name, bio) on table public.profiles to authenticated;

create function public.update_own_profile(
  p_display_name text,
  p_bio text,
  p_skill_ids uuid[],
  p_display_name_audience text,
  p_bio_audience text,
  p_skills_audience text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  normalized_display_name text := btrim(coalesce(p_display_name, ''));
  normalized_bio text := nullif(btrim(p_bio), '');
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to update a profile.';
  end if;

  if char_length(normalized_display_name) not between 2 and 60 then
    raise exception using
      errcode = '22023',
      message = 'Display name must contain between 2 and 60 characters.';
  end if;

  if normalized_bio is not null and char_length(normalized_bio) > 500 then
    raise exception using
      errcode = '22023',
      message = 'Bio must contain at most 500 characters.';
  end if;

  if p_skill_ids is null or array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Skill identifiers must be a non-null list of known skills.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_ids) as requested(skill_id)
    left join public.skills as skill on skill.id = requested.skill_id
    where skill.id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'One or more skill identifiers are not in the catalog.';
  end if;

  if p_display_name_audience is null
    or p_bio_audience is null
    or p_skills_audience is null
    or p_display_name_audience not in ('public', 'private')
    or p_bio_audience not in ('public', 'private')
    or p_skills_audience not in ('public', 'private') then
    raise exception using
      errcode = '22023',
      message = 'Profile audiences must be public or private.';
  end if;

  update public.profiles
  set
    display_name = normalized_display_name,
    bio = normalized_bio
  where id = current_profile_id;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The current user does not have a profile anchor.';
  end if;

  delete from public.profile_skills
  where profile_id = current_profile_id
    and not (skill_id = any(p_skill_ids));

  insert into public.profile_skills (profile_id, skill_id)
  select current_profile_id, requested.skill_id
  from (
    select distinct skill_id
    from unnest(p_skill_ids) as selected(skill_id)
  ) as requested
  on conflict (profile_id, skill_id) do nothing;

  insert into public.profile_field_visibility (profile_id, field_key, audience)
  values
    (current_profile_id, 'display_name', p_display_name_audience),
    (current_profile_id, 'bio', p_bio_audience),
    (current_profile_id, 'skills', p_skills_audience)
  on conflict (profile_id, field_key)
  do update set audience = excluded.audience;
end;
$$;

comment on function public.update_own_profile(text, text, uuid[], text, text, text) is
  'Atomically updates the current user profile, controlled skills, and field visibility.';

create function public.get_public_profile(p_profile_id uuid)
returns table (
  profile_id uuid,
  display_name text,
  bio text,
  skills jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.id as profile_id,
    case
      when display_visibility.audience = 'public' then profile.display_name
      else null
    end as display_name,
    case
      when bio_visibility.audience = 'public' then profile.bio
      else null
    end as bio,
    case
      when skills_visibility.audience = 'public' then coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', skill.id,
              'slug', skill.slug,
              'label', skill.label,
              'category_id', category.id,
              'category_slug', category.slug,
              'category_label', category.label
            )
            order by category.sort_order, skill.sort_order
          )
          from public.profile_skills as profile_skill
          join public.skills as skill on skill.id = profile_skill.skill_id
          join public.skill_categories as category on category.id = skill.category_id
          where profile_skill.profile_id = profile.id
        ),
        '[]'::jsonb
      )
      else '[]'::jsonb
    end as skills
  from public.profiles as profile
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = profile.id
    and display_visibility.field_key = 'display_name'
  left join public.profile_field_visibility as bio_visibility
    on bio_visibility.profile_id = profile.id
    and bio_visibility.field_key = 'bio'
  left join public.profile_field_visibility as skills_visibility
    on skills_visibility.profile_id = profile.id
    and skills_visibility.field_key = 'skills'
  where profile.id = p_profile_id
    and profile.display_name is not null
$$;

comment on function public.get_public_profile(uuid) is
  'Returns one exact-ID sanitized completed profile without exposing Auth or visibility internals.';

revoke all privileges on function private.set_profile_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.initialize_profile_visibility()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.update_own_profile(text, text, uuid[], text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_profile(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.update_own_profile(text, text, uuid[], text, text, text)
  to authenticated;
grant execute on function public.get_public_profile(uuid)
  to anon, authenticated;
