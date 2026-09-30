create or replace function public.list_resource_exchange_agreement_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
returns table (
  terms_id uuid,
  version_number integer,
  proposed_by_profile_id uuid,
  listing_title_snapshot text,
  listing_description_snapshot text,
  owner_transfer_kind text,
  owner_lend_starts_at timestamptz,
  owner_lend_ends_at timestamptz,
  requester_transfer_kind text,
  requester_resource_description text,
  requester_lend_starts_at timestamptz,
  requester_lend_ends_at timestamptz,
  private_note text,
  created_at timestamptz,
  is_current boolean,
  is_pending boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
begin
  select candidate.* into agreement
  from public.resource_exchange_agreements as candidate
  join public.resource_listing_requests as request
    on request.id = candidate.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  where candidate.id = p_agreement_id
    and current_profile_id in (
      listing.owner_profile_id,
      request.requester_profile_id
    );

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The current user cannot read this resource exchange agreement.';
  end if;

  return query
  select
    terms.id,
    terms.version_number,
    terms.proposed_by_profile_id,
    terms.listing_title_snapshot,
    terms.listing_description_snapshot,
    terms.owner_transfer_kind,
    terms.owner_lend_starts_at,
    terms.owner_lend_ends_at,
    terms.requester_transfer_kind,
    terms.requester_resource_description,
    terms.requester_lend_starts_at,
    terms.requester_lend_ends_at,
    terms.private_note,
    terms.created_at,
    coalesce(terms.id = agreement.current_terms_id, false),
    coalesce(terms.id = agreement.pending_terms_id, false)
  from public.resource_exchange_agreement_terms as terms
  where terms.agreement_id = agreement.id
  order by terms.version_number desc;
end;
$$;
