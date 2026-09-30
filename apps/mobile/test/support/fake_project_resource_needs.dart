import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_need_models.dart';

class FakeProjectResourceNeedsGateway implements ProjectResourceNeedsGateway {
  List<PublicProjectResourceNeed> publicItems = [];
  List<ProjectResourceNeed> ownItems = [];
  Object? error;
  Future<void>? publicDelay;
  Future<void>? ownerDelay;
  Future<void>? mutationDelay;
  final List<String> calls = [];
  String? lastExpectedCreatorProfileId;
  String? lastProjectId;
  String? lastResourceNeedId;
  String? lastTitle;
  String? lastDetails;

  @override
  Future<List<PublicProjectResourceNeed>> listPublic(String projectId) async {
    calls.add('list-public:$projectId');
    lastProjectId = projectId;
    if (publicDelay case final delay?) await delay;
    _throwIfNeeded();
    return List.unmodifiable(publicItems);
  }

  @override
  Future<List<ProjectResourceNeed>> listOwn({
    required String expectedCreatorProfileId,
    required String projectId,
  }) async {
    calls.add('list-own:$projectId');
    lastExpectedCreatorProfileId = expectedCreatorProfileId;
    lastProjectId = projectId;
    if (ownerDelay case final delay?) await delay;
    _throwIfNeeded();
    return List.unmodifiable(ownItems);
  }

  @override
  Future<String> create({
    required String expectedCreatorProfileId,
    required String projectId,
    required String title,
    String? details,
  }) async {
    calls.add('create:$projectId');
    lastExpectedCreatorProfileId = expectedCreatorProfileId;
    lastProjectId = projectId;
    lastTitle = title;
    lastDetails = details;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    final id = 'need-${ownItems.length + 1}';
    final need = projectResourceNeedFixture(
      id: id,
      projectId: projectId,
      title: title,
      details: details,
    );
    ownItems = [...ownItems, need];
    _syncPublic();
    return id;
  }

  @override
  Future<void> update({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required String title,
    String? details,
  }) async {
    calls.add('update:$resourceNeedId');
    lastExpectedCreatorProfileId = expectedCreatorProfileId;
    lastResourceNeedId = resourceNeedId;
    lastTitle = title;
    lastDetails = details;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    ownItems = [
      for (final need in ownItems)
        if (need.id == resourceNeedId)
          projectResourceNeedFixture(
            id: need.id,
            projectId: need.projectId,
            projectKind: need.projectKind,
            title: title,
            details: details,
            state: need.state,
          )
        else
          need,
    ];
    _syncPublic();
  }

  @override
  Future<void> close({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
  }) async {
    calls.add('close:$resourceNeedId');
    lastExpectedCreatorProfileId = expectedCreatorProfileId;
    lastResourceNeedId = resourceNeedId;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    ownItems = [
      for (final need in ownItems)
        if (need.id == resourceNeedId)
          projectResourceNeedFixture(
            id: need.id,
            projectId: need.projectId,
            projectKind: need.projectKind,
            title: need.title,
            details: need.details,
            state: ProjectResourceNeedState.closed,
          )
        else
          need,
    ];
    _syncPublic();
  }

  void _syncPublic() {
    publicItems = [
      for (final need in ownItems)
        if (need.isOpen)
          publicProjectResourceNeedFixture(
            id: need.id,
            title: need.title,
            details: need.details,
            createdAt: need.createdAt,
          ),
    ];
  }

  void _throwIfNeeded() {
    if (error case final failure?) throw failure;
  }
}

PublicProjectResourceNeed publicProjectResourceNeedFixture({
  String id = 'need-1',
  String title = 'Paint',
  String? details = 'Weather-resistant exterior paint.',
  DateTime? createdAt,
}) => PublicProjectResourceNeed(
  id: id,
  title: title,
  details: details,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 15, 9),
);

ProjectResourceNeed projectResourceNeedFixture({
  String id = 'need-1',
  String projectId = 'proposal-1',
  ProjectKind projectKind = ProjectKind.oneTime,
  String title = 'Paint',
  String? details = 'Weather-resistant exterior paint.',
  ProjectResourceNeedState state = ProjectResourceNeedState.open,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 15, 9);
  return ProjectResourceNeed(
    id: id,
    projectId: projectId,
    projectKind: projectKind,
    title: title,
    details: details,
    state: state,
    createdAt: created,
    updatedAt: created,
    closedAt: state == ProjectResourceNeedState.closed
        ? created.add(const Duration(hours: 1))
        : null,
  );
}
