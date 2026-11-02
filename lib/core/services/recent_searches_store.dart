import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/books/domain/book.dart';

/// Books the reader recently opened from search. Lightweight, local only.
class RecentSearchesStore {
  RecentSearchesStore(this._prefs);

  final SharedPreferencesAsync _prefs;
  static const _key = 'recent_books_v1';
  static const _max = 12;

  Future<List<Book>> load() async {
    try {
      final raw = await _prefs.getStringList(_key) ?? const [];
      return raw.map((s) => Book.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    } catch (_) {
      // Corrupt or old-format cache: start over rather than crash.
      await _prefs.remove(_key);
      return const [];
    }
  }

  Future<List<Book>> remember(Book book) async {
    final current = await load();
    final next = [book, ...current.where((b) => b.key != book.key)].take(_max).toList();
    await _prefs.setStringList(_key, next.map((b) => jsonEncode(b.toJson())).toList());
    return next;
  }

  Future<void> clear() => _prefs.remove(_key);
}
