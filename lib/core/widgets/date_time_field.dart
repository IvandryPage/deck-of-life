import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Picks a date and time. Returns null when canceled so callers can retain
/// their existing value.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  DateTime? initial,
  bool dateOnly = false,
  TimeOfDay defaultTime = const TimeOfDay(hour: 9, minute: 0),
}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 10),
  );
  if (date == null) return null;
  if (dateOnly) return DateTime(date.year, date.month, date.day, 23, 59);
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: initial != null
        ? TimeOfDay(hour: initial.hour, minute: initial.minute)
        : defaultTime,
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Optional date/time field with a clear button.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.dateOnly = false,
    this.defaultTime = const TimeOfDay(hour: 9, minute: 0),
    this.emptyText = 'Not set',
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? helper;
  final bool dateOnly;
  final TimeOfDay defaultTime;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = value == null
        ? emptyText
        : (dateOnly ? Formatters.date(value!) : Formatters.dateTime(value!));
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await pickDateTime(
          context,
          initial: value,
          dateOnly: dateOnly,
          defaultTime: defaultTime,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          text,
          style: value == null
              ? theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Picks a time and returns it in storage format ("HH:mm").
Future<String?> pickHhmm(BuildContext context, {String? initial}) async {
  var start = const TimeOfDay(hour: 8, minute: 0);
  if (initial != null) {
    final parts = initial.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) start = TimeOfDay(hour: h, minute: m);
    }
  }
  final t = await showTimePicker(context: context, initialTime: start);
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
