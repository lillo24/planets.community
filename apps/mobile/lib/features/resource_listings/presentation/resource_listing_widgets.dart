import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../locations/domain/location_preview.dart';
import '../../locations/presentation/location_preview_panel.dart';
import '../../locations/presentation/location_attribution.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/cover_image.dart';
import '../domain/resource_listing_models.dart';

String resourceListingModeLabel(
  AppLocalizations l10n,
  ResourceListingMode mode,
) => switch (mode) {
  ResourceListingMode.donate => l10n.resourceModeDonate,
  ResourceListingMode.exchange => l10n.resourceModeExchange,
};

String resourceListingLifecycleLabel(
  AppLocalizations l10n,
  ResourceListingLifecycle lifecycle,
) => switch (lifecycle) {
  ResourceListingLifecycle.draft => l10n.resourceLifecycleDraft,
  ResourceListingLifecycle.published => l10n.resourceLifecyclePublished,
  ResourceListingLifecycle.closed => l10n.resourceLifecycleClosed,
};

String resourceListingFailureMessage(
  AppLocalizations l10n,
  ResourceListingFailureKind? failure,
) => switch (failure) {
  ResourceListingFailureKind.invalidInput => l10n.resourceInvalidInput,
  ResourceListingFailureKind.profilePhotoRequired =>
    l10n.profilePhotoScambioRequiredTitle,
  ResourceListingFailureKind.forbidden => l10n.resourceForbidden,
  ResourceListingFailureKind.invalidState => l10n.resourceInvalidState,
  ResourceListingFailureKind.notFound => l10n.resourceNotFound,
  ResourceListingFailureKind.unavailable || null => l10n.resourceSafeError,
};

String formatResourceListingDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date.toLocal());

String formatResourceListingRelativeAge(
  BuildContext context,
  DateTime publishedAt, {
  required DateTime now,
}) {
  final l10n = AppLocalizations.of(context);
  final age = now.toUtc().difference(publishedAt.toUtc());
  if (age.isNegative || age < const Duration(minutes: 1)) {
    return l10n.resourceAgeNow;
  }
  if (age < const Duration(hours: 1)) {
    return l10n.resourceAgeMinutes(age.inMinutes);
  }
  if (age < const Duration(days: 1)) {
    return l10n.resourceAgeHours(age.inHours);
  }
  if (age < const Duration(days: 7)) {
    return l10n.resourceAgeDays(age.inDays);
  }
  return DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag())
      .format(publishedAt.toLocal());
}

String canonicalResourceListingLocation({
  required String publicLocationLabel,
  required String locality,
  required String? administrativeArea,
  required String countryCode,
}) {
  final publicLabel = publicLocationLabel.trim();
  if (publicLabel.isNotEmpty) return publicLabel;

  final result = <String>[];
  for (final part in [locality, ?administrativeArea, countryCode]) {
    final normalized = part.trim();
    if (normalized.isEmpty ||
        result.any(
          (value) => value.toLowerCase() == normalized.toLowerCase(),
        )) {
      continue;
    }
    result.add(normalized);
  }
  return result.join(' · ');
}

class ResourceListingModeBadge extends StatelessWidget {
  const ResourceListingModeBadge({required this.mode, super.key});

  final ResourceListingMode mode;

  @override
  Widget build(BuildContext context) {
    final label = resourceListingModeLabel(AppLocalizations.of(context), mode);
    return Semantics(
      label: label,
      child: Chip(
        key: Key('resource-mode-${mode.wireValue}'),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        side: BorderSide.none,
      ),
    );
  }
}

class ResourceListingLifecycleBadge extends StatelessWidget {
  const ResourceListingLifecycleBadge({required this.lifecycle, super.key});

  final ResourceListingLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final label = resourceListingLifecycleLabel(
      AppLocalizations.of(context),
      lifecycle,
    );
    return Semantics(
      label: label,
      child: Chip(
        key: Key('resource-lifecycle-${lifecycle.wireValue}'),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        side: BorderSide.none,
      ),
    );
  }
}

class PublicResourceListingCard extends StatelessWidget {
  const PublicResourceListingCard({
    required this.listing,
    required this.onTap,
    required this.now,
    this.footer,
    this.semanticDetails = const [],
    super.key,
  });

  final PublicResourceListingSummary listing;
  final VoidCallback onTap;
  final DateTime now;
  final Widget? footer;
  final List<String> semanticDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = resourceListingModeLabel(l10n, listing.mode);
    final interest = l10n.resourceInterestCount(listing.activeRequestCount);
    final age = formatResourceListingRelativeAge(
      context,
      listing.publishedAt,
      now: now,
    );
    // Cards favor structured locality; detail retains the canonical public
    // label. No geographic parsing or truncation of arbitrary labels is used.
    final locality = listing.locality.trim();
    final location = locality.isNotEmpty
        ? locality
        : canonicalResourceListingLocation(
            publicLocationLabel: listing.publicLocationLabel,
            locality: listing.locality,
            administrativeArea: listing.administrativeArea,
            countryCode: listing.countryCode,
          );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: [
        mode,
        listing.title,
        l10n.resourcePublishedRelative(age),
        interest,
        location,
        ...semanticDetails,
      ].join(', '),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('resource-card-${listing.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoverImage(
                key: Key('resource-cover-${listing.id}'),
                title: listing.title,
                objectPath: listing.coverObjectPath,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            key: Key('resource-card-title-${listing.id}'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.small),
                        Semantics(
                          label: l10n.resourcePublishedRelative(age),
                          excludeSemantics: true,
                          child: Text(
                            age,
                            key: Key('resource-age-${listing.id}'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ResourceListingModeBadge(mode: listing.mode),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      listing.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Wrap(
                      key: Key('resource-metadata-${listing.id}'),
                      spacing: AppSpacing.medium,
                      runSpacing: AppSpacing.small,
                      children: [
                        _IconText(
                          icon: Icons.people_outline,
                          text: interest,
                          key: Key('resource-interest-count-${listing.id}'),
                        ),
                      ],
                    ),
                    LocationPreviewPanel(
                      item: PreviewItem('resource', listing.id),
                      legacy: LegacyPreviewArea(
                        listing.locality,
                        listing.countryCode,
                      ),
                      publicLabel: location,
                      key: Key('resource-location-${listing.id}'),
                    ),
                    if (footer case final footer?) ...[
                      const SizedBox(height: AppSpacing.medium),
                      footer,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResourceListingLocation extends StatelessWidget {
  const ResourceListingLocation({
    required this.publicLocationLabel,
    required this.locality,
    required this.administrativeArea,
    required this.countryCode,
    this.listingId,
    super.key,
  });

  final String publicLocationLabel;
  final String locality;
  final String? administrativeArea;
  final String countryCode;
  final String? listingId;

  @override
  Widget build(BuildContext context) {
    final location = canonicalResourceListingLocation(
      publicLocationLabel: publicLocationLabel,
      locality: locality,
      administrativeArea: administrativeArea,
      countryCode: countryCode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).resourceLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        if (listingId case final id?)
          LocationPreviewPanel(
            item: PreviewItem('resource', id),
            legacy: LegacyPreviewArea(locality, countryCode),
            publicLabel: location,
            detail: true,
            labelKey: const Key('resource-canonical-location'),
          )
        else ...[
          Text(location, key: const Key('resource-canonical-location')),
          const LocationAttribution(),
        ],
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.small),
      Flexible(child: Text(text)),
    ],
  );
}
