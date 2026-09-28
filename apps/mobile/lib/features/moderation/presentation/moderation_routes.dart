import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../domain/moderation_models.dart';

abstract final class ModerationRoutes {
  static const ownReports = '/profile/reports';
  static const newReport = '/profile/reports/new';
  static const reviewRequests = '/profile/reports/review-requests';

  static String corroborationDetail(String requestId) =>
      '$reviewRequests/corroboration/$requestId';

  static String counterstatementDetail(String requestId) =>
      '$reviewRequests/counterstatement/$requestId';

  static Future<T?> openReport<T>(
    BuildContext context,
    ModerationReportTarget target,
  ) => context.push<T>(newReport, extra: target);
}

ModerationReportTarget projectReportTarget(String projectId, String label) =>
    ModerationReportTarget(
      kind: ModerationTargetKind.project,
      id: projectId,
      label: label,
    );

ModerationReportTarget projectMessageReportTarget(
  String messageId,
  String label,
) => ModerationReportTarget(
  kind: ModerationTargetKind.projectChatMessage,
  id: messageId,
  label: label,
);

ModerationReportTarget resourceListingReportTarget(
  String listingId,
  String label,
) => ModerationReportTarget(
  kind: ModerationTargetKind.resourceListing,
  id: listingId,
  label: label,
);

ModerationReportTarget resourceMessageReportTarget(
  String messageId,
  String label,
) => ModerationReportTarget(
  kind: ModerationTargetKind.resourceChatMessage,
  id: messageId,
  label: label,
);
