import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../external_activities/domain/external_activity.dart';
import '../data/co_creation_events_gateway.dart';
import 'people_manage_screen.dart';
import 'people_widgets.dart';

class CoEventComposerScreen extends ConsumerStatefulWidget {
  const CoEventComposerScreen({required this.activityId, super.key});
  final String activityId;
  @override
  ConsumerState<CoEventComposerScreen> createState() => _EventComposerState();
}

class _EventComposerState extends ConsumerState<CoEventComposerScreen> {
  late Future<ExternalActivity?> request;
  @override
  void initState() {
    super.initState();
    request = ref
        .read(coCreationEventsGatewayProvider)
        .context(widget.activityId);
  }

  @override
  void didUpdateWidget(CoEventComposerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId) {
      request = ref
          .read(coCreationEventsGatewayProvider)
          .context(widget.activityId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<ExternalActivity?>(
      future: request,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.done &&
            s.hasData &&
            s.data!.id == widget.activityId) {
          return PeopleComposerScreen(key: ValueKey(s.data!.id), event: s.data);
        }
        return PeoplePage(
          title: l.coEventFindPeople,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else
                Text(s.hasError ? l.coPeopleError : l.coEventDraftUnavailable),
              TextButton(
                onPressed: () => setState(
                  () => request = ref
                      .read(coCreationEventsGatewayProvider)
                      .context(widget.activityId),
                ),
                child: Text(l.coPeopleRefresh),
              ),
            ],
          ),
        );
      },
    );
  }
}
