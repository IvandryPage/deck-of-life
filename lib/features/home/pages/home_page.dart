import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/design/tokens.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/logic.dart';
import '../../finance/controllers/finance_controller.dart';
import '../../finance/widgets/bill_sheet.dart';
import '../../inbox/controllers/inbox_controller.dart';
import '../../inbox/inbox_args.dart';
import '../../shell/controllers/shell_controller.dart';
import '../../tasks/task_args.dart';
import '../../tasks/widgets/task_tile.dart';
import '../controllers/home_controller.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final data = controller.data.value;
    if (controller.isLoading.value && data == null) {
      return const _HomeSkeleton();
    }
    if (data == null) {
      return ErrorState(
        message: controller.errorMessage.value ?? 'Home failed to load.',
        onRetry: controller.load,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xl),
        children: [
          const _Header(),
          _TodaySection(data: data),
          _DeadlinesSection(data: data),
          const _NotesSection(),
        ],
      ),
    );
  });
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpace.gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 180, height: 24),
        SizedBox(height: AppSpace.sm),
        SkeletonBox(width: 120, height: 14),
        SizedBox(height: AppSpace.xl),
        SkeletonBox(height: 180, radius: AppRadius.lg),
        SizedBox(height: AppSpace.md),
        SkeletonBox(height: 160, radius: AppRadius.lg),
        SizedBox(height: AppSpace.md),
        SkeletonBox(height: 170, radius: AppRadius.lg),
      ],
    ),
  );
}

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat('EEE, d MMM', 'en_US').format(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _greeting(now),
                    style: context.text.headlineSmall,
                  ),
                ),
                Text(
                  date,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed<dynamic>(Routes.search),
          ),
        ],
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.sm,
      AppSpace.gutter,
      AppSpace.sm,
    ),
    child: SectionCard(
      title: 'TODAY',
      trailing: IconButton(
        tooltip: 'Add event',
        onPressed: () => Get.toNamed<dynamic>(Routes.eventForm),
        icon: const Icon(Icons.add),
      ),
      child: data.todayEvents.isEmpty
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🗓️', style: TextStyle(fontSize: 24)),
              title: const Text('Nothing scheduled today'),
              trailing: TextButton(
                onPressed: () => Get.toNamed<dynamic>(Routes.eventForm),
                child: const Text('Add event'),
              ),
            )
          : Column(
              children: [
                for (final event in data.todayEvents)
                  ListTile(
                    dense: true,
                    minTileHeight: AppSize.tap,
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 52,
                      child: Text(
                        Formatters.time(event.startsAt),
                        style: context.text.titleSmall?.copyWith(
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                    ),
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: event.location == null
                        ? null
                        : Text(event.location!),
                    onTap: () => Get.toNamed<dynamic>(
                      Routes.eventForm,
                      arguments: event,
                    ),
                  ),
              ],
            ),
    ),
  );
}

class _DeadlinesSection extends StatelessWidget {
  const _DeadlinesSection({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final entries = <({DateTime due, Task? task, Bill? bill})>[
      for (final task in data.nearestDeadlines)
        if (task.dueAt != null) (due: task.dueAt!, task: task, bill: null),
      for (final bill in data.nearestBills)
        (due: bill.dueAt, task: null, bill: bill),
    ]..sort((a, b) => a.due.compareTo(b.due));
    final shown = entries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: AppSpace.sm,
      ),
      child: SectionCard(
        title: 'NEXT DEADLINES',
        trailing: TextButton(
          onPressed: () =>
              Get.find<ShellController>().goTo(ShellController.tabTask),
          child: const Text('All tasks'),
        ),
        child: shown.isEmpty
            ? ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('✨', style: TextStyle(fontSize: 24)),
                title: const Text('No upcoming deadlines'),
                trailing: IconButton(
                  tooltip: 'Add task',
                  onPressed: () => Get.toNamed<dynamic>(
                    Routes.taskForm,
                    arguments: const TaskFormArgs(),
                  ),
                  icon: const Icon(Icons.add),
                ),
              )
            : Column(
                children: [
                  for (final item in shown)
                    if (item.task case final task?)
                      TaskTile(
                        task: task,
                        dense: true,
                        onToggleDone: () =>
                            Get.find<HomeController>().completeTask(task.id),
                        onTap: () => Get.toNamed<dynamic>(
                          Routes.taskDetail,
                          arguments: task.id,
                        ),
                      )
                    else if (item.bill case final bill?)
                      ListTile(
                        dense: true,
                        minTileHeight: AppSize.tap,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.receipt_long_outlined,
                          color: bill.isOverdue(now)
                              ? context.scheme.error
                              : context.scheme.primary,
                        ),
                        title: Text(
                          bill.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_deadlineLabel(bill.dueAt, now)),
                        trailing: Text(
                          Formatters.rupiah(bill.amount),
                          style: context.text.labelLarge,
                        ),
                        onTap: () => showBillSheet(
                          context,
                          Get.find<FinanceController>(),
                          existing: bill,
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  static String _deadlineLabel(DateTime due, DateTime now) {
    final days = DateTimeUtils.calendarDaysBetween(now, due);
    if (due.isBefore(now)) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM', 'en_US').format(due);
  }
}

class _NotesSection extends StatefulWidget {
  const _NotesSection();

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: Get.find<HomeController>().notesQuery.value,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openNotes() {
    final inbox = Get.find<InboxController>();
    inbox.query.value = _search.text.trim();
    Get.find<ShellController>().goTo(ShellController.tabNotes);
  }

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: AppSpace.sm,
      ),
      child: SectionCard(
        title: 'NOTES',
        trailing: TextButton(
          onPressed: _openNotes,
          child: const Text('All notes'),
        ),
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: (value) => home.notesQuery.value = value,
              onSubmitted: (_) => _openNotes(),
              decoration: const InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Obx(() {
              final notes = home.recentNotes;
              if (notes.isEmpty) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('📝', style: TextStyle(fontSize: 24)),
                  title: Text(
                    _search.text.isEmpty ? 'No notes yet' : 'No matching notes',
                  ),
                  trailing: IconButton(
                    tooltip: 'Add note',
                    onPressed: () => Get.toNamed<dynamic>(
                      Routes.savedItemForm,
                      arguments: const SavedItemFormArgs(),
                    ),
                    icon: const Icon(Icons.add),
                  ),
                );
              }
              return Column(
                children: [
                  for (final note in notes)
                    _NoteRow(
                      note: note,
                      onTap: () => Get.toNamed<dynamic>(
                        Routes.savedItemDetail,
                        arguments: note.id,
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onTap});

  final SavedItem note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(note.createdAt);
    final age = elapsed.inHours < 1
        ? '${elapsed.inMinutes.clamp(1, 59)}m ago'
        : elapsed.inDays == 0
        ? '${elapsed.inHours}h ago'
        : elapsed.inDays == 1
        ? 'Yesterday'
        : DateFormat('d MMM', 'en_US').format(note.createdAt);
    final preview = note.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    return ListTile(
      dense: true,
      minTileHeight: AppSize.tap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        note.itemType == SavedItemType.link
            ? Icons.link
            : Icons.sticky_note_2_outlined,
      ),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: preview.isEmpty || preview == note.title
          ? null
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.needsReview) const StatusTag('New', tone: TagTone.info),
          const SizedBox(width: AppSpace.sm),
          Text(age, style: context.text.bodySmall),
        ],
      ),
      onTap: onTap,
    );
  }
}
