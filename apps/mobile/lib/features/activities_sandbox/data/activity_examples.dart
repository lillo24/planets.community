import '../domain/activity_example.dart';

// Fictional local UI fixtures. No source URLs, provider identifiers, account
// data, network covers or real-world availability. IDs never enter native APIs.
const activityExamples = [
  ActivityExample(
    id: 'example-climbing',
    title: ExampleText(
      'First steps on the climbing wall',
      'Primi passi sulla parete',
    ),
    description: ExampleText(
      'A fictional introductory climbing course in a small group.',
      'Un corso immaginario di introduzione all’arrampicata in piccolo gruppo.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.climbing,
    format: ExampleFormat.course,
    schedule: ExampleText('Tuesdays · 18:30–19:30', 'Martedì · 18:30–19:30'),
    level: ExampleText('Beginners', 'Principianti'),
    cost: ExampleText(
      'Example cost: €60 / month',
      'Costo di esempio: 60 € / mese',
    ),
  ),
  ActivityExample(
    id: 'example-acrobatics',
    title: ExampleText('Acrobatics together', 'Acrobatica insieme'),
    description: ExampleText(
      'An imagined course exploring balance and floor movement.',
      'Un corso immaginario per esplorare equilibrio e movimento a terra.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.acrobatics,
    format: ExampleFormat.course,
    level: ExampleText('Beginners', 'Principianti'),
  ),
  ActivityExample(
    id: 'example-running',
    title: ExampleText('Easy evening run', 'Corsa serale tranquilla'),
    description: ExampleText(
      'An example of a relaxed weekly running session.',
      'Un esempio di appuntamento settimanale di corsa a ritmo tranquillo.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.running,
    format: ExampleFormat.recurring,
    schedule: ExampleText(
      'Wednesdays · 18:00–19:00',
      'Mercoledì · 18:00–19:00',
    ),
  ),
  ActivityExample(
    id: 'example-volleyball',
    title: ExampleText(
      'An afternoon of volleyball',
      'Un pomeriggio di pallavolo',
    ),
    description: ExampleText(
      'A fictional open practice afternoon for trying volleyball.',
      'Un pomeriggio immaginario di allenamento aperto per provare la pallavolo.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.volleyball,
    format: ExampleFormat.event,
    schedule: ExampleText(
      '14 Nov 2026 · 15:00–17:00',
      '14 novembre 2026 · 15:00–17:00',
    ),
  ),
  ActivityExample(
    id: 'example-swimming',
    title: ExampleText(
      'Find your swimming rhythm',
      'Trova il tuo ritmo in acqua',
    ),
    description: ExampleText(
      'An example swimming course focused on technique.',
      'Un corso di nuoto di esempio dedicato alla tecnica.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.swimming,
    format: ExampleFormat.course,
    schedule: ExampleText(
      'Mondays and Thursdays · 19:00–20:00',
      'Lunedì e giovedì · 19:00–20:00',
    ),
    level: ExampleText('Intermediate', 'Intermedio'),
  ),
  ActivityExample(
    id: 'example-martial-arts',
    title: ExampleText('Discover martial arts', 'Scopri le arti marziali'),
    description: ExampleText(
      'A fictional introduction to movement and coordination.',
      'Un’introduzione immaginaria al movimento e alla coordinazione.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.martialArts,
    format: ExampleFormat.event,
    schedule: ExampleText(
      '21 Nov 2026 · 10:00–12:00',
      '21 novembre 2026 · 10:00–12:00',
    ),
  ),
  ActivityExample(
    id: 'example-dance',
    title: ExampleText(
      'Contemporary dance lab',
      'Laboratorio di danza contemporanea',
    ),
    description: ExampleText(
      'An imagined weekly space for dance and improvisation.',
      'Uno spazio settimanale immaginario di danza e improvvisazione.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.dance,
    format: ExampleFormat.course,
    schedule: ExampleText('Fridays · 18:00–19:30', 'Venerdì · 18:00–19:30'),
  ),
  ActivityExample(
    id: 'example-yoga',
    title: ExampleText('A quiet hour of yoga', 'Un’ora tranquilla di yoga'),
    description: ExampleText(
      'An example recurring session of gentle movement.',
      'Una sessione ricorrente di esempio dedicata al movimento dolce.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.yoga,
    format: ExampleFormat.recurring,
    schedule: ExampleText('Saturdays · 09:00–10:00', 'Sabato · 09:00–10:00'),
  ),
  ActivityExample(
    id: 'example-trail',
    title: ExampleText(
      'Introduction to trail running',
      'Introduzione alla corsa sui sentieri',
    ),
    description: ExampleText(
      'A fictional one-off session to discover trail running.',
      'Una sessione singola immaginaria per scoprire la corsa sui sentieri.',
    ),
    category: ExampleCategory.sports,
    discipline: ExampleDiscipline.running,
    format: ExampleFormat.event,
    schedule: ExampleText(
      '28 Nov 2026 · 09:00–11:00',
      '28 novembre 2026 · 09:00–11:00',
    ),
  ),
  ActivityExample(
    id: 'example-printmaking',
    title: ExampleText(
      'Printmaking afternoon',
      'Pomeriggio di stampa artistica',
    ),
    description: ExampleText(
      'An imagined workshop exploring simple printmaking techniques.',
      'Un laboratorio immaginario per esplorare semplici tecniche di stampa artistica.',
    ),
    category: ExampleCategory.culture,
    format: ExampleFormat.event,
    schedule: ExampleText(
      '15 Nov 2026 · 14:00–17:00',
      '15 novembre 2026 · 14:00–17:00',
    ),
  ),
  ActivityExample(
    id: 'example-reading',
    title: ExampleText('Stories out loud', 'Storie ad alta voce'),
    description: ExampleText(
      'A fictional recurring reading activity, separate from PLANETS Cultural Tables.',
      'Un’attività ricorrente immaginaria di lettura, separata dai Tavoli culturali di PLANETS.',
    ),
    category: ExampleCategory.culture,
    format: ExampleFormat.recurring,
    schedule: ExampleText('Thursdays · 17:30–18:30', 'Giovedì · 17:30–18:30'),
  ),
  ActivityExample(
    id: 'example-photography',
    title: ExampleText(
      'Looking through a lens',
      'Guardare attraverso un obiettivo',
    ),
    description: ExampleText(
      'An example photography course for curious beginners.',
      'Un corso di fotografia di esempio per principianti curiosi.',
    ),
    category: ExampleCategory.culture,
    format: ExampleFormat.course,
    level: ExampleText('Beginners', 'Principianti'),
  ),
];

ActivityExample? activityExampleById(String id) {
  for (final item in activityExamples) {
    if (item.id == id) return item;
  }
  return null;
}
