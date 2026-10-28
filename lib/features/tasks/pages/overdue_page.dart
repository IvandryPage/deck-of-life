import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../home/controllers/home_controller.dart';

/// Pemulihan: tugas yang lewat deadline ditangani satu per satu tanpa form.
/// Pilihan: selesai, besok, akhir pekan, atau batalkan.
class OverduePage extends GetView<HomeController> {
  const OverduePage({super.key});

  /// Hari sampai Sabtu berikutnya (minimal 1).
  static int daysToWeekend(DateTime now) {
    final d = (DateTime.saturday - now.weekday) % 7;
    return d == 0 ? 7 : d;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tugas terlewat')),
      body: Obx(() {
        final tasks = controller.data.value?.overdueTasks ?? const [];
        if (tasks.isEmpty) {
          return const Center(child: Text('Tidak ada tugas terlewat.'));
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
                    Text('Tenggat ${Formatters.dateTime(t.dueAt!)}'),
                    Wrap(spacing: 8, children: [
                      ActionChip(
                        label: const Text('Selesai'),
                        onPressed: () => controller.completeTask(t.id),
                      ),
                      ActionChip(
                        label: const Text('Besok'),
                        onPressed: () => controller.moveTask(t.id, 1),
                      ),
                      ActionChip(
                        label: const Text('Akhir pekan'),
                        onPressed: () =>
                            controller.moveTask(t.id, daysToWeekend(now)),
                      ),
                      ActionChip(
                        label: const Text('Batalkan'),
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
