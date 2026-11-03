import 'package:intl/intl.dart';

String relativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final sameYear = time.year == (now ?? DateTime.now()).year;
  return (sameYear ? DateFormat.MMMd() : DateFormat.yMMMd()).format(time);
}

String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

String formatCount(int n) => NumberFormat.compact().format(n);

String formatStars(double stars) => NumberFormat('0.0').format(stars);
