import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../devtools/demo/demo_widgets.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/resource_listing_controllers.dart';
import '../domain/resource_listing_models.dart';
import 'resource_listing_widgets.dart';

class ResourceListingEditorScreen extends ConsumerStatefulWidget {
  const ResourceListingEditorScreen({this.listingId, super.key});

  final String? listingId;

  @override
  ConsumerState<ResourceListingEditorScreen> createState() =>
      _ResourceListingEditorScreenState();
}

class _ResourceListingEditorScreenState
    extends ConsumerState<ResourceListingEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _country = TextEditingController();
  final _locality = TextEditingController();
  final _administrativeArea = TextEditingController();
  final _publicLocation = TextEditingController();
  ResourceListingMode _mode = ResourceListingMode.donate;
  String? _requestedIdentity;
  String? _hydratedVersion;
  bool _attemptPublish = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _country.dispose();
    _locality.dispose();
    _administrativeArea.dispose();
    _publicLocation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final identity = ref.read(authSessionProvider).identity;
    if (identity != null) {
      _requestedIdentity = identity.id;
      await ref
          .read(resourceListingEditorProvider.notifier)
          .load(identity.id, widget.listingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(authSessionProvider).identity;
    final state = ref.watch(resourceListingEditorProvider);
    final ownsState = state.expectedOwnerId == identity?.id;
    final listing = ownsState ? state.listing : null;
    if (identity != null && _requestedIdentity != identity.id) {
      Future<void>.microtask(_load);
    }
    if (listing != null) {
      final version = '${listing.id}:${listing.updatedAt.toIso8601String()}';
      if (_hydratedVersion != version) {
        _hydrate(listing);
        _hydratedVersion = version;
      }
    }
    final isClosed = listing?.lifecycle == ResourceListingLifecycle.closed;
    final isPublished =
        listing?.lifecycle == ResourceListingLifecycle.published;
    final showInitialLoading =
        !ownsState ||
        state.phase == ResourceListingEditorPhase.idle ||
        (state.phase == ResourceListingEditorPhase.loading && listing == null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.listingId == null && state.listingId == null
              ? l10n.resourceCreateListing
              : isClosed
              ? l10n.resourceViewListing
              : l10n.resourceEditListing,
        ),
      ),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : showInitialLoading
            ? LoadingState(message: l10n.resourceLoading)
            : state.phase == ResourceListingEditorPhase.failure &&
                  listing == null &&
                  widget.listingId != null
            ? ErrorState(
                message: resourceListingFailureMessage(l10n, state.failure),
                onRetry: _load,
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.listingId == null && state.listingId == null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DemoFillSampleAction(
                            buttonKey: const Key('resource-fill-sample'),
                            onPressed: state.isBusy ? null : _fillSample,
                          ),
                        ),
                      if (isClosed) ...[
                        ResourceListingLifecycleBadge(
                          lifecycle: ResourceListingLifecycle.closed,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          l10n.resourceClosedReadOnly,
                          key: const Key('resource-closed-read-only'),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                      ],
                      Semantics(
                        label: l10n.resourceModeField,
                        child: SegmentedButton<ResourceListingMode>(
                          key: const Key('resource-editor-mode'),
                          segments: [
                            ButtonSegment(
                              value: ResourceListingMode.donate,
                              label: Text(l10n.resourceModeDonate),
                            ),
                            ButtonSegment(
                              value: ResourceListingMode.exchange,
                              label: Text(l10n.resourceModeExchange),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: isClosed || state.isBusy
                              ? null
                              : (selection) =>
                                    setState(() => _mode = selection.single),
                        ),
                      ),
                      _field(
                        key: const Key('resource-title-field'),
                        controller: _title,
                        label: l10n.resourceTitleField,
                        max: 120,
                        min: 2,
                        requiredForPublish: true,
                        enabled: !isClosed,
                      ),
                      _field(
                        key: const Key('resource-description-field'),
                        controller: _description,
                        label: l10n.resourceDescriptionField,
                        max: 5000,
                        requiredForPublish: true,
                        maxLines: 6,
                        enabled: !isClosed,
                      ),
                      _field(
                        key: const Key('resource-country-field'),
                        controller: _country,
                        label: l10n.resourceCountryCodeField,
                        max: 2,
                        requiredForPublish: true,
                        enabled: !isClosed,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2),
                          _UpperCaseTextFormatter(),
                        ],
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (_attemptPublish && trimmed.isEmpty) {
                            return l10n.resourceRequiredField;
                          }
                          if (trimmed.isNotEmpty &&
                              !RegExp(r'^[A-Z]{2}$').hasMatch(trimmed)) {
                            return l10n.resourceCountryCodeValidation;
                          }
                          return null;
                        },
                      ),
                      _field(
                        key: const Key('resource-locality-field'),
                        controller: _locality,
                        label: l10n.resourceLocalityField,
                        max: 120,
                        requiredForPublish: true,
                        enabled: !isClosed,
                      ),
                      _field(
                        key: const Key('resource-administrative-area-field'),
                        controller: _administrativeArea,
                        label: l10n.resourceAdministrativeAreaField,
                        max: 120,
                        enabled: !isClosed,
                      ),
                      _field(
                        key: const Key('resource-public-location-field'),
                        controller: _publicLocation,
                        label: l10n.resourcePublicLocationField,
                        max: 180,
                        requiredForPublish: true,
                        enabled: !isClosed,
                      ),
                      if (state.phase ==
                          ResourceListingEditorPhase.failure) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Text(
                          state.draftSavedAfterPublishFailure
                              ? l10n.resourceDraftSavedPublishFailed
                              : resourceListingFailureMessage(
                                  l10n,
                                  state.failure,
                                ),
                          key: const Key('resource-editor-error'),
                        ),
                      ],
                      if (!isClosed) ...[
                        const SizedBox(height: AppSpacing.large),
                        Wrap(
                          spacing: AppSpacing.small,
                          runSpacing: AppSpacing.small,
                          children: [
                            if (!isPublished)
                              OutlinedButton(
                                key: const Key('resource-save-draft'),
                                onPressed: state.isBusy
                                    ? null
                                    : () => _submit(publish: false),
                                child:
                                    state.phase ==
                                        ResourceListingEditorPhase.saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Text(l10n.resourceSaveDraft),
                              ),
                            if (!isPublished)
                              FilledButton(
                                key: const Key('resource-publish'),
                                onPressed: state.isBusy
                                    ? null
                                    : () => _submit(publish: true),
                                child:
                                    state.phase ==
                                        ResourceListingEditorPhase.publishing
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Text(l10n.resourcePublish),
                              ),
                            if (isPublished)
                              FilledButton(
                                key: const Key('resource-save-changes'),
                                onPressed: state.isBusy
                                    ? null
                                    : () => _submit(publish: false),
                                child:
                                    state.phase ==
                                        ResourceListingEditorPhase.saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Text(l10n.resourceSaveChanges),
                              ),
                            if (isPublished)
                              TextButton(
                                key: const Key('resource-close-listing'),
                                onPressed: state.isBusy ? null : _confirmClose,
                                child: Text(l10n.resourceCloseListing),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required int max,
    required bool enabled,
    int min = 0,
    bool requiredForPublish = false,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.small),
    child: TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final custom = validator?.call(value);
        if (custom != null) return custom;
        final length = value?.trim().length ?? 0;
        final l10n = AppLocalizations.of(context);
        if (_attemptPublish && requiredForPublish && length == 0) {
          return l10n.resourceRequiredField;
        }
        if (length > 0 && length < min) {
          return l10n.resourceMinimumLength(min);
        }
        if (length > max) return l10n.resourceMaximumLength(max);
        return null;
      },
    ),
  );

  ResourceListingInput _input() => ResourceListingInput(
    mode: _mode,
    title: _title.text,
    description: _description.text,
    countryCode: _country.text,
    locality: _locality.text,
    administrativeArea: _administrativeArea.text,
    publicLocationLabel: _publicLocation.text,
  );

  Future<void> _submit({required bool publish}) async {
    final lifecycle = ref
        .read(resourceListingEditorProvider)
        .listing
        ?.lifecycle;
    setState(
      () => _attemptPublish =
          publish || lifecycle == ResourceListingLifecycle.published,
    );
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null) return;
    final controller = ref.read(resourceListingEditorProvider.notifier);
    final id = publish
        ? await controller.publish(identity.id, _input())
        : await controller.save(identity.id, _input());
    if (!mounted) return;
    if (id == null) return;
    if (publish) {
      context.go('/resources/mine');
    } else if (widget.listingId == null) {
      context.go('/resources/$id/edit');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).resourceSaved)),
      );
    }
  }

  Future<void> _confirmClose() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resourceCloseConfirmTitle),
        content: Text(l10n.resourceCloseConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.resourceKeepListing),
          ),
          FilledButton(
            key: const Key('resource-confirm-close'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.resourceCloseListing),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null) return;
    final closed = await ref
        .read(resourceListingEditorProvider.notifier)
        .close(identity.id);
    if (closed && mounted) {
      context.go('/resources/mine');
    }
  }

  void _hydrate(OwnResourceListing listing) {
    _mode = listing.mode;
    _title.text = listing.title ?? '';
    _description.text = listing.description ?? '';
    _country.text = listing.countryCode ?? '';
    _locality.text = listing.locality ?? '';
    _administrativeArea.text = listing.administrativeArea ?? '';
    _publicLocation.text = listing.publicLocationLabel ?? '';
  }

  void _fillSample() {
    setState(() {
      _title.text = 'Shared garden tools';
      _description.text =
          'A sturdy set of hand tools ready for another neighborhood project.';
      _country.text = 'IT';
      _locality.text = 'Bologna';
      _administrativeArea.text = 'Emilia-Romagna';
      _publicLocation.text = 'Central Bologna';
      _attemptPublish = false;
    });
    _formKey.currentState?.validate();
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
