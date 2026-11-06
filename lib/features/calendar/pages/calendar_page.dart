import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../shell/controllers/shell_controller.dart';
import '../controllers/android_calendar_controller.dart';
import '../controllers/calendar_controller.dart';

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Tab Kalender: bulan ringkas di atas, daftar hari terpilih di bawah.
class CalendarPage extends GetView<CalendarController> {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.errorMessage.value != null) {
        return ErrorState(
          message: controller.errorMessage.value!,
          onRetry: controller.load,
        );
      }
      final day = controller.selected.value;
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.listBottom),
          children: [
            const _MonthHeader(),
            const _AndroidCalendarControl(),
            const _MonthGrid(),
            const SizedBox(height: AppSpace.sm),
            _DayHeader(day: day),
            if (controller.isLoading.value)
              const Padding(
                padding: EdgeInsets.all(AppSpace.gutter),
                child: Column(
                  children: [
                    SkeletonBox(height: 56, radius: AppRadius.md),
                    SizedBox(height: AppSpace.sm),
                    SkeletonBox(height: 56, radius: AppRadius.md),
                  ],
                ),
              )
            else
              _DayAgenda(day: day),
          ],
        ),
      );
    });
  }
}

class _AndroidCalendarControl extends GetView<AndroidCalendarController> {
  const _AndroidCalendarControl();

