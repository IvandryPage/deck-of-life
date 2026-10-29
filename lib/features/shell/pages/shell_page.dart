import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/design/tokens.dart';
import '../../../app/routes/app_routes.dart';
import '../../calendar/pages/calendar_page.dart';
import '../../finance/controllers/finance_controller.dart';
import '../../finance/pages/finance_page.dart';
import '../../finance/widgets/transaction_sheet.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/pages/home_page.dart';
import '../../inbox/inbox_args.dart';
import '../../inbox/pages/inbox_page.dart';
import '../../tasks/pages/tasks_page.dart';
import '../../tasks/task_args.dart';
import '../controllers/shell_controller.dart';

class ShellPage extends GetView<ShellController> {
  const ShellPage({super.key});

  static const List<String> _titles = [
    'Home',
    'Calendar',
    'Tasks',
    'Money',
    'Notes',
  ];

  @override
  Widget build(BuildContext context) => Obx(() {
    final index = controller.tab.value;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _NavigationRail(index: index, onSelected: controller.goTo),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: index == ShellController.tabHome
                    ? null
                    : AppBar(
                        title: Text(_titles[index]),
                        actions: [
                          IconButton(
                            tooltip: 'Search',
                            icon: const Icon(Icons.search),
                            onPressed: () =>
                                Get.toNamed<dynamic>(Routes.search),
                          ),
                        ],
                      ),
                body: IndexedStack(
                  index: index,
                  children: const [
                    HomePage(),
                    CalendarPage(),
                    TasksPage(),
                    FinancePage(),
                    InboxPage(),
                  ],
                ),
                floatingActionButton: _QuickAddButton(activeTab: index),
              ),
            ),
          ],
        ),
      ),
    );
  });
}

class _NavigationRail extends GetView<HomeController> {
  const _NavigationRail({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _icons = [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.checklist_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.sticky_note_2_outlined,
  ];
  static const _selectedIcons = [
    Icons.home,
    Icons.calendar_month,
    Icons.checklist,
    Icons.account_balance_wallet,
    Icons.sticky_note_2,
  ];
  static const _labels = ['Home', 'Cal', 'Tasks', 'Money', 'Notes'];

  @override
  Widget build(BuildContext context) => Obx(() {
    final data = controller.data.value;
    final counts = [
      0,
      data?.todayEvents.length ?? 0,
      data?.overdueTaskCount ?? 0,
      data?.overdueBillCount ?? 0,
      data?.needsReviewItemCount ?? 0,
    ];
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: _RailDestination(
                label: _labels[i],
                count: counts[i],
                icon: i == index ? _selectedIcons[i] : _icons[i],
                selected: i == index,
                onTap: () => onSelected(i),
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Get.toNamed<dynamic>(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  });
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleLabel = count > 0 ? '$label $count' : label;
    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '$label, $count items need attention' : label,
      child: Tooltip(
        message: count > 0 ? '$label · $count' : label,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.standard),
            margin: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: AppSpace.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.secondaryContainer : Colors.transparent,
              borderRadius: AppRadius.control,
              border: selected
                  ? Border(left: BorderSide(color: colors.primary, width: 3))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: AppSize.iconMd,
                  color: selected
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpace.xs),
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    visibleLabel,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? colors.onSecondaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _QuickAction { note, task, event, transaction }

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.activeTab});

  final int activeTab;

  Future<void> _open(BuildContext context) async {
    final actions = switch (activeTab) {
      ShellController.tabCalendar => [
        _QuickAction.event,
        _QuickAction.task,
        _QuickAction.note,
        _QuickAction.transaction,
      ],
      ShellController.tabTask => [
        _QuickAction.task,
        _QuickAction.note,
        _QuickAction.event,
        _QuickAction.transaction,
      ],
      ShellController.tabFinance => [
        _QuickAction.transaction,
        _QuickAction.note,
        _QuickAction.task,
        _QuickAction.event,
      ],
      ShellController.tabNotes => [
        _QuickAction.note,
        _QuickAction.task,
        _QuickAction.event,
        _QuickAction.transaction,
      ],
      _ => [
        _QuickAction.note,
        _QuickAction.task,
        _QuickAction.event,
        _QuickAction.transaction,
      ],
    };
    final selected = await showModalBottomSheet<_QuickAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: Icon(_iconFor(action)),
                title: Text(_labelFor(action)),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case _QuickAction.note:
        await Get.toNamed<dynamic>(
          Routes.savedItemForm,
          arguments: const SavedItemFormArgs(),
        );
        break;
      case _QuickAction.task:
        await Get.toNamed<dynamic>(
          Routes.taskForm,
          arguments: const TaskFormArgs(),
        );
        break;
      case _QuickAction.event:
        await Get.toNamed<dynamic>(Routes.eventForm);
        break;
      case _QuickAction.transaction:
        await showTransactionSheet(context, Get.find<FinanceController>());
        break;
    }
  }

  static IconData _iconFor(_QuickAction action) => switch (action) {
    _QuickAction.note => Icons.sticky_note_2_outlined,
    _QuickAction.task => Icons.checklist,
    _QuickAction.event => Icons.event_outlined,
    _QuickAction.transaction => Icons.payments_outlined,
  };

  static String _labelFor(_QuickAction action) => switch (action) {
    _QuickAction.note => 'Note',
    _QuickAction.task => 'Task',
    _QuickAction.event => 'Event',
    _QuickAction.transaction => 'Transaction',
  };

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    tooltip: 'Add',
    onPressed: () => _open(context),
    child: const Icon(Icons.add),
  );
}
