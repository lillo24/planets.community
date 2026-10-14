import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/discussion_links_gateway.dart';
import '../domain/discussion_links.dart';
import '../domain/discussion_models.dart';
import 'discussion_controllers.dart';

/// The collection owns its scope without fetching a transcript or Project data.
class DiscussionLinksController extends ChangeNotifier {
  DiscussionLinksController(
    this.gateway,
    this.actor,
    this.room,
    this.authorized,
  ) {
    pager = DiscussionPager<DiscussionLink>((cursor) async {
      final revision = pager.revision;
      final page = await gateway.page(actor, room, admission, cursor);
      if (!disposed && authorized() && revision == pager.revision) {
        admission = page.admissionId;
        canManage = page.canManage;
        archived = page.archived;
        scopeEnded = false;
      }
      return page.items;
    }, authorized);
    pager.addListener(changed);
  }
  final DiscussionLinksGateway gateway;
  final String actor, room;
  final bool Function() authorized;
  late final DiscussionPager<DiscussionLink> pager;
  String? admission;
  bool canManage = false,
      archived = false,
      disposed = false,
      scopeEnded = false;
  int epoch = 0;
  void changed() {
    if (pager.error != null &&
        discussionFailure(pager.error!) == DiscussionFailure.denied &&
        !scopeEnded) {
      epoch++;
      scopeEnded = true;
      admission = null;
      canManage = false;
    }
    if (!disposed) notifyListeners();
  }

  bool current(String expectedAdmission, int expectedEpoch) =>
      !disposed &&
      !scopeEnded &&
      authorized() &&
      admission == expectedAdmission &&
      epoch == expectedEpoch;
  @override
  void dispose() {
    disposed = true;
    epoch++;
    admission = null;
    pager.removeListener(changed);
    pager.dispose();
    super.dispose();
  }
}

final discussionLinksProvider = Provider.autoDispose
    .family<DiscussionLinksController?, String>((ref, room) {
      final session = ref.watch(authSessionProvider),
          actor = session.phase == AuthSessionPhase.ready
              ? session.identity?.id
              : null;
      if (actor == null) return null;
      final c = DiscussionLinksController(
        ref.read(discussionLinksGatewayProvider),
        actor,
        room,
        () =>
            ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
            ref.read(authSessionProvider).identity?.id == actor,
      );
      void clearDenied() {
        if (c.scopeEnded) ref.read(discussionCommandsProvider).clearRoom(room);
      }

      c.addListener(clearDenied);
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) c.pager.invalidate();
      });
      ref.onDispose(() {
        c.removeListener(clearDenied);
        c.dispose();
      });
      return c;
    });
