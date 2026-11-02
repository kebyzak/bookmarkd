enum ReadingStatus {
  wantToRead('want_to_read', 'Want to Read', 'Want to Read'),
  reading('reading', 'Currently Reading', 'Reading'),
  finished('finished', 'Finished', 'Finished'),
  dnf('dnf', 'Did Not Finish', 'DNF');

  const ReadingStatus(this.dbValue, this.label, this.shortLabel);

  final String dbValue;
  final String label;
  final String shortLabel;

  static ReadingStatus fromDb(String value) =>
      values.firstWhere((s) => s.dbValue == value, orElse: () => throw FormatException('Unknown status $value'));
}
