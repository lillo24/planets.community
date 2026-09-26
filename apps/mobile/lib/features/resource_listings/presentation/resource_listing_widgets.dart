import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    super.key,
  });

  final PublicResourceListingSummary listing;
  final VoidCallback onTap;
  final DateTime now;

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
    final location = canonicalResourceListingLocation(
      publicLocationLabel: listing.publicLocationLabel,
      locality: listing.locality,
      administrativeArea: listing.administrativeArea,
      countryCode: listing.countryCode,
    );
    return Semantics(
      button: true,
      label: [
        mode,
        listing.title,
        l10n.resourcePublishedRelative(age),
        interest,
        location,
      ].join(', '),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('resource-card-${listing.id}'),
          onTap: onTap,
          child: Padding(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _IconText(
                        icon: Icons.people_outline,
                        text: interest,
                        key: Key('resource-interest-count-${listing.id}'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: _IconText(
                        icon: Icons.location_on_outlined,
                        text: location,
                        textAlign: TextAlign.end,
                        key: Key('resource-location-${listing.id}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    super.key,
  });

  final String publicLocationLabel;
  final String locality;
  final String? administrativeArea;
  final String countryCode;

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
        Text(location, key: const Key('resource-canonical-location')),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({
    required this.icon,
    required this.text,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final IconData icon;
  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.small),
      Expanded(child: Text(text, textAlign: textAlign)),
    ],
  );
}
