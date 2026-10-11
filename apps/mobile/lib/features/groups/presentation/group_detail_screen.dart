import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
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
  Future<bool>? manager;
  String? actor;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    detail = ref.read(groupGatewayProvider).publicDetail(widget.id);
    manager = null;
    actor = null;
  }

  Future<bool> checkManager(String id) async {
    try {
      await ref.read(groupGatewayProvider).ownDetail(id, widget.id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '42501') return false;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final current = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    if (actor != current) {
      actor = current;
      manager = current == null ? null : checkManager(current);
    }
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
                    ? GroupLoadError(
                        error: snapshot.error,
                        retry: () => setState(load),
                      )
                    : snapshot.data == null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.groupsUnavailable),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          GroupSummary(snapshot.data!, full: true),
                          const SizedBox(height: 24),
                          Text(l.groupsDeclaration),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            key: const Key('group-report'),
                            onPressed: () =>
                                context.push('/groups/${widget.id}/report'),
                            icon: const Icon(Icons.flag_outlined),
                            label: Text(l.groupsReport),
                          ),
                          if (manager != null)
                            FutureBuilder(
                              future: manager,
                              builder: (context, access) {
                                if (actor != current ||
                                    access.connectionState !=
                                        ConnectionState.done ||
                                    ref
                                            .read(authSessionProvider)
                                            .identity
                                            ?.id !=
                                        current) {
                                  return const SizedBox.shrink();
                                }
                                if (access.hasError) {
                                  return Text(l.groupsManageError);
                                }
                                return access.data == true
                                    ? TextButton(
                                        key: const Key('group-manage'),
                                        onPressed: () async {
                                          await context.push(
                                            '/groups/${widget.id}/edit',
                                          );
                                          if (mounted) setState(load);
                                        },
                                        child: Text(l.groupsEdit),
                                      )
                                    : const SizedBox.shrink();
                              },
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
