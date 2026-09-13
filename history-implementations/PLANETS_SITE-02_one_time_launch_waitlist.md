# PLANETS SITE-02 — One-Time Launch Waitlist

## Objective

Turn the SITE-01 email form from a local-only preview into a real, privacy-minimal launch waitlist.

A visitor should be able to submit an email address and explicitly request:

> **one email when the PLANETS Android/iOS app becomes available.**

This is **not a newsletter** and must not become one.

SITE-02 should implement the complete application-side/local infrastructure for:

- validated waitlist submissions;
- explicit consent to the one-time launch notification;
- server-side abuse verification;
- durable email storage in Cloudflare D1;
- duplicate-safe/idempotent signup behavior;
- local development and automated testing;
- a clean boundary for SITE-03 to attach the real Cloudflare production resources.

SITE-02 must **not** deploy production, change DNS, send the launch email, or configure the live `planets.community` domain.

## Hard dependency / repository state

Before editing:

1. inspect current `main` and Git status;
2. confirm **SITE-01 / PR #25 has been merged**;
3. confirm `apps/site` contains the founder-approved visual landing page and waitlist UI;
4. re-read the current repository documentation and `AGENTS.md`.

At prompt preparation time:

- PR #25 is still open;
- its head is `a0359260f8faf9f6c2673093514d2a8f7a6c3b51`;
- the branch contains the actual landing page and `WaitlistForm`;
- the current SITE-01 form validates locally but deliberately does not transmit or store anything;
- the page explicitly promises one launch email only and no newsletter/marketing reuse.

Do **not** start SITE-02 from an unmerged SITE-01 branch unless the user explicitly selects it as the base.

After SITE-01 is merged, inspect the actual merged files rather than assuming the prompt-era paths remain identical.

Likely relevant areas:

- `apps/site/src/WaitlistForm.tsx`
- `apps/site/src/email-validation.ts`
- `apps/site/src/site-content.ts`
- `apps/site/src/App.tsx`
- `apps/site/package.json`
- `apps/site/README.md`
- root `package.json`
- `.github/workflows/validation.yml`
- `docs/implementation/roadmap.md`
- `docs/architecture/decisions/0004-separate-static-informational-site.md`
- `AGENTS.md`

## Settled product/privacy rule

This is a hard constraint:

> The submitted email address is used solely to send one notification when PLANETS becomes available. It is not a newsletter signup and must not be reused for advertising, promotions, recurring product updates, marketing, profiling, or unrelated communications.

Do not broaden this purpose.

Do not collect extra personal data merely because it may be useful later.

## Architecture decision for SITE-02

Use the Cloudflare stack already selected for this mini-track:

- static Vite/React site;
- a tiny Cloudflare server-side function/endpoint for submission;
- Cloudflare D1 for waitlist persistence;
- Cloudflare Turnstile for abuse/bot protection.

Keep the site itself static. Only the waitlist submission endpoint is dynamic.

Prefer Cloudflare's current supported Pages Functions/Workers-compatible patterns after checking the current versioned documentation and repository setup.

Do not introduce Supabase, Firebase, Google Sheets, a VPS, or a second general-purpose backend.

Production account/resource creation remains SITE-03.

## D1 data model

Keep the schema deliberately small.

A single waitlist table is sufficient.

Recommended logical fields:

- normalized email address — unique/primary identifier;
- `created_at`;
- `consented_at`;
- a stable consent/purpose version such as `launch_notification_v1`;
- nullable `notified_at` for SITE-04.

Do not store:

- name;
- IP address;
- user agent;
- location;
- marketing preferences;
- profile data;
- analytics identifiers;
- arbitrary request payloads.

Use Cloudflare D1 migrations committed to the repository so the database is reproducible.

Normalize email consistently before storage, at minimum:

- trim surrounding whitespace;
- use a deterministic case-normalization strategy suitable for duplicate prevention.

Do not attempt provider-specific email canonicalization such as stripping Gmail dots or `+` aliases.

## Consent behavior

The existing explanatory text remains visible:

> Ti invieremo una sola email quando PLANETS sarà disponibile. Il tuo indirizzo non verrà usato per newsletter, pubblicità, promozioni o altre comunicazioni.

SITE-02 should add an explicit affirmative consent control if one is not already present.

Preferred UX:

- one unchecked checkbox;
- concise text confirming the user wants the one-time launch notification;
- privacy link nearby;
- the form cannot submit until the consent is checked.

Do not pre-check consent.

Do not add unrelated cookie/marketing consent.

The exact copy can be concise, for example:

