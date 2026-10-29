import 'package:flutter/material.dart';
import '../../../app/design/tokens.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/recurrence.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';
import '../task_args.dart';

/// Hanya judul yang wajib. Semua kolom lain opsional (PRD 7.4).
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  late final TaskFormArgs _args;
  Task? get _existing => _args.existing;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _nextAction = TextEditingController();
  final _minutes = TextEditingController();
  final _course = TextEditingController();
  final _group = TextEditingController();
  final _source = TextEditingController();
  final _location = TextEditingController();
  final _intervalDays = TextEditingController(text: '3');

  DateTime? _due;
  RecurrenceKind? _repeat;
  final Set<int> _repeatWeekdays = {};
  DateTime? _reminder;
  TaskPriority _priority = TaskPriority.normal;
  TaskStatus _status = TaskStatus.todo;
  TaskKind _kind = TaskKind.individual;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _args = (Get.arguments as TaskFormArgs?) ?? const TaskFormArgs();
    final t = _existing;
    if (t != null) {
      _title.text = t.title;
      _description.text = t.description;
      _nextAction.text = t.nextAction ?? '';
      _minutes.text = t.estimatedMinutes?.toString() ?? '';
      _course.text = t.courseName ?? '';
      _group.text = t.groupName ?? '';
      _source.text = t.instructionSource ?? '';
      _location.text = t.instructionLocation ?? '';
      _due = t.dueAt;
      final rule = RecurrenceRule.tryParse(t.recurrenceRule);
      _repeat = rule?.kind;
      if (rule?.intervalDays != null) {
        _intervalDays.text = rule!.intervalDays.toString();
      }
      _repeatWeekdays.addAll(rule?.weekdays ?? const []);
      _priority = t.priority;
      _status = t.status;
      _kind = t.taskKind;
      Get.find<ReminderRepository>()
          .getForTarget(ReminderTargetType.task, t.id)
          .then((r) {
            if (mounted && r != null && r.isEnabled) {
              setState(() => _reminder = r.remindAt);
            }
          });
    } else {
      _title.text = _args.title ?? '';
      _description.text = _args.description ?? '';
      _course.text = _args.courseName ?? '';
      _group.text = _args.groupName ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _nextAction,
      _minutes,
      _course,
      _group,
      _source,
      _location,
      _intervalDays,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_repeat == RecurrenceKind.weekdays && _repeatWeekdays.isEmpty) {
      AppToast.show(
        'Select at least one day for the repeat schedule.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final e = _existing;
    final task = Task(
      id: e?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      status: _status,
      priority: _priority,
      dueAt: _due,
      estimatedMinutes: int.tryParse(_minutes.text.trim()),
      courseName: _course.text,
      groupName: _group.text,
      taskKind: _kind,
      instructionSource: _source.text,
      instructionLocation: _location.text,
      initiatedBy: e?.initiatedBy,
      nextAction: _nextAction.text,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
      completedAt: e?.completedAt,
      archivedAt: e?.archivedAt,
      recurrenceRule: _repeat == null || _due == null
          ? null
          : switch (_repeat!) {
              RecurrenceKind.interval => RecurrenceRule(
                RecurrenceKind.interval,
                intervalDays: int.parse(_intervalDays.text.trim()),
              ).encoded,
              RecurrenceKind.weekdays => RecurrenceRule(
                RecurrenceKind.weekdays,
                weekdays: _repeatWeekdays.toList(),
              ).encoded,
              _ => RecurrenceRule.forDue(_repeat!, _due!).encoded,
            },
    );
    try {
      final result = await Get.find<SaveTask>()(
        task,
        isNew: e == null,
        reminderAt: _reminder,
        savedItemIds: _args.savedItemIds,
      );
      Get.find<DataRevision>().bump();
      final msg = result.reminder?.message;
      Get.back<void>();
      AppToast.show(msg ?? 'Task saved', isError: msg != null);
    } catch (err, st) {
      AppLog.error('task.save', err, st);
      if (mounted) setState(() => _saving = false);
      AppToast.show(messageOf(err), isError: true);
    }
  }

  /// Opens More options automatically when advanced fields already have values.
  bool get _hasAdvanced =>
      _priority != TaskPriority.normal ||
      _status != TaskStatus.todo ||
      _repeat != null ||
      _kind != TaskKind.individual ||
      [
        _description,
        _nextAction,
        _minutes,
        _course,
        _group,
        _source,
        _location,
      ].any((c) => c.text.trim().isNotEmpty);

  late final bool _openAdvanced = _hasAdvanced;

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    final statusChoices = isNew
        ? const [TaskStatus.needsReview, TaskStatus.todo, TaskStatus.inProgress]
        : TaskStatus.values;
    return FormPage(
      title: isNew ? 'New task' : 'Edit task',
      formKey: _formKey,
      onSave: _save,
      saving: _saving,
      children: [
        TextFormField(
          controller: _title,
          autofocus: isNew && _args.title == null,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(labelText: 'Task title'),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Task title is required'
              : null,
        ),
        DateTimeField(
          label: 'Due date',
          value: _due,
          emptyText: 'Not set yet',
          onChanged: (v) => setState(() => _due = v),
        ),
        if (_due != null)
          ReminderField(
            value: _reminder,
            anchor: _due,
            presets: const [
              ReminderPreset('1 hour before', Duration(hours: 1)),
              ReminderPreset('1 day before', Duration(days: 1)),
              ReminderPreset('3 days before', Duration(days: 3)),
            ],
            onChanged: (v) => setState(() => _reminder = v),
          ),
        AdvancedOptions(
          initiallyOpen: _openAdvanced,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EnumDropdown<TaskPriority>(
                    label: 'Priority',
                    value: _priority,
                    items: TaskPriority.values,
                    labelOf: (p) => p.label,
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: EnumDropdown<TaskStatus>(
                    label: 'Status',
                    value: statusChoices.contains(_status)
                        ? _status
                        : statusChoices.first,
                    items: statusChoices,
                    labelOf: (s) => s.label,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
              ],
            ),
            if (_due != null)
              DropdownButtonFormField<RecurrenceKind?>(
                initialValue: _repeat,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Does not repeat'),
                  ),
                  for (final k in RecurrenceKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setState(() {
                  _repeat = v;
                  if (v == RecurrenceKind.weekdays &&
                      _repeatWeekdays.isEmpty &&
                      _due != null) {
                    _repeatWeekdays.add(_due!.weekday);
                  }
                }),
              ),
            if (_repeat == RecurrenceKind.interval)
              TextFormField(
                controller: _intervalDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Repeat every (days)',
                ),
                validator: (value) {
                  if (_repeat != RecurrenceKind.interval) return null;
                  final days = int.tryParse(value?.trim() ?? '');
                  return days == null || days < 1
                      ? 'Enter at least 1 day'
                      : null;
                },
              ),
            if (_repeat == RecurrenceKind.weekdays)
              Wrap(
                spacing: AppSpace.xs,
                children: [
                  for (final (index, label) in [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ].indexed)
                    FilterChip(
                      label: Text(label),
                      selected: _repeatWeekdays.contains(index + 1),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _repeatWeekdays.add(index + 1);
                        } else {
                          _repeatWeekdays.remove(index + 1);
                        }
                      }),
                    ),
                ],
              ),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            TextFormField(
              controller: _course,
              decoration: const InputDecoration(
                labelText: 'Course / category',
              ),
            ),
            TextFormField(
              controller: _group,
              decoration: const InputDecoration(labelText: 'Class / group'),
            ),
            EnumDropdown<TaskKind>(
              label: 'Task type',
              value: _kind,
              items: TaskKind.values,
              labelOf: (k) => k.label,
              onChanged: (v) => setState(() => _kind = v),
            ),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated duration (minutes)',
                helperText: 'Leave blank if unknown; we will not guess',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                return (n == null || n < 0)
                    ? 'Enter a valid number of minutes'
                    : null;
              },
            ),
            TextFormField(
              controller: _nextAction,
              decoration: const InputDecoration(
                labelText: 'Next action',
              ),
            ),
            TextFormField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Instructions from',
                helperText: 'e.g. class group chat, instructor',
              ),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Instruction location',
                helperText: 'e.g. group name or Drive link',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
