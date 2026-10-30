import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/design/tokens.dart';
import '../errors/app_exception.dart';

/// Safe, user-facing error messages never expose raw SQL.
String messageOf(Object error) => error is AppException
    ? error.message
    : 'Something went wrong. Please try again.';

class AppToast {
  const AppToast._();

  /// Closes the previous snackbar before showing an optional action.
  static void show(
    String message, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ctx = Get.context;
    final scheme = ctx == null ? null : Theme.of(ctx).colorScheme;
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.showSnackbar(
      GetSnackBar(
        messageText: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(
              color: isError
                  ? (scheme?.onError ?? Colors.white)
                  : (scheme?.onInverseSurface ?? Colors.white),
            ),
          ),
        ),
        duration: Duration(seconds: isError ? 5 : (onAction != null ? 5 : 3)),
        animationDuration: AppMotion.standard,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          AppSpace.md,
        ),
        borderRadius: AppRadius.md,
        backgroundColor: isError
            ? (scheme?.error ?? const Color(0xFFC0392B))
            : (scheme?.inverseSurface ?? const Color(0xFF3A2E25)),
        mainButton: (actionLabel != null && onAction != null)
            ? TextButton(
                onPressed: () {
                  Get.closeCurrentSnackbar();
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: scheme?.inversePrimary ?? Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// Success feedback with an Undo action.
  static void undoable(String message, VoidCallback onUndo) =>
      show(message, actionLabel: 'Undo', onAction: onUndo);
}

/// Confirmation dialog for destructive actions.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Compact version for use inside cards and sections.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSize.avatarIcon + 8,
            height: AppSize.avatarIcon + 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: AppRadius.control,
            ),
            child: Icon(
              icon,
              size: AppSize.iconMd,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.lg),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
    return compact
        ? content
        : Center(child: SingleChildScrollView(child: content));
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.error_outline,
    title: message,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// Flat section card separated from the background by a subtle themed border.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: AppSpace.xs + 2,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight section heading for long lists without nested cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.count});

  final String title;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.xl,
        AppSpace.gutter,
        AppSpace.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                count == null ? title : '$title · $count',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

enum TagTone { neutral, info, urgent, warning, success }

/// Status label that does not rely on color alone.
class StatusTag extends StatelessWidget {
  const StatusTag(
    this.label, {
    super.key,
    this.icon,
    this.warning = false,
    this.tone,
  });

  final String label;
  final IconData? icon;

  /// Kompatibilitas lama: `warning: true` = nada mendesak.
  final bool warning;
  final TagTone? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = context.semantic;
    final t = tone ?? (warning ? TagTone.urgent : TagTone.neutral);
    final (Color bg, Color fg) = switch (t) {
      TagTone.urgent => (scheme.errorContainer, scheme.onErrorContainer),
      TagTone.warning => (sem.warningContainer, sem.warning),
      TagTone.success => (sem.incomeContainer, sem.income),
      TagTone.info => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      TagTone.neutral => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.tag),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSize.iconXs, color: fg),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rupiah amount with tabular figures and an explicit sign.
class AmountText extends StatelessWidget {
  const AmountText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.align = TextAlign.end,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align == TextAlign.end
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: base?.copyWith(color: color, fontFeatures: AppText.tabular),
      ),
    );
  }
}

/// Fades and shifts in once, respecting reduced-motion settings.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delayIndex = 0});

  final Widget child;

  /// Light staggering with up to four short steps.
  final int delayIndex;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final extra = Duration(milliseconds: 30 * delayIndex.clamp(0, 4));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.standard + extra,
      curve: AppMotion.enter,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 8), child: c),
      ),
      child: child,
    );
  }
}

/// Skeleton placeholder that respects reduced-motion settings.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: 0.55 + 0.45 * _c.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(
                widget.radius ?? AppRadius.sm,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton list rows matching task and transaction rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.gutter),
      itemCount: rows,
      itemBuilder: (_, i) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(
          children: [
            SkeletonBox(width: 28, height: 28, radius: AppRadius.sm),
            SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14),
                  SizedBox(height: AppSpace.sm),
                  SkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
    this.label,
    this.value, {
    super.key,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasize
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: AppText.tabular,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: AppText.tabular,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