> `Voglio ricevere una sola email quando PLANETS sarà disponibile.`

Keep the longer no-newsletter/no-marketing statement visible as already designed.

## Submission endpoint

Implement one narrow endpoint for signup, e.g. conceptually:

`POST /api/waitlist`

Use the route/location that best matches the current Cloudflare Pages/Workers integration after inspecting current docs.

### Input

Accept only the fields necessary for this operation:

- email;
- explicit consent;
- Turnstile token.

Reject malformed input safely.

### Server-side processing

The server must:

1. require POST;
2. parse safely;
3. validate the email again server-side;
4. require explicit consent;
5. verify the Turnstile token server-side;
6. normalize the email;
7. insert it into D1 using parameterized/prepared queries;
8. return a minimal response.

Do not trust browser validation.

Do not expose D1 directly to the browser.

Do not expose the Turnstile secret.

## Duplicate / privacy behavior

Submitting the same normalized address multiple times must be safe and idempotent.

The response should not unnecessarily reveal whether an email was already present.

A duplicate valid signup may return the same user-facing success state as a new signup.

Do not return:

- whether the address existed;
- timestamps;
- database IDs;
- waitlist counts.

Do not reset `notified_at` if a later SITE-04 state exists unless the product intentionally changes this behavior in a future plan.

For the current pre-launch state, preserve the original valid signup/consent record unless there is a concrete reason to update it.

## Turnstile

Use Cloudflare Turnstile for abuse protection.

Important:

- client-side Turnstile rendering alone is not sufficient;
- the endpoint must validate the token against Cloudflare's server-side Siteverify API;
- fail closed when validation fails;
- never expose the secret key to browser code.

For local/test development:

- use Cloudflare's official test keys / test-mode approach where appropriate;
- keep real production keys out of the repository;
- document the eventual SITE-03 secret/site-key setup.

Do not require the founder to create production Turnstile resources merely to complete local SITE-02 implementation if official test credentials can validate the integration.

## Form UX

Replace SITE-01's preview-only behavior with the real API client boundary.

States should include:

- idle;
- client validation error;
- consent missing;
- submitting;
- success;
- safe server/network failure.

Success copy should be accurate, e.g.:

> `Perfetto. Ti avviseremo una sola volta quando PLANETS sarà disponibile.`

Do not say the user is subscribed to anything.

After successful submission:

- clear or disable the email field as appropriate;
- prevent accidental repeated requests;
- keep the one-use promise visible.

Errors must not imply success.

Keep the UI accessible.

## Removal / withdrawal

Do not build a user account or a complex unsubscribe system for a single pre-launch notification.

However, the architecture must support deletion of an email before launch.

For SITE-02:

- document the exact operator procedure for deleting a waitlist email from D1;
- prefer actual deletion of the row when a valid removal request is received;
- do not retain a shadow marketing record after deletion.

The public site may continue to say removal can be requested through the privacy/public contact once that approved contact is available.

If no approved public/privacy contact address exists yet, do not invent one. Record it as a SITE-03 production-cutover blocker.

A self-service removal link/email flow can be reconsidered only if waitlist scale makes manual handling unreasonable.

## Privacy and logging

Because the email itself is personal data:

- never print submitted email addresses in ordinary application logs;
- do not include them in error messages, analytics, Sentry, console logs, or Turnstile diagnostic logs;
- do not log the Turnstile secret/token;
- return generic server errors.

If tests inspect stored emails, use deterministic fake addresses only.

Do not introduce analytics/tracking/cookies in SITE-02.

## Local development

Make the full flow testable locally without production Cloudflare resources.

Use the currently supported Wrangler/Cloudflare local runtime and local D1 simulation.

Provide repository scripts/documentation for at least:

- running/applying D1 migrations locally;
- starting the site + function runtime locally;
- exercising the real local signup path;
- inspecting/deleting test rows locally;
- resetting local test data safely.

Do not make ordinary local SITE-02 testing write to a remote D1 database by default.

Keep provider/account-specific IDs out of committed configuration where they are not needed for local development.

## Testing

This plan handles personal data and a public write endpoint, so automated coverage is required.

At minimum test:

### Client

- invalid email does not submit;
- unchecked consent does not submit;
- valid input reaches the API boundary;
- submitting/loading state;
- success state;
- network/server failure remains visibly a failure.

### Endpoint

- invalid request/body rejected;
- invalid email rejected;
- missing/false consent rejected;
- missing/invalid Turnstile rejected;
- valid Turnstile + valid email inserts one row;
- duplicate signup is idempotent and does not create duplicate rows;
- response does not reveal prior membership;
- database errors fail safely;
- logs/errors do not leak submitted addresses.

