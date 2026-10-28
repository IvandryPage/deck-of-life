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

/// Kerangka dengan bottom navigation. Setiap tab mempertahankan state dan posisi
/// scroll (IndexedStack). Lencana pada ikon menampilkan informasi yang menuntut
/// perhatian (tugas terlambat, tagihan terlambat, item perlu diperiksa, agenda hari ini).
class ShellPage extends GetView<ShellController> {
  const ShellPage({super.key});

  static const List<String> _titles = [
    'Beranda',
    'Keuangan',
    'Tugas',
    'Kalender',
    'Informasi',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final i = controller.tab.value;
      return Scaffold(
        appBar: i == ShellController.tabHome
            ? null // Beranda punya header sendiri yang kontekstual.
            : AppBar(
                title: Text(_titles[i]),
                actions: _actions(),
              ),
        body: SafeArea(
          top: i == ShellController.tabHome,
          bottom: false,
          child: IndexedStack(
            index: i,
            children: const [
              HomePage(),
              FinancePage(),
              TasksPage(),
              CalendarPage(),
              InboxPage(),
            ],
          ),
        ),
        floatingActionButton: _fab(context, i),
        bottomNavigationBar: _NavBar(
          index: i,
          onSelected: (v) => controller.tab.value = v,
        ),
      );
    });
  }

  static List<Widget> _actions() => [
        IconButton(
          tooltip: 'Cari',
          icon: const Icon(Icons.search),
          onPressed: () => Get.toNamed<dynamic>(Routes.search),
        ),
        const _MoreMenu(),
      ];

  Widget? _fab(BuildContext context, int tab) {
    switch (tab) {
      case ShellController.tabFinance:
        return FloatingActionButton.extended(
          onPressed: () => showTransactionSheet(
              context, Get.find<FinanceController>()),
          icon: const Icon(Icons.add),
          label: const Text('Transaksi'),
        );
      case ShellController.tabTask:
        return FloatingActionButton.extended(
          onPressed: () => Get.toNamed<dynamic>(
            Routes.taskForm,
            arguments: const TaskFormArgs(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Tugas baru'),
        );
      case ShellController.tabCalendar:
        return FloatingActionButton.extended(
          onPressed: () => Get.toNamed<dynamic>(Routes.eventForm),
          icon: const Icon(Icons.add),
          label: const Text('Agenda'),
        );
      case ShellController.tabInfo:
        return FloatingActionButton.extended(
          onPressed: () => Get.toNamed<dynamic>(
            Routes.savedItemForm,
            arguments: const SavedItemFormArgs(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Simpan info'),
        );
      default:
        return null; // Beranda: aksi cepat ada di halamannya.
    }
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Menu lainnya',
        onSelected: (route) => Get.toNamed<dynamic>(route),
        itemBuilder: (_) => const [
          PopupMenuItem(value: Routes.routines, child: Text('Rutinitas')),
          PopupMenuItem(value: Routes.settings, child: Text('Pengaturan')),
        ],
      );
}

class _NavBar extends GetView<HomeController> {
  const _NavBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Semua Rx dibaca di dalam builder.
      final d = controller.data.value;
      final overdueTasks = d?.overdueTaskCount ?? 0;
      final overdueBills = d?.overdueBillCount ?? 0;
      final review = d?.needsReviewItemCount ?? 0;
      final today = d?.todayEvents.length ?? 0;

      Widget icon(IconData base, int count, String what) => _Badged(
            icon: base,
            count: count,
            label: what,
          );

      return NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        animationDuration: AppMotion.of(context, AppMotion.standard),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: icon(Icons.account_balance_wallet_outlined, overdueBills,
                'tagihan terlambat'),
            selectedIcon: icon(Icons.account_balance_wallet, overdueBills,
                'tagihan terlambat'),
            label: 'Keuangan',
          ),
          NavigationDestination(
            icon: icon(Icons.checklist_outlined, overdueTasks, 'tugas terlambat'),
            selectedIcon: icon(Icons.checklist, overdueTasks, 'tugas terlambat'),
            label: 'Tugas',
          ),
          NavigationDestination(
            icon: icon(Icons.calendar_month_outlined, today, 'agenda hari ini'),
            selectedIcon: icon(Icons.calendar_month, today, 'agenda hari ini'),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: icon(Icons.inbox_outlined, review, 'perlu diperiksa'),
            selectedIcon: icon(Icons.inbox, review, 'perlu diperiksa'),
            label: 'Informasi',
          ),
        ],
      );
    });
  }
}

/// Ikon dengan lencana angka. Angka juga masuk ke label aksesibilitas,
/// sehingga informasinya tidak hanya bergantung pada warna lencana.
class _Badged extends StatelessWidget {
  const _Badged({required this.icon, required this.count, required this.label});

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Semantics(
      label: '$count $label',
      child: Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(icon),
      ),
    );
  }
}
