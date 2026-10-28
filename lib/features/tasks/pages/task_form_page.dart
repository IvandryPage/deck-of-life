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

  DateTime? _due;
  RecurrenceKind? _repeat;
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
      _repeat = RecurrenceRule.tryParse(t.recurrenceRule)?.kind;
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
      _title, _description, _nextAction, _minutes, _course, _group, _source, _location,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      recurrenceRule: (_repeat != null && _due != null)
          ? RecurrenceRule.forDue(_repeat!, _due!).encoded
          : null,
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
      AppToast.show(msg ?? 'Tugas tersimpan', isError: msg != null);
    } catch (err, st) {
      AppLog.error('task.save', err, st);
      if (mounted) setState(() => _saving = false);
      AppToast.show(messageOf(err), isError: true);
    }
  }

  /// Buka "Opsi lanjutan" otomatis bila ada isian lanjutan (ubah / prefill konteks).
  bool get _hasAdvanced =>
      _priority != TaskPriority.normal ||
      _status != TaskStatus.todo ||
      _repeat != null ||
      _kind != TaskKind.individual ||
      [_description, _nextAction, _minutes, _course, _group, _source, _location]
          .any((c) => c.text.trim().isNotEmpty);

  late final bool _openAdvanced = _hasAdvanced;

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    final statusChoices = isNew
        ? const [TaskStatus.needsReview, TaskStatus.todo, TaskStatus.inProgress]
        : TaskStatus.values;
    return FormPage(
      title: isNew ? 'Tugas baru' : 'Ubah tugas',
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
          decoration: const InputDecoration(labelText: 'Judul tugas'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Judul tugas wajib diisi' : null,
        ),
        DateTimeField(
          label: 'Deadline',
          value: _due,
          emptyText: 'Belum diketahui',
          onChanged: (v) => setState(() => _due = v),
        ),
        if (_due != null)
          ReminderField(
            value: _reminder,
            anchor: _due,
            presets: const [
              ReminderPreset('1 jam sebelum', Duration(hours: 1)),
              ReminderPreset('1 hari sebelum', Duration(days: 1)),
              ReminderPreset('3 hari sebelum', Duration(days: 3)),
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
                    label: 'Prioritas',
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
                decoration: const InputDecoration(labelText: 'Ulangi'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tidak berulang')),
                  for (final k in RecurrenceKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setState(() => _repeat = v),
              ),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                alignLabelWithHint: true,
              ),
            ),
            TextFormField(
              controller: _course,
              decoration: const InputDecoration(labelText: 'Mata kuliah / kategori'),
            ),
            TextFormField(
              controller: _group,
              decoration: const InputDecoration(labelText: 'Kelas / grup'),
            ),
            EnumDropdown<TaskKind>(
              label: 'Jenis tugas',
              value: _kind,
              items: TaskKind.values,
              labelOf: (k) => k.label,
              onChanged: (v) => setState(() => _kind = v),
            ),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Perkiraan durasi (menit)',
                helperText: 'Kosongkan bila tidak tahu; tidak akan ditebak',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                return (n == null || n < 0) ? 'Isi angka menit yang valid' : null;
              },
            ),
            TextFormField(
              controller: _nextAction,
              decoration: const InputDecoration(labelText: 'Langkah berikutnya'),
            ),
            TextFormField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Sumber instruksi',
                helperText: 'mis. Grup WA kelas, dosen',
              ),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Lokasi instruksi',
                helperText: 'mis. nama grup / tautan Drive',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
