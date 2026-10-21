# Client compatibility startup gate (APPVER01)

This feature checks compatibility before `PlanetsApp` is mounted.

- `domain/client_compatibility.dart` owns numeric release/build comparisons,
  exact platform/application matching and allowlisted store destinations. Build
  numbers break ties within a release; a newer iOS release may reset its build.
- `data/client_compatibility_gateway.dart` reads installed native metadata with
  pinned `package_info_plus`, reads the public Supabase Edge policy, delegates
  Android UI to pinned `in_app_update` (Google Play Core Immediate Update), and
  opens the exact store listing. Availability checks time out after eight seconds;
  consent/download/install remain Google's UI. In-progress updates resume after
  process recreation and through the plugin's native lifecycle handler.
- `application/client_compatibility_controller.dart` owns checking, supported,
  update-required and failed states. Metadata/policy reads each have an eight
  second deadline. One automatic native attempt per cold start avoids consent
  loops after cancellation; deliberate retry remains available. Native success
  or opening a store never proves the running binary changed: recheck admission.
- `presentation/client_compatibility_gate.dart` blocks navigation/auth/profile
  startup until supported. Android shows a minimal fallback behind/after native
  cancellation/unavailability/failure; iOS links to its App Store listing. Failed
  policy checks expose Retry. Blocked resume rechecks; admitted sessions preserve
  their forms until next cold startup. This is not RLS or session revocation.

Bootstrap wraps the existing app. `ENABLE_CLIENT_COMPATIBILITY_CHECK` defaults
to false locally and true in staging/production. Local/staging can override for
isolated QA; production false is a configuration error. Flutter web/desktop
tooling bypasses this Android/iOS gate. Deploy the policy endpoint **before**
releasing enabled clients: missing/malformed policy blocks with Retry and never
silently admits the app. No last-allowed policy is persisted.

No floor, release or recovery campaign is activated. Existing installed clients
do not know about this gate. See the [rollout prerequisite](../../../../../docs/development/appver01-client-compatibility.md).
