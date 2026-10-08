import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/proposal_models.dart';

/// Raw immutable acknowledgement: invalid text is never converted to null.
class ProposalDraftSnapshot {
  ProposalDraftSnapshot({
    required List<String> text,
    required ProposalInput input,
    required this.coverRevision,
  }) : text = List.unmodifiable(text),
       input = freezeProposalInput(input);

  final List<String> text;
  final ProposalInput input;
  final int coverRevision;

  bool sameAs(ProposalDraftSnapshot other) =>
      listEquals(text, other.text) &&
      input.startsAt == other.input.startsAt &&
      input.endsAt == other.input.endsAt &&
      input.exactLocationVisibility == other.input.exactLocationVisibility &&
      input.countOrganizersTowardCapacity ==
          other.input.countOrganizersTowardCapacity &&
      mapEquals(input.skillImportanceById, other.input.skillImportanceById) &&
      coverRevision == other.coverRevision;

  bool get meaningful =>
      text.indexed.any(
        (entry) =>
            entry.$2.trim().isNotEmpty &&
            (entry.$1 != 4 ||
                !{'UTC', 'Europe/Rome'}.contains(entry.$2.trim())),
      ) ||
      input.startsAt != null ||
      input.endsAt != null ||
      input.skillImportanceById.isNotEmpty ||
      coverRevision != 0 ||
      input.countOrganizersTowardCapacity ||
      input.exactLocationVisibility != ExactLocationVisibility.participants;
}

/// Only opaque creation markers survive form disposal. No private content is
/// cached in settings. Recovery is explicit and scoped to the current actor.
class DraftCreationRecovery extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => const {};

  void remember(String actor, String request) => state = {
    ...state,
    actor: {...?state[actor], request},
  };
  void resolved(String actor, String request) => state = {
    ...state,
    actor: {...?state[actor]}..remove(request),
  };
}

final draftCreationRecoveryProvider =
    NotifierProvider<DraftCreationRecovery, Map<String, Set<String>>>(
      DraftCreationRecovery.new,
    );

ProposalInput freezeProposalInput(ProposalInput input) => ProposalInput(
  title: input.title,
  summary: input.summary,
  description: input.description,
  startsAt: input.startsAt,
  endsAt: input.endsAt,
  eventTimezone: input.eventTimezone,
  countryCode: input.countryCode,
  locality: input.locality,
  administrativeArea: input.administrativeArea,
  publicLocationLabel: input.publicLocationLabel,
  exactMeetingText: input.exactMeetingText,
  exactLocationVisibility: input.exactLocationVisibility,
  skillImportanceById: Map.unmodifiable(input.skillImportanceById),
  registrationCapacity: input.registrationCapacity,
  countOrganizersTowardCapacity: input.countOrganizersTowardCapacity,
);
