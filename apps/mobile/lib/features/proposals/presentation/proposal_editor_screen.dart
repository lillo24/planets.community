import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../app/router/draft_departure_coordinator.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../devtools/demo/demo_widgets.dart';
import '../../../devtools/demo/demo_tools.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../locations/presentation/location_editor_section.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../cover_media/domain/cover_media_models.dart';
import '../../cover_media/presentation/cover_editor_section.dart';
import '../../template_workshop/presentation/template_workshop_screens.dart';
import '../../participation/domain/participation_models.dart';
import '../../profile_photo/presentation/profile_photo_trust_gate.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../application/proposal_controllers.dart';
import '../application/proposal_draft_session.dart';
import '../application/similar_proposal_controller.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';
import '../domain/similar_proposal.dart';
import 'similar_proposal_suggestions.dart';
import 'proposal_editor_controls.dart';

class ProposalEditorScreen extends ConsumerStatefulWidget {
  const ProposalEditorScreen({
    this.proposalId,
    this.returnToHub = false,
    super.key,
  });

  final String? proposalId;
  final bool returnToHub;

  @override
  ConsumerState<ProposalEditorScreen> createState() =>
      _ProposalEditorScreenState();
}

class _ProposalEditorScreenState extends ConsumerState<ProposalEditorScreen> {
  String? _requestedIdentity;
  var _sessionId = const Uuid().v4();
  VoidCallback? _releaseSession;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final session = ref.read(authSessionProvider);
    final identity = session.identity;
    if (session.phase == AuthSessionPhase.ready &&
        identity != null &&
        (force || _requestedIdentity != identity.id)) {
      _requestedIdentity = identity.id;
      final controller = ref.read(
        proposalEditorSessionProvider(_sessionId).notifier,
      );
      _releaseSession = controller.releaseSession;
      await controller.load(identity.id, widget.proposalId);
    }
  }

  @override
  void didUpdateWidget(ProposalEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposalId != widget.proposalId) {
      _releaseSession?.call();
      _releaseSession = null;
      _sessionId = const Uuid().v4();
      _requestedIdentity = null;
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _releaseSession?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final identity = session.identity;
    final state = ref.watch(proposalEditorSessionProvider(_sessionId));
    // A create route keeps its session after binding the first canonical ID.
    final proposalMatches =
        widget.proposalId == null ||
        state.phase == ProposalEditorPhase.failure ||
        state.proposal?.id == widget.proposalId;
    final isCurrent =
        identity != null &&
        state.expectedCreatorId == identity.id &&
        proposalMatches;
    final structuralAccessDenied =
        state.phase == ProposalEditorPhase.failure &&
        state.failure == ProposalFailureKind.forbidden;
    if (identity != null && _requestedIdentity != identity.id) {
      Future<void>.microtask(_load);
    } else if (session.phase == AuthSessionPhase.ready &&
        identity != null &&
        state.phase == ProposalEditorPhase.idle) {
      // Access loss clears the session even if the account ID stays the same.
      // Reload once readiness returns instead of retaining an empty loading state.
      Future<void>.microtask(() => _load(force: true));
    }
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(
          widget.proposalId == null
              ? l10n.proposalCreateTitle
              : l10n.proposalEditTitle,
        ),
      ),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : !isCurrent || state.phase == ProposalEditorPhase.loading
            ? LoadingState(message: l10n.proposalLoading)
            : structuralAccessDenied ||
                  (state.phase == ProposalEditorPhase.failure &&
                      state.categories.isEmpty)
            ? ErrorState(
                message: l10n.proposalSafeError,
                onRetry: () => _load(force: true),
              )
            : _ProposalForm(
                key: ValueKey('${identity.id}:$_sessionId'),
                sessionId: _sessionId,
                identityId: identity.id,
                proposal: state.proposal,
                categories: state.categories,
                returnToHub: widget.returnToHub,
              ),
      ),
    );
  }
}

class _ProposalForm extends ConsumerStatefulWidget {
  const _ProposalForm({
    required this.identityId,
    required this.sessionId,
    required this.proposal,
    required this.categories,
    required this.returnToHub,
    super.key,
  });

  final String identityId;
  final String sessionId;
  final OwnProposal? proposal;
  final List<ProposalSkillCategory> categories;
  final bool returnToHub;

