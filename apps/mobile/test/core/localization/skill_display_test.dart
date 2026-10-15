import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/localization/skill_display.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  const skills = <(String, String, String, String)>[
    (
      "mural-painting",
      "d0000000-0000-4000-8001-000000000001",
      "Mural painting",
      "Pittura murale",
    ),
    (
      "drawing-illustration",
      "d0000000-0000-4000-8001-000000000002",
      "Drawing & illustration",
      "Disegno e illustrazione",
    ),
    (
      "photography",
      "d0000000-0000-4000-8001-000000000003",
      "Photography",
      "Fotografia",
    ),
    (
      "graphic-design",
      "d0000000-0000-4000-8001-000000000004",
      "Graphic design",
      "Grafica",
    ),
    (
      "musician",
      "d0000000-0000-4000-8002-000000000001",
      "Musician",
      "Musicista",
    ),
    ("singing", "d0000000-0000-4000-8002-000000000002", "Singing", "Canto"),
    (
      "audio-sound-setup",
      "d0000000-0000-4000-8002-000000000003",
      "Audio & sound setup",
      "Allestimento audio",
    ),
    (
      "practical-making",
      "d0000000-0000-4000-8003-000000000001",
      "Practical making",
      "Lavori manuali",
    ),
    (
      "woodworking",
      "d0000000-0000-4000-8003-000000000002",
      "Woodworking",
      "Falegnameria",
    ),
    (
      "basic-repairs",
      "d0000000-0000-4000-8003-000000000003",
      "Basic repairs",
      "Piccole riparazioni",
    ),
    (
      "painting-decorating",
      "d0000000-0000-4000-8003-000000000004",
      "Painting & decorating",
      "Pittura e decorazione",
    ),
    (
      "gardening",
      "d0000000-0000-4000-8004-000000000001",
      "Gardening",
      "Giardinaggio",
    ),
    (
      "plant-care",
      "d0000000-0000-4000-8004-000000000002",
      "Plant care",
      "Cura delle piante",
    ),
    (
      "urban-gardening",
      "d0000000-0000-4000-8004-000000000003",
      "Urban gardening",
      "Orticoltura urbana",
    ),
    ("cooking", "d0000000-0000-4000-8005-000000000001", "Cooking", "Cucina"),
    (
      "baking",
      "d0000000-0000-4000-8005-000000000002",
      "Baking",
      "Pasticceria e panificazione",
    ),
    (
      "food-event-support",
      "d0000000-0000-4000-8005-000000000003",
      "Food-event support",
      "Supporto cucina per eventi",
    ),
    (
      "programming",
      "d0000000-0000-4000-8006-000000000001",
      "Programming",
      "Programmazione",
    ),
    (
      "electronics",
      "d0000000-0000-4000-8006-000000000002",
      "Electronics",
      "Elettronica",
    ),
    (
      "web-design-tools",
      "d0000000-0000-4000-8006-000000000003",
      "Web & design tools",
      "Strumenti web e grafica",
    ),
    (
      "event-organization",
      "d0000000-0000-4000-8007-000000000001",
      "Event organization",
      "Organizzazione eventi",
    ),
    (
      "facilitation",
      "d0000000-0000-4000-8007-000000000002",
      "Facilitation",
      "Facilitazione",
    ),
    (
      "communication-social-media",
      "d0000000-0000-4000-8007-000000000003",
      "Communication & social media",
      "Comunicazione e social media",
    ),
    (
      "fundraising-community-outreach",
      "d0000000-0000-4000-8007-000000000004",
      "Fundraising & community outreach",
      "Raccolta fondi e coinvolgimento della comunità",
    ),
  ];
  const categories = <(String, String, String)>[
    ("art-creativity", "Art & Creativity", "Arte e creatività"),
    ("music", "Music", "Musica"),
    ("diy-practical", "DIY & Practical", "Fai da te e manualità"),
    ("gardening-nature", "Gardening & Nature", "Giardinaggio e natura"),
    ("cooking-food", "Cooking & Food", "Cucina e cibo"),
    ("technology", "Technology", "Tecnologia"),
    (
      "organization-community",
      "Organization & Community",
      "Organizzazione e comunità",
    ),
  ];
  for (final locale in ['en', 'it']) {
    testWidgets(
      'controlled skills and IDs localize; unknown labels survive $locale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold));
        for (final skill in skills) {
          final expected = locale == 'it' ? skill.$4 : skill.$3;
          expect(skillDisplayLabel(context, skill.$1, skill.$3), expected);
          expect(skillDisplayLabel(context, skill.$2, skill.$3), expected);
        }
        for (final category in categories) {
          expect(
            skillCategoryDisplayLabel(context, category.$1, category.$2),
            locale == 'it' ? category.$3 : category.$2,
          );
        }
        expect(
          skillDisplayLabel(
            context,
            'future-controlled-skill',
            'Unknown / Ω skill',
          ),
          'Unknown / Ω skill',
        );
        // Canonical English spelling alone is never a translation key.
        expect(
          skillDisplayLabel(context, 'unknown', 'Woodworking'),
          'Woodworking',
        );
        expect(
          skillCategoryDisplayLabel(
            context,
            'future-category',
            'Future category',
          ),
          'Future category',
        );
      },
    );
  }
}
