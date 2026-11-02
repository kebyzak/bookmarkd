import '../../features/books/domain/book.dart';
import '../../features/library/domain/rating.dart';
import '../../features/library/domain/reading_status.dart';
import '../../features/profile/domain/profile.dart';
import 'demo_backend.dart';

/// Demo-only readers. Their names say "demo" so they are never mistaken for
/// real people.
const demoFriendIds = ['demo-ada', 'demo-sam', 'demo-maya'];

Book _book(String isbn13, String title, String author, int pages, String year, String category, String about) => Book(
  ids: ExternalIds(isbn13: isbn13),
  title: title,
  authors: [author],
  pageCount: pages,
  publishedDate: year,
  categories: [category],
  description: about,
  // default=false: a missing cover 404s and shows our placeholder, not a blank image.
  coverUrl: 'https://covers.openlibrary.org/b/isbn/$isbn13-L.jpg?default=false',
);

final _catalog = [
  _book(
    '9780441172719',
    'Dune',
    'Frank Herbert',
    604,
    '1965',
    'Science Fiction',
    'A desert planet, a powerful family, and a fight over the most valuable substance in the universe.',
  ),
  _book(
    '9780441478125',
    'The Left Hand of Darkness',
    'Ursula K. Le Guin',
    304,
    '1969',
    'Science Fiction',
    'An envoy visits a wintry world whose people have no fixed gender.',
  ),
  _book(
    '9780375704024',
    'Norwegian Wood',
    'Haruki Murakami',
    296,
    '1987',
    'Literary Fiction',
    'A man looks back on love and loss during his student years in Tokyo.',
  ),
  _book(
    '9780547928227',
    'The Hobbit',
    'J.R.R. Tolkien',
    300,
    '1937',
    'Fantasy',
    'A home-loving hobbit is swept into a quest with thirteen dwarves and a wizard.',
  ),
  _book(
    '9780451524935',
    '1984',
    'George Orwell',
    328,
    '1949',
    'Dystopian',
    'A clerk in a surveillance state begins to doubt the Party.',
  ),
  _book(
    '9781455563920',
    'Pachinko',
    'Min Jin Lee',
    496,
    '2017',
    'Historical Fiction',
    'Four generations of a Korean family make a life in Japan.',
  ),
  _book(
    '9781635575637',
    'Piranesi',
    'Susanna Clarke',
    272,
    '2020',
    'Fantasy',
    'A man lives alone in an endless house of statues and tides.',
  ),
  _book(
    '9780679731726',
    'The Remains of the Day',
    'Kazuo Ishiguro',
    245,
    '1989',
    'Literary Fiction',
    'An English butler takes a road trip and reconsiders a lifetime of service.',
  ),
  _book(
    '9780804172448',
    'Station Eleven',
    'Emily St. John Mandel',
    333,
    '2014',
    'Science Fiction',
    'A travelling theatre troupe performs Shakespeare after a pandemic.',
  ),
  _book(
    '9781571313560',
    'Braiding Sweetgrass',
    'Robin Wall Kimmerer',
    408,
    '2013',
    'Nature',
    'A botanist weaves together science and Indigenous knowledge of plants.',
  ),
];

void seedDemoData(DemoBackend db) {
  const people = [
    Profile(
      id: 'demo-ada',
      username: 'ada_demo',
      displayName: 'Ada (demo)',
      bio: 'Sample reader for demo mode.',
      readingGoal: 30,
      onboarded: true,
    ),
    Profile(
      id: 'demo-sam',
      username: 'sam_demo',
      displayName: 'Sam (demo)',
      bio: 'Sample reader for demo mode.',
      readingGoal: 12,
      onboarded: true,
    ),
    Profile(
      id: 'demo-maya',
      username: 'maya_demo',
      displayName: 'Maya (demo)',
      bio: 'Sample reader for demo mode.',
      onboarded: true,
    ),
  ];
  for (final p in people) {
    db.profiles[p.id] = p;
  }
  final stored = [for (final b in _catalog) db.saveSync(b)];
  DateTime ago(int days) => db.now.subtract(Duration(days: days));

  void log(String user, int book, ReadingStatus status, int daysAgo, {int? halfStars}) {
    db.addSync(
      user,
      stored[book],
      status,
      at: ago(daysAgo),
      rating: halfStars == null ? null : Rating.fromHalfStars(halfStars),
    );
  }

  log('demo-ada', 0, ReadingStatus.finished, 20, halfStars: 10);
  log('demo-ada', 6, ReadingStatus.finished, 9, halfStars: 9);
  log('demo-ada', 1, ReadingStatus.reading, 2);
  log('demo-sam', 4, ReadingStatus.finished, 12, halfStars: 8);
  log('demo-sam', 3, ReadingStatus.finished, 5, halfStars: 7);
  log('demo-sam', 8, ReadingStatus.wantToRead, 1);
  log('demo-maya', 2, ReadingStatus.reading, 3);
  log('demo-maya', 5, ReadingStatus.finished, 15, halfStars: 9);
  log('demo-maya', 9, ReadingStatus.wantToRead, 6);
  log('demo-maya', 0, ReadingStatus.finished, 30, halfStars: 8);

  db.upsertSync(
    'demo-ada',
    stored[6].id!,
    'Sample review written for demo mode: quiet, strange and kind.',
    false,
    at: ago(8),
  );
  db.upsertSync('demo-sam', stored[3].id!, 'Sample review written for demo mode: a cozy adventure.', false, at: ago(4));
}
