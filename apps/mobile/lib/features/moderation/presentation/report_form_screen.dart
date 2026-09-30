import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/moderation_controllers.dart';
import '../domain/moderation_models.dart';

class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({required this.target, super.key});

  final ModerationReportTarget target;

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _explanation = TextEditingController();
  ModerationCategory? _category;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(moderationSubmissionProvider.notifier).begin(widget.target);
    });
  }

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      setState(() {});
      return;
    }
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    await ref
        .read(moderationSubmissionProvider.notifier)
        .submit(
          expectedProfileId: profileId,
          target: widget.target,
          category: _category!,
          explanation: _explanation.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submission = ref.watch(moderationSubmissionProvider);
    final isCurrent = submission.targetScope == widget.target.submissionScope;
    final received =
        isCurrent && submission.phase == ModerationSubmissionPhase.received;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationReportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            Text(
              widget.target.label,
              key: const Key('moderation-target-label'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.medium),
            if (received)
              _ReceivedState(target: widget.target)
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<ModerationCategory>(
                      key: const Key('moderation-category'),
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: l10n.moderationCategoryLabel,
                      ),
                      items: [
                        for (final category in ModerationCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(_categoryLabel(l10n, category)),
                          ),
                      ],
                      onChanged: submission.isSubmitting
                          ? null
                          : (value) => setState(() => _category = value),
                      validator: (value) => value == null
                          ? l10n.moderationCategoryRequired
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    TextFormField(
                      key: const Key('moderation-explanation'),
                      controller: _explanation,
                      enabled: !submission.isSubmitting,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: moderationExplanationMaxLength,
                      decoration: InputDecoration(
                        labelText: l10n.moderationExplanationLabel,
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          isValidModerationExplanation(value ?? '')
                          ? null
                          : l10n.moderationExplanationInvalid,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      widget.target.hasProjectContext
                          ? l10n.moderationGroupDisclosure
                          : l10n.moderationStandardDisclosure,
                      key: Key(
                        widget.target.hasProjectContext
                            ? 'moderation-group-disclosure'
                            : 'moderation-standard-disclosure',
                      ),
                    ),
                    if (isCurrent &&
                        submission.phase ==
                            ModerationSubmissionPhase.failure) ...[
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        l10n.moderationSubmitError,
                        key: const Key('moderation-submit-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    FilledButton(
                      key: const Key('moderation-submit'),
                      onPressed: submission.isSubmitting ? null : _submit,
                      child: submission.isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.moderationSubmitAction),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedState extends StatelessWidget {
  const _ReceivedState({required this.target});

  final ModerationReportTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const Key('moderation-received'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            l10n.moderationReceivedTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(l10n.moderationReceivedDescription, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

String _categoryLabel(AppLocalizations l10n, ModerationCategory category) =>
    switch (category) {
      ModerationCategory.safetyConcern => l10n.moderationCategorySafety,
      ModerationCategory.harassmentAbuse => l10n.moderationCategoryHarassment,
      ModerationCategory.fraudScam => l10n.moderationCategoryFraud,
      ModerationCategory.inappropriateContentConduct =>
        l10n.moderationCategoryInappropriate,
      ModerationCategory.spam => l10n.moderationCategorySpam,
      ModerationCategory.other => l10n.moderationCategoryOther,
    };
