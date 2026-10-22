/// Closed vocabulary for canonical public Tavoli and ACTAPI01 imported records.
final class PublicActivityInterestItem {
  const PublicActivityInterestItem._(this.id, this.kind);

  final String id;
  final String kind;

  static final _publicId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// Rejects example slugs, URLs, tokens and unvalidated arbitrary properties.
  static PublicActivityInterestItem? tavolo(String id) => _parse(id, 'tavolo');

  static PublicActivityInterestItem? importedActivity(String id) =>
      _parse(id, 'imported_activity');

  static PublicActivityInterestItem? _parse(String id, String kind) =>
      _publicId.stringMatch(id) == id
      ? PublicActivityInterestItem._(id, kind)
      : null;
}

enum ActivityShareAction {
  linkCopied('link_copied'),
  shareSheetInvoked('share_sheet_invoked');

  const ActivityShareAction(this.value);
  final String value;
}

final class ActivityInterestEvent {
  const ActivityInterestEvent.cardOpened(this.item) : action = null;
  const ActivityInterestEvent.publicShare(
    this.item,
    ActivityShareAction this.action,
  );

  final PublicActivityInterestItem item;
  final ActivityShareAction? action;

  String get name =>
      action == null ? 'activity_card_opened' : 'activity_share_action';

  /// A detail handoff has its own truthful origin; it need not follow a card tap.
  Map<String, Object> get properties => Map.unmodifiable({
    'schema_version': 1,
    'item_kind': item.kind,
    'item_id': item.id,
    'origin_surface': item.kind == 'tavolo'
        ? (action == null ? 'tavoli_list' : 'tavolo_detail')
        : (action == null ? 'activities_list' : 'imported_activity_detail'),
    if (action case final action?) 'action': action.value,
  });

  String get deduplicationKey =>
      '$name:${item.kind}:${item.id}:${action?.value ?? ''}';
}
