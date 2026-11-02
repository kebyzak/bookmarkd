import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/domain/status_transition.dart';
import 'package:flutter_test/flutter_test.dart';

import 'library_domain_test.dart' show entry;

void main() {
  final today = DateTime(2026, 11, 2);

  test('starting a book records the start date', () {
    final e = transitionStatus(entry('A'), ReadingStatus.reading, today: today);
    expect(e.status, ReadingStatus.reading);
    expect(e.startedAt, today);
    expect(e.finishedAt, isNull);
  });

  test('finishing records finish date and keeps an existing start date', () {
    final started = entry('A', status: ReadingStatus.reading).copyWith(startedAt: () => DateTime(2026, 10, 1));
    final e = transitionStatus(started, ReadingStatus.finished, today: today);
    expect(e.startedAt, DateTime(2026, 10, 1));
    expect(e.finishedAt, today);
    expect(e.progressPercent, 100);
  });

  test('moving back to want-to-read clears dates and progress', () {
    final finished = transitionStatus(entry('A'), ReadingStatus.finished, today: today);
    final e = transitionStatus(finished, ReadingStatus.wantToRead, today: today);
    expect(e.startedAt, isNull);
    expect(e.finishedAt, isNull);
    expect(e.progressPercent, isNull);
    expect(e.currentPage, isNull);
  });

  test('is idempotent', () {
    final once = transitionStatus(entry('A'), ReadingStatus.finished, today: today);
    expect(transitionStatus(once, ReadingStatus.finished, today: DateTime(2027)), once);
  });
}
