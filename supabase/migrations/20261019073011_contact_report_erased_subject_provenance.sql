-- Contact dispatchers already preserve exact typed evidence after the author is
-- erased and deliberately derive a null live subject. OST01's generic non-template
-- branch accidentally rejected those reports. Keep its template/legacy branches
-- unchanged; only the five contact kinds can use retained target provenance.
alter table private.moderation_cases
  drop constraint moderation_cases_template_provenance_valid;
alter table private.moderation_cases
  add constraint moderation_cases_template_provenance_valid check (
    (target_kind = 'proposal_template' and template_report_content_version is not null
      and template_report_content_version ~ '^tw01:[0-9a-f]{64}$'
      and ((template_source_proposal_id is null and subject_profile_id is null)
        or (template_source_proposal_id is not null and subject_profile_id is not null)))
    or (target_kind <> 'proposal_template' and subject_profile_id is not null
      and template_source_proposal_id is null and template_report_content_version is null)
    or (target_kind in (
        'group_contact_request', 'group_contact_message', 'group_coordination_proposal',
        'member_contact_request', 'member_contact_message'
      ) and subject_profile_id is null
      and template_source_proposal_id is null and template_report_content_version is null)
  );

-- Existing typed-target/context CHECKs, immutable provenance triggers, report
-- authorization and restrictive subject/account FKs remain unchanged. This does
-- not permit deleting an account already retained by an existing report.
comment on constraint moderation_cases_template_provenance_valid on private.moderation_cases is
  'Preserves template source/version provenance and legacy live subjects; exact D/M contact targets may retain evidence with no live subject after prior erasure. No account-deletion or retention policy change.';

-- Update the effective canonical staff readers, not a copied historical body.
-- CREATE OR REPLACE retains signatures/OIDs/ACLs; fail if the expected expression
-- drifted or identity/grants change. Official attribution is template-specific.
do $$
declare
  signature text;
  original_oid oid;
  original_acl aclitem[];
  definition text;
  previous_label text := $label$case when moderation_case.subject_profile_id is null then 'Planets Community Official' else subject.display_name end$label$;
  contact_label text := $label$case
      when moderation_case.subject_profile_id is null
        and moderation_case.target_kind = 'proposal_template'
        and exists (select 1 from private.proposal_templates official
          where official.id = moderation_case.target_proposal_template_id
            and official.template_kind = 'official_starter')
        then 'Planets Community Official'
      when moderation_case.subject_profile_id is null
        and moderation_case.target_kind in ('group_contact_request', 'group_contact_message',
          'group_coordination_proposal', 'member_contact_request', 'member_contact_message')
        then 'Deleted account'
      else subject.display_name end$label$;
begin
  foreach signature in array array[
    'public.list_moderation_cases(uuid,text,integer,timestamptz,uuid)',
    'public.get_moderation_case_detail(uuid,uuid)'
  ] loop
    select p.oid, p.proacl into strict original_oid, original_acl
    from pg_proc p where p.oid = signature::regprocedure;
    definition := pg_get_functiondef(original_oid);
    if length(definition) - length(replace(definition, previous_label, '')) <> length(previous_label) then
      raise exception 'Review effective staff subject label in % before contact erasure migration.', signature;
    end if;
    execute replace(definition, previous_label, contact_label);
    if signature::regprocedure::oid <> original_oid
      or (select p.proacl from pg_proc p where p.oid = original_oid) is distinct from original_acl then
      raise exception 'Contact subject-label update changed function identity or grants: %.', signature;
    end if;
  end loop;
end;
$$;
