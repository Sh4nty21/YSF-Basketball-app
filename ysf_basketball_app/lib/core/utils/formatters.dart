import 'package:intl/intl.dart';

/// Date/time formatting used across screens. Presentation only.
abstract final class Formatters {
  static final DateFormat _full = DateFormat('EEEE, d MMMM y');
  static final DateFormat _short = DateFormat('EEE, d MMM y');
  static final DateFormat _compact = DateFormat('d MMM');
  static final DateFormat _clock = DateFormat('h:mm a');

  /// "Saturday, 22 August 2026"
  static String fullDate(DateTime date) => _full.format(date);

  /// "Sat, 22 Aug 2026"
  static String shortDate(DateTime date) => _short.format(date);

  /// "22 Aug"
  static String compactDate(DateTime date) => _compact.format(date);

  /// "7:15 PM" — check-in timestamps arrive as naive UTC-ish server time, so
  /// they are shown as-is rather than shifted into the device's zone.
  static String clock(DateTime time) => _clock.format(time);

  /// "Today" / "Yesterday" / "Tomorrow", else the short date.
  static String relativeDay(DateTime date, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(date);
    final difference = target.difference(today).inDays;

    return switch (difference) {
      0 => 'Today',
      -1 => 'Yesterday',
      1 => 'Tomorrow',
      _ => shortDate(date),
    };
  }

  /// "12 players" / "1 player"
  static String players(int count) => '$count player${count == 1 ? '' : 's'}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
