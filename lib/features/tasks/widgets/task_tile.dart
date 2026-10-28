import 'package:flutter/material.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';

/// Baris tugas. Terlambat dibedakan oleh teks + ikon + garis kiri (bukan warna
/// saja); selesai oleh coretan dan redup.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    this.onToggleDone,
    this.dense = false,
  });

  final Task task;
  final VoidCallback onTap;

  /// Bila diisi, tampil kotak centang: satu ketukan = selesai / buka kembali.
  final VoidCallback? onToggleDone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final overdue = task.isOverdue(now);
    final done = task.status == TaskStatus.done;
    final cancelled = task.status == TaskStatus.cancelled;
    final muted = done || cancelled;

    final due = task.dueAt;
    final meta = <String>[
      if (due != null)
        '${DueLabel.of(due, now: now)} · ${Formatters.dateShort(due)}${DateTimeUtils.hasMeaningfulTime(due) ? ' ${Formatters.time(due)}' : ''}'
      else
        'Tanpa deadline',
      if (task.courseName != null) task.courseName!,
    ];

    return Semantics(
      container: true,
      label: [
        task.title,
        if (overdue) 'terlambat',
        if (done) 'selesai',
        meta.first,
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.tap + 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Garis kiri hanya untuk terlambat; ada juga tag "Terlambat" berteks.
              AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.standard),
                width: 3,
                color: overdue ? scheme.error : Colors.transparent,
              ),
              if (onToggleDone != null)
                SizedBox(
                  width: AppSize.tap,
                  child: Center(
                    child: Checkbox(
                      value: done,
                      shape: const CircleBorder(),
                      onChanged: (_) => onToggleDone!(),
                      semanticLabel: done ? 'Buka kembali tugas' : 'Tandai selesai',
                    ),
                  ),
                )
              else
                const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: dense ? AppSpace.sm : AppSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.of(context, AppMotion.standard),
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                        child: Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            meta.join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: overdue
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                              fontWeight: overdue ? FontWeight.w600 : null,
                            ),
                          ),
                          if (overdue)
                            const StatusTag('Terlambat',
                                icon: Icons.warning_amber, warning: true),
                          if (task.isRecurring && task.isActive)
                            const StatusTag('Berulang', icon: Icons.repeat),
                          if (task.status == TaskStatus.needsReview)
                            const StatusTag('Perlu diperiksa',
                                icon: Icons.help_outline),
                          if (task.priority.isHigh && task.isActive)
                            StatusTag(task.priority.label,
                                icon: Icons.flag_outlined, tone: TagTone.warning),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
            ],
          ),
        ),
      ),
    );
  }
}
