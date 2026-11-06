import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/recurrence.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';
import '../task_args.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final String _id;
  final _tasks = Get.find<TaskRepository>();
  final _routines = Get.find<RoutineRepository>();

  Task? _task;
  List<SavedItem> _items = const [];
  List<RoutineLog> _routineHistory = const [];
  Reminder? _reminder;
  bool _loading = true;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _id = Get.arguments as String;
    _load();
    _worker = ever<int>(Get.find<DataRevision>().revision, (_) => _load());
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await _tasks.getById(_id);
      final items = t == null ? <SavedItem>[] : await _tasks.savedItemsFor(_id);
      final r = t == null
          ? null
          : await Get.find<ReminderRepository>().getForTarget(
              ReminderTargetType.task,
              _id,
            );
      final routineHistory = t == null
          ? <RoutineLog>[]
          : await _routines.logsForTask(_id);
      if (!mounted) return;
      setState(() {
        _task = t;
        _items = items;
        _routineHistory = routineHistory;
        _reminder = r;
        _loading = false;
      });
    } catch (e, st) {
      AppLog.error('task.detail', e, st);
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<void> _setStatus(TaskStatus s) async {
    try {
      await Get.find<ChangeTaskStatus>()(_id, s);
      Get.find<DataRevision>().bump();
    } catch (e, st) {
      AppLog.error('task.status', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<void> _saveChecklist(List<TaskChecklistItem> checklist) async {
    final task = _task;
    if (task == null) return;
    try {
      await _tasks.update(task.copyWith(checklist: checklist));
      Get.find<DataRevision>().bump();
    } catch (e, st) {
      AppLog.error('task.checklist', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<void> _addChecklistItem() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add checklist step'),
        content: TextField(
          controller: text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Step'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(text.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    text.dispose();
    final title = value?.trim();
    if (title == null || title.isEmpty || !mounted) return;
    await _saveChecklist([
      ...?_task?.checklist,
      TaskChecklistItem(id: const Uuid().v4(), title: title),
    ]);
  }

  Future<void> _linkExistingNote() async {
    final linkedIds = _items.map((item) => item.id).toSet();
    final notes = await Get.find<SavedItemRepository>().search('', limit: 100);
    final options = notes
        .where((item) => !linkedIds.contains(item.id))
        .toList();
    if (!mounted) return;
    if (options.isEmpty) {
      AppToast.show('No unlinked notes found.');
      return;
    }
    final picked = await showModalBottomSheet<SavedItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Link a note')),
            for (final item in options)
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: Text(item.title),
                subtitle: Text(item.itemType.label),
                onTap: () => Navigator.of(context).pop(item),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await _tasks.linkSavedItem(_id, picked.id);
      Get.find<DataRevision>().bump();
      AppToast.show('Note linked');
    } catch (e, st) {
      AppLog.error('task.link_note', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final task = _task;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Task not found'),
      );
    }
    final theme = Theme.of(context);
    final now = DateTime.now();
    final overdue = task.isOverdue(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          IconButton(
            tooltip: 'Edit task',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Get.toNamed<dynamic>(
              Routes.taskForm,
              arguments: TaskFormArgs(existing: task),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete task?',
                  message:
                      'The task and its reminder will be deleted. Linked notes will not be deleted.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!ok) return;
                try {
                  await Get.find<DeleteTask>()(task.id);
                  Get.find<DataRevision>().bump();
                  Get.back<void>();
                  AppToast.show('Task deleted');
                } catch (e) {
                  AppToast.show(messageOf(e), isError: true);
                }
              } else {
                await _setStatus(TaskStatus.fromValue(v));
              }
            },
            itemBuilder: (_) => [
              for (final s in TaskStatus.values)
                if (s != task.status)
                  PopupMenuItem(
                    value: s.value,
                    child: Text('Change to: ${s.label}'),
                  ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(task.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusTag(
                task.status.label,
                icon: task.status == TaskStatus.needsReview
                    ? Icons.help_outline
                    : null,
                tone: task.status == TaskStatus.needsReview
                    ? TagTone.info
                    : null,
              ),
              if (overdue)
                const StatusTag(
                  'Overdue',
                  icon: Icons.warning_amber,
                  warning: true,
                ),
              StatusTag('${task.priority.label} priority'),
              if (task.courseName != null) StatusTag(task.courseName!),
            ],
          ),
          const SizedBox(height: 16),
          KeyValueRow(
            'Due date',
            task.dueAt == null
                ? 'Not set'
                : '${Formatters.dateTime(task.dueAt!)} (${DueLabel.of(task.dueAt, now: now)})',
          ),
          if (task.recurrenceRule != null)
            KeyValueRow(
              'Repeat',
              RecurrenceRule.tryParse(task.recurrenceRule)?.label ??
                  'Repeat schedule',
            ),
          if (_reminder != null && _reminder!.isEnabled)
            KeyValueRow(
              'Reminder',
              _reminder!.lastScheduledAt == null
                  ? '${Formatters.dateTime(_reminder!.remindAt)} (not scheduled; check notification permissions)'
                  : Formatters.dateTime(_reminder!.remindAt),
            ),
          if (task.estimatedMinutes != null)
            KeyValueRow('Estimated duration', '${task.estimatedMinutes} min'),
          if (task.groupName != null)
            KeyValueRow('Class / group', task.groupName!),
          KeyValueRow('Task type', task.taskKind.label),
          if (task.nextAction != null)
            KeyValueRow('Next action', task.nextAction!),
          if (task.instructionSource != null)
            KeyValueRow('Instructions from', task.instructionSource!),
          if (task.instructionLocation != null)
            KeyValueRow('Instruction location', task.instructionLocation!),
          if (task.completedAt != null)
            KeyValueRow('Completed', Formatters.dateTime(task.completedAt!)),
          if (_routineHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Routine history', style: theme.textTheme.titleMedium),
            for (final log in _routineHistory)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(Formatters.dateTime(log.completedAt)),
                subtitle: log.note == null ? null : Text(log.note!),
              ),
          ],
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            SelectableText(task.description, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Checklist', style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Add checklist step',
                onPressed: _addChecklistItem,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (task.checklist.isNotEmpty) ...[
            Text(
              '${task.checklist.where((item) => item.isDone).length} of ${task.checklist.length} steps complete',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value:
                  task.checklist.where((item) => item.isDone).length /
                  task.checklist.length,
            ),
            for (final (index, item) in task.checklist.indexed)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.isDone,
                title: Text(
                  item.title,
                  style: item.isDone
                      ? TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        )
                      : null,
                ),
                secondary: IconButton(
                  tooltip: 'Remove step',
                  icon: const Icon(Icons.close),
                  onPressed: () => _saveChecklist([
                    for (var i = 0; i < task.checklist.length; i++)
                      if (i != index) task.checklist[i],
                  ]),
                ),
                onChanged: (done) => _saveChecklist([
                  for (var i = 0; i < task.checklist.length; i++)
                    if (i == index)
                      item.copyWith(isDone: done)
                    else
                      task.checklist[i],
                ]),
              ),
          ] else
            Text(
              'Break this task into smaller steps.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          if (task.isActive)
            FilledButton.icon(
              onPressed: () => _setStatus(TaskStatus.done),
              icon: const Icon(Icons.check),
              label: const Text('Mark as done'),
            )
          else if (task.status == TaskStatus.done)
            OutlinedButton.icon(
              onPressed: () => _setStatus(TaskStatus.todo),
              icon: const Icon(Icons.undo),
              label: const Text('Reopen task'),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Linked notes', style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Link a note',
                onPressed: _linkExistingNote,
                icon: const Icon(Icons.link),
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'No notes linked yet. You can link one from its detail page.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final i in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bookmark_border),
              title: Text(i.title),
              subtitle: Text(i.itemType.label),
              trailing: IconButton(
                tooltip: 'Unlink note',
                icon: const Icon(Icons.link_off),
                onPressed: () async {
                  await _tasks.unlinkSavedItem(task.id, i.id);
                  Get.find<DataRevision>().bump();
                },
              ),
              onTap: () =>
                  Get.toNamed<dynamic>(Routes.savedItemDetail, arguments: i.id),
            ),
        ],
      ),
    );
  }
}
