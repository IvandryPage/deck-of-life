import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shell/controllers/shell_controller.dart';
import '../../../domain/entities/enums.dart';
import '../../inbox/widgets/saved_item_tile.dart';
import '../../tasks/widgets/task_tile.dart';
import '../controllers/search_controller.dart';

class SearchPage extends GetView<UniversalSearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cari judul, isi, grup, mata kuliah, tautan…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (v) => controller.query.value = v,
        ),
      ),
      body: Column(
        children: [
          _Filters(controller: controller),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final r = controller.results.value;
              if (controller.errorMessage.value != null) {
                return ErrorState(
                  message: controller.errorMessage.value!,
                  onRetry: controller.run,
                );
              }
              if (r == null) {
                return const SkeletonList();
              }
              if (r.isEmpty) {
                final searching = controller.query.value.trim().isNotEmpty ||
                    controller.hasFilters;
                return EmptyState(
                  icon: Icons.search_off,
                  title: searching ? 'Tidak ada hasil' : 'Belum ada informasi tersimpan',
                  message: searching
                      ? 'Coba kata kunci lain atau hapus filter. Pencarian hanya mencakup yang sudah disimpan di aplikasi ini.'
                      : null,
                );
              }
              return ListView(
                children: [
                  if (r.items.isNotEmpty) ...[
                    _Header(
                      controller.query.value.trim().isEmpty
                          ? 'Terbaru'
                          : 'Informasi tersimpan (${r.items.length})',
                    ),
                    for (final i in r.items)
                      SavedItemTile(
                        item: i,
                        onTap: () => Get.toNamed<dynamic>(
                          Routes.savedItemDetail,
                          arguments: i.id,
                        ),
                      ),
                  ],
                  if (r.tasks.isNotEmpty) ...[
                    _Header('Tugas (${r.tasks.length})'),
                    for (final t in r.tasks)
                      TaskTile(
                        task: t,
                        onTap: () => Get.toNamed<dynamic>(
                          Routes.taskDetail,
                          arguments: t.id,
                        ),
                      ),
                  ],
                  if (r.events.isNotEmpty) ...[
                    _Header('Agenda (${r.events.length})'),
                    for (final e in r.events)
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(e.title),
                        subtitle: Text(Formatters.dateTime(e.startsAt)),
                        onTap: () => Get.toNamed<dynamic>(Routes.eventForm,
                            arguments: e),
                      ),
                  ],
                  if (r.bills.isNotEmpty) ...[
                    _Header('Tagihan (${r.bills.length})'),
                    for (final b in r.bills)
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(b.title),
                        subtitle: Text(
                          '${Formatters.rupiah(b.amount)} - ${b.isUnpaid ? "jatuh tempo ${Formatters.dateShort(b.dueAt)}" : "lunas"}',
                        ),
                        onTap: () =>
                            Get.find<ShellController>().goTo(ShellController.tabFinance),
                      ),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller});
  final UniversalSearchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final type = controller.type.value;
      final review = controller.review.value;
      final course = controller.course.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _menu<SavedItemType>(
              label: type?.label ?? 'Jenis',
              selected: type != null,
              values: SavedItemType.values,
              labelOf: (t) => t.label,
              onSelected: (v) => controller.type.value = v,
            ),
            const SizedBox(width: 8),
            _menu<ReviewStatus>(
              label: review?.label ?? 'Status',
              selected: review != null,
              values: ReviewStatus.values,
              labelOf: (t) => t.label,
              onSelected: (v) => controller.review.value = v,
            ),
            if (controller.courses.isNotEmpty) ...[
              const SizedBox(width: 8),
              _menu<String>(
                label: course ?? 'Mata kuliah',
                selected: course != null,
                values: controller.courses.toList(),
                labelOf: (c) => c,
                onSelected: (v) => controller.course.value = v,
              ),
            ],
            if (controller.hasFilters) ...[
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.clear, size: 16),
                label: const Text('Hapus filter'),
                onPressed: controller.clearFilters,
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _menu<T>({
    required String label,
    required bool selected,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final v in values) PopupMenuItem<T>(value: v, child: Text(labelOf(v))),
      ],
      child: IgnorePointer(
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {},
          deleteIcon: const Icon(Icons.arrow_drop_down),
          onDeleted: () {},
        ),
      ),
    );
  }
}