  Future<void> _connect(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Android calendars'),
        content: const Text(
          'Deck of Life will read event titles, times, and locations from calendars you select. '
          'They stay read-only unless you separately choose a Google calendar for new Deck events. '
          'Make sure your Google account is synced in Android settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (approved == true) await controller.connect();
  }

  Future<void> _manage(BuildContext context) async {
    await controller.refreshCalendars();
    if (!context.mounted) return;
    final selected = controller.selectedCalendarIds.toSet();
    final initialWriteId =
        controller.calendars.any(
          (calendar) =>
              calendar.id == controller.writeCalendarId.value &&
              calendar.isGoogleAccount,
        )
        ? controller.writeCalendarId.value!
        : '';
    var writeCalendarId = initialWriteId;
    final result =
        await showModalBottomSheet<
          ({List<String> selectedIds, String? writeCalendarId})
        >(
          context: context,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: [
                    const ListTile(title: Text('Calendars to show')),
                    Expanded(
                      child: ListView(
                        children: [
                          if (controller.calendars.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(AppSpace.lg),
                              child: Text(
                                'No visible calendars found. Sync your Google account in Android settings and try again.',
                              ),
                            ),
                          for (final calendar in controller.calendars)
                            CheckboxListTile(
                              value: selected.contains(calendar.id),
                              title: Text(calendar.name),
                              subtitle: Text(
                                [
                                  if (calendar.isGoogleAccount) 'Google',
                                  if (calendar.accountName?.isNotEmpty ?? false)
                                    calendar.accountName!,
                                ].join(' · '),
                              ),
                              onChanged: (checked) => setState(() {
                                if (checked == true) {
                                  selected.add(calendar.id);
                                } else {
                                  selected.remove(calendar.id);
                                }
                              }),
                            ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg,
                              vertical: AppSpace.sm,
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: writeCalendarId,
                              decoration: const InputDecoration(
                                labelText: 'Send new Deck events to',
                                helperText:
                                    'Only Google calendars sync automatically to Google.',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    'Do not write to Android calendar',
                                  ),
                                ),
                                for (final calendar
                                    in controller.calendars.where(
                                      (calendar) => calendar.isGoogleAccount,
                                    ))
                                  DropdownMenuItem(
                                    value: calendar.id,
                                    child: Text(
                                      calendar.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => writeCalendarId = value ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop((
                            selectedIds: selected.toList(),
                            writeCalendarId: writeCalendarId.isEmpty
                                ? null
                                : writeCalendarId,
                          )),
                          child: const Text('Save selection'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    if (result != null) {
      await controller.setSelectedCalendars(result.selectedIds);
      if (result.writeCalendarId != controller.writeCalendarId.value ||
          (result.writeCalendarId != null &&
              !controller.hasWritePermission.value)) {
        await controller.setWriteCalendar(result.writeCalendarId);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final connected = controller.isConnected;
    final selectedNames = controller.selectedCalendars
        .map((calendar) => calendar.name)
        .join(', ');
    String? writeCalendarName;
    for (final calendar in controller.calendars) {
      if (calendar.id == controller.writeCalendarId.value) {
        writeCalendarName = calendar.name;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.sync : Icons.calendar_month_outlined,
                size: AppSize.iconSm,
                color: context.scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  connected
                      ? 'Android · $selectedNames'
                      : controller.hasReadPermission.value
                      ? 'No calendars selected'
                      : 'Google calendars are not connected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: controller.isLoading.value
                    ? null
                    : connected || controller.hasReadPermission.value
                    ? () => _manage(context)
                    : () => _connect(context),
                child: Text(
                  controller.isLoading.value
                      ? 'Loading'
                      : connected || controller.hasReadPermission.value
                      ? 'Manage'
                      : 'Connect',
                ),
              ),
            ],
          ),
          if (controller.writeCalendarId.value != null)
            Text(
              controller.hasWritePermission.value
                  ? 'New Deck events go to ${writeCalendarName ?? 'Google Calendar'}.'
                  : 'Calendar write permission is needed to send new Deck events.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          if (controller.errorMessage.value != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                controller.errorMessage.value!,
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  });
}

class _MonthHeader extends GetView<CalendarController> {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = controller.month.value;
      final mode = controller.viewMode.value;
      final week = controller.visibleWeek;
      final today = DateTimeUtils.startOfDay(DateTime.now());
      final isCurrent = mode == CalendarViewMode.week
          ? week.any((day) => DateTimeUtils.isSameDay(day, today))
          : DateTimeUtils.isSameDay(
              DateTime(m.year, m.month),
              DateTime(DateTime.now().year, DateTime.now().month),
            );
      final title = mode == CalendarViewMode.week
          ? '${Formatters.dateShort(week.first)} – ${Formatters.dateShort(week.last)}'
          : '${_months[m.month - 1]} ${m.year}';
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, 0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: mode == CalendarViewMode.week
                      ? 'Previous week'
                      : 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => mode == CalendarViewMode.week
                      ? controller.shiftWeek(-1)
                      : controller.shiftMonth(-1),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                  ),
                ),
                if (!isCurrent)
                  TextButton(
                    onPressed: controller.goToday,
                    child: const Text('Today'),
                  ),
                IconButton(
                  tooltip: mode == CalendarViewMode.week
                      ? 'Next week'
                      : 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => mode == CalendarViewMode.week
                      ? controller.shiftWeek(1)
                      : controller.shiftMonth(1),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: SegmentedButton<CalendarViewMode>(
                segments: const [
                  ButtonSegment(
                    value: CalendarViewMode.month,
                    label: Text('Month'),
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                  ButtonSegment(
                    value: CalendarViewMode.week,
                    label: Text('Week'),
                    icon: Icon(Icons.view_week_outlined),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    controller.setViewMode(value.single),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MonthGrid extends GetView<CalendarController> {
  const _MonthGrid();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = controller.month.value;
      // Baca Rx di dalam builder agar Obx berlangganan.
      final selected = controller.selected.value;
      final dir = controller.direction.value;
      // Ketergantungan ke peta data agar titik penanda ikut diperbarui.
      controller.eventsByDay.length;
      controller.tasksByDay.length;
      controller.billsByDay.length;

      final first = DateTime(m.year, m.month, 1);
      final lead = (first.weekday + 6) % 7; // Senin = 0
      final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
      final rows = ((lead + daysInMonth) / 7).ceil();
      final today = DateTimeUtils.startOfDay(DateTime.now());

      final weekMode = controller.viewMode.value == CalendarViewMode.week;
      final week = controller.visibleWeek;
      Widget grid = weekMode
          ? Padding(
              key: ValueKey('week-${week.first.toIso8601String()}'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: _DayCell(
                        date: day,
                        isToday: DateTimeUtils.isSameDay(day, today),
                        isSelected: DateTimeUtils.isSameDay(day, selected),
                        markers: controller.markersOn(day),
                        onTap: () => controller.select(day),
                      ),
                    ),
                ],
              ),
            )
          : Padding(
              key: ValueKey('${m.year}-${m.month}'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++)
                    Row(
                      children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                final n = r * 7 + c - lead + 1;
                                if (n < 1 || n > daysInMonth) {
                                  return const SizedBox(
                                    height: AppSize.calendarCell,
                                  );
                                }
                                final d = DateTime(m.year, m.month, n);
                                return _DayCell(
                                  date: d,
                                  isToday: DateTimeUtils.isSameDay(d, today),
                                  isSelected: DateTimeUtils.isSameDay(
                                    d,
                                    selected,
                                  ),
                                  markers: controller.markersOn(d),
                                  onTap: () => controller.select(d),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Row(
              children: [
                for (final w in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: context.text.labelMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(0.08 * dir, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: grid,
          ),
        ],
      );
    });
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.markers,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final int markers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = isSelected ? scheme.primary : Colors.transparent;
    final fg = isSelected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${Formatters.date(date)}'
          '${isToday ? ', today' : ''}'
          '${markers > 0 ? ', $markers items' : ''}',
      child: InkResponse(
        onTap: onTap,
        radius: AppSize.calendarCell / 2 + 4,
        child: SizedBox(
          height: AppSize.calendarCell + 4,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.micro),
              curve: AppMotion.standardCurve,
              width: AppSize.calendarCell - 6,
              height: AppSize.calendarCell - 6,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.control,
                // Hari ini dibedakan dengan cincin, bukan hanya warna.
                border: isToday && !isSelected
                    ? Border.all(color: scheme.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: context.text.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w700
                          : null,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                  if (markers > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? scheme.onPrimary : scheme.primary,
                      ),
                    )
                  else
                    const SizedBox(height: 7),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = DateTimeUtils.startOfDay(DateTime.now());
    return SectionHeader(
      DateTimeUtils.isSameDay(day, today)
          ? 'Today · ${Formatters.dateShort(day)}'
          : Formatters.dateShort(day),
      trailing: TextButton.icon(
        onPressed: () => Get.toNamed<dynamic>(Routes.eventForm, arguments: day),
        icon: const Icon(Icons.add, size: AppSize.iconSm),
        label: const Text('Add event'),
      ),
    );
  }
}

class _DayAgenda extends GetView<CalendarController> {
  const _DayAgenda({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.eventsByDay.length;
      final events = controller.eventsOn(day);
      final tasks = controller.tasksOn(day);
      final bills = controller.billsOn(day);
      if (events.isEmpty && tasks.isEmpty && bills.isEmpty) {
        return EmptyState(
          compact: true,
          icon: Icons.event_available_outlined,
          title: 'Nothing scheduled',
          message:
              'Your day is clear. Add an event with just a title and time.',
          actionLabel: 'Add event',
          onAction: () =>
              Get.toNamed<dynamic>(Routes.eventForm, arguments: day),
        );
      }
      final now = DateTime.now();
      return AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.standard),
        child: Column(
          key: ValueKey(day),
          children: [
            for (final e in events) _EventRow(event: e, now: now),
            for (final t in tasks)
              _InfoRow(
                icon: Icons.flag_outlined,
                kind: 'Task deadline',
                title: t.title,
                trailing: Formatters.time(t.dueAt!),
                onTap: () =>
                    Get.toNamed<dynamic>(Routes.taskDetail, arguments: t.id),
              ),
            for (final b in bills)
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                kind: 'Bill due',
                title: b.title,
                trailing: Formatters.rupiah(b.amount),
                onTap: () => Get.find<ShellController>().goTo(
                  ShellController.tabFinance,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _EventRow extends GetView<CalendarController> {
  const _EventRow({required this.event, required this.now});
  final Event event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final over = (e.endsAt ?? e.startsAt).isBefore(now);
    final ongoing = !e.startsAt.isAfter(now) && !over && e.endsAt != null;
    final scheme = context.scheme;
    if (e.isDeviceCalendarEvent) {
      return ListTile(
        minTileHeight: AppSize.tap + 8,
        leading: SizedBox(
          width: 52,
          child: Text(
            e.isAllDay ? 'All day' : Formatters.time(e.startsAt),
            style: context.text.labelLarge?.copyWith(
              fontFeatures: AppText.tabular,
            ),
          ),
        ),
        title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            e.externalCalendarName ?? 'Android calendar',
            if (e.location != null) e.location!,
            if (e.endsAt != null && !e.isAllDay)
              'Until ${Formatters.time(e.endsAt!)}',
          ].join(' · '),
        ),
        trailing: const Tooltip(
          message: 'Read-only Android calendar event',
          child: Icon(Icons.lock_outline, size: AppSize.iconSm),
        ),
      );
    }
    return Dismissible(
      key: ValueKey('ev-${e.id}-${e.startsAt.toIso8601String()}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.xl),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
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
        minTileHeight: AppSize.tap + 8,
        leading: SizedBox(
          width: 52,
          child: Text(
            Formatters.time(e.startsAt),
            style: context.text.titleSmall?.copyWith(
              fontFeatures: AppText.tabular,
              color: over ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
        title: Text(
          e.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: over ? TextStyle(color: scheme.onSurfaceVariant) : null,
        ),
        subtitle: Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              [
                e.eventType.label,
                if (e.endsAt != null) 'Until ${Formatters.time(e.endsAt!)}',
                if (e.location != null) e.location!,
              ].join(' · '),
            ),
            if (e.isRecurring) const StatusTag('Repeats', icon: Icons.repeat),
            if (ongoing)
              const StatusTag(
                'In progress',
                icon: Icons.play_arrow,
                tone: TagTone.success,
              )
            else if (over)
              const StatusTag('Ended', icon: Icons.check),
          ],
        ),
        onTap: () => Get.toNamed<dynamic>(Routes.eventForm, arguments: e),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.kind,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String kind;
  final String title;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: AppSize.tap + 8,
    leading: SizedBox(
      width: 52,
      child: Icon(icon, color: context.scheme.onSurfaceVariant),
    ),
    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(kind),
    trailing: Text(trailing, style: context.text.labelLarge),
    onTap: onTap,
  );
}
