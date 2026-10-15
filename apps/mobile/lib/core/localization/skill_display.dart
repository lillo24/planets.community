import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

const _skillSlugsById = {
  'd0000000-0000-4000-8001-000000000001': 'mural-painting',
  'd0000000-0000-4000-8001-000000000002': 'drawing-illustration',
  'd0000000-0000-4000-8001-000000000003': 'photography',
  'd0000000-0000-4000-8001-000000000004': 'graphic-design',
  'd0000000-0000-4000-8002-000000000001': 'musician',
  'd0000000-0000-4000-8002-000000000002': 'singing',
  'd0000000-0000-4000-8002-000000000003': 'audio-sound-setup',
  'd0000000-0000-4000-8003-000000000001': 'practical-making',
  'd0000000-0000-4000-8003-000000000002': 'woodworking',
  'd0000000-0000-4000-8003-000000000003': 'basic-repairs',
  'd0000000-0000-4000-8003-000000000004': 'painting-decorating',
  'd0000000-0000-4000-8004-000000000001': 'gardening',
  'd0000000-0000-4000-8004-000000000002': 'plant-care',
  'd0000000-0000-4000-8004-000000000003': 'urban-gardening',
  'd0000000-0000-4000-8005-000000000001': 'cooking',
  'd0000000-0000-4000-8005-000000000002': 'baking',
  'd0000000-0000-4000-8005-000000000003': 'food-event-support',
  'd0000000-0000-4000-8006-000000000001': 'programming',
  'd0000000-0000-4000-8006-000000000002': 'electronics',
  'd0000000-0000-4000-8006-000000000003': 'web-design-tools',
  'd0000000-0000-4000-8007-000000000001': 'event-organization',
  'd0000000-0000-4000-8007-000000000002': 'facilitation',
  'd0000000-0000-4000-8007-000000000003': 'communication-social-media',
  'd0000000-0000-4000-8007-000000000004': 'fundraising-community-outreach',
};

// Display-only controlled catalog mapping. Unknown slugs keep the canonical
// label; IDs, stored labels, importance, search and matching payloads stay intact.

String skillDisplayLabel(
  BuildContext context,
  String slug,
  String canonicalLabel,
) {
  final l = AppLocalizations.of(context);
  final key = _skillSlugsById[slug] ?? slug;
  return switch (key) {
    'mural-painting' => l.skillDisplayMuralPainting,
    'drawing-illustration' => l.skillDisplayDrawingIllustration,
    'photography' => l.skillDisplayPhotography,
    'graphic-design' => l.skillDisplayGraphicDesign,
    'musician' => l.skillDisplayMusician,
    'singing' => l.skillDisplaySinging,
    'audio-sound-setup' => l.skillDisplayAudioSoundSetup,
    'practical-making' => l.skillDisplayPracticalMaking,
    'woodworking' => l.skillDisplayWoodworking,
    'basic-repairs' => l.skillDisplayBasicRepairs,
    'painting-decorating' => l.skillDisplayPaintingDecorating,
    'gardening' => l.skillDisplayGardening,
    'plant-care' => l.skillDisplayPlantCare,
    'urban-gardening' => l.skillDisplayUrbanGardening,
    'cooking' => l.skillDisplayCooking,
    'baking' => l.skillDisplayBaking,
    'food-event-support' => l.skillDisplayFoodEventSupport,
    'programming' => l.skillDisplayProgramming,
    'electronics' => l.skillDisplayElectronics,
    'web-design-tools' => l.skillDisplayWebDesignTools,
    'event-organization' => l.skillDisplayEventOrganization,
    'facilitation' => l.skillDisplayFacilitation,
    'communication-social-media' => l.skillDisplayCommunicationSocialMedia,
    'fundraising-community-outreach' =>
      l.skillDisplayFundraisingCommunityOutreach,
    _ => canonicalLabel,
  };
}

String skillCategoryDisplayLabel(
  BuildContext context,
  String slug,
  String canonicalLabel,
) {
  final l = AppLocalizations.of(context);
  return switch (slug) {
    'art-creativity' => l.skillCategoryDisplayArtCreativity,
    'music' => l.skillCategoryDisplayMusic,
    'diy-practical' => l.skillCategoryDisplayDiyPractical,
    'gardening-nature' => l.skillCategoryDisplayGardeningNature,
    'cooking-food' => l.skillCategoryDisplayCookingFood,
    'technology' => l.skillCategoryDisplayTechnology,
    'organization-community' => l.skillCategoryDisplayOrganizationCommunity,
    _ => canonicalLabel,
  };
}
