# Personal Resource saved-search mobile boundary

This feature owns private, identity-bound saved definitions of the existing
Scambio-Dona Browse filters. It does not own a second results screen.

- `domain/resource_saved_search_models.dart` owns saved definitions, normalized
  mutable input, paired keyset cursors, pages, and safe failure kinds.
- `data/resource_saved_search_gateway.dart` is the only backend adapter. It
  calls category-aware V2 create/update/get/list RPCs and the original delete
  RPC; it never reads `resource_saved_searches` directly.
- `application/resource_saved_search_controller.dart` owns identity-scoped
  paging, busy guards, stale-response rejection, and canonical first-page
  reloads after create, update, or delete.
- `presentation/resource_saved_searches_screen.dart` owns private management,
  explicit filter cards, Open/Edit/Delete actions, refresh, and pagination.
- `presentation/resource_saved_search_editor.dart` owns the local edit dialog.
- `presentation/resource_saved_search_routes.dart` owns the protected static
  route contract.

The tuple contains keyword, nullable mode, locality and nullable category.
Category alone is valid; summaries and Edit include it, and All clears it.
Existing NULL-category definitions keep their unrestricted meaning. See the
[CAT01 rollout/legacy contract](../../../../../docs/development/resource-cat01-categories.md).

Open applies the complete saved tuple through the existing public Resource Browse
controller and then returns to `/resources`. Later Browse edits do not mutate
the saved definition. Saved searches are independent from Project resource
matching and do not create notifications, preview listings, result snapshots,
or delivery-frequency settings; the existing 04C4F3 backend owns notification delivery.
