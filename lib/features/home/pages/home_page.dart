import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/logic.dart';
import '../../finance/controllers/finance_controller.dart';
import '../../finance/widgets/account_dialog.dart';
import '../../finance/widgets/bill_sheet.dart';
import '../../finance/widgets/transaction_sheet.dart';
import '../../shell/controllers/shell_controller.dart';
import '../../tasks/task_args.dart';
import '../../tasks/widgets/task_tile.dart';
import '../controllers/home_controller.dart';

/// Pusat komando pribadi. Menjawab tiga hal: apa yang perlu dilakukan hari ini,
/// bagaimana kondisi uang, dan apa yang terpenting berikutnya.
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.data.value;
      if (controller.isLoading.value && data == null) {
        return const _HomeSkeleton();
      }
      if (data == null) {
        return ErrorState(
          message: controller.errorMessage.value ?? 'Beranda gagal dimuat.',
          onRetry: controller.load,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xl),
          children: [
            const _Header(),
            const _QuickCapture(),
            const _QuickActions(),
            if (data.nextAction != null)
              FadeSlideIn(child: _NextActionCard(action: data.nextAction!)),
            FadeSlideIn(delayIndex: 1, child: _FinanceSnapshot(data: data)),
            FadeSlideIn(delayIndex: 2, child: _TodayCard(data: data)),
            FadeSlideIn(delayIndex: 3, child: _PriorityTasks(data: data)),
            if (data.nextRoutines.isNotEmpty)
              FadeSlideIn(delayIndex: 4, child: _RoutineCard(data: data)),
            if (data.backupReminder) const _BackupBanner(),
          ],
        ),
      );
    });
  }
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
            SkeletonBox(height: 52, radius: AppRadius.md),
            SizedBox(height: AppSpace.lg),
            SkeletonBox(height: 140, radius: AppRadius.lg),
            SizedBox(height: AppSpace.md),
            SkeletonBox(height: 110, radius: AppRadius.lg),
            SizedBox(height: AppSpace.md),
            SkeletonBox(height: 110, radius: AppRadius.lg),
          ],
        ),
      );
}

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 19) return 'Selamat sore';
  return 'Selamat malam';
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter, AppSpace.md, AppSpace.sm, AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(_greeting(now), style: context.text.headlineSmall),
                ),
                Text(
                  Formatters.date(now),
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed<dynamic>(Routes.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu lainnya',
            onSelected: (route) => Get.toNamed<dynamic>(route),
            itemBuilder: (_) => const [
              PopupMenuItem(value: Routes.routines, child: Text('Rutinitas')),
              PopupMenuItem(value: Routes.settings, child: Text('Pengaturan')),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCapture extends StatefulWidget {
  const _QuickCapture();

  @override
  State<_QuickCapture> createState() => _QuickCaptureState();
}

class _QuickCaptureState extends State<_QuickCapture> {
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
    final ok = await Get.find<HomeController>().quickCapture(_c.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _c.clear(); // Gagal: teks dipertahankan.
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter, AppSpace.sm, AppSpace.gutter, AppSpace.xs),
        child: TextField(
          controller: _c,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Simpan cepat: teks atau tautan',
            prefixIcon: const Icon(Icons.bolt_outlined),
            suffixIcon: IconButton(
              tooltip: 'Simpan ke Informasi',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _busy ? null : _submit,
            ),
          ),
        ),
      );
}

/// Aksi cepat: setiap tombol membuka form ringkas (bottom sheet / form singkat).
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            label: 'Tambah $label',
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.control,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.tap + 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: AppSize.tap,
                      height: AppSize.tap - 8,
                      decoration: BoxDecoration(
                        color: context.scheme.secondaryContainer,
                        borderRadius: AppRadius.control,
                      ),
                      child: Icon(icon,
                          color: context.scheme.onSecondaryContainer),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(label, style: context.text.labelMedium),
                  ],
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.xs),
      child: Row(
        children: [
          item(Icons.payments_outlined, 'Transaksi', () {
            showTransactionSheet(context, Get.find<FinanceController>());
          }),
          item(Icons.add_task, 'Tugas', () {
            Get.toNamed<dynamic>(Routes.taskForm, arguments: const TaskFormArgs());
          }),
          item(Icons.event_outlined, 'Agenda', () {
            Get.toNamed<dynamic>(Routes.eventForm);
          }),
          item(Icons.receipt_long_outlined, 'Tagihan', () {
            showBillSheet(context, Get.find<FinanceController>());
          }),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.action});
  final NextAction action;

  void _open() {
    final shell = Get.find<ShellController>();
    switch (action.kind) {
      case NextActionKind.overdueTask:
        Get.toNamed<dynamic>(Routes.overdue);
      case NextActionKind.reviewTask:
      case NextActionKind.task:
        final id = action.targetId;
        if (id != null) Get.toNamed<dynamic>(Routes.taskDetail, arguments: id);
      case NextActionKind.bill:
        shell.goTo(ShellController.tabFinance);
      case NextActionKind.reviewItems:
        shell.goTo(ShellController.tabInfo);
      case NextActionKind.routine:
        Get.toNamed<dynamic>(Routes.routines);
      case NextActionKind.resume:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tappable = action.kind != NextActionKind.resume;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter, vertical: AppSpace.xs + 2),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tappable ? _open : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lakukan berikutnya',
                        style: context.text.labelMedium
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        action.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.reason,
                        style: context.text.bodyMedium
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                if (tappable)
                  Icon(Icons.arrow_forward, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Snapshot keuangan: fakta (saldo terkonfirmasi) dipisah dari estimasi.
class _FinanceSnapshot extends StatelessWidget {
  const _FinanceSnapshot({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final r = data.reality;
    final shell = Get.find<ShellController>();

    if (!r.hasAccounts) {
      return SectionCard(
        title: 'Keuangan',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan saldo terakhir Anda agar uang bebas dan target harian bisa dihitung.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton.tonal(
              onPressed: () =>
                  showAddAccountDialog(context, Get.find<FinanceController>()),
              child: const Text('Tambah akun'),
            ),
          ],
        ),
      );
    }

    final sem = context.semantic;
    final free = r.estimatedFree;
    return SectionCard(
      title: 'Saldo terkonfirmasi',
      onTap: () => shell.goTo(ShellController.tabFinance),
      trailing: const Icon(Icons.chevron_right),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AmountText(
            Formatters.rupiah(r.confirmedTotal),
            style: context.text.displaySmall,
            align: TextAlign.start,
          ),
          if (r.lastConfirmedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Wrap(
                spacing: AppSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'per ${Formatters.dateTime(r.lastConfirmedAt!)}',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                  if (r.balanceStale)
                    const StatusTag('Perlu diperbarui',
                        icon: Icons.schedule, tone: TagTone.warning),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Tagihan belum dibayar',
                  value: Formatters.rupiah(r.unpaidTotal),
                  note: r.overdueCount > 0 ? '${r.overdueCount} terlambat' : null,
                  noteColor: sem.expense,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _Stat(
                  label: 'Uang bebas (estimasi)',
                  value: free < 0
                      ? 'Kurang ${Formatters.rupiah(-free)}'
                      : Formatters.rupiah(free),
                  valueColor: free < 0 ? sem.expense : null,
                ),
              ),
            ],
          ),
          if (r.fundingGap > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: StatusTag(
                'Kurang ${Formatters.rupiah(r.fundingGap)} untuk ${r.horizonDays} hari ke depan',
                icon: Icons.info_outline,
                tone: TagTone.warning,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.note,
    this.noteColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? note;
  final Color? noteColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          AmountText(
            value,
            style: context.text.titleMedium,
            color: valueColor,
            align: TextAlign.start,
          ),
          if (note != null)
            Text(note!,
                style: context.text.bodySmall
                    ?.copyWith(color: noteColor, fontWeight: FontWeight.w600)),
        ],
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final events = data.todayEvents;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Agenda hari ini',
      onTap: () => Get.find<ShellController>().goTo(ShellController.tabCalendar),
      trailing: const Icon(Icons.chevron_right),
      child: events.isEmpty
          ? Text(
              'Tidak ada agenda hari ini.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final e in events)
                  ListTile(
                    dense: true,
                    minTileHeight: AppSize.tap,
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 52,
                      child: Text(
                        Formatters.time(e.startsAt),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontFeatures: AppText.tabular),
                      ),
                    ),
                    title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: e.location == null ? null : Text(e.location!),
                    onTap: () =>
                        Get.toNamed<dynamic>(Routes.eventForm, arguments: e),
                  ),
              ],
            ),
    );
  }
}

