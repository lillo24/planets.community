# Browser navigation adapters

`client-navigation.tsx` is the small host interface used by shared invitation,
Auth, profile and handoff views. `next-navigation.tsx` supplies the existing Next
Link/router behavior. The isolated static trial supplies History API navigation;
it never aliases or bundles Next's runtime.
