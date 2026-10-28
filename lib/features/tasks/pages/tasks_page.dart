import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../controllers/tasks_controller.dart';
import '../task_args.dart';
import '../widgets/task_tile.dart';

class TasksPage extends GetView<TasksController> {
  const TasksPage({super.key});

  static const Map<TaskFilter, String> _labels = {
    TaskFilter.active: 'Aktif',
    TaskFilter.done: 'Selesai',
    TaskFilter.all: 'Semua',
  };

  static const Map<TaskBucket, String> _bucketTitles = {
    TaskBucket.overdue: 'Terlambat',
    TaskBucket.today: 'Hari ini',
    TaskBucket.upcoming: 'Mendatang',
    TaskBucket.noDeadline: 'Tanpa deadline',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _QuickAdd(),
        Obx(
          () => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.gutter, vertical: AppSpace.xs),
            child: Row(
              children: [
                for (final f in TaskFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: ChoiceChip(
                      label: Text(_labels[f]!),
                      selected: controller.filter.value == f,
                      onSelected: (_) => controller.filter.value = f,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) return const SkeletonList();
            if (controller.errorMessage.value != null) {
              return ErrorState(
                message: controller.errorMessage.value!,
                onRetry: controller.load,
              );
            }
            final tasks = controller.tasks.toList();
            final filter = controller.filter.value;
            if (tasks.isEmpty) {
              final active = filter == TaskFilter.active;
              return EmptyState(
                icon: Icons.checklist,
                title: active ? 'Tidak ada tugas aktif' : 'Belum ada tugas',
                message: active
                    ? 'Ketik judul di atas lalu Enter. Deadline dan detail lain boleh menyusul.'
                    : null,
                actionLabel: active ? 'Tugas lengkap' : null,
                onAction: active
                    ? () => Get.toNamed<dynamic>(
                          Routes.taskForm,
                          arguments: const TaskFormArgs(),
                        )
                    : null,
              );
            }

            Widget row(Task t) => TaskTile(
                  task: t,
                  onToggleDone: () => controller.toggleDone(t),
                  onTap: () => Get.toNamed<dynamic>(
                    Routes.taskDetail,
                    arguments: t.id,
                  ),
                );

            final children = <Widget>[];
            if (filter == TaskFilter.active) {
              final groups = TasksController.bucketize(tasks, DateTime.now());
              for (final b in TaskBucket.values) {
                final list = groups[b]!;
                if (list.isEmpty) continue;
                children.add(SectionHeader(_bucketTitles[b]!, count: list.length));
                children.addAll(list.map(row));
              }
            } else {
              children.addAll(tasks.map(row));
            }

            return RefreshIndicator(
              onRefresh: controller.load,
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.standard),
                child: ListView(
                  key: ValueKey(filter),
                  padding: const EdgeInsets.only(bottom: AppSpace.listBottom),
                  children: children,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Quick add: hanya judul. Field dipertahankan bila gagal menyimpan.
class _QuickAdd extends StatefulWidget {
  const _QuickAdd();

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _c.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await Get.find<TasksController>().quickAdd(_c.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _c.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter, AppSpace.sm, AppSpace.gutter, AppSpace.xs),
        child: TextField(
          controller: _c,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Tambah tugas, lalu Enter',
            prefixIcon: const Icon(Icons.add_task),
            suffixIcon: IconButton(
              tooltip: 'Tambah',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _busy ? null : _submit,
            ),
          ),
        ),
      );
}