### D1 migration

- migrations apply to a clean local database;
- expected constraints exist;
- duplicate normalized email cannot create two rows.

Use official Cloudflare test mechanisms/mocks as appropriate so CI does not require production credentials.

Do not claim Turnstile production behavior was tested if only official testing keys/mocks were used; report that distinction accurately.

## CI / root tooling

Integrate the new SITE-02 validation into the existing site/root CI without weakening current checks.

Prefer explicit scripts for the waitlist/function tests and local D1 migration checks.

Do not require a remote Cloudflare account for ordinary PR CI.

Keep existing web/mobile/database jobs working.

## Documentation

Update:

- `apps/site/README.md` with local waitlist setup and privacy purpose;
- relevant development docs/scripts;
- roadmap SITE statuses;
- architecture docs only if SITE-02 establishes a lasting boundary not already covered.

After merge:

- SITE-00 should remain Implemented;
- SITE-01 should become Implemented;
- SITE-02 becomes Implemented;
- SITE-03 remains deployment/domain cutover;
- SITE-04 remains launch notification + waitlist retirement.

Archive this implementation prompt under `history-implementations/` if the established workflow remains active.

## Production/external setup intentionally deferred to SITE-03

Do not in SITE-02:

- deploy the site;
- create/attach the real `planets.community` domain;
- change DNS;
- retire Serverplan/WordPress;
- configure production Turnstile secrets;
- send launch emails;
- configure Resend for the waitlist;
- add app-store links that do not exist.

SITE-02 should leave clear SITE-03 instructions/placeholders for the Cloudflare resources it will require.

## Non-goals

Do not add:

- newsletter features;
- marketing consent;
- recurring campaigns;
- user accounts;
- Supabase;
- Google Sheets/Apps Script;
- CRM integrations;
- contact-form backend;
- admin dashboard for the waitlist;
- analytics;
- tracking cookies;
- launch-email delivery;
- domain/deployment work.

## Acceptance criteria

SITE-02 is complete when:

- [ ] SITE-01 is merged and this work is based on current `main`.
- [ ] A reproducible D1 migration defines the minimal one-purpose waitlist.
- [ ] The site submits to a real local/server-side waitlist endpoint.
- [ ] Both client and server validate the email.
- [ ] Explicit affirmative consent is required and not pre-checked.
- [ ] Turnstile is validated server-side.
- [ ] Production secrets are not committed or exposed.
- [ ] Duplicate submissions are idempotent/privacy-safe.
- [ ] No email is used or represented as a newsletter/marketing signup.
- [ ] No unnecessary personal/request metadata is stored.
- [ ] A documented manual deletion procedure exists.
- [ ] Local development uses local D1 by default.
- [ ] Automated tests cover client, endpoint, consent, Turnstile, duplicates, and D1 constraints.
- [ ] Existing repository validation remains green.
- [ ] No production deployment/DNS changes occur.
- [ ] SITE-03 can provision/bind production Cloudflare resources without redesigning the waitlist.

## Git/PR completion rule

Do not finish this task only as local commits.

At minimum:

1. commit intended changes on the isolated task branch/worktree;
2. push the branch;
3. open a GitHub pull request against current `main`;
4. ensure the PR contains the implementation and validation report so later ChatGPT/Codex sessions can inspect it from GitHub.

If repository instructions explicitly authorize automatic merge after green CI and no blocking decisions, follow them. Otherwise leave the clean PR open and report it.

Never report SITE-02 as completed while the work exists only in a local worktree.

## Stop conditions

Stop and report rather than guessing if:

- SITE-01 is not merged;
- current Cloudflare APIs/runtime materially conflict with this architecture;
- production credentials/account access become necessary for ordinary local/CI completion;
- a public privacy/contact identity must be invented;
- the implementation would start collecting data beyond the one-purpose email waitlist;
- a recurring-cost/provider decision outside the accepted Cloudflare/D1/Turnstile scope appears.

## Completion report

Return:

1. summary;
2. branch/commit and **GitHub PR URL**;
3. confirmation SITE-01 was merged before starting;
4. waitlist schema/migration;
5. endpoint behavior;
6. Turnstile validation approach;
7. exact data stored and explicit data not stored;
8. duplicate/idempotency semantics;
9. removal procedure;
10. client UX states;
11. tests/checks and exact results;
12. external SITE-03 setup still required;
13. missing founder/legal/public-contact inputs;
14. any warning that should block SITE-03.
