import '../domain/co_creation_demo.dart';

// Fictional identities never share the UUID namespace of canonical objects.
const demoHubs = [
  DemoHub('demo-football', DemoText('Five-a-side football', 'Calcetto')),
  DemoHub('demo-board-games', DemoText('Board games', 'Giochi da tavolo')),
  DemoHub('demo-newcomers', DemoText('New in Trento', 'Nuovi a Trento')),
  DemoHub('demo-hiking', DemoText('Hiking', 'Escursioni')),
];
const demoPosts = [
  DemoPost(
    'demo-football-post',
    'demo-football',
    DemoText(
      'Looking for company for football',
      'Cerco compagnia per calcetto',
    ),
    DemoText(
      'A fictional example for meeting people who enjoy a casual game.',
      'Un esempio immaginario per conoscere persone a cui piace giocare senza impegno.',
    ),
  ),
  DemoPost(
    'demo-games-post',
    'demo-board-games',
    DemoText('Anyone for board games?', 'Qualcuno per giochi da tavolo?'),
    DemoText(
      'A fictional evening of board games, including Werewolf.',
      'Una serata immaginaria di giochi da tavolo, incluso Lupus in Fabula.',
    ),
  ),
  DemoPost(
    'demo-newcomer-post',
    'demo-newcomers',
    DemoText(
      'New in Trento and looking for friends',
      'Nuovo a Trento, cerco amicizie',
    ),
    DemoText(
      'A fictional newcomer would like to explore the city together.',
      'Una persona immaginaria appena arrivata vorrebbe scoprire la città insieme.',
    ),
  ),
  DemoPost(
    'demo-trip-post',
    'demo-newcomers',
    DemoText(
      'Company for a Trento–Verona trip',
      'Compagnia per un viaggio Trento–Verona',
    ),
    DemoText(
      'An example of finding company, without booking, payments or contact details.',
      'Un esempio per trovare compagnia, senza prenotazioni, pagamenti o contatti.',
    ),
  ),
];
DemoHub? demoHubById(String id) {
  for (final hub in demoHubs) {
    if (hub.id == id) return hub;
  }
  return null;
}

DemoPost? demoPostById(String id) {
  for (final post in demoPosts) {
    if (post.id == id) return post;
  }
  return null;
}
