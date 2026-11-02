import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:bookmarkd/features/search/presentation/search_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCatalog implements CatalogRepository {
  final queries = <String>[];
  bool fail = false;

  @override
  Future<List<Book>> search(CatalogQuery query, {int startIndex = 0}) async {
    queries.add('${query.googleQuery}@$startIndex');
    if (fail) throw const AppFailure.network();
    return List.generate(
      startIndex == 0 ? 20 : 3,
      (i) => Book(
        ids: ExternalIds(googleBooksId: '${query.text}-${startIndex + i}'),
        title: 'B$i',
        authors: const [],
      ),
    );
  }

  @override
  Future<Book> lookup(String catalogKey) => throw UnimplementedError();
}

void main() {
  test('debounces typing into a single search', () {
    fakeAsync((async) {
      final catalog = FakeCatalog();
      final cubit = SearchCubit(catalog);
      cubit.queryChanged('d');
      cubit.queryChanged('du');
      cubit.queryChanged('dune');
      async.elapse(const Duration(milliseconds: 100));
      expect(catalog.queries, isEmpty);
      async.elapse(SearchCubit.debounce);
      async.flushMicrotasks();
      expect(catalog.queries, ['dune@0']);
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.results, hasLength(20));
      cubit.close();
    });
  });

  test('changing the mode re-runs the query field-scoped', () {
    fakeAsync((async) {
      final catalog = FakeCatalog();
      final cubit = SearchCubit(catalog)..queryChanged('herbert');
      async.elapse(SearchCubit.debounce);
      cubit.modeChanged(SearchMode.author);
      async.flushMicrotasks();
      expect(catalog.queries.last, 'inauthor:herbert@0');
      cubit.close();
    });
  });

  test('loads the next page and appends', () {
    fakeAsync((async) {
      final catalog = FakeCatalog();
      final cubit = SearchCubit(catalog)..queryChanged('dune');
      async.elapse(SearchCubit.debounce);
      cubit.loadMore();
      async.flushMicrotasks();
      expect(cubit.state.results, hasLength(23));
      expect(cubit.state.hasMore, isFalse);
      cubit.close();
    });
  });

  test('surfaces failures and clears on empty input', () {
    fakeAsync((async) {
      final catalog = FakeCatalog()..fail = true;
      final cubit = SearchCubit(catalog)..queryChanged('dune');
      async.elapse(SearchCubit.debounce);
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.failure?.kind, FailureKind.network);
      cubit.queryChanged('');
      expect(cubit.state.status, LoadStatus.initial);
      cubit.close();
    });
  });
}
