# Staging Worker boundary

`index.ts` wraps vinext's App Router entry without changing domain/auth logic.
It reuses the two canonical Next association handlers because vinext 1.0.1
does not discover hidden `.well-known` route directories. `ingress.ts` owns
bounded route ownership, public Host/Origin validation, reconstructed forwarding
headers and sensitive response privacy; its tests include independent cookies.

The canonical Site Custom Domain stays behind any future narrowly scoped Routes.
Only a prefix Route match outside actual web ownership falls through to that
Site origin. Staging deployment has **no Routes or Custom Domains**. Static
app output is under `/_next/`, separate from Site's `/assets/` namespace.

See the [hosting runbook](../../../docs/development/link-host01-cloudflare-invitations.md)
for configuration, known compatibility limits, evidence and the live approval gate.