  @override
  ConsumerState<_ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends ConsumerState<_ProposalForm>
    with WidgetsBindingObserver {
  final _locationHandle = LocationEditorHandle();
  final _formKey = GlobalKey<FormState>();
  final _titleAnchor = GlobalKey();
  final _summaryAnchor = GlobalKey();
  final _descriptionAnchor = GlobalKey();
  final _capacityAnchor = GlobalKey();
  final _timezoneAnchor = GlobalKey();
  final _startAnchor = GlobalKey();
  final _endAnchor = GlobalKey();
  final _countryAnchor = GlobalKey();
  final _localityAnchor = GlobalKey();
  final _administrativeAreaAnchor = GlobalKey();
  final _publicLocationAnchor = GlobalKey();
  final _exactLocationAnchor = GlobalKey();
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _timezone;
  late final TextEditingController _country;
  late final TextEditingController _locality;
  late final TextEditingController _administrativeArea;
  late final TextEditingController _publicLocation;
  late final TextEditingController _exactLocation;
  late final Map<String, ProposalSkillImportance> _skills;
  late ExactLocationVisibility _visibility;
  late bool _countOrganizersTowardCapacity;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _validatingPublish = false;
  List<String> _validationIssues = const [];
  CoverChange _coverChange = const CoverChange.unchanged();
  int _coverRevision = 0;
  int _acknowledgedCoverRevision = 0;
  int _coverResetEpoch = 0;
  late ProposalDraftSnapshot _acknowledged;
  late final DraftDepartureOwner _departureOwner;
  late final DraftDepartureCoordinator _departure;
  bool _saving = false;
  ProposalDraftSnapshot? _partialAcknowledged;
  late final SimilarProposalController _similar;
  bool _appResumed = true;
  bool _sheetOpen = false;
  bool _openingCandidate = false;
  bool _preparingDeparture = false;
  ModalRoute<String>? _suggestionRoute;
  String get _similarKey => '${widget.identityId}:${widget.sessionId}';

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    _title = TextEditingController(text: p?.title ?? '');
    _summary = TextEditingController(text: p?.summary ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _capacity = TextEditingController(
      text: p?.capacity.registrationCapacity?.toString() ?? '',
    );
    // Only genuine scratch creation adopts Italy's default; legacy values stay.
    _timezone = TextEditingController(
      text: p == null ? 'Europe/Rome' : p.eventTimezone ?? 'UTC',
    );
    _country = TextEditingController(text: p?.countryCode ?? '');
    _locality = TextEditingController(text: p?.locality ?? '');
    _administrativeArea = TextEditingController(
      text: p?.administrativeArea ?? '',
    );
    _publicLocation = TextEditingController(text: p?.publicLocationLabel ?? '');
    _exactLocation = TextEditingController(text: p?.exactMeetingText ?? '');
    _startsAt = p?.startsAt;
    _endsAt = p?.endsAt;
    _visibility =
        p?.exactLocationVisibility ?? ExactLocationVisibility.participants;
    _countOrganizersTowardCapacity =
        p?.capacity.countOrganizersTowardCapacity ?? false;
    _skills = {
      for (final skill in p?.skills ?? const <ProposalSkill>[])
        skill.id: skill.importance,
    };
    _acknowledged = _snapshot();
    _departure = ref.read(draftDepartureProvider);
    _similar = ref.read(similarProposalProvider(_similarKey).notifier);
    _similar.acquireSession();
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    for (final controller in [_title, _country, _locality]) {
      controller.addListener(_syncMatching);
    }
  }

  bool _registeredDeparture = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future<void>.microtask(_syncMatching);
    if (_registeredDeparture) return;
    _registeredDeparture = true;
    _departureOwner = DraftDepartureOwner(
      actorId: widget.identityId,
      pageKey: GoRouterState.of(context).pageKey,
      isActive: () =>
          mounted &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? false),
      prepare: _prepareDeparture,
    );
    _departure.register(_departureOwner);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _similar.releaseSession();
    _departure.unregister(_departureOwner);
    for (final controller in [
      _title,
      _summary,
      _description,
      _capacity,
      _timezone,
      _country,
      _locality,
      _administrativeArea,
      _publicLocation,
      _exactLocation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(_ProposalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Binding is lookup invalidation only; accepted router departure still owns
    // its original choice and performs exactly one DRAFT01 preparation.
    Future<void>.microtask(_syncMatching);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncMatching();
  }

  void _syncMatching() {
    if (!mounted) return;
    final session = ref.read(authSessionProvider);
    final editor = ref.read(proposalEditorSessionProvider(widget.sessionId));
    final ready =
        session.phase == AuthSessionPhase.ready &&
        session.identity?.id == widget.identityId &&
        editor.expectedCreatorId == widget.identityId;
    final draft =
        widget.proposal == null ||
        widget.proposal?.lifecycle == ProposalLifecycle.draft;
    final busy =
        _saving || editor.isBusy || _preparingDeparture || _openingCandidate;
    final route = ModalRoute.of(context);
    final visible = TickerMode.valuesOf(context).enabled;
    final temporarySheet =
        _sheetOpen &&
        _appResumed &&
        ready &&
        draft &&
        visible &&
        !busy &&
        ((route?.isCurrent ?? false) || (_suggestionRoute?.isCurrent ?? false));
    _similar.setActive(
      ready &&
          draft &&
          _appResumed &&
          visible &&
          (route?.isCurrent ?? false) &&
          !busy &&
          !_sheetOpen,
      sheet: temporarySheet,
    );
    try {
      _similar.setQuery(
        ready && draft
            ? SimilarProposalQuery.fromForm(
                actorId: widget.identityId,
                title: _title.text,
                skillIds: _skills.keys,
                country: _country.text,
                locality: _locality.text,
                excludedProposalId: ref
                    .read(
                      proposalEditorSessionProvider(widget.sessionId).notifier,
                    )
                    .boundProposalId,
              )
            : null,
      );
    } on FormatException {
      _similar.invalidInput();
    }
  }

  Future<void> _viewSimilar() async {
    if (_sheetOpen || _openingCandidate || !_departureOwner.isActive()) return;
    final selection = _similar.selection();
    if (selection == null) return;
    final items = ref.read(similarProposalProvider(_similarKey)).items;
    _sheetOpen = true;
    _similar.setActive(false, sheet: true);
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        _suggestionRoute = ModalRoute.of<String>(context);
        return SimilarProposalSheet(
          items: items,
          sessionId: _similarKey,
          selection: selection,
        );
      },
    );
    // popped resolves before the exit animation. completed waits for actual
    // overlay removal; endOfFrame restores editor TickerMode/route ownership.
    await _suggestionRoute?.completed;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final valid =
        selected != null &&
        _appResumed &&
        _departureOwner.isActive() &&
        identical(_departure.activeOwner, _departureOwner) &&
        _similar.accepts(selection, selected);
    _sheetOpen = false;
    _suggestionRoute = null;
    if (!valid) {
      _syncMatching();
      return;
    }
    setState(() => _openingCandidate = true);
    _syncMatching();
    try {
      // The ordinary router guard owns saving, retry/discard and destination
      // feedback. Never manually prepare and then prepare again through push.
      await context.push('/proposals/$selected');
    } finally {
      if (mounted) {
        setState(() => _openingCandidate = false);
        _syncMatching();
      }
    }
  }

