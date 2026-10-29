import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/recurrence.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  Event? _existing;
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

  DateTime? _start;
  DateTime? _end;
  DateTime? _reminder;
  EventType _type = EventType.other;
  RecurrenceKind? _repeat;
  bool _saving = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    // Arguments are an event to edit or a date selected in Calendar.
    final arg = Get.arguments;
    _existing = arg is Event ? arg : null;
    final presetDay = arg is DateTime ? arg : null;
    final e = _existing;
    if (e != null) {
      _title.text = e.title;
      _location.text = e.location ?? '';
      _description.text = e.description;
      _start = e.startsAt;
      _end = e.endsAt;
      _type = e.eventType;
      _repeat = RecurrenceRule.tryParse(e.recurrenceRule)?.kind;
      Get.find<ReminderRepository>()
          .getForTarget(ReminderTargetType.event, e.id)
          .then((r) {
            if (mounted && r != null && r.isEnabled) {
              setState(() => _reminder = r.remindAt);
            }
          });
    } else if (presetDay != null) {
      // Start at 9:00 AM for dates opened from Calendar.
      _start = DateTime(presetDay.year, presetDay.month, presetDay.day, 9);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (_start == null) {
      setState(() => _timeError = 'Start time is required');
      return;
    }
    if (!valid) return;
    setState(() {
      _timeError = null;
      _saving = true;
    });
    final now = DateTime.now();
    final e = _existing;
    final event = Event(
      id: e?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      startsAt: _start!,
      endsAt: _end,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      eventType: _type,
      linkedTaskId: e?.linkedTaskId,
      linkedSavedItemId: e?.linkedSavedItemId,
      recurrenceRule: _repeat == null || _start == null
          ? null
          : RecurrenceRule.forDue(_repeat!, _start!).encoded,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final result = await Get.find<SaveEvent>()(
        event,
        isNew: e == null,
        reminderAt: _repeat == null ? _reminder : null,
      );
      Get.find<DataRevision>().bump();
      final msg = result.reminder?.message;
      Get.back<void>();
      AppToast.show(msg ?? 'Event saved', isError: msg != null);
    } catch (err, st) {
      AppLog.error('event.save', err, st);
      if (mounted) setState(() => _saving = false);
      AppToast.show(messageOf(err), isError: true);
    }
  }

  bool get _hasAdvanced =>
      _end != null ||
      _type != EventType.other ||
      _repeat != null ||
      _location.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty;

  late final bool _openAdvanced = _hasAdvanced;

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    return FormPage(
      title: isNew ? 'New event' : 'Edit event',
      formKey: _formKey,
      onSave: _save,
      saving: _saving,
      children: [
        TextFormField(
          controller: _title,
          autofocus: isNew,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(labelText: 'Event title'),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Event title is required'
              : null,
        ),
        DateTimeField(
          label: 'Starts',
          value: _start,
          emptyText: 'Choose a date and time',
          onChanged: (v) => setState(() {
            _start = v;
            _timeError = null;
          }),
        ),
        if (_timeError != null)
          Text(
            _timeError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_repeat == null)
          ReminderField(
            value: _reminder,
            anchor: _start,
            presets: const [
              ReminderPreset('15 minutes before', Duration(minutes: 15)),
              ReminderPreset('1 hour before', Duration(hours: 1)),
              ReminderPreset('1 day before', Duration(days: 1)),
            ],
            onChanged: (v) => setState(() => _reminder = v),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Recurring reminders are not available yet. Events will still appear on each matching date.',
            ),
          ),
        AdvancedOptions(
          initiallyOpen: _openAdvanced,
          children: [
            DropdownButtonFormField<RecurrenceKind?>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Does not repeat'),
                ),
                for (final kind in const [
                  RecurrenceKind.daily,
                  RecurrenceKind.weekly,
                  RecurrenceKind.monthly,
                ])
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (value) => setState(() {
                _repeat = value;
                if (value != null) _reminder = null;
              }),
            ),
            DateTimeField(
              label: 'Ends',
              value: _end,
              emptyText: 'No end time',
              defaultTime: _start != null
                  ? TimeOfDay(
                      hour: (_start!.hour + 1) % 24,
                      minute: _start!.minute,
                    )
                  : const TimeOfDay(hour: 10, minute: 0),
              onChanged: (v) => setState(() => _end = v),
            ),
            EnumDropdown<EventType>(
              label: 'Type',
              value: _type,
              items: EventType.values,
              labelOf: (t) => t.label,
              onChanged: (v) => setState(() => _type = v),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
