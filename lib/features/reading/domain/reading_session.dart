import 'package:equatable/equatable.dart';

class ReadingSession extends Equatable {
  const ReadingSession({
    required this.id,
    required this.percent,
    required this.readOn,
    this.fromPage,
    this.toPage,
  });

  final String id;
  final int? fromPage;
  final int? toPage;
  final int percent;
  final DateTime readOn;

  int? get pagesRead => fromPage != null && toPage != null && toPage! > fromPage! ? toPage! - fromPage! : null;

  factory ReadingSession.fromJson(Map<String, dynamic> json) => ReadingSession(
        id: json['id'] as String,
        fromPage: json['from_page'] as int?,
        toPage: json['to_page'] as int?,
        percent: json['progress_percent'] as int,
        readOn: DateTime.parse(json['read_on'] as String),
      );

  @override
  List<Object?> get props => [id, fromPage, toPage, percent, readOn];
}