  ProposalInput _input() => ProposalInput(
    title: _title.text,
    summary: _summary.text,
    description: _description.text,
    startsAt: _startsAt,
    endsAt: _endsAt,
    // Preserve a legacy unset zone while its schedule remains unset. Choosing
    // dates uses the pre-existing UTC picker convention, never the new Rome default.
    eventTimezone:
        widget.proposal != null &&
            widget.proposal!.eventTimezone == null &&
            _startsAt == null &&
            _endsAt == null
        ? ''
        : _timezone.text,
    countryCode: _country.text,
    locality: _locality.text,
    administrativeArea: _administrativeArea.text,
    publicLocationLabel: _publicLocation.text,
    exactMeetingText: _exactLocation.text,
    exactLocationVisibility: _visibility,
    skillImportanceById: {..._skills},
    registrationCapacity: int.tryParse(_capacity.text.trim()),
    countOrganizersTowardCapacity: _countOrganizersTowardCapacity,
  );

  ProposalDraftSnapshot _snapshot() => ProposalDraftSnapshot(
    text: [
      _title.text,
      _summary.text,
      _description.text,
      _capacity.text,
      _timezone.text,
      _country.text,
      _locality.text,
      _administrativeArea.text,
      _publicLocation.text,
      _exactLocation.text,
    ],
    input: _input(),
    coverRevision: _coverRevision,
  );

  Future<DraftDepartureOutcome> _prepareDeparture() async {
    _preparingDeparture = true;
    _syncMatching();
    try {
      return await _prepareDraftDeparture();
    } finally {
      _preparingDeparture = false;
      _syncMatching();
    }
  }

