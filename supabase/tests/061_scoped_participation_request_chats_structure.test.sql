begin;

select no_plan();

select has_function(
  'public',
  'list_own_scoped_message_chat_items',
  array['uuid', 'text', 'integer', 'timestamptz', 'text', 'uuid'],
  'scoped unified Chats API exists without overloading the legacy RPC'
);

select is(
  pg_get_function_result(
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)'::regprocedure
  ),
  'TABLE(item_kind text, chat_id uuid, activity_at timestamp with time zone, display_title text, viewer_role text, is_read_only boolean, last_visible_message_id uuid, last_visible_message_body text, last_visible_message_at timestamp with time zone, last_visible_sender_profile_id uuid, last_visible_sender_display_name text, project_id uuid, project_kind text, resource_request_id uuid, resource_agreement_id uuid, resource_listing_id uuid, agreement_lifecycle text, coordination_closed_at timestamp with time zone, project_request_id uuid, project_request_project_id uuid, project_request_project_kind text, project_request_project_title text, project_request_counterparty_profile_id uuid, project_request_counterparty_display_name text, project_request_status text, project_request_message text, project_request_resolved_at timestamp with time zone, accepted_project_group_chat_id uuid)',
  'the scoped projection exposes strict branch-specific participation-request context'
);

select ok(
  pg_get_functiondef(
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)'::regprocedure
  ) ilike '%security definer%'
    and pg_get_functiondef(
      'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)'::regprocedure
    ) ilike '%set search_path to%''''%',
  'the scoped read is a fixed-search-path security definer'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_scoped_message_chat_items(uuid,text,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can execute the scoped projection'
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
  'anonymous and broad service roles cannot execute the private scoped read'
);

select ok(
  to_regprocedure(
    'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)'
  ) is not null,
  'the legacy unified Chats RPC remains available for compatibility'
);

select * from finish();

rollback;
