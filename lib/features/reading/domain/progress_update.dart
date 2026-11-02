/// A validated progress update: either a page (when the page count is known)
/// or a percentage (when it is not).
class ProgressUpdate {
  ProgressUpdate._({required this.percent, this.page});

  factory ProgressUpdate.page(int page, {required int pageCount}) {
    final error = validatePage(page, pageCount: pageCount);
    if (error != null) throw ArgumentError(error);
    return ProgressUpdate._(page: page, percent: (page * 100 / pageCount).round());
  }

  factory ProgressUpdate.percent(int percent) {
    if (percent < 0 || percent > 100) throw ArgumentError.value(percent, 'percent', 'must be 0..100');
    return ProgressUpdate._(percent: percent);
  }

  final int? page;
  final int percent;

  /// Reaching the end only *offers* to finish; status never changes silently.
  bool get isComplete => percent >= 100;

  static String? validatePage(int? page, {required int pageCount}) {
    if (page == null) return 'Enter a page number';
    if (page < 0) return 'Page cannot be negative';
    if (page > pageCount) return 'This edition has $pageCount pages';
    return null;
  }
}