class _PriorityTasks extends GetView<HomeController> {
  const _PriorityTasks({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tasks = data.nearestDeadlines;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Tugas prioritas',
      trailing: data.overdueTaskCount > 0
          ? TextButton(
              onPressed: () => Get.toNamed<dynamic>(Routes.overdue),
              child: Text('${data.overdueTaskCount} terlambat'),
            )
          : TextButton(
              onPressed: () =>
                  Get.find<ShellController>().goTo(ShellController.tabTask),
              child: const Text('Semua'),
            ),
      child: tasks.isEmpty
          ? Text(
              'Belum ada tugas dengan deadline.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final t in tasks)
                  TaskTile(
                    task: t,
                    dense: true,
                    onToggleDone: () => controller.completeTask(t.id),
                    onTap: () => Get.toNamed<dynamic>(
                      Routes.taskDetail,
                      arguments: t.id,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SectionCard(
      title: data.dueRoutineCount > 0
          ? 'Rutinitas (${data.dueRoutineCount} jatuh tempo)'
          : 'Rutinitas berikutnya',
      onTap: () => Get.toNamed<dynamic>(Routes.routines),
      trailing: const Icon(Icons.chevron_right),
      child: Column(
        children: [
          for (final r in data.nextRoutines)
            ListTile(
              dense: true,
              minTileHeight: AppSize.tap,
              contentPadding: EdgeInsets.zero,
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                r.isDue(now) ? 'Jatuh tempo' : Formatters.dateShort(r.nextDueAt!),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupBanner extends StatelessWidget {
  const _BackupBanner();

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Amankan data Anda',
        onTap: () => Get.toNamed<dynamic>(Routes.settings),
        trailing: const Icon(Icons.chevron_right),
        child: const Text(
          'Belum ada backup baru-baru ini. Ekspor di Pengaturan agar data tidak hilang.',
        ),
      );
}
