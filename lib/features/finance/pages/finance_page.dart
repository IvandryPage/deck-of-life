import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/fields_dialog.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/logic.dart';
import '../controllers/finance_controller.dart';
import '../widgets/account_dialog.dart';
import '../widgets/bill_sheet.dart';
import '../widgets/transaction_sheet.dart';

class FinancePage extends GetView<FinanceController> {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) return const SkeletonList();
      if (controller.errorMessage.value != null) {
        return ErrorState(
          message: controller.errorMessage.value!,
          onRetry: controller.load,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            _SummaryCard(controller: controller),
            _AccountsCard(controller: controller),
            _BillsCard(controller: controller),
            if (controller.transactions.isNotEmpty)
              _TransactionsCard(controller: controller),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final s = controller.summary.value;
    final t = controller.target.value;
    if (s == null || t == null) return const SizedBox.shrink();

    if (!s.hasAccounts) {
      return SectionCard(
        title: 'Ringkasan',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Belum ada saldo. Tambahkan akun (rekening atau uang tunai) dan masukkan saldo '
              'yang Anda lihat sekarang. Tidak perlu mencatat setiap pengeluaran.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showAddAccountDialog(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('Tambah akun'),
            ),
          ],
        ),
      );
    }

    final free = s.estimatedFreeMoney;
    final stale = s.oldestConfirmedAt != null &&
        DateTime.now().difference(s.oldestConfirmedAt!).inDays >= 7;

    return SectionCard(
      title: 'Ringkasan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo terkonfirmasi',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          AmountText(
            Formatters.rupiah(s.confirmedTotal),
            style: theme.textTheme.displaySmall,
            align: TextAlign.start,
          ),
          if (s.lastConfirmedAt != null)
            Text(
              'Terakhir diperbarui ${Formatters.dateTime(s.lastConfirmedAt!)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (stale)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: StatusTag('Ada saldo yang lebih dari 7 hari belum diperbarui',
                  icon: Icons.schedule, warning: true),
            ),
          const Divider(height: 20),
          KeyValueRow('Tagihan belum dibayar', Formatters.rupiah(s.knownUnpaidBills)),
          KeyValueRow(
            'Uang bebas (estimasi)',
            free < 0 ? 'Kurang ${Formatters.rupiah(-free)}' : Formatters.rupiah(free),
            emphasize: true,
          ),
          if (controller.reality.value != null) ..._breakdown(controller.reality.value!),
          Text(
            'Estimasi = saldo terkonfirmasi dikurangi tagihan belum dibayar. Ini bukan saldo bank aktual.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Divider(height: 20),
          _targetSection(context, t, s),
        ],
      ),
    );
  }

  List<Widget> _breakdown(RealityCheck r) => [
        if (r.overdueTotal > 0)
          KeyValueRow('  Sudah lewat jatuh tempo', Formatters.rupiah(r.overdueTotal)),
        KeyValueRow(
          '  Jatuh tempo ${r.horizonDays} hari ke depan',
          Formatters.rupiah(r.dueInHorizonTotal),
        ),
        if (r.laterTotal > 0)
          KeyValueRow('  Lebih dari itu', Formatters.rupiah(r.laterTotal)),
        if (r.fundingGap > 0)
          KeyValueRow(
            'Kesenjangan dana (${r.horizonDays} hari)',
            Formatters.rupiah(r.fundingGap),
            emphasize: true,
          ),
      ];

  Widget _targetSection(BuildContext context, IncomeTarget t, FinanceSummary s) {
    final theme = Theme.of(context);
    final days = controller.workdays.value;
    final income = controller.confirmedIncome.value;

    final Widget headline;
    switch (t.status) {
      case IncomeTargetStatus.notNeeded:
        headline = const KeyValueRow(
          'Target pemasukan/hari',
          'Tidak perlu tambahan',
          emphasize: true,
        );
      case IncomeTargetStatus.needsWorkdays:
        headline = const KeyValueRow(
          'Target pemasukan/hari',
          'Tentukan hari kerja',
          emphasize: true,
        );
      case IncomeTargetStatus.ready:
        headline = KeyValueRow(
          'Target pemasukan/hari (estimasi)',
          Formatters.rupiah(t.dailyTarget!),
          emphasize: true,
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headline,
        const SizedBox(height: 4),
        Text(
          'Asumsi: kewajiban ${Formatters.rupiah(s.knownUnpaidBills)} − dana tersedia '
          '${Formatters.rupiah(s.confirmedTotal)} − pemasukan terkonfirmasi '
          '${Formatters.rupiah(income)} = kekurangan ${Formatters.rupiah(t.fundingGap)}'
          '${days != null && days > 0 ? ', dibagi $days hari kerja' : ''}. '
          'Pemasukan yang belum pasti tidak dihitung.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _editWorkdays(context),
              child: Text(days == null ? 'Atur hari kerja' : 'Hari kerja: $days'),
            ),
            TextButton(
              onPressed: () => _editIncome(context),
              child: const Text('Pemasukan terkonfirmasi'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editWorkdays(BuildContext context) async {
    final r = await showFieldsDialog(
      context,
      title: 'Hari kerja tersedia',
      message: 'Berapa hari Anda bisa bekerja sampai tagihan jatuh tempo?',
      fields: [
        FieldSpec(
          label: 'Jumlah hari',
          numeric: true,
          initial: controller.workdays.value?.toString() ?? '',
        ),
      ],
    );
    if (r == null) return;
    final n = int.tryParse(r[0]);
    await controller.setWorkdays(n == null || n <= 0 ? null : n);
  }

  Future<void> _editIncome(BuildContext context) async {
    final r = await showFieldsDialog(
      context,
      title: 'Pemasukan terkonfirmasi',
      message:
          'Hanya uang yang PASTI akan diterima sebelum jatuh tempo (mis. gaji yang sudah dijanjikan). Kosongkan/0 bila tidak ada.',
      fields: [
        FieldSpec(
          label: 'Nominal (Rp)',
          numeric: true,
          required: false,
          initial: controller.confirmedIncome.value == 0
              ? ''
              : controller.confirmedIncome.value.toString(),
        ),
      ],
    );
    if (r == null) return;
    await controller.setConfirmedIncome(Formatters.parseRupiah(r[0]) ?? 0);
  }
}

// ---------------------------------------------------------------------------

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final accounts = controller.accounts;
    return SectionCard(
      title: 'Akun & saldo',
      trailing: TextButton.icon(
        onPressed: () => showAddAccountDialog(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Akun'),
      ),
      child: accounts.isEmpty
          ? const Text('Belum ada akun.')
          : Column(
              children: [
                for (final a in accounts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.accountType.label} · per ${Formatters.dateTime(a.balanceConfirmedAt)}',
                    ),
                    trailing: Text(
                      Formatters.rupiah(a.confirmedBalance),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    onTap: () => _updateBalance(context, a),
                    onLongPress: () => _accountMenu(context, a),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => showTransactionSheet(context, controller),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Catat transaksi'),
                    ),
                  ],
                ),
                Text(
                  'Ketuk akun untuk memperbarui saldo. Transaksi hanya catatan; tidak mengubah saldo terkonfirmasi.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
    );
  }

  Future<void> _updateBalance(BuildContext context, Account a) async {
    final r = await showFieldsDialog(
      context,
      title: 'Perbarui saldo ${a.name}',
      message:
          'Masukkan saldo aktual yang Anda lihat sekarang. Saldo sebelumnya: ${Formatters.rupiah(a.confirmedBalance)}.',
      fields: [
        FieldSpec(label: 'Saldo aktual (Rp)', numeric: true, initial: a.confirmedBalance.toString()),
        const FieldSpec(label: 'Alasan', required: false, advanced: true, helper: 'mis. koreksi, setelah bayar kost'),
      ],
      confirmLabel: 'Konfirmasi',
    );
    if (r == null) return;
    final value = Formatters.parseRupiah(r[0]);
    if (value == null) return;
    await controller.confirmBalance(a, value, reason: r[1].isEmpty ? null : r[1]);
  }

  Future<void> _accountMenu(BuildContext context, Account a) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Riwayat penyesuaian saldo'),
              onTap: () => Navigator.of(ctx).pop('history'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Ganti nama'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Sembunyikan akun'),
              subtitle: const Text('Tidak dihitung lagi di ringkasan'),
              onTap: () => Navigator.of(ctx).pop('hide'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'history':
        final list = await controller.adjustmentsOf(a);
        if (!context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada penyesuaian.'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final adj in list)
                        ListTile(
                          title: Text(
                            '${Formatters.rupiah(adj.previousBalance)} → ${Formatters.rupiah(adj.correctedBalance)}',
                          ),
                          subtitle: Text(
                            '${Formatters.dateTime(adj.adjustedAt)}'
                            '${adj.reason == null ? '' : ' · ${adj.reason}'}',
                          ),
                        ),
                    ],
                  ),
          ),
        );
      case 'rename':
        final r = await showFieldsDialog(
          context,
          title: 'Ganti nama',
          fields: [FieldSpec(label: 'Nama', initial: a.name)],
        );
        if (r != null) await controller.renameAccount(a, r[0]);
      case 'hide':
        final ok = await confirmDialog(
          context,
          title: 'Sembunyikan akun?',
          message: 'Riwayatnya tetap tersimpan, tetapi saldo tidak lagi masuk ringkasan.',
          confirmLabel: 'Sembunyikan',
        );
        if (ok) await controller.deactivateAccount(a);
    }
  }
}

