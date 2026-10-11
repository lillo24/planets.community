import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../messages/domain/message_chat_models.dart';
import '../../messages/presentation/message_example_preview.dart';
import '../../messages/presentation/messages_navigation.dart';

/// Public, fictional presentation. Scope is local to this page: no real
/// Messages state, identity, gateway or private content loaders are mounted.
class MessagesPreviewScreen extends StatefulWidget {
  const MessagesPreviewScreen({super.key});

  @override
  State<MessagesPreviewScreen> createState() => _MessagesPreviewScreenState();
}

class _MessagesPreviewScreenState extends State<MessagesPreviewScreen> {
  var _scope = MessageChatScope.private;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.settingsMessagesPreview)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Text(
                  l10n.settingsMessagesPreviewNotice,
                  key: const Key('settings-messages-preview-notice'),
                ),
                MessageChatScopeToggle(
                  scope: _scope,
                  onChanged: (scope) => setState(() => _scope = scope),
                ),
                const SizedBox(height: AppSpacing.medium),
                MessageExamplePreview(scope: _scope),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
