# Mock-only control plane

These files are **not product migrations** and are never applied by ordinary
Supabase migration replay. `marker.sql` is a separate operator acknowledgment;
`control.sql` requires that marker before creating any privileged control object.
Product data continues to use the unchanged canonical migrations and RPCs.

Control tables are private, RLS enabled, with no client grants. Service-only
functions in `public` are reachable only by the broker/operator service role.
Neither a persona session nor an app publishable key can call them.
