import 'package:flutter/material.dart';

import '../../../app/design/tokens.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

class RoutineFormPage extends StatefulWidget {
  const RoutineFormPage({super.key});

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> {
  Routine? _existing;
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _interval = TextEditingController(text: '3');

  RecurrenceType _type = RecurrenceType.interval;
  final Set<int> _weekdays = {};
  String? _time;
  bool _active = true;
  bool _remind = true;
  bool _saving = false;
  String? _weekdayError;

  static const List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _existing = Get.arguments as Routine?;
    final r = _existing;
    if (r != null) {
      _title.text = r.title;
      _description.text = r.description;
      _interval.text = (r.intervalDays ?? 3).toString();
      _type = r.recurrenceType;
      _weekdays.addAll(r.weekdays);
      _time = r.preferredTime;
      _active = r.isActive;
      Get.find<ReminderRepository>()
          .getForTarget(ReminderTargetType.routine, r.id)
          .then((rem) {
        if (mounted) setState(() => _remind = rem != null && rem.isEnabled);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (_type == RecurrenceType.weekly && _weekdays.isEmpty) {
      setState(() => _weekdayError = 'Select at least one day');
      return;
    }
    if (!valid) return;
    setState(() {
      _weekdayError = null;
      _saving = true;
    });

    final now = DateTime.now();
    final old = _existing;
    final interval = int.tryParse(_interval.text.trim());
    final days = (_weekdays.toList()..sort());

    // Bila pola jadwal berubah, jadwal berikutnya dihitung ulang dari sekarang.
    final scheduleChanged = old == null ||
        old.recurrenceType != _type ||
        (_type == RecurrenceType.interval && old.intervalDays != interval) ||
        old.preferredTime != _time ||
        (_type == RecurrenceType.weekly &&
            (old.weekdays.toSet().length != _weekdays.length ||
                !_weekdays.containsAll(old.weekdays)));

    final routine = Routine(
      id: old?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      recurrenceType: _type,
      intervalDays: _type == RecurrenceType.interval ? interval : null,
      weekdays: _type == RecurrenceType.weekly ? days : const [],
      preferredTime: _time,
      nextDueAt: scheduleChanged || old == null ? null : old.nextDueAt,
      lastCompletedAt: old?.lastCompletedAt,
      isActive: _active,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final result = await Get.find<SaveRoutine>()(
        routine,
        isNew: old == null,
        remind: _remind,
      );
      Get.find<DataRevision>().bump();
      final msg = result.reminder?.message;
      Get.back<void>();
      AppToast.show(msg ?? 'Routine saved', isError: msg != null);
    } catch (err, st) {
      AppLog.error('routine.save', err, st);
      if (mounted) setState(() => _saving = false);
      AppToast.show(messageOf(err), isError: true);
    }
  }

  Future<void> _delete() async {
    final r = _existing!;
    final ok = await confirmDialog(
      context,
      title: 'Delete routine?',
      message: '"${r.title}" and its completion history will be deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Get.find<DeleteRoutine>()(r.id);
      Get.find<DataRevision>().bump();
      Get.back<void>();
      AppToast.show('Routine deleted');
    } catch (e) {
      AppToast.show(messageOf(e), isError: true);
    }
  }

  bool get _hasAdvanced =>
      _time != null || !_active || _description.text.trim().isNotEmpty;

  late final bool _openAdvanced = _hasAdvanced;

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    return FormPage(
      title: isNew ? 'New routine' : 'Edit routine',
      formKey: _formKey,
      onSave: _save,
      saving: _saving,
      actions: [
        if (!isNew)
          IconButton(
            tooltip: 'Delete routine',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
      ],
      children: [
        TextFormField(
          controller: _title,
          autofocus: isNew,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(
            labelText: 'Routine name',
            helperText: 'e.g. Tidy your room',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Routine name is required' : null,
        ),
        EnumDropdown<RecurrenceType>(
          label: 'Repeat pattern',
          value: _type,
          items: RecurrenceType.values,
          labelOf: (t) => t.label,
          onChanged: (v) => setState(() => _type = v),
        ),
        if (_type == RecurrenceType.interval)
          TextFormField(
            controller: _interval,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Repeat every',
              suffixText: 'days',
            ),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              return (n == null || n < 1) ? 'At least 1 day' : null;
            },
          ),
        if (_type == RecurrenceType.weekly)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(_dayLabels[d - 1]),
                      selected: _weekdays.contains(d),
                      onSelected: (on) => setState(() {
                        on ? _weekdays.add(d) : _weekdays.remove(d);
                        _weekdayError = null;
                      }),
                    ),
                ],
              ),
              if (_weekdayError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs + 2),
                  child: Text(
                    _weekdayError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me when it is due'),
          value: _remind,
          onChanged: (v) => setState(() => _remind = v),
        ),
        AdvancedOptions(
          initiallyOpen: _openAdvanced,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Time',
                helperText:
                    'Leave blank for an all-day due date; reminders default to 8:00 AM',
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_time ?? 'Not set')),
                  TextButton(
                    onPressed: () async {
                      final t = await pickHhmm(context, initial: _time);
                      if (t != null) setState(() => _time = t);
                    },
                    child: const Text('Choose'),
                  ),
                  if (_time != null)
                    IconButton(
                      tooltip: 'Clear time',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _time = null),
                    ),
                ],
              ),
            ),
            if (!isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive routines are hidden from Home'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
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
