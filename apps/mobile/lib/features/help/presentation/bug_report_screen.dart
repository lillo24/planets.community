import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import 'help_screen.dart';
import 'support_mail_action.dart';

class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _steps = TextEditingController();
  final _expected = TextEditingController();
  final _scroll = ScrollController();
  bool _reviewing = false;
  bool? _copied;
  int _generation = 0;

  @override
  void dispose() {
    _description.dispose();
    _steps.dispose();
    _expected.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clear() {
    _generation++;
    _description.clear();
    _steps.clear();
    _expected.clear();
    _showStart();
    setState(() {
      _reviewing = false;
      _copied = null;
    });
  }

  void _showStart() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _body(AppLocalizations l10n) => [
    '${l10n.helpBugDescription}:\n${_description.text.trim()}',
    if (_steps.text.trim().isNotEmpty)
      '${l10n.helpBugSteps}:\n${_steps.text.trim()}',
    if (_expected.text.trim().isNotEmpty)
      '${l10n.helpBugExpected}:\n${_expected.text.trim()}',
  ].join('\n\n');

  Future<void> _copy(String body) async {
    final generation = _generation;
    bool copied;
    try {
      await Clipboard.setData(ClipboardData(text: body));
      copied = true;
    } on Exception {
      copied = false;
    }
    if (!mounted || generation != _generation) return;
    setState(() => _copied = copied);
  }

  @override
  Widget build(BuildContext context) {
    // A draft belongs only to this mounted screen and this session. Token refresh
    // keeps the same owner; account replacement/sign-out/readiness changes clear it.
    ref.listen(
      authSessionProvider.select(
        (session) => (session.identity?.id, session.phase),
      ),
      (previous, next) {
        if (previous != next) _clear();
      },
    );
    final l10n = AppLocalizations.of(context);
    final body = _body(l10n);
    return HelpScaffold(
      key: const Key('help-bug-screen'),
      title: l10n.helpReportBug,
      scrollController: _scroll,
      children: [
        Text(l10n.helpBugExplanation),
        const SizedBox(height: AppSpacing.medium),
        if (!_reviewing)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('help-bug-description'),
                  controller: _description,
                  decoration: InputDecoration(
                    labelText: l10n.helpBugDescription,
                  ),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.helpBugRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  key: const Key('help-bug-steps'),
                  controller: _steps,
                  decoration: InputDecoration(labelText: l10n.helpBugSteps),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                ),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  key: const Key('help-bug-expected'),
                  controller: _expected,
                  decoration: InputDecoration(labelText: l10n.helpBugExpected),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                ),
                const SizedBox(height: AppSpacing.medium),
                FilledButton(
                  key: const Key('help-bug-review'),
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    FocusScope.of(context).unfocus();
                    _showStart();
                    setState(() => _reviewing = true);
                  },
                  child: Text(l10n.helpBugReview),
                ),
              ],
            ),
          )
        else ...[
          Text(
            l10n.helpBugReview,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.small),
          SelectableText(body, key: const Key('help-bug-draft')),
          const SizedBox(height: AppSpacing.medium),
          OutlinedButton(
            key: const Key('help-bug-edit'),
            onPressed: () => setState(() {
              _generation++;
              _showStart();
              _reviewing = false;
              _copied = null;
            }),
            child: Text(l10n.helpBugEdit),
          ),
          OutlinedButton.icon(
            key: const Key('help-bug-copy'),
            onPressed: () => _copy(body),
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.helpBugCopy),
          ),
          if (_copied != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _copied! ? l10n.helpBugCopied : l10n.helpBugCopyFailed,
              ),
            ),
          const SizedBox(height: AppSpacing.medium),
          SupportMailAction(
            key: ValueKey((_generation, body)),
            subject: l10n.helpBugSubject,
            body: body,
          ),
        ],
      ],
    );
  }
}
