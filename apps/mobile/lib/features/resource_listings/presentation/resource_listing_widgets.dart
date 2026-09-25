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
    this.footer,
    this.semanticDetails = const [],
    super.key,
  });

  final PublicResourceListingSummary listing;
  final VoidCallback onTap;
  final Widget? footer;
  final List<String> semanticDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = resourceListingModeLabel(l10n, listing.mode);
    final interest = listing.activeRequestCount == 0
        ? null
        : l10n.resourceInterestCount(listing.activeRequestCount);
    return Semantics(
      button: true,
      label: [
        mode,
        listing.title,
        listing.publicLocationLabel,
        ?interest,
        ...semanticDetails,
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
                    ResourceListingModeBadge(mode: listing.mode),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  listing.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.medium),
                _IconText(
                  icon: Icons.location_on_outlined,
                  text: listing.publicLocationLabel,
                ),
                const SizedBox(height: AppSpacing.xSmall),
                _IconText(
                  icon: Icons.calendar_today_outlined,
                  text: l10n.resourcePublishedDate(
                    formatResourceListingDate(context, listing.publishedAt),
                  ),
                ),
                if (interest != null) ...[
                  const SizedBox(height: AppSpacing.xSmall),
                  _IconText(
                    icon: Icons.people_outline,
                    text: interest,
                    key: Key('resource-interest-count-${listing.id}'),
                  ),
                ],
                if (footer case final footer?) ...[
                  const SizedBox(height: AppSpacing.medium),
                  footer,
                ],
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
    final parts = [locality, ?administrativeArea, countryCode];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).resourceLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(publicLocationLabel),
        Text(parts.join(', ')),
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
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.small),
      Expanded(child: Text(text)),
    ],
  );
}
