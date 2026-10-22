# SPORTUI01 — Sports beyond an event list

Read [001_context.md](001_context.md). Depends on 002 and 003. Complete this UI with backend-shaped deterministic fixtures when live data is not configured; do not wait for source onboarding.

## User outcome

From **Activities → Sports**, a person can distinguish something to join regularly, a dated sporting event, and a place where they can practise. They can search/filter the genuine catalogue, understand known versus unknown information, open meaningful details and use the official source link. The design should feel usable with sparse real data, not need twelve fictional cards to appear complete.

## Required UI

1. Offer **All / Courses & sessions / Events / Places to practise**, with Italian equivalents such as **Tutte / Corsi e allenamenti / Eventi / Luoghi per praticare**. Reuse 003's hierarchy and controls rather than nesting another independent navigation system. All uses a documented stable ordering or clearly separated groups, not a popularity ranking.
2. Discipline selection uses controlled metadata from the whole eligible catalogue. Display IT/EN labels, retain source-specific type text where useful and keep unknown disciplines available under an honest generic state. Do not copy the fictional example taxonomy to assert source coverage. A discipline with no real results must not create fake clubs/courses.
3. Provide search and active-filter summary/reset. Keep fine filters modest: kind/discipline and supported date scope are sufficient initially. Only add audience/level/cost/access controls if backed by explicit canonical fields and real backend predicates. Unknown values must not match “free”, “beginner”, “open now” or “places available.”
4. Course card: title, discipline, source, public place, known schedule/term, and supplied price/eligibility where concise. A weekly class appears once. Unknown next session is explicit and never replaced by today's date. Do not treat enrollment opening as first lesson or a sports facility's opening hours as course sessions.
5. Event card: exact source-backed date/time semantics and an organizer/venue when provided. Preserve whether the event is for participation or spectators if explicit; unknown remains unspecified. No generic “Join” action.
6. Place card: title/type and venue/area, no event date. An access label can repeat the source's stated scope, with a distinction from live opening/availability. Multiple sports equipment entries in one park can be separate results; do not label their count as distinct parks. Distance is added only when 007/008 provides an explicit user-chosen reference and valid public precision.
7. Kind-aware details show plain text, known schedule/season, relevant conditions, location, attribution/licence and a truthfully worded observation date. Put the primary action in clear language: **Official information / Vedi informazioni ufficiali**, or a verified course/enrollment link when actually supplied. A dataset-level fallback must be labelled **View source dataset / Vedi dataset della fonte**, not “Book this course.”
8. Reuse the existing safe link launcher and ACTMET01 public copy/share actions. Preserve canonical UUIDs and denied analytics. No fabricated PLANETS public URL, participant count, chat, native profile or membership. Missing description should produce a clean detail, not filler.
9. Make the location block ready to use the shared public map in 008; before then show honest address/source information. Do not introduce geocoding, location permissions, map tiles or new provider traffic here.
10. Support loading/error/not-found/source-disabled, cancelled/ended offering, stale-record and unknown schedule states. Do not retain a now-disabled record as a normal actionable detail after a refreshed backend denial. Give source trouble modest copy rather than exposing run IDs/technical diagnostics to users.

## Scope and source independence

No booking, payments, favorite-account sync, manual submissions, scraped content, AI recommendations, invented membership, course signup inside PLANETS or new sport-specific native creation flow. Keep existing example preview; if extending preview cases is necessary for a place/course layout, identify them as synthetic and keep them excluded from real reads and analytics.

The first live source 006 supplies public equipment/places, not courses. The interface may have an honest empty Courses section. Source availability is not a prerequisite for building or testing this UI. Tests can inject synthetic accepted records without committing them as enabled real sources.

## Acceptance and evidence

Render and inspect at least a weekly course, an unknown-time current course, a cancelled event, a sports place with no description, a place with only dataset-level link, and sparse/empty results. Cover long Italian labels, 320/360 dp, 2× text, dark/light and English. Meaningful widget/controller tests verify kind-aware semantics, filter reset/paging, unavailable record handling, detail-back state, official action labels, safe-link failures and no native/analytics side effects.

Run scoped mobile validation and required CI; update feature maps, progress and useful visual evidence. Merge and proceed to 005. Do not wait for physical-phone review or a sports-course API to make this step complete.
