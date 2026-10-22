# COCREATE-FILL01 — meetings, filling and mode-specific mock data

Status: implementation in progress, 2026-10-23. New isolated branch
`codex/cocreate-fill01` builds on RUNALL `a0e810d0` and preserves VIS01
`512192ec` through an explicit merge. Main, ACTAPI01, ACTMET01 and other
worktrees are untouched. Keep the cumulative PR unmerged as requested.

## Requested behavior and working contract

- A topic's General chat can publish a meeting request with a date/time and
  meeting occupancy, including creator-only requests. Joining reserves one
  meeting place and enters the same persistent numbered chat atomically.
- Chat membership persists across meetings. Each new meeting starts with its
  creator attending; other members explicitly confirm attendance. Declining a
  meeting frees its place without leaving the chat. Existing chat exit/removal,
  block, moderation, policy, identity and immutable retry controls still apply.
- Meeting time is a UTC instant, entered/displayed in the device's local zone
  with its offset. Changing time requires cancelling and publishing a new
  meeting; old cards retain their original time. No exact address is introduced.
- Meeting capacity remains 2–50 including the creator. Scheduling explicitly
  converts a numbered room to a persistent chat with the existing maximum of
  50 members; meeting places and chat membership counts are distinct. No one
  loses chat access when a meeting fills, passes or is declined.
- General members receive durable in-app filling notifications with the meeting
  time. Respect current membership episode, mute, blocking, account eligibility
  and notification preferences; no author self-notification. Provider delivery
  must use existing controls and cannot claim configured credentials.
- Mock is an independent data realm. Activities and Find People are mutually
  exclusive presentations, with separate synthetic login persona catalogs.
  Mock fixtures exercise the same canonical RPCs as ordinary data.
- Requested mock topics: Videogames → Valorant/Minecraft; Board games → Lupus
  in Fabula/Catan; Concerts → Rock/Techno; Sports → Running; Travel → China;
  Art → Cooking/Sewing 🧵/Drawing. These are test examples, not a production
  taxonomy decision.
- After the flow is complete, add only a Home Crazy Ideas button beside Find
  People. Do not connect Projects or create Crazy Ideas mock data.

## COMM01 dependency

The user explicitly included COCREATE-COMM01. No matching file, commit or
implementation was found in fetched main, RUNALL, VIS01 or local Markdown.
The related “Propose community groups” discussion confirms category → topic →
numbered-group navigation and proposing/supporting topics. Its assistant prompt
is unavailable through the conversation reader. Requested the exact prompt/path
asynchronously; continue independent meeting/mock work meanwhile. Do not invent
its approval threshold or moderation rules.

## Progress and next action

- Inspected local/unpushed state before changes: RUNALL has only its preserved
  untracked `.local/`; VIS01 is clean/pushed; primary main has preserved
  untracked `.vis01/`. Fetched origin safely; main remains `217ce73e`.
- Created managed worktree `cocreate-fill01`, branch `codex/cocreate-fill01`.
  Integrated the existing tested VIS01 source without conflicts.
- Read current architecture, tooling, recruitment, room membership, notification
  composition and mock control code. Existing recruitment has no meeting time
  or durable notification, and mock personas currently serve one shared catalog.
- Next: implement additive meeting/attendance/card RPCs with atomic canonical
  chat admission, bounded notification fanout and negative/concurrency tests;
  then mobile UI, mode-specific mock fixtures/catalogs, COMM01 and Home button.
- No hosted migrations, deployment, provider activation, approval bypass or
  automatic merge is authorized/performed. RUNALL owner migration review remains
  an inherited CI gate, to be refreshed for the exact cumulative head.
