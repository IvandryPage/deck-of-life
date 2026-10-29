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
import '../widgets/transfer_sheet.dart';
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
            _WalletOverview(controller: controller),
            _TransactionsCard(controller: controller),
            _BillsCard(controller: controller),
            _AccountsCard(controller: controller),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.gutter,
                vertical: AppSpace.sm,
              ),
              child: ExpansionTile(
                title: const Text('Insights'),
                children: [
                  _TransactionInsights(controller: controller),
                  _SummaryCard(controller: controller),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------

class _WalletOverview extends StatelessWidget {
  const _WalletOverview({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final accounts = controller.accounts;
    final total = accounts.fold<int>(
      0,
      (sum, account) => sum + account.confirmedBalance,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.sm,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: SectionCard(
        title: 'Total',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmountText(
              Formatters.rupiah(total),
              style: context.text.displaySmall,
              align: TextAlign.start,
            ),
            const SizedBox(height: AppSpace.md),
            if (accounts.isEmpty)
              const Text('Add a wallet to start tracking money.')
            else
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpace.sm),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return Container(
                      constraints: const BoxConstraints(minWidth: 132),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: AppSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: context.scheme.secondaryContainer,
                        borderRadius: AppRadius.control,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          AmountText(
                            Formatters.rupiah(account.confirmedBalance),
                            style: context.text.titleSmall,
                            align: TextAlign.start,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: _MoneyAction(
                    label: 'Income',
                    icon: Icons.south_west,
                    color: context.semantic.income,
                    onPressed: accounts.isEmpty
                        ? null
                        : () => showTransactionSheet(
                            context,
                            controller,
                            direction: TransactionDirection.income,
                          ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _MoneyAction(
                    label: 'Expense',
                    icon: Icons.north_east,
                    color: context.semantic.expense,
                    onPressed: accounts.isEmpty
                        ? null
                        : () => showTransactionSheet(
                            context,
                            controller,
                            direction: TransactionDirection.expense,
                          ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _MoneyAction(
                    label: 'Transfer',
                    icon: Icons.swap_horiz,
                    onPressed: accounts.length < 2
                        ? null
                        : () => showTransferSheet(context, controller),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  });
}

class _MoneyAction extends StatelessWidget {
  const _MoneyAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: AppSize.iconSm, color: color),
    label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
    ),
  );
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
        title: 'Summary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No balance yet. Add a wallet, such as cash or a bank account, and enter its current balance. '
              'You do not need to record every expense.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showAddAccountDialog(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('Add wallet'),
            ),
          ],
        ),
      );
    }

    final free = s.estimatedFreeMoney;
    final stale =
        s.oldestConfirmedAt != null &&
        DateTime.now().difference(s.oldestConfirmedAt!).inDays >= 7;

    return SectionCard(
      title: 'Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirmed balance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AmountText(
            Formatters.rupiah(s.confirmedTotal),
            style: theme.textTheme.displaySmall,
            align: TextAlign.start,
          ),
          if (s.lastConfirmedAt != null)
            Text(
              'Last updated ${Formatters.dateTime(s.lastConfirmedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (stale)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: StatusTag(
                'A balance has not been updated in over 7 days',
                icon: Icons.schedule,
                warning: true,
              ),
            ),
          const Divider(height: 20),
          KeyValueRow(
            'Unpaid bills',
            Formatters.rupiah(s.knownUnpaidBills),
          ),
          KeyValueRow(
            'Estimated money left',
            free < 0
                ? 'Short by ${Formatters.rupiah(-free)}'
                : Formatters.rupiah(free),
            emphasize: true,
          ),
          if (controller.reality.value != null)
            ..._breakdown(controller.reality.value!),
          Text(
            'Estimate = confirmed balance minus unpaid bills. This is not your actual bank balance.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 20),
          _targetSection(context, t, s),
        ],
      ),
    );
  }

  List<Widget> _breakdown(RealityCheck r) => [
    if (r.overdueTotal > 0)
      KeyValueRow(
        '  Overdue',
        Formatters.rupiah(r.overdueTotal),
      ),
    KeyValueRow(
      '  Due in the next ${r.horizonDays} days',
      Formatters.rupiah(r.dueInHorizonTotal),
    ),
    if (r.laterTotal > 0)
      KeyValueRow('  Later', Formatters.rupiah(r.laterTotal)),
    if (r.fundingGap > 0)
      KeyValueRow(
        'Funding gap (${r.horizonDays} days)',
        Formatters.rupiah(r.fundingGap),
        emphasize: true,
      ),
  ];

  Widget _targetSection(
    BuildContext context,
    IncomeTarget t,
    FinanceSummary s,
  ) {
    final theme = Theme.of(context);
    final days = controller.workdays.value;
    final income = controller.confirmedIncome.value;

    final Widget headline;
    switch (t.status) {
      case IncomeTargetStatus.notNeeded:
        headline = const KeyValueRow(
          'Daily income target',
          'No extra income needed',
          emphasize: true,
        );
      case IncomeTargetStatus.needsWorkdays:
        headline = const KeyValueRow(
          'Daily income target',
          'Set workdays',
          emphasize: true,
        );
      case IncomeTargetStatus.ready:
        headline = KeyValueRow(
          'Estimated daily income target',
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
          'Estimate: bills ${Formatters.rupiah(s.knownUnpaidBills)} − available funds '
          '${Formatters.rupiah(s.confirmedTotal)} − confirmed income '
          '${Formatters.rupiah(income)} = shortfall ${Formatters.rupiah(t.fundingGap)}'
          '${days != null && days > 0 ? ', divided across $days workdays' : ''}. '
          'Unconfirmed income is not included.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _editWorkdays(context),
              child: Text(
                days == null ? 'Set workdays' : 'Workdays: $days',
              ),
            ),
            TextButton(
              onPressed: () => _editIncome(context),
              child: const Text('Confirmed income'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editWorkdays(BuildContext context) async {
    final r = await showFieldsDialog(
      context,
      title: 'Available workdays',
      message: 'How many days can you work before your bills are due?',
      fields: [
        FieldSpec(
          label: 'Number of days',
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
      title: 'Confirmed income',
      message:
          'Only include money you are certain to receive before bills are due, such as a confirmed paycheck. Leave blank or enter 0 if none.',
      fields: [
        FieldSpec(
          label: 'Amount (Rp)',
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
      title: 'Wallets',
      trailing: TextButton.icon(
        onPressed: () => showAddAccountDialog(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: accounts.isEmpty
          ? FilledButton.icon(
              onPressed: () => showAddAccountDialog(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('Add wallet'),
            )
          : Column(
              children: [
                for (final a in accounts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.accountType.label} · as of ${Formatters.dateTime(a.balanceConfirmedAt)}',
                    ),
                    trailing: Text(
                      Formatters.rupiah(a.confirmedBalance),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    onTap: () => _updateBalance(context, a),
                    onLongPress: () => _accountMenu(context, a),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showAddAccountDialog(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('Add wallet'),
                  ),
                ),
                Text(
                  'Tap a wallet to adjust its balance. Long-press to rename or hide it.',
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
      title: 'Adjust ${a.name} balance',
      message:
          'Enter the current balance you see. Previous balance: ${Formatters.rupiah(a.confirmedBalance)}.',
      fields: [
        FieldSpec(
          label: 'Current balance (Rp)',
          numeric: true,
          initial: a.confirmedBalance.toString(),
        ),
        const FieldSpec(
          label: 'Reason',
          required: false,
          advanced: true,
          helper: 'e.g. correction, after paying rent',
        ),
      ],
      confirmLabel: 'Confirm',
    );
    if (r == null) return;
    final value = Formatters.parseRupiah(r[0]);
    if (value == null) return;
    await controller.confirmBalance(
      a,
      value,
      reason: r[1].isEmpty ? null : r[1],
    );
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
              title: const Text('Balance adjustment history'),
              onTap: () => Navigator.of(ctx).pop('history'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide wallet'),
              subtitle: const Text('Excluded from totals'),
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
                    child: Text('No adjustments yet.'),
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
          title: 'Rename wallet',
          fields: [FieldSpec(label: 'Name', initial: a.name)],
        );
        if (r != null) await controller.renameAccount(a, r[0]);
      case 'hide':
        final ok = await confirmDialog(
          context,
          title: 'Hide wallet?',
          message:
              'Its history will be kept, but the balance will no longer be included in totals.',
          confirmLabel: 'Hide wallet',
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
      title: 'Bills',
      trailing: TextButton.icon(
        onPressed: () => showBillSheet(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Add bill'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unpaid.isEmpty)
            const Text('No unpaid bills.'),
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
                    const StatusTag(
                      'Overdue',
                      icon: Icons.warning_amber,
                      warning: true,
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(b.amount),
                    style: theme.textTheme.titleSmall,
                  ),
                  TextButton(
                    onPressed: () => _payBill(context, b),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 36),
                    ),
                    child: const Text('Pay'),
                  ),
                ],
              ),
              onTap: () => showBillSheet(context, controller, existing: b),
              onLongPress: () => _billMenu(context, b),
            ),
          if (unpaid.isNotEmpty)
            Text(
              'Tap a bill to edit it. Pay records an expense in the selected wallet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (paid.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Paid', style: theme.textTheme.labelLarge),
            for (final b in paid)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(b.title),
                subtitle: b.paidAt == null
                    ? null
                    : Text('Paid ${Formatters.date(b.paidAt!)}'),
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
              title: const Text('Mark as paid'),
              subtitle: const Text('Choose a wallet for the expense'),
              onTap: () => Navigator.of(ctx).pop('paid'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete bill'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'paid') {
      await _payBill(context, b);
    } else {
      final ok = await confirmDialog(
        context,
        title: 'Delete bill?',
        message: '"${b.title}" will be deleted and no longer counted.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (ok) await controller.deleteBill(b);
    }
  }

  Future<void> _payBill(BuildContext context, Bill bill) async {
    if (controller.accounts.isEmpty) {
      AppToast.show('Add a wallet before paying a bill.');
      return;
    }
    final preferredId = controller.lastUsedAccountId.value;
    var selectedAccount = controller.accounts.firstWhere(
      (item) => item.id == preferredId,
      orElse: () => controller.accounts.first,
    );
    final accountId = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose a wallet'),
          content: DropdownButtonFormField<Account>(
            initialValue: selectedAccount,
            items: [
              for (final account in controller.accounts)
                DropdownMenuItem(value: account, child: Text(account.name)),
            ],
            onChanged: (account) {
              if (account != null) {
                setDialogState(() => selectedAccount = account);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedAccount.id),
              child: const Text('Mark as paid'),
            ),
          ],
        ),
      ),
    );
    if (accountId == null || !context.mounted) return;
    final account = controller.accounts.firstWhere(
      (item) => item.id == accountId,
    );
    await controller.markPaid(bill, account);
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  static const int _collapsed = 8;

  Widget _content(BuildContext context) {
    final all = controller.filteredTransactions;
    final expanded = controller.txnExpanded.value;
    final shown = expanded ? all : all.take(_collapsed).toList();
    final dir = controller.txnFilter.value;

    return SectionCard(
      title: 'Recent transactions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => controller.txnQuery.value = v,
            decoration: const InputDecoration(
              hintText: 'Search categories, notes, or wallets',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Text(
              'Tap to edit or swipe left to delete.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              ChoiceChip(
                label: const Text('All'),
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
              title: 'No matching transactions',
            )
          else
            AnimatedSize(
              duration: AppMotion.of(context, AppMotion.standard),
              curve: AppMotion.standardCurve,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (final t in shown)
                    if (t.billId == null)
                      Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.lg,
                          ),
                          color: context.scheme.errorContainer,
                          child: Icon(
                            Icons.delete_outline,
                            color: context.scheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) async {
                          final deleted = await controller.deleteTransaction(t);
                          if (!deleted) await controller.load();
                        },
                        child: _TransactionRow(
                          t: t,
                          accountName: controller.accountName(t.accountId),
                          onTap: t.transferId == null
                              ? () => showTransactionSheet(
                                  context,
                                  controller,
                                  existing: t,
                                )
                              : () => showTransferSheet(
                                  context,
                                  controller,
                                  existing: t,
                                ),
                        ),
                      )
                    else
                      _TransactionRow(
                        t: t,
                        accountName: controller.accountName(t.accountId),
                        onTap: null,
                      ),
                  if (all.length > _collapsed)
                    TextButton(
                      onPressed: () => controller.txnExpanded.value = !expanded,
                      child: Text(
                        expanded
                            ? 'Show less'
                            : 'Show all (${all.length})',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionInsights extends StatelessWidget {
  const _TransactionInsights({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final month = controller.monthSummary(DateTime.now());
    if (month.income == 0 && month.expense == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.sm,
        AppSpace.gutter,
        0,
      ),
      child: SectionCard(
        title: 'This month',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniTotal(
                    label: 'Income',
                    value: Formatters.rupiah(month.income),
                    color: context.semantic.income,
                    icon: Icons.south_west,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _MiniTotal(
                    label: 'Expenses',
                    value: Formatters.rupiah(month.expense),
                    color: context.semantic.expense,
                    icon: Icons.north_east,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                'Based only on transactions you have recorded.',
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (month.byCategory.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              _CategoryBars(byCategory: month.byCategory, total: month.expense),
            ],
          ],
        ),
      ),
    );
  });
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
      Row(
        children: [
          Icon(icon, size: AppSize.iconXs, color: color),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      AmountText(
        value,
        style: context.text.titleMedium,
        align: TextAlign.start,
      ),
    ],
  );
}

/// Expense distribution by category (up to four plus "Other"), with labels and percentages.
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
      if (rest > 0) ('Other', rest),
    ];
    return Column(
      children: [
        for (final (name, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Semantics(
              label:
                  '$name ${(value * 100 / total).round()} percent, ${Formatters.rupiah(value)}',
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.tag,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: value / total),
                        duration: AppMotion.of(context, AppMotion.emphasized),
                        curve: AppMotion.enter,
                        builder: (_, v, _) => LinearProgressIndicator(
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
                      style: context.text.bodySmall?.copyWith(
                        fontFeatures: AppText.tabular,
                      ),
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
    this.onTap,
  });

  final MoneyTransaction t;
  final String accountName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sem = context.semantic;
    final income = t.direction == TransactionDirection.income;
    final color = income ? sem.income : sem.expense;
    return Semantics(
      label:
          '${income ? "Income" : "Expense"} ${Formatters.rupiah(t.amount)}, ${t.category}',
      child: InkWell(
        onTap: onTap,
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
                child: Icon(
                  income ? Icons.south_west : Icons.north_east,
                  size: AppSize.iconSm,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge,
                    ),
                    Text(
                      '$accountName · ${Formatters.dateShort(t.occurredAt)}'
                      '${t.note == null ? '' : ' · ${t.note}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
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
