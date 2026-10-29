/// Repeat rules for tasks, events, and bills (`recurrence_rule`).
///
/// Format teks yang disimpan di SQLite:
///   - `daily`
///   - `weekly`
///   - `monthly:<day>` (day 1-31; retains day 31 after shorter months)
///   - `interval:<days>`
///   - `weekdays:<day>,...` (1 = Monday, 7 = Sunday)
enum RecurrenceKind {
  daily('Every day'),
  weekly('Every week'),
  monthly('Every month'),
  interval('Every N days'),
  weekdays('Selected weekdays');

  const RecurrenceKind(this.label);
  final String label;
}

class RecurrenceRule {
  const RecurrenceRule(
    this.kind, {
    this.anchorDay,
    this.intervalDays,
    this.weekdays = const [],
  });

  final RecurrenceKind kind;

  /// Used only by [RecurrenceKind.monthly].
  final int? anchorDay;
  final int? intervalDays;
  final List<int> weekdays;

  /// Builds a rule from the user's choice; monthly anchor is taken from [due].
  factory RecurrenceRule.forDue(RecurrenceKind kind, DateTime due) =>
      RecurrenceRule(
        kind,
        anchorDay: kind == RecurrenceKind.monthly ? due.day : null,
      );

  /// Returns null for empty or unknown values so older or malformed data remains
  /// safely displayable as a non-repeating item.
  static RecurrenceRule? tryParse(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v == 'daily') return const RecurrenceRule(RecurrenceKind.daily);
    if (v == 'weekly') return const RecurrenceRule(RecurrenceKind.weekly);
    if (v.startsWith('interval:')) {
      final days = int.tryParse(v.substring('interval:'.length));
      if (days == null || days < 1) return null;
      return RecurrenceRule(RecurrenceKind.interval, intervalDays: days);
    }
    if (v.startsWith('weekdays:')) {
      final parsedDays = v
          .substring('weekdays:'.length)
          .split(',')
          .map(int.tryParse)
          .toList();
      if (parsedDays.isEmpty ||
          parsedDays.any((day) => day == null || day < 1 || day > 7)) {
        return null;
      }
      final days = parsedDays.whereType<int>().toSet().toList()..sort();
      return RecurrenceRule(RecurrenceKind.weekdays, weekdays: days);
    }
    if (v.startsWith('monthly')) {
      final parts = v.split(':');
      final day = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (day != null && (day < 1 || day > 31)) return null;
      return RecurrenceRule(RecurrenceKind.monthly, anchorDay: day);
    }
    return null;
  }

  String get encoded => switch (kind) {
    RecurrenceKind.daily => 'daily',
    RecurrenceKind.weekly => 'weekly',
    RecurrenceKind.monthly =>
      anchorDay == null ? 'monthly' : 'monthly:$anchorDay',
    RecurrenceKind.interval => 'interval:${intervalDays ?? 1}',
    RecurrenceKind.weekdays => 'weekdays:${([...weekdays]..sort()).join(',')}',
  };

  String get label => switch (kind) {
    RecurrenceKind.interval => 'Every ${intervalDays ?? 1} days',
    RecurrenceKind.weekdays =>
      weekdays
          .map(
            (day) => const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ].elementAt(day - 1),
          )
          .join(', '),
    _ => kind.label,
  };

  /// Returns the next occurrence at the same local time using calendar
  /// arithmetic, safe across month, year, and leap-year boundaries.
  DateTime next(DateTime from) {
    switch (kind) {
      case RecurrenceKind.daily:
        return DateTime(
          from.year,
          from.month,
          from.day + 1,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.weekly:
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.weekdays:
        final days = weekdays.where((day) => day >= 1 && day <= 7).toSet();
        if (days.isEmpty) {
          return DateTime(
            from.year,
            from.month,
            from.day + 7,
            from.hour,
            from.minute,
          );
        }
        for (var offset = 1; offset <= 7; offset++) {
          final candidate = DateTime(
            from.year,
            from.month,
            from.day + offset,
            from.hour,
            from.minute,
          );
          if (days.contains(candidate.weekday)) return candidate;
        }
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.interval:
        final days = intervalDays ?? 1;
        return DateTime(
          from.year,
          from.month,
          from.day + days,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.monthly:
        var year = from.year;
        var month = from.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final wanted = anchorDay ?? from.day;
        final day = wanted > daysInMonth ? daysInMonth : wanted;
        return DateTime(year, month, day, from.hour, from.minute);
    }
  }

  /// Returns the first occurrence after [from] that also falls after [notBefore].
  /// This prevents completing an overdue repeating task from creating another
  /// already-overdue task.
  DateTime nextAfter(DateTime from, DateTime notBefore) {
    var n = next(from);
    // Batas pengaman agar tidak pernah berputar tanpa akhir pada data aneh.
    for (var i = 0; i < 1000 && !n.isAfter(notBefore); i++) {
      n = next(n);
    }
    return n;
  }
}
