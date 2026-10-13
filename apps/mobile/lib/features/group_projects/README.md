# Registered-group Project publication

This feature owns publication association, never Project authority or group
membership. See the [canonical contract](../../../../../docs/development/group-attributed-projects.md).

- `domain/group_project_models.dart` owns strict private bindings, neutral/public
  badges, eligible-group cursors and the small public group Project projection.
- `domain/group_project_failures.dart` recognizes only the structured post-lock
  representation denial that permits abandoning a rejected creation intent.
- `data/group_project_gateway.dart` owns bounded RPCs, Creator-only association
  reads/writes, publication revision checks and page-wide public enrichment.
- `application/group_attribution_draft.dart` owns actor-bound pending commands,
  confirmed revision, partial creation reconciliation and explicit conflict reload.
- `presentation/group_project_widgets.dart` owns the explicit personal/group
  choice, current/neutral public badge and bounded group Project/Tavolo feed.

Proposal/Tavolo editors own their existing content/cover/location save chain and
pass this session into it. Concrete content gateways carry atomic creation and
confirmed publication arguments; old callers remain compatible. The group
profile/participation section owns contextual navigation, preserving the normal
scratch/template chooser and independent People/Team/invitation/report paths.
