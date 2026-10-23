import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../settings/application/co_creation_preference_controller.dart';
import '../application/people_signals.dart';
import '../data/co_creation_calendar_gateway.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../data/people_posts_gateway.dart';
import '../domain/co_creation_calendar.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import 'co_creation_calendar_month.dart';
import 'co_creation_meeting_screen.dart';
import 'people_widgets.dart';

class CoCreationCalendarScreen extends ConsumerWidget {
  const CoCreationCalendarScreen({required this.hub, super.key});
  final HubId hub;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final enabled = ref.watch(coCreationPreferenceProvider).enabled;
    final gateway = ref.watch(coCreationRoomsGatewayProvider);
    return PeoplePage(
      title: l.coCalendarTitle,
      child: enabled
          ? PeopleAccess(
              child: _CalendarBody(
                key: ValueKey((hub.value, gateway)),
                hub: hub,
              ),
            )
          : Text(l.coPeopleBackendOff),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.hub, super.key});
  final HubId hub;
  @override
  ConsumerState<_CalendarBody> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<_CalendarBody>
    with WidgetsBindingObserver {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  List<CoCalendarMeeting> meetings = [];
  CoHubMembership? membership;
  String? cursor;
  bool busy = true, failed = false, unavailable = false;
  int revision = 0;
  // Non-private coverage intent survives invalidation; rows/cursors do not.
  int wantedRows = 25;
  (DateTime, String)? frontier;
  bool reading = false, refreshQueued = false;
  bool wasActive = false;
  double savedOffset = 0;
  Timer? timer;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (activeView) load();
    });
  }

  // Socket hints invalidate rows; they do not grant or disable canonical HTTP
  // access. Keep foreground polling usable when metadata delivery is down.
  bool get activeView =>
      mounted &&
      ModalRoute.of(context)?.isCurrent == true &&
      TickerMode.valuesOf(context).enabled &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = activeView;
    // Route/TickerMode may become current only after pop's result completes.
    // Revalidate when that foreground transition actually becomes usable.
    if (active && !wasActive) Future<void>.microtask(load);
    wasActive = active;
  }

  void rememberExtent() {
    if (meetings.isNotEmpty) {
      final last = meetings.last;
      if (frontier == null ||
          last.startsAt.isAfter(frontier!.$1) ||
          last.startsAt == frontier!.$1 &&
              last.id.compareTo(frontier!.$2) > 0) {
        frontier = (last.startsAt, last.id);
      }
      if (meetings.length > wantedRows) wantedRows = meetings.length;
      if (scroll.hasClients) savedOffset = scroll.offset;
    }
  }

  void clear({bool resetExtent = false}) {
    rememberExtent();
    revision++;
    meetings = [];
    membership = null;
    cursor = null;
    if (resetExtent) {
      wantedRows = 25;
      frontier = null;
      savedOffset = 0;
    }
  }

  @override
  void dispose() {
    revision++;
    timer?.cancel();
    scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
    } else if (mounted) {
      setState(() {
        clear();
        busy = true;
      });
    }
  }

  Future<void> load({
    bool append = false,
    bool preserveScroll = true,
    bool recoveringScope = false,
  }) async {
    if (!activeView) return;
    if (reading) {
      // Timer/detail/hint triggers share one follow-up, never restart each other.
      refreshQueued = true;
      return;
    }
    reading = true;
    rememberExtent();
    if (append) {
      final target = ((meetings.length + 24) ~/ 25 + 1) * 25;
      if (target > wantedRows) wantedRows = target;
    }
    final generation = ++revision;
    final actor = ref.read(authSessionProvider).identity?.id;
    final gateway = ref.read(coCreationRoomsGatewayProvider);
    final window = CoCalendarWindow.month(selected);
    var before = append ? cursor : null;
    var previous = append ? meetings : <CoCalendarMeeting>[];
    final oldMember = membership;
    final offset = preserveScroll ? savedOffset : 0.0;
    bool retryScope = false;
    bool current() =>
        activeView &&
        generation == revision &&
        ref.read(authSessionProvider).identity?.id == actor &&
        identical(ref.read(coCreationRoomsGatewayProvider), gateway);
    setState(() {
      busy = true;
      failed = false;
      unavailable = false;
      if (!append) {
        meetings = [];
        membership = null;
        cursor = null;
      }
    });
    try {
      final enabled = await ref.read(peoplePostsGatewayProvider).available();
      if (!current()) return;
      final member = actor == null || !enabled
          ? null
          : await gateway.membership(actor, widget.hub);
      if (!current()) return;
      if (member == null) {
        setState(() {
          clear(resetExtent: true);
          busy = false;
          unavailable = true;
        });
        return;
      }
      if (before != null &&
          (oldMember?.roomId.value != member.roomId.value ||
              oldMember?.episodeId.value != member.episodeId.value)) {
        before = null;
        previous = [];
        setState(() {
          meetings = [];
          membership = null;
          cursor = null;
        });
      }
      // At most four 25-row reads per pass. If inserts push the old frontier
      // farther away, disclose partial coverage and continue via Load more.
      for (var pageNumber = 0; pageNumber < 4; pageNumber++) {
        CoCalendarPage page;
        try {
          page = await gateway.calendar(
            actor!,
            widget.hub,
            member,
            window,
            cursor: before,
          );
        } on PostgrestException catch (error) {
          if (error.code != '22023' || before == null || recoveringScope) {
            rethrow;
          }
          // Membership scope may have changed since the preceding page. Drop
          // that signed keyset and authorize again from the beginning.
          if (!current()) return;
          setState(() => clear());
          refreshQueued = true;
          retryScope = true;
          return;
        }
        if (!current()) return;
        final ids = previous.map((m) => m.id).toSet();
        for (final row in page.meetings) {
          if (!ids.add(row.id) ||
              (previous.isNotEmpty &&
                  (row.startsAt.isBefore(previous.last.startsAt) ||
                      (row.startsAt == previous.last.startsAt &&
                          row.id.compareTo(previous.last.id) <= 0)))) {
            throw const FormatException('Calendar pagination moved; refresh.');
          }
        }
        if (page.nextCursor != null && page.nextCursor == before) {
          throw const FormatException('Calendar cursor did not advance.');
        }
        previous = [...previous, ...page.meetings];
        before = page.nextCursor;
        final last = previous.isEmpty ? null : previous.last;
        final covered =
            frontier == null ||
            last != null &&
                (last.startsAt.isAfter(frontier!.$1) ||
                    last.startsAt == frontier!.$1 &&
                        last.id.compareTo(frontier!.$2) >= 0);
        if (before == null || previous.length >= wantedRows && covered) break;
      }
      setState(() {
        meetings = previous;
        membership = member;
        cursor = before;
        busy = false;
      });
      if (!append && offset > 0) {
        // Clearing private rows during a real network read can clamp the
        // retained ListView to its short loading state. Restore after layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (current() && scroll.hasClients) {
            scroll.jumpTo(
              offset.clamp(0, scroll.position.maxScrollExtent).toDouble(),
            );
          }
        });
      }
    } catch (error) {
      // Explicit UI request boundary: failures discard protected data, preserve
      // the selected month/day and offer a fresh canonical retry.
      if (current()) {
        setState(() {
          clear(
            resetExtent: error is PostgrestException && error.code == '42501',
          );
          busy = false;
          unavailable = error is PostgrestException && error.code == '42501';
          failed = !unavailable;
        });
      }
    } finally {
      reading = false;
      if (refreshQueued) {
        refreshQueued = false;
        if (activeView) {
          Future<void>.microtask(() => load(recoveringScope: retryScope));
        }
      }
    }
  }

  void moveMonth(int offset) {
    setState(() {
      clear(resetExtent: true);
      selected = DateTime(selected.year, selected.month + offset);
    });
    load(preserveScroll: false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(peopleSignalsProvider, (_, next) {
      setState(() {
        clear();
        busy = next.asData?.value.connected == true;
        failed = !busy;
        unavailable = false;
      });
      if (busy && activeView) Future<void>.microtask(load);
    });
    final l = AppLocalizations.of(context),
        material = MaterialLocalizations.of(context);
    final day = meetings
        .where((m) => coCalendarSameDay(m.startsAt.toLocal(), selected))
        .toList();
    final upcoming = meetings.where((m) => m.state == 'scheduled').toList();
    return ListView(
      controller: scroll,
      key: PageStorageKey('co-calendar/${widget.hub.value}'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          material.formatMonthYear(selected),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: material.previousMonthTooltip,
              key: const Key('co-calendar-previous'),
              onPressed: () => moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  clear(resetExtent: true);
                  selected = DateUtils.dateOnly(DateTime.now());
                });
                load();
              },
              child: Text(l.coCalendarToday),
            ),
            IconButton(
              tooltip: material.nextMonthTooltip,
              key: const Key('co-calendar-next'),
              onPressed: () => moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        CoCalendarMonth(
          selected: selected,
          meetings: meetings,
          onSelect: (date) => setState(() => selected = date),
        ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (unavailable) ...[
          Text(l.coCalendarAccess),
          TextButton(
            onPressed: () => context.push(CoCreationRoutes.hub(widget.hub)),
            child: Text(l.coCreationHubs),
          ),
        ],
        if (failed) Text(l.coPeopleError),
        if (!busy && !failed && !unavailable) ...[
          Semantics(
            header: true,
            child: Text(
              material.formatFullDate(selected),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (day.isEmpty && cursor == null) Text(l.coCalendarDayEmpty),
          if (cursor != null) Text(l.coCalendarMoreDates),
          for (final m in day) meetingRow(m),
          if (day.isEmpty && upcoming.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l.coCalendarUpcoming,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final m in upcoming) meetingRow(m),
          ],
        ],
        if (cursor != null)
          TextButton(
            onPressed: busy ? null : () => load(append: true),
            child: Text(l.coPeopleMore),
          ),
        TextButton(
          onPressed: busy ? null : load,
          child: Text(
            failed || unavailable ? l.coPeopleRetry : l.coPeopleRefresh,
          ),
        ),
      ],
    );
  }

  Widget meetingRow(CoCalendarMeeting m) {
    final l = AppLocalizations.of(context),
        colors = Theme.of(context).colorScheme;
    final past = m.state == 'past';
    final label = m.state == 'cancelled'
        ? l.coMeetingCancelled
        : past
        ? l.coCalendarPast
        : m.attending
        ? l.coMeetingAttending
        : m.full
        ? l.coGroupsFull
        : m.available
        ? l.coCalendarAvailable
        : l.coCalendarNoRecruitment;
    final color = m.state != 'scheduled' || past || m.attending
        ? colors.onSurfaceVariant
        : m.full
        ? colors.error
        : m.available
        ? (colors.brightness == Brightness.dark
              ? const Color(0xff8cdb9e)
              : const Color(0xff176b32))
        : colors.onSurfaceVariant;
    return Card(
      child: InkWell(
        key: ValueKey('co-calendar-meeting-${m.id}'),
        onTap: () async {
          final member = membership;
          if (member == null) return;
          await context.push(m.reviewRoute(widget.hub, member));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.coGroupsNumber(m.number),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(coMeetingTime(context, m.startsAt)),
              Text(l.coMeetingPlaces(m.occupied, m.capacity)),
              Text(label, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attendance review reuses immutable command recovery without opening chat.
class CoCalendarMeetingReviewScreen extends ConsumerWidget {
  const CoCalendarMeetingReviewScreen({
    required this.hub,
    required this.room,
    required this.episode,
    required this.meeting,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  final String meeting;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PeoplePage(
    title: AppLocalizations.of(context).coCalendarTitle,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!ref.watch(coCreationPreferenceProvider).enabled)
          Text(AppLocalizations.of(context).coPeopleBackendOff)
        else
          PeopleAccess(
            child: KeyedSubtree(
              key: ValueKey(ref.watch(coCreationRoomsGatewayProvider)),
              child: CoMeetingPanel(
                hub: hub,
                room: room,
                episode: episode,
                expectedMeetingId: meeting,
              ),
            ),
          ),
      ],
    ),
  );
}
