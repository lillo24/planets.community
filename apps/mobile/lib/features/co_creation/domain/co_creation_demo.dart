class DemoText {
  const DemoText(this.en, this.it);
  final String en;
  final String it;
  String inLanguage(String code) => code == 'it' ? it : en;
}

class DemoHub {
  const DemoHub(this.id, this.title);
  final String id;
  final DemoText title;
  String get locality => 'Trento';
}

class DemoPost {
  const DemoPost(this.id, this.hubId, this.title, this.body);
  final String id;
  final String hubId;
  final DemoText title;
  final DemoText body;
  String get locality => 'Trento';
}
