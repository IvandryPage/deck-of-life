import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../controllers/routines_controller.dart';

class RoutinesPage extends GetView<RoutinesController> {
  const RoutinesPage({super.key});

  static const List<String> _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String describe(Routine r) {
    switch (r.recurrenceType) {
      case RecurrenceType.daily:
        return 'Every day';
      case RecurrenceType.interval:
        return 'Every ${r.intervalDays} days';
      case RecurrenceType.weekly:
        final days = [...r.weekdays]..sort();
        return days.map((d) => _dayNames[d - 1]).join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed<dynamic>(Routes.routineForm),
        icon: const Icon(Icons.add),
        label: const Text('New routine'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const SkeletonList();
        }
        if (controller.errorMessage.value != null) {
          return ErrorState(
            message: controller.errorMessage.value!,
            onRetry: controller.load,
          );
        }
        final list = controller.routines;
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.repeat,
            title: 'No routines yet',
            message: 'For example, tidy your room every 3 days.',
            actionLabel: 'New routine',
            onAction: () => Get.toNamed<dynamic>(Routes.routineForm),
          );
        }
        final now = DateTime.now();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = list[i];
            final due = r.isDue(now);
            return ListTile(
              onTap: () =>
                  Get.toNamed<dynamic>(Routes.routineForm, arguments: r),
              title: Text(r.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(describe(r)),
                  Text(
                    r.lastCompletedAt == null
                        ? 'Never completed'
                        : 'Last completed: ${Formatters.dateTime(r.lastCompletedAt!)}',
                  ),
                  if (r.isActive && r.nextDueAt != null)
                    Text(
                      due
                          ? 'Next: due (${Formatters.dateShort(r.nextDueAt!)})'
                          : 'Next: ${Formatters.dateShort(r.nextDueAt!)}',
                    ),
                  if (!r.isActive) const StatusTag('Inactive'),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (due)
                    const StatusTag('Due', icon: Icons.schedule, warning: true),
                  if (r.isActive)
                    IconButton(
                      tooltip: 'Mark complete',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => controller.complete(r),
                    ),
                  IconButton(
                    tooltip: 'History',
                    icon: const Icon(Icons.history),
                    onPressed: () => _showLogs(context, r),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _showLogs(BuildContext context, Routine r) async {
    final logs = await controller.logsOf(r);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: logs.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No completion history yet.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      r.title,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  for (final l in logs)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check),
                      title: Text(Formatters.dateTime(l.completedAt)),
                      subtitle: l.note == null ? null : Text(l.note!),
                    ),
                ],
              ),
      ),
    );
  }
}
