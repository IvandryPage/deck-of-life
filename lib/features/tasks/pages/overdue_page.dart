import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../home/controllers/home_controller.dart';

/// Recovery flow for overdue tasks: complete, reschedule, or cancel each task.
class OverduePage extends GetView<HomeController> {
  const OverduePage({super.key});

  /// Days until next Saturday (at least one).
  static int daysToWeekend(DateTime now) {
    final d = (DateTime.saturday - now.weekday) % 7;
    return d == 0 ? 7 : d;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overdue tasks')),
      body: Obx(() {
        final tasks = controller.data.value?.overdueTasks ?? const [];
        if (tasks.isEmpty) {
          return const Center(child: Text('No overdue tasks.'));
        }
        final now = DateTime.now();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: tasks.length,
          itemBuilder: (_, i) {
            final t = tasks[i];
            return Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Get.toNamed<dynamic>(Routes.taskDetail,
                          arguments: t.id),
                      child: Text(t.title,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text('Due ${Formatters.dateTime(t.dueAt!)}'),
                    Wrap(spacing: 8, children: [
                      ActionChip(
                        label: const Text('Done'),
                        onPressed: () => controller.completeTask(t.id),
                      ),
                      ActionChip(
                        label: const Text('Tomorrow'),
                        onPressed: () => controller.moveTask(t.id, 1),
                      ),
                      ActionChip(
                        label: const Text('This weekend'),
                        onPressed: () =>
                            controller.moveTask(t.id, daysToWeekend(now)),
                      ),
                      ActionChip(
                        label: const Text('Cancel'),
                        onPressed: () => controller.dropTask(t.id),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
