import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../app/startup/startup_flow.dart';
import '../../blocking/presentation/blocking_routes.dart';
import '../../profile/presentation/profile_visibility_screen.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/account_sign_out_action.dart';
import '../../policies/application/policy_documents.dart';
import '../../policies/presentation/policy_link_action.dart';
import 'activities_split_setting.dart';
import 'co_creation_setting.dart';
import '../../mock_mode/presentation/mock_mode_setting.dart';
import '../application/language_preference_controller.dart';
import '../application/navigation_preference_controller.dart';
import '../domain/language_preference.dart';
import '../domain/navigation_preference.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(languagePreferenceProvider);
    final navigationPreference = ref.watch(navigationPreferenceProvider);
    final session = ref.watch(authSessionProvider);
    final showAccountSettings = session.phase == AuthSessionPhase.ready;

    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: ListTileTheme.merge(
              minLeadingWidth: 24,
              horizontalTitleGap: AppSpacing.small,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.small,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  _SectionLabel(l10n.settingsAppSection),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: const Key('settings-language-row'),
                      leading: const Icon(Icons.translate),
                      title: Text(l10n.settingsLanguage),
                      subtitle: Text(_preferenceLabel(l10n, preference)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/language'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _SectionLabel(l10n.settingsAccountSection),
                  Card(
                    child: PolicyLinkAction(
                      key: const Key('settings-privacy-policy-row'),
                      asTile: true,
                      label: l10n.policyPrivacy,
                      uri: ref.watch(policyDocumentsProvider).privacy,
                    ),
                  ),
                  if (showAccountSettings)
                    Card(
                      child: ListTile(
                        key: const Key('settings-profile-privacy-row'),
                        leading: const Icon(Icons.visibility_outlined),
                        title: Text(l10n.settingsProfilePrivacy),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(profileVisibilityPath),
                      ),
                    ),
                  if (showAccountSettings)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: const Key('settings-notifications-row'),
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(l10n.notificationsTitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/notifications/preferences'),
                      ),
                    ),
                  if (showAccountSettings)
                    Card(
                      child: ListTile(
                        key: const Key('settings-reports-row'),
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(l10n.moderationOwnReportsAction),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(ModerationRoutes.ownReports),
                      ),
                    ),
                  if (showAccountSettings)
                    Card(
                      child: ListTile(
                        key: const Key('settings-blocked-users-row'),
                        leading: const Icon(Icons.person_off_outlined),
                        title: Text(l10n.blockingBlockedUsersAction),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(BlockingRoutes.blockedUsers),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.large),
                  _SectionLabel(l10n.settingsSandbox),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: const Key('settings-navigation-row'),
                      leading: const Icon(Icons.navigation_outlined),
                      title: Text(l10n.settingsBottomRightTab),
                      subtitle: Text(
                        navigationPreference.restoreFailed
                            ? l10n.settingsNavigationRestoreError
                            : l10n.settingsPersistentTab(
                                navigationPreference.destination ==
                                        BottomTabDestination.messages
                                    ? l10n.messagesTitle
                                    : l10n.navigationBrowse,
                              ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/navigation'),
                    ),
                  ),
                  const ActivitiesSplitSetting(),
                  const CoCreationSetting(),
                  const MockModeSetting(),
                  if (kDebugMode)
                    TextButton(
                      key: const Key('startup-development-reset'),
                      onPressed: () async {
                        final reset = await ref
                            .read(startupFlowProvider)
                            .resetForDevelopment();
                        if (!context.mounted) return;
                        if (reset) {
                          context.go('/');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.startupPreferenceError),
                            ),
                          );
                        }
                      },
                      child: Text(l10n.startupDevelopmentReset),
                    ),
                  if (session.isAuthenticated) ...[
                    const SizedBox(height: AppSpacing.large),
                    const Divider(),
                    const SizedBox(height: AppSpacing.medium),
                    const AccountSignOutAction(),
                    const SizedBox(height: AppSpacing.medium),
                    const Divider(),
                    ListTile(
                      key: const Key('settings-delete-account-row'),
                      leading: const Icon(Icons.person_remove_outlined),
                      title: Text(l10n.policyDeleteAccount),
                      onTap: () => context.push(accountDeletionPath),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.small,
      0,
      AppSpacing.small,
      AppSpacing.xSmall,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

String _preferenceLabel(AppLocalizations l10n, LanguagePreference preference) =>
    switch (preference) {
      LanguagePreference.system => l10n.settingsLanguageSystem,
      LanguagePreference.english => l10n.settingsLanguageEnglish,
      LanguagePreference.italian => l10n.settingsLanguageItalian,
    };

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  var _isSaving = false;

  Future<void> _select(LanguagePreference preference) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final saved = await ref
        .read(languagePreferenceProvider.notifier)
        .select(preference);
    if (!mounted) return;
    if (saved) {
      context.pop();
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).settingsLanguageSaveError),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(languagePreferenceProvider);

    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.settingsLanguage)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: RadioGroup<LanguagePreference>(
              groupValue: preference,
              onChanged: (value) {
                if (value != null) {
                  _select(value);
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  RadioListTile<LanguagePreference>(
                    key: const Key('language-system-option'),
                    value: LanguagePreference.system,
                    title: Text(l10n.settingsLanguageSystem),
                    enabled: !_isSaving,
                  ),
                  RadioListTile<LanguagePreference>(
                    key: const Key('language-italian-option'),
                    value: LanguagePreference.italian,
                    title: Text(l10n.settingsLanguageItalian),
                    enabled: !_isSaving,
                  ),
                  RadioListTile<LanguagePreference>(
                    key: const Key('language-english-option'),
                    value: LanguagePreference.english,
                    title: Text(l10n.settingsLanguageEnglish),
                    enabled: !_isSaving,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
