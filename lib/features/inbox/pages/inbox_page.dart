import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/widgets/common_widgets.dart';
import '../controllers/inbox_controller.dart';
import '../inbox_args.dart';
import '../widgets/saved_item_tile.dart';

class InboxPage extends GetView<InboxController> {
  const InboxPage({super.key});

  static const Map<InboxFilter, String> _labels = {
    InboxFilter.all: 'All',
    InboxFilter.needsReview: 'Needs review',
    InboxFilter.archived: 'Archived',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            onChanged: (value) => controller.query.value = value,
            decoration: const InputDecoration(
              hintText: 'Search notes',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Obx(
          () => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (final f in InboxFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_labels[f]!),
                      selected: controller.filter.value == f,
                      onSelected: (_) => controller.setFilter(f),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const SkeletonList();
            }
            if (controller.errorMessage.value != null) {
              return ErrorState(
                message: controller.errorMessage.value!,
                onRetry: controller.load,
              );
            }
            final items = controller.items;
            if (items.isEmpty) {
              final f = controller.filter.value;
              return EmptyState(
                icon: Icons.inbox_outlined,
                title: f == InboxFilter.needsReview
                    ? 'Nothing needs review'
                    : f == InboxFilter.archived
                    ? 'No archived notes'
                    : 'No notes yet',
                message: f == InboxFilter.all
                    ? 'Share text or a link from another app, or tap “Save note”. You can add details later.'
                    : null,
                actionLabel: f == InboxFilter.all ? 'Save note' : null,
                onAction: f == InboxFilter.all
                    ? () => Get.toNamed<dynamic>(
                        Routes.savedItemForm,
                        arguments: const SavedItemFormArgs(),
                      )
                    : null,
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => SavedItemTile(
                  item: items[i],
                  onTap: () => Get.toNamed<dynamic>(
                    Routes.savedItemDetail,
                    arguments: items[i].id,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
