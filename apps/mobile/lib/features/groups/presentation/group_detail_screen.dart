import '../../group_projects/presentation/group_project_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../group_membership/presentation/group_participation_section.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/report_form_screen.dart';
import '../data/group_gateway.dart';
import '../domain/group_models.dart';
import 'group_widgets.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.id, this.report = false, super.key});
  final String id;
  final bool report;
  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late Future<PublicGroup?> detail;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    detail = ref.read(groupGatewayProvider).publicDetail(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final current = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    return FutureBuilder(
      future: detail,
      builder: (context, snapshot) {
        if (widget.report && snapshot.hasData && current != null) {
          return ReportFormScreen(
            target: ModerationReportTarget(
              kind: ModerationTargetKind.group,
              id: widget.id,
              label: snapshot.data!.content.name,
            ),
            onClose: () => closeGroups(context, '/groups/${widget.id}'),
          );
        }
        return Scaffold(
          appBar: groupAppBar(context, l.groupsTitle),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          GroupLoadError(
                            error: snapshot.error,
                            retry: () => setState(load),
                          ),
                          GroupParticipationSection(
                            groupId: widget.id,
                            publicAvailable: false,
                          ),
                        ],
                      )
                    : snapshot.data == null
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(l.groupsUnavailable),
                          const SizedBox(height: 16),
                          GroupParticipationSection(
                            groupId: widget.id,
                            publicAvailable: false,
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          GroupSummary(snapshot.data!, full: true),
                          const SizedBox(height: 24),
                          Text(l.groupsDeclaration),
                          GroupProjectFeed(groupId: widget.id),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            key: const Key('group-report'),
                            onPressed: () =>
                                context.push('/groups/${widget.id}/report'),
                            icon: const Icon(Icons.flag_outlined),
                            label: Text(l.groupsReport),
                          ),
                          GroupParticipationSection(
                            groupId: widget.id,
                            publicAvailable: true,
                            onChanged: () => setState(load),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
