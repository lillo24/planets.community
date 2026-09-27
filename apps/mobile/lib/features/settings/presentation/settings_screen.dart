import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/language_preference_controller.dart';
import '../domain/language_preference.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(languagePreferenceProvider);
    final session = ref.watch(authSessionProvider);
    final showAccountSettings = session.phase == AuthSessionPhase.ready;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_preferenceLabel(l10n, preference)),
                        const SizedBox(width: AppSpacing.small),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/settings/language'),
                  ),
                ),
                if (showAccountSettings) ...[
                  const SizedBox(height: AppSpacing.large),
                  _SectionLabel(l10n.settingsAccountSection),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          key: const Key('settings-notifications-row'),
                          leading: const Icon(Icons.notifications_outlined),
                          title: Text(l10n.notificationsTitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/notifications/preferences'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          key: const Key('settings-profile-privacy-row'),
                          leading: const Icon(Icons.manage_accounts_outlined),
                          title: Text(l10n.settingsProfilePrivacy),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                            Uri(
                              path: '/profile/edit',
                              queryParameters: const {'returnTo': '/settings'},
                            ).toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
      appBar: AppBar(title: Text(l10n.settingsLanguage)),
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
