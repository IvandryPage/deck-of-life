import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';

class SavedItemTile extends StatelessWidget {
  const SavedItemTile({super.key, required this.item, required this.onTap});

  final SavedItem item;
  final VoidCallback onTap;

  static IconData iconFor(SavedItemType t) => switch (t) {
    SavedItemType.link => Icons.link,
    SavedItemType.message => Icons.chat_bubble_outline,
    SavedItemType.note => Icons.sticky_note_2_outlined,
    SavedItemType.fileReference => Icons.insert_drive_file_outlined,
    SavedItemType.imageReference => Icons.image_outlined,
    SavedItemType.other => Icons.bookmark_border,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = <String>[
      item.itemType.label,
      if (item.courseName != null) item.courseName!,
      if (item.groupName != null) item.groupName!,
      Formatters.dateShort(item.createdAt),
    ];
    final preview = item.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    return ListTile(
      onTap: onTap,
      leading: Icon(iconFor(item.itemType)),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.isNotEmpty && preview != item.title)
            Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            meta.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (item.sourceApp == 'share_sheet' && item.needsReview)
            Tooltip(
              message: 'New',
              child: Semantics(
                label: 'New note',
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (item.needsReview)
            const StatusTag('Needs review', icon: Icons.help_outline),
        ],
      ),
    );
  }
}
