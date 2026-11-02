import 'package:bookmarkd/app/app.dart';
import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/core/config/app_config.dart';
import 'package:bookmarkd/core/demo/demo_backend.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:bookmarkd/features/search/presentation/search_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const demoConfig = AppConfig(supabaseUrl: '', supabaseKey: '', googleBooksApiKey: '', passwordResetRedirect: '');

/// Catalog with one coverless book, so no network is touched.
class OfflineCatalog implements CatalogRepository {
  static const book = Book(
    ids: ExternalIds(googleBooksId: 'flow-1'),
    title: 'The Test of Time',
    authors: ['Ada Example'],
    pageCount: 320,
    categories: ['Fantasy'],
  );

  @override
  Future<List<Book>> search(CatalogQuery query, {int startIndex = 0}) async =>
      startIndex == 0 && query.isSearchable ? [book] : [];

  @override
  Future<Book> lookup(String catalogKey) async => book;
}

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    await configureDependencies(
      demoConfig,
      catalog: OfflineCatalog(),
      demo: DemoBackend(latency: Duration.zero, seed: false),
    );
  });

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 50));

  testWidgets('a new reader signs in, onboards, adds a book and sees it on Home', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390x844 phone
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BookmarkdApp());
    await settle(tester);

    // Welcome → login
    expect(find.text('Demo mode · sample data, nothing is saved to a server'), findsOneWidget);
    await tester.tap(find.text('I already have an account'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'reader@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);

    // Onboarding: username is validated, the rest is optional.
    expect(find.text('Pick a username'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('At least 3 characters'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'username'), 'reader_one');
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Add a profile photo'), findsOneWidget);
    await tester.tap(find.text('Continue').hitTestable());
    await settle(tester);
    expect(find.text('Set a reading goal'), findsOneWidget);
    await tester.tap(find.text('Continue').hitTestable());
    await settle(tester);
    await tester.tap(find.text('Start reading'));
    await settle(tester);

    // Home, empty state
    expect(find.text('reader_one'), findsOneWidget);
    expect(find.text('Find your first book to start tracking.'), findsOneWidget);

    // Search → details → add as Currently Reading
    await tester.tap(find.text('Search'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'time');
    await tester.pump(SearchCubit.debounce);
    await settle(tester);
    await tester.tap(find.text('The Test of Time').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Add to Library'));
    await tester.tap(find.text('Add to Library'));
    await settle(tester);
    await tester.tap(find.text('Currently Reading'));
    await settle(tester);
    expect(find.textContaining('Currently Reading'), findsOneWidget);

    // Back to Home: the book is in progress there.
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('Page 0 of 320'), findsOneWidget);
    expect(find.text('Update progress'), findsOneWidget);
  });
}
