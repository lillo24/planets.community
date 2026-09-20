# Local demo data

PLANETS has two deliberately separate demo conveniences:

- **DEMO-A** is presentation-only Flutter tooling. It shows a DEMO marker and
  fills supported forms, but never submits or persists data.
- **DEMO-B** is this trusted local backend dataset. It authenticates synthetic
  users and calls the real Supabase RPC, RLS, outbox, notification, Messages,
  chat, and discovery paths. Flutter continues to use its normal repositories.

## Create or rebuild the world

Start the project-scoped local stack, then choose one command:

```text
npm run demo:seed:local
npm run demo:reset:local
```

`demo:seed:local` brings only the stable `DEMO · ...` scenarios owned by the
three demo identities to their desired state. Repeated runs reuse canonical
entity IDs, add only missing transitions/messages, refresh relative Proposal
times, and let the notification projector consume any pending supported local
events. It does not reset unrelated developer rows.

`demo:reset:local` is intentionally destructive to the local database: it runs
the existing migration reset and then seeds the demo world. To return to a
clean non-demo database, run `npm run db:reset` without the demo seed.

Both commands derive credentials from `supabase status` and refuse a non-local
or non-loopback API, database, or Mailpit target. There is no staging command,
remote reset, production mode, app-start hook, or public reset endpoint.

Run the focused read/security check at any time with:

```text
npm run demo:verify:local
```

## Personas and useful flows

| Identity                     | Role in the world                                                         |
| ---------------------------- | ------------------------------------------------------------------------- |
| `demo-alice@planets.invalid` | Organizer: owns Proposals, Tavoli, a donation listing, and the mural chat |
| `demo-bob@planets.invalid`   | Requester: has pending, rejected, and withdrawn Messages plus a listing   |
| `demo-carla@planets.invalid` | Participant: accepted into the mural Project and active in its chat       |

All three profiles are complete, public, synthetic, and use different skills
from the controlled catalog. The connected dataset includes:

- upcoming restricted and public-location Proposals, plus a relative
  **Just Finished** Proposal;
- active weekly/monthly Tavoli and a paused owner-history Tavolo;
- pending, accepted, rejected, and withdrawn participation history exposed by
  the structured Messages projection;
- in-app history produced by the real notification projector;
- a three-message Project chat for Alice and Carla;
- published `donate` and `exchange` Scambio-Dona listings plus a closed owner
  example. The current canonical domain has no loan or barter lifecycle.

The script uses ordinary authenticated RPCs for domain creation and lifecycle
changes. Its trusted direct local PostgreSQL access is limited to a concurrency
lock, stable demo-owned lookups, verification, and refreshing the timestamps of
the naturally aged historical Proposal. It never fabricates notification or
chat rows.

## Sign in and run the app

The seed command consumes its own local OTP messages without printing them.
To switch personas in the app, enter one of the emails above, open Mailpit at
`http://127.0.0.1:54324`, and paste the newest six-digit code.

The complete happy path is:

```text
npm run restore
npm run db:start
npm run demo:reset:local
npm run mobile:config:local
npm run dev:mobile
```

For a physical Android device, keep the existing ADB reverse or reachable-host
configuration described in [Getting started](getting-started.md); the demo
dataset does not change networking.

## Staging status

The stable scenario registry and authenticated domain operations can be reused
by a future staging runner, but the repository currently has no approved
trusted staging-admin credential/configuration contract. Adding one requires an
explicit separately named command, HTTPS target allow-listing, account-owner
credentials, and non-production environment proof. Production must remain an
invalid target.
