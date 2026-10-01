begin;

select no_plan();

select has_function(
  'private',
  'list_own_scoped_message_chat_items_base',
  array['uuid', 'text', 'integer', 'timestamptz', 'text', 'uuid'],
  'the previously validated scoped projection is retained as a private base'
);

select is(
  pg_get_function_result(
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)'::regprocedure
  ),
  'TABLE(item_kind text, chat_id uuid, activity_at timestamp with time zone, display_title text, viewer_role text, is_read_only boolean, last_visible_message_id uuid, last_visible_message_body text, last_visible_message_at timestamp with time zone, last_visible_sender_profile_id uuid, last_visible_sender_display_name text, project_id uuid, project_kind text, resource_request_id uuid, resource_agreement_id uuid, resource_listing_id uuid, resource_counterparty_profile_id uuid, resource_counterparty_display_name text, agreement_lifecycle text, coordination_closed_at timestamp with time zone, project_request_id uuid, project_request_project_id uuid, project_request_project_kind text, project_request_project_title text, project_request_counterparty_profile_id uuid, project_request_counterparty_display_name text, project_request_status text, project_request_message text, project_request_resolved_at timestamp with time zone, accepted_project_group_chat_id uuid)',
  'the public scoped projection exposes canonical Resource counterparty fields'
);

select ok(
  pg_get_functiondef(
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)'::regprocedure
  ) ilike '%security definer%'
    and pg_get_functiondef(
      'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)'::regprocedure
    ) ilike '%set search_path to%''''%',
  'the extended projection remains a fixed-search-path security definer'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can execute the extended scoped projection'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ),
  false,
  'anonymous and broad service roles cannot execute the scoped projection'
);

select is(
  has_function_privilege(
    'anon',
    'private.list_own_scoped_message_chat_items_base(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.list_own_scoped_message_chat_items_base(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.list_own_scoped_message_chat_items_base(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ),
  false,
  'the preserved base projection is not an API surface'
);

select has_function(
  'private',
  'has_current_project_profile_photo_interaction',
  array['uuid', 'uuid'],
  'current Project photo interaction has one centralized predicate'
);

select ok(
  pg_get_functiondef(
    'private.has_current_project_profile_photo_interaction(uuid,uuid)'::regprocedure
  ) ilike '%security definer%'
    and pg_get_functiondef(
      'private.has_current_project_profile_photo_interaction(uuid,uuid)'::regprocedure
    ) ilike '%set search_path to%''''%'
    and (
      select provolatile = 's'
      from pg_proc
      where oid =
        'private.has_current_project_profile_photo_interaction(uuid,uuid)'::regprocedure
    ),
  'the Project photo predicate is stable and uses a fixed search path'
);

select is(
  has_function_privilege(
    'anon',
    'private.has_current_project_profile_photo_interaction(uuid,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.has_current_project_profile_photo_interaction(uuid,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.has_current_project_profile_photo_interaction(uuid,uuid)',
    'EXECUTE'
  ),
  false,
  'no API role can call the private Project photo predicate directly'
);

select ok(
  pg_get_functiondef(
    'private.can_view_profile_photo(uuid,uuid)'::regprocedure
  ) ilike '%has_current_project_profile_photo_interaction%',
  'canonical photo metadata and Storage authorization share the Project predicate'
);

select * from finish();

rollback;
