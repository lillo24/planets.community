import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../application/people_signals.dart';
import '../data/people_posts_gateway.dart';
import '../data/people_private_gateway.dart';
import '../domain/people_post.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_private.dart';
import 'people_widgets.dart';

const _idPattern =
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
bool isPeopleOwnExitPath(String path) =>
    RegExp('^/messages/cocreate/contacts/$_idPattern/close\$').hasMatch(path) ||
    RegExp(
      '^/messages/cocreate/posts/$_idPattern/interests/$_idPattern/withdraw\$',
    ).hasMatch(path);

class PeopleContactCloseScreen extends StatelessWidget {
  const PeopleContactCloseScreen({required this.contactId, super.key});
  final String contactId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPeopleClose,
      child: PeopleAccess(
        requirePolicy: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PeopleCommand(
            slot: 'contact/$contactId/close',
            rpc: 'mutate_cocreate_contact',
            intent: {'p_operation': 'close', 'p_contact_id': contactId},
            label: l.coPeopleClose,
            onSuccess: (_) async {
              context.go('/messages');
            },
          ),
        ),
      ),
    );
  }
}

final _available = FutureProvider.autoDispose<bool>((ref) {
  ref.watch(authSessionProvider.select((s) => (s.identity?.id, s.phase)));
  ref.listen(peopleSignalsProvider, (_, _) => ref.invalidateSelf());
  return ref.watch(peoplePostsGatewayProvider).available();
});

class PeopleContactExit {
  PeopleContactExit(Object? value, {bool interest = false}) {
    final row = coCreationObject(
      value,
      interest
          ? {'interest_id', 'post_id', 'created_at'}
          : {'contact_id', 'created_at'},
    );
    id = peopleUuid(row[interest ? 'interest_id' : 'contact_id']);
    postId = interest ? PostId.parse(row['post_id']) : null;
    createdAt = coCreationDate(row['created_at']);
  }
  late final String id;
  late final PostId? postId;
  late final DateTime createdAt;
}

/// Identity-only recovery, even with the experiment OFF or policy out of date.
/// Its reader exposes only the actor's open anchors, no source titles/bodies.
class PeopleContactExits extends ConsumerWidget {
  const PeopleContactExits({this.interest = false, super.key});
  final bool interest;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        session = ref.watch(authSessionProvider);
    final accepted = ref
        .watch(policyAcceptanceProvider)
        .allows(session.identity?.id, ref.watch(policyVersionProvider));
    if (accepted && ref.watch(_available).asData?.value == true) {
      return const SizedBox.shrink();
    }
    return PeopleAccess(
      requirePolicy: false,
      child: PeopleList<PeopleContactExit>(
        availabilityRequired: false,
        emptyVisible: false,
        load: (ref, actor, before) async {
          final raw = await ref.read(peoplePrivateGatewayProvider).rpc(
            interest
                ? 'list_own_cocreate_interest_exits'
                : 'list_own_cocreate_contact_exits',
            {
              'p_expected_profile_id': actor,
              'p_limit': 25,
              'p_before_created_at': before?.createdAt
                  .toUtc()
                  .toIso8601String(),
              'p_before_id': before?.id,
            },
          );
          if (raw is! List || raw.length > 25) {
            throw const FormatException('Invalid exit projection.');
          }
          final rows = raw
                  .map((r) => PeopleContactExit(r, interest: interest))
                  .toList(growable: false),
              ids = <String>{};
          DateTime? time = before?.createdAt;
          String? id = before?.id;
          for (final row in rows) {
            if (!ids.add(row.id) ||
                (time != null &&
                    (row.createdAt.isAfter(time) ||
                        (row.createdAt.isAtSameMomentAs(time) &&
                            row.id.compareTo(id!) >= 0)))) {
              throw const FormatException('Invalid exit order.');
            }
            time = row.createdAt;
            id = row.id;
          }
          return rows;
        },
        row: (context, row, refresh) => ListTile(
          title: Text(interest ? l.coPeopleRequests : l.coPeopleChat),
          subtitle: Text(interest ? l.coPeopleWithdraw : l.coPeopleClose),
          onTap: () => context.push(
            interest
                ? '/messages/cocreate/posts/${row.postId!.value}/interests/${row.id}/withdraw'
                : '/messages/cocreate/contacts/${row.id}/close',
          ),
        ),
      ),
    );
  }
}

class PeopleInterestWithdrawScreen extends StatelessWidget {
  const PeopleInterestWithdrawScreen({
    required this.postId,
    required this.interestId,
    super.key,
  });
  final PostId postId;
  final String interestId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPeopleWithdraw,
      child: PeopleAccess(
        requirePolicy: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PeopleCommand(
            slot: 'interest/${postId.value}',
            rpc: 'mutate_cocreate_interest',
            intent: {
              'p_operation': 'withdraw',
              'p_post_id': postId.value,
              'p_interest_id': interestId,
            },
            label: l.coPeopleWithdraw,
            onSuccess: (_) async {
              context.go('/messages');
            },
          ),
        ),
      ),
    );
  }
}
