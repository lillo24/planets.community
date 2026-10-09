import 'package:flutter/material.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'participation_request_details.dart';

class ParticipationRequestMessageScreen extends StatelessWidget {
  const ParticipationRequestMessageScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: pageAppBar(
      context,
      title: Text(AppLocalizations.of(context).messagesRequestDetailTitle),
    ),
    body: SafeArea(
      child: ParticipationRequestDetailsContent(requestId: requestId),
    ),
  );
}
