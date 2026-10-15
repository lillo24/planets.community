# C-R04 — Group and Idea workspaces, WhatsApp/Telegram signposting

## Objective

Provide both Group-wide and Idea-specific named links while preserving already-merged Project/Tavolo workspaces. Depends on C-R01–R03; not on D.

## Requirements

1. Reuse WORKSPACE02 name/HTTPS validation, automatic built-in icon classification, bounded pagination, expected item versions, lost-Add recovery and exact authorized external-open checks. Do not fetch favicons, previews, document content, provider APIs or attachments. Keep native launch abstractable for tests but report whether real external launching was exercised.
2. Group-wide collection: current Group people may read/open; current Group managers may manage under the defined Group authority. Authorize its mutations without granting broader structural Group editing. General points to this collection prominently. Exited users do not get a newly updated current collection via retained chat history.
3. Idea-specific collection: current admitted planners and entitled managers may read/open; eligible Discussion Creator and Group managers may add/edit/remove. Full-history message permission must not accidentally become a broader current-link permission. Revoked room access and lost creator/manager privileges affect every link path, including pending external-open confirmation.
4. Keep the collections separate from each other and Project links. Shared presentation must not mean a universal `group_id` check authorizes all targets. Test cross-Group, cross-room and cross-Project item IDs and receipt namespaces.
5. Optional named WhatsApp/Telegram links receive recognizable local icons and visible external intent. General/Group details make them easy to find. A first-visit tip points to shared communication links without forcing anyone to install/join anything. An external URL does not grant external app membership or inherit PLANETS permission rules.
6. Project details may show an authorized Group communication entry only when the actor independently has that Group access, or a real Project manager deliberately publishes selected links into the private Project workspace. Never put Group-private invitation URLs into anonymous/public Project/Group projections or templates.
7. An empty collection retains an available Workspace/Links control for entitled users; members see a neutral empty state, not manager editing or a fabricated URL. Errors remain errors and retries retain their exact intent.
8. Preserve messages and old link provenance. A URL already pasted into an old retained message is not retroactively revocable inside WhatsApp/Telegram; do not claim external revocation. Do not use this fact to expose a mutable link collection to former readers.

## Validation and deliverables

Forward migration/replay and populated preservation; existing Project single-link compatibility and named extras unchanged; server role matrix; many-page ordering; duplicate Add after lost reply; conflicting edit/remove; revoked identity/role while confirming external open; allowlisted safe source data in screenshots. Render General, empty/member/manager collections, long names/hosts and relevant authorized Project entry in both locales/themes.

No real partner links, contact sends, provider setup, hosting or shared database writes. Document the exact Group/room/Project distinctions for conversion and for the parallel D lane's limited widget reuse.
