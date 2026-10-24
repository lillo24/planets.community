import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../proposals/data/proposal_gateway.dart';

/// Resolve only a current canonical public title. Never retain a message-time
/// snapshot or consult an owner/private reader, including for the sender.
class CoSharedProjectCard extends ConsumerStatefulWidget {
  const CoSharedProjectCard({
    required this.projectId,
    required this.revision,
    super.key,
  });
  final String projectId;
  final int revision;

  @override
  ConsumerState<CoSharedProjectCard> createState() =>
      _CoSharedProjectCardState();
}

class _CoSharedProjectCardState extends ConsumerState<CoSharedProjectCard> {
  String? title;
  bool loading = true, failed = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(load);
  }

  @override
  void didUpdateWidget(CoSharedProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.revision != widget.revision) {
      generation++;
      title = null;
      loading = true;
      Future<void>.microtask(load);
    }
  }

  Future<bool> load() async {
    if (!mounted) return false;
    final request = ++generation;
    final actor = ref.read(authSessionProvider).identity?.id;
    final id = widget.projectId;
    setState(() {
      title = null;
      loading = true;
      failed = false;
    });
    try {
      final detail = await ref
          .read(proposalGatewayProvider)
          .getPublicProposal(id);
      if (!mounted ||
          request != generation ||
          actor != ref.read(authSessionProvider).identity?.id ||
          id != widget.projectId) {
        return false;
      }
      if (detail != null && detail.summary.id != id) {
        throw const FormatException('Shared Project identity differs.');
      }
      setState(() {
        title = detail?.summary.title;
        loading = false;
      });
      return detail != null;
    } catch (_) {
      // Explicit preview UI boundary: failure has a visible retry and discards
      // prior content. An unavailable public result is a separate domain state.
      if (mounted &&
          request == generation &&
          actor == ref.read(authSessionProvider).identity?.id) {
        setState(() {
          title = null;
          loading = false;
          failed = true;
        });
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      generation++;
      setState(() {
        title = null;
        loading = true;
      });
      Future<void>.microtask(load);
    });
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        key: Key('co-shared-project-${widget.projectId}'),
        leading: const Icon(Icons.event_outlined),
        title: Text(
          loading
              ? l.coShareProjectLoading
              : failed
              ? l.coPeopleError
              : title ?? l.coShareProjectUnavailable,
        ),
        subtitle: title == null ? null : Text(l.coShareProjectOpen),
        trailing: loading
            ? null
            : title == null
            ? IconButton(
                tooltip: l.coPeopleRefresh,
                onPressed: load,
                icon: const Icon(Icons.refresh),
              )
            : const Icon(Icons.chevron_right),
        onTap: loading || title == null
            ? null
            : () async {
                final id = widget.projectId;
                // Revalidate on explicit open, then let native detail/participation
                // perform their own current canonical reads and authorization.
                if (await load() &&
                    context.mounted &&
                    widget.projectId == id &&
                    (ModalRoute.of(context)?.isCurrent ?? false)) {
                  await context.push('/proposals/$id');
                }
              },
      ),
    );
  }
}