// ---------------------------------------------------------------------------

class _BillsCard extends StatelessWidget {
  const _BillsCard({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final now = DateTime.now();
    final unpaid = controller.unpaidBills;
    final paid = controller.paidBills;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Tagihan',
      trailing: TextButton.icon(
        onPressed: () => showBillSheet(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Tagihan'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unpaid.isEmpty)
            const Text('Tidak ada tagihan yang belum dibayar.'),
          for (final b in unpaid)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(b.title),
              subtitle: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${Formatters.date(b.dueAt)} · ${DueLabel.of(b.dueAt, now: now)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: b.isOverdue(now) ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (b.isOverdue(now))
                    const StatusTag('Terlambat', icon: Icons.warning_amber, warning: true),
                ],
              ),
              trailing: Text(
                Formatters.rupiah(b.amount),
                style: theme.textTheme.titleSmall,
              ),
              onTap: () => showBillSheet(context, controller, existing: b),
              onLongPress: () => _billMenu(context, b),
            ),
          if (unpaid.isNotEmpty)
            Text(
              'Ketuk untuk mengubah. Tahan untuk menandai dibayar atau menghapus.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (paid.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Sudah dibayar', style: theme.textTheme.labelLarge),
            for (final b in paid)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(b.title),
                subtitle: b.paidAt == null
                    ? null
                    : Text('Dibayar ${Formatters.date(b.paidAt!)}'),
                trailing: Text(Formatters.rupiah(b.amount)),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _billMenu(BuildContext context, Bill b) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Tandai dibayar'),
              subtitle: const Text('Saldo akun tidak berubah otomatis'),
              onTap: () => Navigator.of(ctx).pop('paid'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Hapus tagihan'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'paid') {
      await controller.markPaid(b);
    } else {
      final ok = await confirmDialog(
        context,
        title: 'Hapus tagihan?',
        message: '"${b.title}" dihapus dan tidak lagi dihitung.',
        confirmLabel: 'Hapus',
        destructive: true,
      );
      if (ok) await controller.deleteBill(b);
    }
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  static const int _collapsed = 8;

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final sem = context.semantic;
    final all = controller.filteredTransactions;
    final expanded = controller.txnExpanded.value;
    final shown = expanded ? all : all.take(_collapsed).toList();
    final month = controller.monthSummary(DateTime.now());
    final dir = controller.txnFilter.value;

    return SectionCard(
      title: 'Riwayat transaksi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ringkasan bulan ini: dari transaksi yang dicatat, bukan seluruh arus kas.
          Row(
            children: [
              Expanded(
                child: _MiniTotal(
                  label: 'Masuk bulan ini',
                  value: Formatters.rupiah(month.income),
                  color: sem.income,
                  icon: Icons.south_west,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _MiniTotal(
                  label: 'Keluar bulan ini',
                  value: Formatters.rupiah(month.expense),
                  color: sem.expense,
                  icon: Icons.north_east,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text(
              'Dihitung dari transaksi yang Anda catat saja.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (month.byCategory.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            _CategoryBars(byCategory: month.byCategory, total: month.expense),
          ],
          const SizedBox(height: AppSpace.lg),
          TextField(
            onChanged: (v) => controller.txnQuery.value = v,
            decoration: const InputDecoration(
              hintText: 'Cari kategori, catatan, atau akun',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: dir == null,
                onSelected: (_) => controller.txnFilter.value = null,
              ),
              for (final d in TransactionDirection.values)
                ChoiceChip(
                  label: Text(d.label),
                  selected: dir == d,
                  onSelected: (_) => controller.txnFilter.value = d,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (all.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.receipt_outlined,
              title: 'Tidak ada transaksi yang cocok',
            )
          else
            AnimatedSize(
              duration: AppMotion.of(context, AppMotion.standard),
              curve: AppMotion.standardCurve,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (final t in shown)
                    _TransactionRow(
                      t: t,
                      accountName: controller.accountName(t.accountId),
                      onDelete: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Hapus catatan?',
                          message:
                              'Hanya catatan ini yang dihapus; saldo tidak berubah.',
                          confirmLabel: 'Hapus',
                          destructive: true,
                        );
                        if (ok) await controller.deleteTransaction(t);
                      },
                    ),
                  if (all.length > _collapsed)
                    TextButton(
                      onPressed: () => controller.txnExpanded.value = !expanded,
                      child: Text(expanded
                          ? 'Tampilkan lebih sedikit'
                          : 'Lihat semua (${all.length})'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniTotal extends StatelessWidget {
  const _MiniTotal({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: AppSize.iconXs, color: color),
            const SizedBox(width: AppSpace.xs),
            Flexible(
              child: Text(label,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant)),
            ),
          ]),
          AmountText(value,
              style: context.text.titleMedium, align: TextAlign.start),
        ],
      );
}

/// Distribusi pengeluaran per kategori (maks 4 + "Lainnya"), berlabel dan persen.
class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.byCategory, required this.total});

  final Map<String, int> byCategory;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(4).toList();
    final rest = entries.skip(4).fold<int>(0, (s, e) => s + e.value);
    final rows = [
      ...top.map((e) => (e.key, e.value)),
      if (rest > 0) ('Lainnya', rest),
    ];
    return Column(
      children: [
        for (final (name, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Semantics(
              label: '$name ${(value * 100 / total).round()} persen, ${Formatters.rupiah(value)}',
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.tag,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: value / total),
                        duration: AppMotion.of(context, AppMotion.emphasized),
                        curve: AppMotion.enter,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: context.scheme.surfaceContainerHigh,
                          color: context.semantic.expense,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(value * 100 / total).round()}%',
                      textAlign: TextAlign.end,
                      style: context.text.bodySmall
                          ?.copyWith(fontFeatures: AppText.tabular),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.t,
    required this.accountName,
    required this.onDelete,
  });

  final MoneyTransaction t;
  final String accountName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sem = context.semantic;
    final income = t.direction == TransactionDirection.income;
    final color = income ? sem.income : sem.expense;
    return Semantics(
      label:
          '${income ? "Pemasukan" : "Pengeluaran"} ${Formatters.rupiah(t.amount)}, ${t.category}',
      child: InkWell(
        onLongPress: onDelete,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.tap + 8),
          child: Row(
            children: [
              Container(
                width: AppSize.avatarIcon,
                height: AppSize.avatarIcon,
                decoration: BoxDecoration(
                  color: income ? sem.incomeContainer : sem.expenseContainer,
                  borderRadius: AppRadius.control,
                ),
                child: Icon(income ? Icons.south_west : Icons.north_east,
                    size: AppSize.iconSm, color: color),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge),
                    Text(
                      '$accountName · ${Formatters.dateShort(t.occurredAt)}'
                      '${t.note == null ? '' : ' · ${t.note}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: AmountText(
                  '${income ? '+' : '−'}${Formatters.rupiah(t.amount)}',
                  style: context.text.titleSmall,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
