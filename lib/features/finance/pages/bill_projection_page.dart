import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../core/utils/date_time_utils.dart';
import '../controllers/finance_controller.dart';

class BillProjectionPage extends GetView<FinanceController> {
  const BillProjectionPage({super.key});

  static const _horizons = [7, 14, 30, 60, 90];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bill projection')),
    body: Obx(() {
      if (controller.isLoading.value) return const SkeletonList();
      final now = DateTime.now();
      final horizon = controller.horizonDays.value;
      final reality = controller.reality.value;
      final summary = controller.summary.value;
      final horizonEnd = DateTime(
        now.year,
        now.month,
        now.day + horizon,
        23,
        59,
        59,
      );
      final bills =
          controller.unpaidBills
              .where((bill) => !bill.dueAt.isAfter(horizonEnd))
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      final dueTotal = bills.fold<int>(0, (total, bill) => total + bill.amount);
      var projectedBalance = summary?.confirmedTotal ?? 0;
      final timeline = <({Bill bill, int balanceAfter})>[];
      for (final bill in bills) {
        projectedBalance -= bill.amount;
        timeline.add((bill: bill, balanceAfter: projectedBalance));
      }

      return ListView(
        padding: const EdgeInsets.only(top: AppSpace.sm, bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Text(
              'Estimated from confirmed wallet balances and unpaid bills. '
              'Assumes no new income or expenses.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          SectionCard(
            title: 'Projection horizon',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<int>(
                  segments: [
                    for (final days in _horizons)
                      ButtonSegment(value: days, label: Text('$days days')),
                    if (!_horizons.contains(horizon))
                      ButtonSegment(
                        value: horizon,
                        label: Text('$horizon days'),
                      ),
                  ],
                  selected: {horizon},
                  showSelectedIcon: false,
                  onSelectionChanged: (selected) {
                    controller.setHorizon(selected.single);
                  },
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: _ProjectionMetric(
                        label: 'Bills due',
                        value: Formatters.rupiah(dueTotal),
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _ProjectionMetric(
                        label: 'Confirmed balance',
                        value: Formatters.rupiah(summary?.confirmedTotal ?? 0),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
                if (reality != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: reality.fundingGap > 0
                          ? context.semantic.warningContainer
                          : context.semantic.incomeContainer,
                      borderRadius: AppRadius.control,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          reality.fundingGap > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: reality.fundingGap > 0
                              ? context.semantic.warning
                              : context.semantic.income,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            reality.fundingGap > 0
                                ? 'Estimated shortfall: ${Formatters.rupiah(reality.fundingGap)}'
                                : 'Confirmed balance covers bills in this horizon',
                            style: context.text.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SectionCard(
            title: 'Due timeline',
            child: timeline.isEmpty
                ? Text(
                    'No unpaid bills due within this horizon.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [
                      for (final item in timeline)
                        _ProjectionBillRow(
                          bill: item.bill,
                          balanceAfter: item.balanceAfter,
                          now: now,
                        ),
                    ],
                  ),
          ),
        ],
      );
    }),
  );
}

class _ProjectionMetric extends StatelessWidget {
  const _ProjectionMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: AppSize.iconSm, color: context.scheme.primary),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.xs),
      AmountText(value, style: context.text.titleSmall, align: TextAlign.start),
    ],
  );
}

class _ProjectionBillRow extends StatelessWidget {
  const _ProjectionBillRow({
    required this.bill,
    required this.balanceAfter,
    required this.now,
  });

  final Bill bill;
  final int balanceAfter;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdue = bill.dueAt.isBefore(now);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
        color: overdue ? context.semantic.warning : context.scheme.primary,
      ),
      title: Text(bill.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${Formatters.date(bill.dueAt)} · ${DueLabel.of(bill.dueAt, now: now)}\n'
        'Estimated balance after: ${Formatters.rupiah(balanceAfter)}',
      ),
      isThreeLine: true,
      trailing: AmountText(
        Formatters.rupiah(bill.amount),
        style: context.text.labelLarge,
        align: TextAlign.end,
      ),
    );
  }
}
