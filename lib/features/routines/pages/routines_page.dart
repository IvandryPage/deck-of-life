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

  static const List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  static String describe(Routine r) {
    switch (r.recurrenceType) {
      case RecurrenceType.daily:
        return 'Setiap hari';
      case RecurrenceType.interval:
        return 'Setiap ${r.intervalDays} hari';
      case RecurrenceType.weekly:
        final days = [...r.weekdays]..sort();
        return days.map((d) => _dayNames[d - 1]).join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutinitas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed<dynamic>(Routes.routineForm),
        icon: const Icon(Icons.add),
        label: const Text('Rutinitas baru'),
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
            title: 'Belum ada rutinitas',
            message: 'mis. bersih-bersih kost setiap 3 hari.',
            actionLabel: 'Rutinitas baru',
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
              onTap: () => Get.toNamed<dynamic>(Routes.routineForm, arguments: r),
              title: Text(r.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(describe(r)),
                  Text(
                    r.lastCompletedAt == null
                        ? 'Belum pernah dilakukan'
                        : 'Terakhir: ${Formatters.dateTime(r.lastCompletedAt!)}',
                  ),
                  if (r.isActive && r.nextDueAt != null)
                    Text(
                      due
                          ? 'Berikutnya: jatuh tempo (${Formatters.dateShort(r.nextDueAt!)})'
                          : 'Berikutnya: ${Formatters.dateShort(r.nextDueAt!)}',
                    ),
                  if (!r.isActive) const StatusTag('Nonaktif'),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (due) const StatusTag('Jatuh tempo', icon: Icons.schedule, warning: true),
                  if (r.isActive)
                    IconButton(
                      tooltip: 'Tandai selesai',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => controller.complete(r),
                    ),
                  IconButton(
                    tooltip: 'Riwayat',
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
                child: Text('Belum ada riwayat pelaksanaan.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(r.title, style: Theme.of(ctx).textTheme.titleMedium),
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
