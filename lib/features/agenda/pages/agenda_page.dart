import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../controllers/agenda_controller.dart';

class AgendaPage extends GetView<AgendaController> {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed<dynamic>(Routes.eventForm),
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null) {
          return ErrorState(
            message: controller.errorMessage.value!,
            onRetry: controller.load,
          );
        }
        final events = controller.events;
        if (events.isEmpty) {
          return EmptyState(
            icon: Icons.event_outlined,
            title: 'No upcoming events',
            message: 'A title and start time are all you need.',
            actionLabel: 'Add event',
            onAction: () => Get.toNamed<dynamic>(Routes.eventForm),
          );
        }

        // Kelompokkan per hari kalender lokal.
        final days = <DateTime, List<Event>>{};
        for (final e in events) {
          days
              .putIfAbsent(DateTimeUtils.startOfDay(e.startsAt), () => [])
              .add(e);
        }
        final keys = days.keys.toList()..sort();
        final today = DateTimeUtils.startOfDay(DateTime.now());

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final day in keys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    DateTimeUtils.isSameDay(day, today)
                        ? 'Today · ${Formatters.dateShort(day)}'
                        : Formatters.dateShort(day),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final e in days[day]!)
                  Dismissible(
                    key: ValueKey('${e.id}-${e.startsAt.toIso8601String()}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Theme.of(context).colorScheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete_outline),
                    ),
                    confirmDismiss: (_) => confirmDialog(
                      context,
                      title: 'Delete event?',
                      message: e.isRecurring
                          ? 'The entire "${e.title}" series and its reminder will be deleted.'
                          : '"${e.title}" and its reminder will be deleted.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    ),
                    onDismissed: (_) => controller.remove(e),
                    child: ListTile(
                      leading: SizedBox(
                        width: 56,
                        child: Text(
                          Formatters.time(e.startsAt),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      title: Text(e.title),
                      subtitle: Text(
                        [
                          e.eventType.label,
                          if (e.isRecurring) 'Repeats',
                          if (e.endsAt != null)
                            'Until ${Formatters.time(e.endsAt!)}',
                          if (e.location != null) e.location!,
                        ].join(' · '),
                      ),
                      onTap: () =>
                          Get.toNamed<dynamic>(Routes.eventForm, arguments: e),
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
