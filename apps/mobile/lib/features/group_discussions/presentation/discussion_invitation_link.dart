import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/discussion_controllers.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';

String discussionInvitationLink(String token) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
    throw const FormatException('Invalid Idea capability.');
  }
  return 'https://planets.community/messages/discussions/invite/$token';
}

class DiscussionInvitationLinkControls extends ConsumerStatefulWidget {
  const DiscussionInvitationLinkControls({
    required this.room,
    required this.actor,
    required this.onChanged,
    super.key,
  });
  final DiscussionRoom room;
  final String actor;
  final Future<void> Function() onChanged;
  @override
  ConsumerState<DiscussionInvitationLinkControls> createState() =>
      _DiscussionInvitationLinkControlsState();
}

class _DiscussionInvitationLinkControlsState
    extends ConsumerState<DiscussionInvitationLinkControls> {
  String? key, operation, token;
  int? version;
  bool busy = false, uncertain = false;
  Object? error;
  Future<void> run(String action) async {
    if (busy || ref.read(authSessionProvider).identity?.id != widget.actor) {
      return;
    }
    if (key == null) {
      key = const Uuid().v4();
      operation = action;
      version = widget.room.invitationLinkVersion;
    }
    if (!await requireGroupPolicy(context, ref, widget.actor) ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != widget.actor) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(supabaseClientProvider)
          .rpc<Object?>(
            operation == 'create'
                ? 'create_group_discussion_invitation_link'
                : 'revoke_group_discussion_invitation_link',
            params: {
              'p_expected_profile_id': widget.actor,
              'p_client_request_id': key,
              'p_room_id': widget.room.id,
              'p_expected_version': version,
            },
          );
      final row = discussionObject(result, {
        'room_id',
        'object_id',
        'version',
        'sequence',
        'invitation_link_version',
        'token',
        'expires_at',
      });
      if (row['room_id'] != widget.room.id) {
        throw const FormatException('Mismatched Idea invitation.');
      }
      final value = row['token'] as String?;
      if (value != null) discussionInvitationLink(value);
      if (!mounted ||
          ref.read(authSessionProvider).identity?.id != widget.actor) {
        return;
      }
      setState(() {
        token = value;
        key = null;
        operation = null;
        version = null;
        uncertain = false;
      });
      await widget.onChanged();
    } catch (failure) {
      if (mounted && ref.read(authSessionProvider).identity?.id == widget.actor) {
        setState(() {
          error = failure;
          uncertain =
              discussionFailure(failure) == DiscussionFailure.unavailable ||
              failure is FormatException;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, _) {
      token = null;
      key = null;
      operation = null;
    });
    return PopScope(
      canPop: !busy && !uncertain,
      child: ExpansionTile(
        title: Text(l.discussionInviteLink),
        children: [
          Text(l.discussionInviteLinkHelp),
          if (error != null) DiscussionError(error!),
          if (uncertain) Text(l.discussionUncertain),
          Wrap(
            spacing: 8,
            children: [
              if (key != null)
                TextButton(
                  onPressed: busy ? null : () => run(operation!),
                  child: Text(l.discussionRetry),
                )
              else if (widget.room.canManage && !widget.room.frozen) ...[
                TextButton(
                  onPressed: busy ? null : () => run('create'),
                  child: Text(l.discussionLinkRotate),
                ),
                TextButton(
                  onPressed: busy ? null : () => run('revoke'),
                  child: Text(l.discussionLinkRevoke),
                ),
              ],
              if (token != null)
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: discussionInvitationLink(token!)),
                  ),
                  icon: const Icon(Icons.copy),
                  label: Text(l.discussionLinkCopy),
                ),
              if (key != null && !busy && !uncertain)
                TextButton(
                  onPressed: () => setState(() {
                    key = null;
                    operation = null;
                    error = null;
                  }),
                  child: Text(l.discussionCancel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class DiscussionInvitationLinkScreen extends ConsumerStatefulWidget {
  const DiscussionInvitationLinkScreen({required this.token, super.key});
  final String token;
  @override
  ConsumerState<DiscussionInvitationLinkScreen> createState() =>
      _DiscussionInvitationLinkScreenState();
}

class _DiscussionInvitationLinkScreenState
    extends ConsumerState<DiscussionInvitationLinkScreen> {
  DiscussionRoom? room;
  String? actor, command;
  Object? error;
  bool busy = false, uncertain = false;
  int epoch = 0;
  Future<void> load(String id) async {
    actor = id;
    final current = ++epoch;
    try {
      discussionInvitationLink(widget.token);
      final result = await ref
          .read(supabaseClientProvider)
          .rpc<Object?>(
            'preview_group_discussion_invitation_link',
            params: {'p_expected_profile_id': id, 'p_token': widget.token},
          );
      if (result is! Map || !result.containsKey('expires_at')) {
        throw const FormatException('Invalid Idea capability preview.');
      }
      final preview = Map<String, dynamic>.from(result)..remove('expires_at');
      final row = DiscussionRoom(preview);
      if (mounted &&
          epoch == current &&
          ref.read(authSessionProvider).identity?.id == id) {
        setState(() {
          room = row;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted && epoch == current) {
        setState(() {
          room = null;
          error = failure;
        });
      }
    }
  }

  Future<void> accept() async {
    final id = actor;
    if (id == null || busy || room == null) return;
    if (!await requireGroupPolicy(context, ref, id) ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != id) {
      return;
    }
    command ??= const Uuid().v4();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = DiscussionReceipt(
        await ref
            .read(supabaseClientProvider)
            .rpc<Object?>(
              'accept_group_discussion_invitation_link',
              params: {
                'p_expected_profile_id': id,
                'p_client_request_id': command,
                'p_token': widget.token,
              },
            ),
      );
      if (!mounted || ref.read(authSessionProvider).identity?.id != id) return;
      ref.read(discussionGroupsProvider)?.invalidate();
      setState(() {
        uncertain = false;
        command = null;
      });
      context.pushReplacement(discussionRoute(result.roomId));
    } catch (failure) {
      if (mounted && ref.read(authSessionProvider).identity?.id == id) {
        setState(() {
          error = failure;
          uncertain =
              discussionFailure(failure) == DiscussionFailure.unavailable ||
              failure is FormatException;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(authSessionProvider).identity?.id,
        l = AppLocalizations.of(context);
    if (id != actor) {
      epoch++;
      room = null;
      command = null;
      uncertain = false;
      actor = id;
      if (id != null) Future.microtask(() => load(id));
    }
    return PopScope(
      canPop: !busy && !uncertain,
      child: Scaffold(
        appBar: groupAppBar(
          context,
          l.discussionInviteLink,
          fallback: '/messages',
        ),
        body: GroupBody(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (room == null && error == null)
                const LinearProgressIndicator(),
              if (error != null)
                DiscussionError(
                  error!,
                  retry: () => command == null ? load(id!) : accept(),
                ),
              if (room != null) ...[
                Text(
                  room!.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(room!.groupName),
                Text(room!.purpose),
                Text(l.discussionConsent),
                Text(l.discussionInviteLinkHelp),
                FilledButton(
                  onPressed: busy ? null : accept,
                  child: Text(
                    uncertain ? l.discussionRetry : l.discussionAccept,
                  ),
                ),
              ],
              if (!busy && !uncertain)
                TextButton(
                  onPressed: () => closeGroups(context, '/messages'),
                  child: Text(l.discussionCancel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