  Future<DraftDepartureOutcome> _prepareDraftDeparture() async {
    if (widget.proposal?.lifecycle == ProposalLifecycle.published) {
      return DraftDepartureOutcome.noChange;
    }
    if (_saving ||
        ref.read(proposalEditorSessionProvider(widget.sessionId)).isBusy) {
      return DraftDepartureOutcome.blocked;
    }
    final current = _snapshot();
    final controller = ref.read(
      proposalEditorSessionProvider(widget.sessionId).notifier,
    );
    if (current.sameAs(_acknowledged) ||
        (controller.boundProposalId == null && !current.meaningful)) {
      return DraftDepartureOutcome.noChange;
    }
    if (await _save(publish: false, navigate: false)) {
      return _snapshot().sameAs(_acknowledged)
          ? DraftDepartureOutcome.saved
          : DraftDepartureOutcome.blocked;
    }
    if (!mounted ||
        ref.read(authSessionProvider).identity?.id != widget.identityId) {
      return DraftDepartureOutcome.blocked;
    }
    final partial =
        ref
            .read(proposalEditorSessionProvider(widget.sessionId))
            .coverPartialSave !=
        null;
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.proposalDraftLeaveTitle),
        content: Text(
          partial
              ? l10n.proposalDraftImageNotSaved
              : l10n.proposalDraftLeaveError,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.proposalDraftKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              partial
                  ? l10n.proposalDraftLeaveWithoutImage
                  : l10n.proposalDraftDiscard,
            ),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return DraftDepartureOutcome.blocked;
    // Discard only unacknowledged changes; preserve a known/ambiguous creation.
    if (partial && _partialAcknowledged != null) {
      _acknowledged = _partialAcknowledged!;
    }
    _restoreAcknowledged();
    return partial
        ? DraftDepartureOutcome.partial
        : DraftDepartureOutcome.discarded;
  }

  void _restoreAcknowledged() {
    final controllers = [
      _title,
      _summary,
      _description,
      _capacity,
      _timezone,
      _country,
      _locality,
      _administrativeArea,
      _publicLocation,
      _exactLocation,
    ];
    final input = _acknowledged.input;
    setState(() {
      for (final entry in controllers.indexed) {
        entry.$2.text = _acknowledged.text[entry.$1];
      }
      _startsAt = input.startsAt;
      _endsAt = input.endsAt;
      _visibility = input.exactLocationVisibility;
      _countOrganizersTowardCapacity = input.countOrganizersTowardCapacity;
      _skills
        ..clear()
        ..addAll(input.skillImportanceById);
      _coverChange = const CoverChange.unchanged();
      _coverRevision = _acknowledged.coverRevision;
      _acknowledgedCoverRevision = _coverRevision;
      // Discard remounts the cover picker even when its saved revision is unchanged.
      _coverResetEpoch++;
      _validationIssues = const [];
    });
  }

  Future<bool> _save({required bool publish, bool navigate = true}) async {
    _locationHandle.beforeContentSave();
    if (_saving ||
        ref.read(proposalEditorSessionProvider(widget.sessionId)).isBusy) {
      return false;
    }
    final publishedEdit =
        widget.proposal?.lifecycle == ProposalLifecycle.published;
    final validateCompleteContent = publish || publishedEdit;
    setState(() => _validatingPublish = validateCompleteContent);
    final valid = _formKey.currentState?.validate() ?? false;
    final captured = _snapshot();
    final input = captured.input;
    final capturedCover = _coverChange;
    final issues = _validationIssueLabels(
      input,
      publish: validateCompleteContent,
    );
    if (!valid || issues.isNotEmpty) {
      setState(() => _validationIssues = issues);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        final target = _firstInvalidAnchor(
          input,
          publish: validateCompleteContent,
        ).currentContext;
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            alignment: 0.12,
            duration: const Duration(milliseconds: 250),
          );
        }
      }
      return false;
    }
    if (_validationIssues.isNotEmpty) {
      setState(() => _validationIssues = const []);
    }
    final identity = ref.read(authSessionProvider).identity;
    if (identity?.id != widget.identityId) return false;
    if (publish &&
        !await requireProfilePhotoForTrustAction(
          context: context,
          ref: ref,
          expectedProfileId: widget.identityId,
          reason: ProfilePhotoTrustReason.publishPersonalActivity,
        )) {
      return false;
    }
    if (!mounted) return false;
    setState(() => _saving = true);
    _syncMatching();
    final controller = ref.read(
      proposalEditorSessionProvider(widget.sessionId).notifier,
    );
    final id = publish
        ? await controller.publish(
            widget.identityId,
            input,
            coverChange: capturedCover,
          )
        : publishedEdit
        ? await controller.saveChanges(
            widget.identityId,
            input,
            coverChange: capturedCover,
          )
        : await controller.saveDraft(
            widget.identityId,
            input,
            coverChange: capturedCover,
          );
    if (!mounted ||
        ref.read(authSessionProvider).identity?.id != widget.identityId) {
      return false;
    }
    setState(() => _saving = false);
    _syncMatching();
    if (id == null &&
        ref
                .read(proposalEditorSessionProvider(widget.sessionId))
                .coverPartialSave !=
            null) {
      _partialAcknowledged = ProposalDraftSnapshot(
        text: captured.text,
        input: captured.input,
        coverRevision: _acknowledged.coverRevision,
      );
    }
    if (id == null &&
        mounted &&
        publish &&
        ref.read(proposalEditorSessionProvider(widget.sessionId)).failure ==
            ProposalFailureKind.profilePhotoRequired) {
      await showProfilePhotoTrustGate(
        context: context,
        reason: ProfilePhotoTrustReason.publishPersonalActivity,
      );
      return false;
    }
    if (id != null && mounted) {
      setState(() {
        _acknowledged = captured;
        if (_coverRevision == captured.coverRevision) {
          _coverChange = const CoverChange.unchanged();
          _acknowledgedCoverRevision = _coverRevision;
        }
      });
      ref.invalidate(ownProposalsProvider);
      ref.invalidate(publicProposalsProvider);
      if (navigate) {
        if (widget.returnToHub && context.canPop()) {
          context.pop();
        } else {
          context.go('/proposals/mine');
        }
      }
      return true;
    }
    return false;
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.proposalCancelConfirmTitle),
        content: Text(l10n.proposalCancelConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.proposalKeepAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.proposalCancelAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cancelled = await ref
        .read(proposalEditorSessionProvider(widget.sessionId).notifier)
        .cancel(widget.identityId);
    if (!cancelled && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.proposalSafeError)));
    }
  }

  Future<void> _fillSampleData() async {
    if (_snapshot().meaningful) {
      final l = AppLocalizations.of(context);
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(l.proposalDemoReplaceTitle),
          content: Text(l.proposalDemoReplaceMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.proposalDraftKeepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.demoFillSampleAction),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    if (!mounted ||
        ref.read(authSessionProvider).identity?.id != widget.identityId) {
      return;
    }
    final start = ref
        .read(proposalClockProvider)()
        .toUtc()
        .add(const Duration(days: 7));
    setState(() {
      _title.text = 'Community garden build day';
      _summary.text = 'Build raised beds together for a neighborhood garden.';
      _description.text = 'We will prepare the site, assemble raised beds, and share the work in small teams.';
      _capacity.text = '20';
      _countOrganizersTowardCapacity = false;
      _timezone.text = 'Europe/Rome';
      _country.text = 'IT';
      _locality.text = 'Bologna';
      _administrativeArea.text = 'Emilia-Romagna';
      _publicLocation.text = 'Central Bologna';
      _exactLocation.text =
          'Meet beside the main entrance to the community garden.';
      _startsAt = start;
      _endsAt = start.add(const Duration(hours: 3));
      _visibility = ExactLocationVisibility.participants;
      _skills.clear();
      final firstSkill = widget.categories.firstOrNull?.skills.firstOrNull;
      if (firstSkill != null) {
        _skills[firstSkill.id] = ProposalSkillImportance.required;
      }
      _validatingPublish = false;
      _validationIssues = const [];
    });
    _formKey.currentState?.validate();
    _syncMatching();
  }

  Future<void> _pickDateTime({required bool start}) async {
    // Never reinterpret a stored instant in the device timezone or an invalid
    // in-progress field value. Keep the existing dates until a valid zone is set.
    final timezoneName = _timezone.text.trim();
    if (!isKnownProposalTimeZone(timezoneName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).proposalTimezoneError),
        ),
      );
      return;
    }
    final now = proposalUtcToWallTime(
      ref.read(proposalClockProvider)(),
      timezoneName,
    );
    final existing = start ? _startsAt : _endsAt;
    final initial = existing == null
        ? now.add(const Duration(days: 1))
        : proposalUtcToWallTime(existing, timezoneName);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      currentDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != widget.identityId) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != widget.identityId) {
      return;
    }
    final wall = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final utc = proposalWallTimeToUtc(wall, timezoneName);
    setState(() => start ? _startsAt = utc : _endsAt = utc);
    _refreshValidationSummary();
  }

  void _refreshValidationSummary() {
    if (_validationIssues.isEmpty) {
      setState(() {});
      return;
    }
    final issues = _validationIssueLabels(
      _input(),
      publish: _validatingPublish,
    );
    if (!listEquals(issues, _validationIssues)) {
      setState(() => _validationIssues = issues);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(proposalEditorSessionProvider(widget.sessionId));
    final busy = state.isBusy || _saving;
    final proposal = widget.proposal;
    final now = ref.read(proposalClockProvider)();
    final contentEditable = proposal == null || proposal.isEditableAt(now);
    final isDraft =
        proposal == null || proposal.lifecycle == ProposalLifecycle.draft;
    final isPublished = proposal?.lifecycle == ProposalLifecycle.published;
    final canCancel = proposal?.canCancelAt(now) ?? false;
    Future<void>.microtask(_syncMatching);
    final readOnlyMessage = proposal == null || contentEditable
        ? null
        : proposal.lifecycle == ProposalLifecycle.cancelled
        ? l10n.proposalCancelledReadOnly
        : proposal.status == ProposalStatus.completed ||
              proposal.status == ProposalStatus.justFinished
        ? l10n.proposalCompletedReadOnly
        : l10n.proposalStartedReadOnly;
    return Form(
      key: _formKey,
      autovalidateMode: _validationIssues.isEmpty
          ? AutovalidateMode.disabled
          : AutovalidateMode.always,
      child: Column(
        children: [
          if (_validationIssues.isNotEmpty)
            Container(
              key: const Key('proposal-validation-summary'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.proposalCheckFields(_validationIssues.join(', ')),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              // Retain built fields and pending covers when they scroll offscreen.
              children: <Widget>[
                if (isDraft &&
                    (widget.proposal != null || _snapshot().meaningful))
                  OutlinedButton.icon(
                    key: const Key('proposal-editor-workshop'),
                    onPressed: busy
                        ? null
                        : () => context.push(WorkshopRoutes.catalog),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(l10n.workshopStartFromTemplate),
                  ),
                if (readOnlyMessage != null) ...[
                  Card(
                    key: const Key('proposal-editor-read-only'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      child: Text(readOnlyMessage),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                _field(
                  _title,
                  l10n.proposalTitleLabel,
                  100,
                  anchorKey: _titleAnchor,
                  fieldKey: const Key('proposal-title'),
                  required: true,
                  minimumLength: 2,
                ),
                if (isDraft)
                  SimilarProposalEntry(
                    sessionId: _similarKey,
                    enabled: !busy && !_openingCandidate,
                    onView: _viewSimilar,
                  ),
                CoverEditorSection(
                  key: ValueKey(
                    '${widget.sessionId}:$_acknowledgedCoverRevision:$_coverResetEpoch',
                  ),
                  ownerProfileId: widget.identityId,
                  title: widget.proposal?.title ?? l10n.proposalCreateTitle,
                  canonicalObjectPath: widget.proposal?.coverObjectPath,
                  enabled: !busy,
                  onChanged: (change) => setState(() {
                    _coverChange = change;
                    _coverRevision++;
                  }),
                ),
                const SizedBox(height: AppSpacing.large),
                _field(
                  _summary,
                  l10n.proposalSummaryLabel,
                  240,
                  anchorKey: _summaryAnchor,
                  fieldKey: const Key('proposal-summary'),
                  required: true,
                ),
                _field(
                  _description,
                  l10n.proposalDescriptionLabel,
                  5000,
                  anchorKey: _descriptionAnchor,
                  fieldKey: const Key('proposal-description'),
                  required: true,
                  lines: 6,
                ),
                Padding(
                  key: _capacityAnchor,
                  padding: const EdgeInsets.only(bottom: AppSpacing.medium),
                  child: ProposalCapacityControl(
                    controller: _capacity,
                    enabled: !busy && contentEditable,
                    validator: (_) => _validateCapacity(),
                    onChanged: _refreshValidationSummary,
                  ),
                ),
                SwitchListTile(
                  key: const Key('proposal-count-organizers-capacity'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.projectCountOrganizersCapacityLabel),
                  value: _countOrganizersTowardCapacity,
                  onChanged: busy || !contentEditable
                      ? null
                      : (value) => setState(
                          () => _countOrganizersTowardCapacity = value,
                        ),
                ),
                Text(
                  l10n.projectCountOrganizersCapacityHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.large),
                Container(
                  key: _timezoneAnchor,
                  child: _timezone.text != 'Europe/Rome'
                      ? Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.medium,
                          ),
                          child: Text(
                            l10n.proposalScheduleZone(_timezone.text),
                            key: const Key('proposal-legacy-zone'),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                ProposalControlPair(
                  first: Container(
                    key: _startAnchor,
                    child: ProposalDateControl(
                      label: l10n.proposalStartLabel,
                      value: _startsAt,
                      timezone: _timezone.text,
                      enabled: !busy && contentEditable,
                      onPick: () => _pickDateTime(start: true),
                      fieldKey: const Key('proposal-start-field'),
                      pickKey: const Key('proposal-pick-start'),
                      validator: (_) => _validatingPublish && _startsAt == null
                          ? l10n.proposalStartRequired
                          : null,
                    ),
                  ),
                  second: Container(
                    key: _endAnchor,
                    child: ProposalDateControl(
                      label: l10n.proposalEndLabel,
                      value: _endsAt,
                      timezone: _timezone.text,
                      enabled: !busy && contentEditable,
                      onPick: () => _pickDateTime(start: false),
                      fieldKey: const Key('proposal-end-field'),
                      pickKey: const Key('proposal-pick-end'),
                      validator: (_) {
                        if (_validatingPublish && _endsAt == null) {
                          return l10n.proposalEndRequired;
                        }
                        if (_startsAt != null &&
                            _endsAt != null &&
                            !_endsAt!.isAfter(_startsAt!)) {
                          return l10n.proposalEndAfterStart;
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                LocationEditorSection(
                  key: ValueKey(widget.sessionId),
                  handle: _locationHandle,
                  manualPublicLabel: () => _publicLocation.text,
                  actorId: widget.identityId,
                  itemKind: 'one_time',
                  itemId: () => ref
                      .read(proposalEditorSessionProvider(widget.sessionId))
                      .proposal
                      ?.id,
                  savePending: () async =>
                      await _save(publish: false, navigate: false)
                      ? ref
                            .read(
                              proposalEditorSessionProvider(widget.sessionId),
                            )
                            .proposal
                            ?.id
                      : null,
                  enabled: contentEditable,
                  exactIsPublic: _visibility == ExactLocationVisibility.public,
                  contentControllers: [
                    _title,
                    _summary,
                    _description,
                    _capacity,
                    _timezone,
                    _country,
                    _locality,
                    _administrativeArea,
                    _publicLocation,
                    _exactLocation,
                  ],
                  contentVersion:
                      '$_startsAt:$_endsAt:$_visibility:$_skills:$_coverRevision:$_countOrganizersTowardCapacity',
                  onCanonical: (value) {
                    final place = value.publicPlace;
                    if (place != null) {
                      _country.text = 'IT';
                      _locality.text = place.locality;
                      _administrativeArea.text = place.administrativeArea ?? '';
                      _publicLocation.text = place.label;
                      _acknowledged = _snapshot();
                    }
                  },
                  manualChildren: [
                    _field(
                      _country,
                      l10n.proposalCountryLabel,
                      2,
                      anchorKey: _countryAnchor,
                      fieldKey: const Key('proposal-country'),
                      required: true,
                      validator: _validateCountry,
                    ),
                    _field(
                      _locality,
                      l10n.proposalLocalityLabel,
                      120,
                      anchorKey: _localityAnchor,
                      fieldKey: const Key('proposal-locality'),
                      required: true,
                    ),
                    _field(
                      _administrativeArea,
                      l10n.proposalAdministrativeAreaLabel,
                      120,
                      anchorKey: _administrativeAreaAnchor,
                      fieldKey: const Key('proposal-administrative-area'),
                    ),
                    _field(
                      _publicLocation,
                      l10n.proposalPublicLocationLabel,
                      180,
                      anchorKey: _publicLocationAnchor,
                      fieldKey: const Key('proposal-public-location'),
                      required: true,
                    ),
                  ],
                ),
                _field(
                  _exactLocation,
                  l10n.proposalExactLocationLabel,
                  1000,
                  anchorKey: _exactLocationAnchor,
                  fieldKey: const Key('proposal-exact-location'),
                  required: true,
                  lines: 3,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  l10n.proposalExactVisibilityLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SegmentedButton<ExactLocationVisibility>(
                  key: const Key('proposal-exact-visibility'),
                  segments: [
                    ButtonSegment(
                      value: ExactLocationVisibility.participants,
                      label: Text(l10n.proposalExactParticipants),
                    ),
                    ButtonSegment(
                      value: ExactLocationVisibility.public,
                      label: Text(l10n.proposalExactPublic),
                    ),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: busy || !contentEditable
                      ? null
                      : (selection) =>
                            setState(() => _visibility = selection.single),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  _visibility == ExactLocationVisibility.participants
                      ? l10n.locationRestrictedPreview
                      : l10n.locationPublicPreview,
                  key: const Key('location-visibility-preview'),
                ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  l10n.proposalSkillsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.small),
                ProposalSkillsControl(
                  categories: widget.categories,
                  values: _skills,
                  enabled: !busy && contentEditable,
                  onChanged: (values) {
                    setState(() {
                      _skills
                        ..clear()
                        ..addAll(values);
                    });
                    _syncMatching();
                  },
                ),
                if (state.coverPartialSave != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.coverPartialSave ==
                              CoverPartialSaveKind.draftCreated
                          ? l10n.coverDraftPartialError
                          : l10n.coverChangesPartialError,
                      key: const Key('proposal-cover-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ] else if (state.phase == ProposalEditorPhase.failure &&
                    state.failure !=
                        ProposalFailureKind.profilePhotoRequired) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    switch (state.failure) {
                      ProposalFailureKind.invalidInput =>
                        l10n.proposalValidationError,
                      ProposalFailureKind.capacityConflict =>
                        l10n.projectOrganizerCapacityConflict,
                      _ => l10n.proposalSafeError,
                    },
                    key: const Key('proposal-editor-safe-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.small,
                  children: [
                    if (widget.proposal != null && contentEditable)
                      OutlinedButton.icon(
                        key: const Key('proposal-manage-resources'),
                        onPressed: busy
                            ? null
                            : () => context.push(
                                ProjectResourceNeedRoutes.manage(
                                  ProjectKind.oneTime,
                                  widget.proposal!.id,
                                ),
                              ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(l10n.projectResourcesManage),
                      ),
                    if (isPublished && contentEditable)
                      FilledButton(
                        key: const Key('proposal-save-changes'),
                        onPressed: busy ? null : () => _save(publish: false),
                        child: Text(l10n.proposalSaveChangesAction),
                      ),
                    if (canCancel)
                      TextButton(
                        key: const Key('proposal-editor-cancel'),
                        onPressed: busy ? null : _confirmCancel,
                        child: Text(l10n.proposalCancelAction),
                      ),
                  ],
                ),
                if (isDraft && contentEditable) ...[
                  const SizedBox(height: AppSpacing.medium),
                  ProposalControlPair(
                    first: OutlinedButton(
                      key: const Key('proposal-save-draft'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: busy ? null : () => _save(publish: false),
                      child: Text(l10n.proposalSaveDraftAction),
                    ),
                    second: FilledButton(
                      key: const Key('proposal-publish'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: busy ? null : () => _save(publish: true),
                      child: Text(l10n.proposalPublishAction),
                    ),
                  ),
                ],
                if (widget.proposal == null &&
                    ref.watch(demoToolsEnabledProvider)) ...[
                  const SizedBox(height: AppSpacing.large),
                  const Divider(),
                  DemoFillSampleAction(
                    buttonKey: const Key('proposal-fill-sample'),
                    onPressed: busy ? null : _fillSampleData,
                  ),
                ],
              ].map((child) => _RetainedDraftField(child: child)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int maxLength, {
    required GlobalKey anchorKey,
    bool required = false,
    int minimumLength = 0,
    int lines = 1,
    Key? fieldKey,
    FormFieldValidator<String>? validator,
  }) => Padding(
    key: anchorKey,
    padding: const EdgeInsets.only(bottom: AppSpacing.medium),
    child: TextFormField(
      key: fieldKey ?? Key('proposal-field-${label.hashCode}'),
      controller: controller,
      enabled:
          !ref.watch(proposalEditorSessionProvider(widget.sessionId)).isBusy &&
          (widget.proposal == null ||
              widget.proposal!.isEditableAt(ref.read(proposalClockProvider)())),
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      onChanged: (_) => _refreshValidationSummary(),
      validator:
          validator ??
          (value) => _validateText(
            value,
            required: required,
            minimumLength: minimumLength,
            maximumLength: maxLength,
          ),
    ),
  );

  String? _validateText(
    String? value, {
    required bool required,
    required int minimumLength,
    required int maximumLength,
  }) {
    final l10n = AppLocalizations.of(context);
    final length = (value ?? '').trim().length;
    if (length == 0) {
      return required && _validatingPublish ? l10n.proposalRequiredField : null;
    }
    if (length < minimumLength) {
      return l10n.proposalMinimumLength(minimumLength);
    }
    if (length > maximumLength) {
      return l10n.proposalMaximumLength(maximumLength);
    }
    return null;
  }

  String? _validateCountry(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty && !_validatingPublish) return null;
    if (text.isEmpty) return AppLocalizations.of(context).proposalRequiredField;
    return RegExp(r'^[A-Za-z]{2}$').hasMatch(text)
        ? null
        : AppLocalizations.of(context).proposalCountryCodeError;
  }

  List<String> _validationIssueLabels(
    ProposalInput input, {
    required bool publish,
  }) {
    final l10n = AppLocalizations.of(context);
    final issues = <String>[];
    void text(
      String label,
      String value,
      int max, {
      bool required = false,
      int min = 0,
    }) {
      final length = value.trim().length;
      if ((publish && required && length == 0) ||
          (length > 0 && length < min) ||
          length > max) {
        issues.add(label);
      }
    }

    text(l10n.proposalTitleLabel, input.title, 100, required: true, min: 2);
    text(l10n.proposalSummaryLabel, input.summary, 240, required: true);
    text(
      l10n.proposalDescriptionLabel,
      input.description,
      5000,
      required: true,
    );
    if (_validateCapacity() != null) {
      issues.add(l10n.projectRegistrationCapacityLabel);
    }
    if ((publish && input.eventTimezone.trim().isEmpty) ||
        (input.eventTimezone.trim().isNotEmpty &&
            !isKnownProposalTimeZone(input.eventTimezone))) {
      issues.add(l10n.proposalTimezoneShortLabel);
    }
    if (publish && input.startsAt == null) issues.add(l10n.proposalStartLabel);
    if ((publish && input.endsAt == null) ||
        (input.startsAt != null &&
            input.endsAt != null &&
            !input.endsAt!.isAfter(input.startsAt!))) {
      issues.add(l10n.proposalEndLabel);
    }
    final country = input.countryCode.trim();
    if ((publish && country.isEmpty) ||
        (country.isNotEmpty && !RegExp(r'^[A-Za-z]{2}$').hasMatch(country))) {
      issues.add(l10n.proposalCountryLabel);
    }
    text(l10n.proposalLocalityLabel, input.locality, 120, required: true);
    text(l10n.proposalAdministrativeAreaLabel, input.administrativeArea, 120);
    text(
      l10n.proposalPublicLocationLabel,
      input.publicLocationLabel,
      180,
      required: true,
    );
    text(
      l10n.proposalExactLocationLabel,
      input.exactMeetingText,
      1000,
      required: true,
    );
    return issues;
  }

  GlobalKey _firstInvalidAnchor(ProposalInput input, {required bool publish}) {
    final titleLength = input.title.trim().length;
    if ((publish && titleLength == 0) ||
        (titleLength > 0 && titleLength < 2) ||
        titleLength > 100) {
      return _titleAnchor;
    }
    if ((publish && input.summary.trim().isEmpty) ||
        input.summary.trim().length > 240) {
      return _summaryAnchor;
    }
    if ((publish && input.description.trim().isEmpty) ||
        input.description.trim().length > 5000) {
      return _descriptionAnchor;
    }
    if (_validateCapacity() != null) return _capacityAnchor;
    final timezone = input.eventTimezone.trim();
    if ((publish && timezone.isEmpty) ||
        (timezone.isNotEmpty && !isKnownProposalTimeZone(timezone))) {
      return _timezoneAnchor;
    }
    if (publish && input.startsAt == null) return _startAnchor;
    if ((publish && input.endsAt == null) ||
        (input.startsAt != null &&
            input.endsAt != null &&
            !input.endsAt!.isAfter(input.startsAt!))) {
      return _endAnchor;
    }
    final country = input.countryCode.trim();
    if ((publish && country.isEmpty) ||
        (country.isNotEmpty && !RegExp(r'^[A-Za-z]{2}$').hasMatch(country))) {
      return _countryAnchor;
    }
    if ((publish && input.locality.trim().isEmpty) ||
        input.locality.trim().length > 120) {
      return _localityAnchor;
    }
    if (input.administrativeArea.trim().length > 120) {
      return _administrativeAreaAnchor;
    }
    if ((publish && input.publicLocationLabel.trim().isEmpty) ||
        input.publicLocationLabel.trim().length > 180) {
      return _publicLocationAnchor;
    }
    return _exactLocationAnchor;
  }

  String? _validateCapacity() {
    final l10n = AppLocalizations.of(context);
    final text = _capacity.text.trim();
    if (text.isEmpty) {
      return _validatingPublish
          ? l10n.projectRegistrationCapacityRequired
          : null;
    }
    final capacity = int.tryParse(text);
    if (capacity == null || capacity < 1 || capacity > 100000) {
      return l10n.projectRegistrationCapacityRange;
    }
    final capacityUsed =
        widget.proposal?.capacity.capacityUsedFor(
          _countOrganizersTowardCapacity,
        ) ??
        (_countOrganizersTowardCapacity ? 1 : 0);
    if (capacity < capacityUsed) {
      return l10n.projectRegistrationCapacityBelowCurrent(capacityUsed);
    }
    return null;
  }
}

class _RetainedDraftField extends StatefulWidget {
  const _RetainedDraftField({required this.child});
  final Widget child;

  @override
  State<_RetainedDraftField> createState() => _RetainedDraftFieldState();
}

class _RetainedDraftFieldState extends State<_RetainedDraftField>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
