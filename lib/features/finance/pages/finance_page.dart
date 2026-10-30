import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/fields_dialog.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
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
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter,
                ),
                childrenPadding: EdgeInsets.zero,
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
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpace.sm),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final visual = _accountVisual(context, account.accountType);
                    return Container(
                      width: 152,
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            visual.bg,
                            context.scheme.surfaceContainerLowest,
                          ],
                        ),
                        borderRadius: AppRadius.control,
                        border: Border.all(
                          color: visual.fg.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                visual.icon,
                                size: AppSize.iconXs,
                                color: visual.fg,
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Expanded(
                                child: Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelMedium?.copyWith(
                                    color: visual.fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AmountText(
                            Formatters.rupiah(account.confirmedBalance),
                            style: context.text.titleSmall,
                            color: visual.fg,
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

({IconData icon, Color bg, Color fg}) _accountVisual(
  BuildContext context,
  AccountType type,
) {
  final scheme = Theme.of(context).colorScheme;
  final sem = context.semantic;
  return switch (type) {
    AccountType.cash => (
      icon: Icons.payments_outlined,
      bg: sem.warningContainer,
      fg: sem.warning,
    ),
    AccountType.bank => (
      icon: Icons.account_balance_outlined,
      bg: scheme.primaryContainer,
      fg: scheme.onPrimaryContainer,
    ),
    AccountType.eWallet => (
      icon: Icons.smartphone_outlined,
      bg: scheme.tertiaryContainer,
      fg: scheme.onTertiaryContainer,
    ),
    AccountType.other => (
      icon: Icons.wallet_outlined,
      bg: scheme.secondaryContainer,
      fg: scheme.onSecondaryContainer,
    ),
  };
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
    if (s == null) return const SizedBox.shrink();

    if (!s.hasAccounts) {
      return SectionCard(
        title: 'Summary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a wallet to see your balance and bill statistics.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.md),
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
    final reality = controller.reality.value;
    final stale =
        s.oldestConfirmedAt != null &&
        DateTime.now().difference(s.oldestConfirmedAt!).inDays >= 7;

    final items = <_StatData>[
      _StatData(
        label: 'Unpaid bills',
        value: Formatters.rupiah(s.knownUnpaidBills),
        icon: Icons.receipt_long_outlined,
        tone: _StatTone.neutral,
      ),
      _StatData(
        label: 'Estimated left',
        value: Formatters.rupiah(free),
        icon: free < 0 ? Icons.trending_down : Icons.savings_outlined,
        tone: free < 0 ? _StatTone.expense : _StatTone.income,
        caption: free < 0 ? 'Shortfall' : 'After unpaid bills',
      ),
      if (reality != null) ...[
        if (reality.overdueTotal > 0)
          _StatData(
            label: 'Overdue',
            value: Formatters.rupiah(reality.overdueTotal),
            icon: Icons.error_outline,
            tone: _StatTone.urgent,
            caption: reality.overdueCount == 1
                ? '1 bill'
                : '${reality.overdueCount} bills',
          ),
        _StatData(
          label: 'Due soon',
          value: Formatters.rupiah(reality.dueInHorizonTotal),
          icon: Icons.event_outlined,
          tone: _StatTone.warning,
          caption: 'Next ${reality.horizonDays} days',
        ),
        if (reality.laterTotal > 0)
          _StatData(
            label: 'Later',
            value: Formatters.rupiah(reality.laterTotal),
            icon: Icons.event_note_outlined,
            tone: _StatTone.info,
            caption: 'After ${reality.horizonDays} days',
          ),
      ],
    ];

    return SectionCard(
      title: 'Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                        'Updated ${Formatters.dateTime(s.lastConfirmedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (stale)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpace.sm),
                  child: Tooltip(
                    message: 'A balance has not been updated in over 7 days',
                    child: StatusTag(
                      'Stale',
                      icon: Icons.schedule,
                      warning: true,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          _StatGrid(items: items),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.account,
    required this.wide,
    required this.onTap,
    required this.onMenu,
  });

  final Account account;
  final bool wide;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _accountVisual(context, account.accountType);
    final badgeSize = wide ? 38.0 : 32.0;

    final badge = Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(visual.icon, size: AppSize.iconSm, color: visual.fg),
    );

    final name = Text(
      account.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (wide ? theme.textTheme.titleSmall : theme.textTheme.labelLarge)
          ?.copyWith(fontWeight: FontWeight.w700),
    );

    final amount = AmountText(
      Formatters.rupiah(account.confirmedBalance),
      style: wide ? theme.textTheme.titleLarge : theme.textTheme.titleMedium,
      align: TextAlign.start,
    );

    final caption = Text(
      wide
          ? '${account.accountType.label} · as of ${Formatters.date(account.balanceConfirmedAt)}'
          : 'as of ${Formatters.date(account.balanceConfirmedAt)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    final menu = IconButton(
      onPressed: onMenu,
      icon: const Icon(Icons.more_horiz),
      iconSize: AppSize.iconSm,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      tooltip: 'Wallet options',
    );

    final content = wide
        ? Row(
            children: [
              badge,
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [name, const SizedBox(height: 2), amount, caption],
                ),
              ),
              menu,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [badge, const Spacer(), menu]),
              const Spacer(),
              name,
              const SizedBox(height: 2),
              amount,
              caption,
            ],
          );

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.control,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [visual.bg, theme.colorScheme.surfaceContainerLowest],
          ),
          borderRadius: AppRadius.control,
          border: Border.all(color: visual.fg.withValues(alpha: 0.16)),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onMenu,
          borderRadius: AppRadius.control,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final accounts = controller.accounts;
    return SectionCard(
      title: 'Wallets',
      child: accounts.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No wallets yet. Add one to start tracking your balance.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  onPressed: () => showAddAccountDialog(context, controller),
                  icon: const Icon(Icons.add),
                  label: const Text('Add wallet'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final half = (constraints.maxWidth - AppSpace.md) / 2;
                    final lastIsWide = accounts.length.isOdd;
                    return Wrap(
                      spacing: AppSpace.md,
                      runSpacing: AppSpace.md,
                      children: [
                        for (var i = 0; i < accounts.length; i++)
                          SizedBox(
                            width: lastIsWide && i == accounts.length - 1
                                ? constraints.maxWidth
                                : half,
                            height: lastIsWide && i == accounts.length - 1
                                ? 108
                                : 136,
                            child: _WalletCard(
                              account: accounts[i],
                              wide: lastIsWide && i == accounts.length - 1,
                              onTap: () => _updateBalance(context, accounts[i]),
                              onMenu: () => _accountMenu(context, accounts[i]),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showAddAccountDialog(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('Add wallet'),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Tap a wallet to adjust its balance. Long-press for more options.',
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
          if (unpaid.isEmpty) const Text('No unpaid bills.'),
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
                        expanded ? 'Show less' : 'Show all (${all.length})',
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
    final net = month.income - month.expense;
    final spentRatio = month.income <= 0
        ? 1.0
        : (month.expense / month.income).clamp(0.0, 1.0);
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
            _StatGrid(
              items: [
                _StatData(
                  label: 'Income',
                  value: Formatters.rupiah(month.income),
                  icon: Icons.south_west,
                  tone: _StatTone.income,
                  caption: '${month.count} transactions',
                ),
                _StatData(
                  label: 'Expenses',
                  value: Formatters.rupiah(month.expense),
                  icon: Icons.north_east,
                  tone: _StatTone.expense,
                  caption: month.expense == 0
                      ? 'No expenses'
                      : '${month.byCategory.length} categories',
                ),
                _StatData(
                  label: 'Net',
                  value:
                      '${net < 0 ? '-' : '+'}${Formatters.rupiah(net.abs())}',
                  icon: net < 0 ? Icons.trending_down : Icons.trending_up,
                  tone: net < 0 ? _StatTone.expense : _StatTone.income,
                ),
                _StatData(
                  label: 'Spent',
                  value: '${(spentRatio * 100).round()}%',
                  icon: Icons.pie_chart_outline,
                  tone: spentRatio > 0.9 ? _StatTone.warning : _StatTone.info,
                  caption: month.income > 0
                      ? 'of recorded income'
                      : 'no recorded income',
                ),
              ],
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

enum _StatTone { neutral, income, expense, warning, info, urgent }

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final _StatTone tone;
  final String? caption;
  final VoidCallback? onTap;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});
  final List<_StatData> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final half = (constraints.maxWidth - AppSpace.md) / 2;
      final lastIsWide = items.length.isOdd;
      return Wrap(
        spacing: AppSpace.md,
        runSpacing: AppSpace.md,
        children: [
          for (var i = 0; i < items.length; i++)
            SizedBox(
              width: lastIsWide && i == items.length - 1
                  ? constraints.maxWidth
                  : half,
              child: _StatTile(data: items[i]),
            ),
        ],
      );
    },
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (data.tone) {
      _StatTone.neutral => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      _StatTone.income => (
        context.semantic.incomeContainer,
        context.semantic.income,
      ),
      _StatTone.expense => (
        context.semantic.expenseContainer,
        context.semantic.expense,
      ),
      _StatTone.warning => (
        context.semantic.warningContainer,
        context.semantic.warning,
      ),
      _StatTone.urgent => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _StatTone.info => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
    };
    final valueColor = data.tone == _StatTone.neutral
        ? theme.colorScheme.onSurface
        : fg;
    final label =
        '${data.label}: ${data.value}'
        '${data.caption == null ? '' : ', ${data.caption}'}';

    Widget content = Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(data.icon, size: AppSize.iconSm, color: fg),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (data.onTap != null)
                Icon(
                  Icons.edit_outlined,
                  size: AppSize.iconXs,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          AmountText(
            data.value,
            style: theme.textTheme.titleMedium,
            color: valueColor,
            align: TextAlign.start,
          ),
          if (data.caption != null) ...[
            const SizedBox(height: 2),
            Text(
              data.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (data.onTap != null) {
      content = InkWell(onTap: data.onTap, child: content);
    }

    return Semantics(
      container: true,
      button: data.onTap != null,
      label: label,
      onTap: data.onTap,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadius.control,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
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
