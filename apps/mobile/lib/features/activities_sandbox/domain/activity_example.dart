/// Bilingual fictional content bundled with the experiment, never a domain row.
class ExampleText {
  const ExampleText(this.en, this.it);
  final String en;
  final String it;
  String inLanguage(String languageCode) => languageCode == 'it' ? it : en;
}

enum ExampleCategory { sports, culture }

enum ExampleFormat { event, recurring, course }

enum ExampleDiscipline {
  climbing(ExampleText('Climbing', 'Arrampicata')),
  acrobatics(ExampleText('Acrobatics', 'Acrobatica')),
  running(ExampleText('Running', 'Corsa')),
  volleyball(ExampleText('Volleyball', 'Pallavolo')),
  swimming(ExampleText('Swimming', 'Nuoto')),
  martialArts(ExampleText('Martial arts', 'Arti marziali')),
  dance(ExampleText('Dance', 'Danza')),
  yoga(ExampleText('Yoga', 'Yoga'));

  const ExampleDiscipline(this.label);
  final ExampleText label;
}

class ActivityExample {
  const ActivityExample({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.format,
    this.discipline,
    this.schedule,
    this.level,
    this.cost,
  });

  final String id;
  final ExampleText title;
  final ExampleText description;
  final ExampleCategory category;
  final ExampleFormat format;
  final ExampleDiscipline? discipline;

  /// Null means unknown, including for a course. Never infer a next session.
  final ExampleText? schedule;
  final ExampleText? level;
  final ExampleText? cost;
  String get city => 'Trento';
}

List<ActivityExample> filterActivityExamples(
  List<ActivityExample> catalogue, {
  ExampleCategory? category,
  ExampleDiscipline? discipline,
  String query = '',
  required String languageCode,
}) {
  final term = query.trim().toLowerCase();
  return catalogue.where((item) {
    if (category != null && item.category != category) return false;
    if (discipline != null && item.discipline != discipline) return false;
    final text = [
      item.title.inLanguage(languageCode),
      item.description.inLanguage(languageCode),
      item.discipline?.label.inLanguage(languageCode) ?? '',
    ].join(' ').toLowerCase();
    return text.contains(term);
  }).toList();
}
