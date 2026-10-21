import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/skill_display.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../blocking/application/blocking_controller.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../profile_photo/presentation/profile_photo_avatar.dart';
import '../application/person_preview_controller.dart';

Future<void> showPersonPreviewSheet(
  BuildContext context, {
  required String profileId,
  String? contextDisplayName,
  String? projectId,
  String? listingId,
  BlockingContextConsequence consequence = BlockingContextConsequence.none,
  FutureOr<void> Function(bool)? onChanged,
  Key? blockingKey,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.medium),
    child: PersonPreviewContent(
      profileId: profileId,
      contextDisplayName: contextDisplayName,
      projectId: projectId,
      listingId: listingId,
      consequence: consequence,
      onChanged: onChanged,
      blockingKey: blockingKey,
    ),
  ),
);

/// Also composes into existing People action sheets, preserving their actions.
class PersonPreviewContent extends ConsumerStatefulWidget {
  const PersonPreviewContent({
    required this.profileId,
    this.contextDisplayName,
    this.projectId,
    this.listingId,
    this.showBlocking = true,
    this.consequence = BlockingContextConsequence.none,
    this.onChanged,
    this.blockingKey,
    super.key,
  });
  final String profileId;
  // A name already authorized by the current source surface. It stays local to
  // this sheet and is never copied into the public-profile projection/cache.
  final String? contextDisplayName;
  final String? projectId;
  final String? listingId;
  final bool showBlocking;
  final BlockingContextConsequence consequence;
  final FutureOr<void> Function(bool)? onChanged;
  final Key? blockingKey;

  @override
  ConsumerState<PersonPreviewContent> createState() =>
      _PersonPreviewContentState();
}

class _PersonPreviewContentState extends ConsumerState<PersonPreviewContent>
    with WidgetsBindingObserver {
  late final String? _viewer;
  bool _identityChanged = false;
  PersonPreviewTarget get _target => (
    profileId: widget.profileId,
    projectId: widget.projectId,
    listingId: widget.listingId,
  );

  @override
  void initState() {
    super.initState();
    _viewer = ref.read(authSessionProvider).identity?.id;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _reload() {
    ref.invalidate(publicProfilePreviewProvider(widget.profileId));
    ref.invalidate(personPreviewPhotoProvider(_target));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_identityChanged) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((state) => state.identity?.id), (
      previous,
      next,
    ) {
      if (next == _viewer || _identityChanged) return;
      _identityChanged = true;
      ref.invalidate(publicProfilePreviewProvider(widget.profileId));
      ref.invalidate(personPreviewPhotoProvider(_target));
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    });
    if (_identityChanged) return const SizedBox.shrink();
    final profile = ref.watch(publicProfilePreviewProvider(widget.profileId));
    final photo = ref.watch(personPreviewPhotoProvider(_target));
    final blocked = ref.watch(
      blockingProvider.select(
        (state) =>
            state.expectedProfileId == _viewer &&
            state.exactStatus(widget.profileId) != null,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.personPreviewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: l10n.projectShareClose,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Align(
          child: photo.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            data: (bytes) => ProfilePhotoAvatar(
              imageBytes: bytes,
              imageSemanticsLabel: l10n.personPreviewPhoto,
              placeholderSemanticsLabel: l10n.personPreviewNoPhoto,
              radius: 96,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
            error: (_, _) => Column(
              children: [
                ProfilePhotoAvatar(
                  imageBytes: null,
                  imageSemanticsLabel: l10n.personPreviewPhoto,
                  placeholderSemanticsLabel: l10n.personPreviewNoPhoto,
                  radius: 96,
                ),
                Text(l10n.personPreviewPhotoError),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(personPreviewPhotoProvider(_target)),
                  child: Text(l10n.retryAction),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        profile.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (person) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                person?.displayName ??
                    widget.contextDisplayName ??
                    l10n.personPreviewAnonymous,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (person?.bio case final bio?) ...[
                const SizedBox(height: AppSpacing.small),
                Text(bio),
              ],
              if (person != null && person.skills.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.medium),
                Text(
                  l10n.profileSkillsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final skill in person.skills)
                      Chip(
                        label: Text(
                          skillDisplayLabel(context, skill.slug, skill.label),
                        ),
                      ),
                  ],
                ),
              ],
              if (person == null ||
                  (person.bio == null && person.skills.isEmpty))
                Text(l10n.personPreviewNoDetails),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.contextDisplayName case final name?)
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
              Text(l10n.personPreviewReadError),
              TextButton(
                onPressed: () => ref.invalidate(
                  publicProfilePreviewProvider(widget.profileId),
                ),
                child: Text(l10n.retryAction),
              ),
            ],
          ),
        ),
        if (blocked) Text(l10n.personPreviewBlocked),
        if (widget.showBlocking) ...[
          const SizedBox(height: AppSpacing.medium),
          BlockingActionButton(
            targetProfileId: widget.profileId,
            targetDisplayName: widget.contextDisplayName,
            consequence: widget.consequence,
            buttonKey: widget.blockingKey,
            onChanged: (blocked) async {
              _reload();
              await widget.onChanged?.call(blocked);
            },
          ),
        ],
      ],
    );
  }
}
