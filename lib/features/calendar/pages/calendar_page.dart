import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../shell/controllers/shell_controller.dart';
import '../controllers/calendar_controller.dart';

const List<String> _weekdays = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];
const List<String> _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
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

class _MonthHeader extends GetView<CalendarController> {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = controller.month.value;
      final isCurrent = DateTimeUtils.isSameDay(
        DateTime(m.year, m.month),
        DateTime(DateTime.now().year, DateTime.now().month),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Bulan sebelumnya',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => controller.shiftMonth(-1),
            ),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  '${_months[m.month - 1]} ${m.year}',
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
              ),
            ),
            if (!isCurrent)
              TextButton(
                onPressed: controller.goToday,
                child: const Text('Hari ini'),
              ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => controller.shiftMonth(1),
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

      Widget grid = Padding(
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
                            return const SizedBox(height: AppSize.calendarCell);
                          }
                          final d = DateTime(m.year, m.month, n);
                          return _DayCell(
                            date: d,
                            isToday: DateTimeUtils.isSameDay(d, today),
                            isSelected: DateTimeUtils.isSameDay(d, selected),
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
          '${isToday ? ', hari ini' : ''}'
          '${markers > 0 ? ', $markers entri' : ''}',
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
          ? 'Hari ini · ${Formatters.dateShort(day)}'
          : Formatters.dateShort(day),
      trailing: TextButton.icon(
        onPressed: () => Get.toNamed<dynamic>(Routes.eventForm, arguments: day),
        icon: const Icon(Icons.add, size: AppSize.iconSm),
        label: const Text('Agenda'),
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
          title: 'Tidak ada agenda',
          message:
              'Hari ini kosong. Tambahkan agenda cukup dengan judul dan waktu.',
          actionLabel: 'Agenda baru',
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
                kind: 'Deadline tugas',
                title: t.title,
                trailing: Formatters.time(t.dueAt!),
                onTap: () =>
                    Get.toNamed<dynamic>(Routes.taskDetail, arguments: t.id),
              ),
            for (final b in bills)
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                kind: 'Tagihan jatuh tempo',
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
        title: 'Hapus agenda?',
        message: e.isRecurring
            ? 'Seluruh rangkaian "${e.title}" dan pengingatnya akan dihapus.'
            : '"${e.title}" dan pengingatnya akan dihapus.',
        confirmLabel: 'Hapus',
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
                if (e.endsAt != null) 's.d. ${Formatters.time(e.endsAt!)}',
                if (e.location != null) e.location!,
              ].join(' · '),
            ),
            if (e.isRecurring) const StatusTag('Berulang', icon: Icons.repeat),
            if (ongoing)
              const StatusTag(
                'Berlangsung',
                icon: Icons.play_arrow,
                tone: TagTone.success,
              )
            else if (over)
              const StatusTag('Selesai', icon: Icons.check),
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
