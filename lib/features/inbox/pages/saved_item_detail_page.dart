import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';
import '../../tasks/task_args.dart';
import '../inbox_args.dart';

class SavedItemDetailPage extends StatefulWidget {
  const SavedItemDetailPage({super.key});

  @override
  State<SavedItemDetailPage> createState() => _SavedItemDetailPageState();
}

class _SavedItemDetailPageState extends State<SavedItemDetailPage> {
  late final String _id;
  final _items = Get.find<SavedItemRepository>();
  final _tasks = Get.find<TaskRepository>();

  SavedItem? _item;
  List<Task> _linked = const [];
  bool _loading = true;
  bool _missing = false;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _id = Get.arguments as String;
    _load();
    _worker = ever<int>(Get.find<DataRevision>().revision, (_) => _load());
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final item = await _items.getById(_id);
      final linked = item == null ? <Task>[] : await _tasks.tasksForSavedItem(_id);
      if (!mounted) return;
      setState(() {
        _item = item;
        _linked = linked;
        _missing = item == null;
        _loading = false;
      });
    } catch (e, st) {
      AppLog.error('savedItem.detail', e, st);
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      Get.find<DataRevision>().bump();
      if (success != null) AppToast.show(success);
    } catch (e, st) {
      AppLog.error('savedItem.action', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<void> _linkExistingTask() async {
    final linkedIds = _linked.map((t) => t.id).toSet();
    final all = await _tasks.list(statuses: {
      TaskStatus.needsReview,
      TaskStatus.todo,
      TaskStatus.inProgress,
    });
    final options = all.where((t) => !linkedIds.contains(t.id)).toList();
    if (!mounted) return;
    if (options.isEmpty) {
      AppToast.show('Belum ada tugas aktif untuk dihubungkan.');
      return;
    }
    final picked = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Hubungkan ke tugas'),
            ),
            for (final t in options)
              ListTile(
                title: Text(t.title),
                subtitle: t.dueAt == null ? null : Text(Formatters.dateTime(t.dueAt!)),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _run(
      () => _tasks.linkSavedItem(picked.id, _id),
      success: 'Dihubungkan ke "${picked.title}"',
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      AppToast.show('Tautan tidak valid.', isError: true);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) AppToast.show('Tidak ada aplikasi untuk membuka tautan ini.', isError: true);
    } catch (_) {
      AppToast.show('Tautan tidak bisa dibuka (mungkin sedang offline).', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final item = _item;
    if (_missing || item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Item tidak ditemukan',
          message: 'Mungkin sudah dihapus.',
        ),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
        actions: [
          IconButton(
            tooltip: 'Ubah',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Get.toNamed<dynamic>(
              Routes.savedItemForm,
              arguments: SavedItemFormArgs(existing: item),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await _run(
                  () => Get.find<ArchiveSavedItem>()(item.id),
                  success: 'Dipindahkan ke arsip',
                );
              } else if (v == 'unarchive') {
                await _run(
                  () => _items.setReviewStatus(item.id, ReviewStatus.reviewed),
                  success: 'Dikembalikan dari arsip',
                );
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Hapus permanen?',
                  message:
                      'Item ini dan hubungannya dengan tugas akan dihapus. Tindakan ini tidak bisa dibatalkan. Gunakan Arsip bila hanya ingin menyembunyikan.',
                  confirmLabel: 'Hapus',
                  destructive: true,
                );
                if (!ok) return;
                await _run(() => Get.find<DeleteSavedItem>()(item.id));
                Get.back<void>();
                AppToast.show('Item dihapus');
              }
            },
            itemBuilder: (_) => [
              if (item.reviewStatus == ReviewStatus.archived)
                const PopupMenuItem(value: 'unarchive', child: Text('Keluarkan dari arsip'))
              else
                const PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
              const PopupMenuItem(value: 'delete', child: Text('Hapus permanen')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(item.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusTag(item.itemType.label),
              StatusTag(item.reviewStatus.label,
                  icon: item.needsReview ? Icons.help_outline : null),
              if (item.courseName != null) StatusTag(item.courseName!),
              if (item.groupName != null) StatusTag(item.groupName!),
            ],
          ),
          const SizedBox(height: 16),
          if (item.contentText.trim().isNotEmpty)
            SelectableText(item.contentText, style: theme.textTheme.bodyLarge),
          if (item.sourceUrl != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text(item.sourceUrl!, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Tautan sumber (isinya tidak ikut tersimpan)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Salin tautan',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: item.sourceUrl!));
                        AppToast.show('Tautan disalin');
                      },
                    ),
                    IconButton(
                      tooltip: 'Buka tautan',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openUrl(item.sourceUrl!),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (item.sourceLabel != null) KeyValueRow('Sumber', item.sourceLabel!),
          if (item.contextNote != null) KeyValueRow('Konteks', item.contextNote!),
          KeyValueRow('Disimpan', Formatters.dateTime(item.createdAt)),
          if (item.updatedAt.difference(item.createdAt).inMinutes > 0)
            KeyValueRow('Diubah', Formatters.dateTime(item.updatedAt)),
          const SizedBox(height: 16),
          if (item.needsReview)
            FilledButton.tonalIcon(
              onPressed: () => _run(
                () => _items.setReviewStatus(item.id, ReviewStatus.reviewed),
                success: 'Ditandai sudah diperiksa',
              ),
              icon: const Icon(Icons.done_all),
              label: const Text('Tandai sudah diperiksa'),
            ),
          const SizedBox(height: 24),
          Text('Tugas terkait', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Menyimpan informasi tidak otomatis membuat tugas.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          for (final t in _linked)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.title),
              subtitle: Text(t.status.label),
              onTap: () => Get.toNamed<dynamic>(Routes.taskDetail, arguments: t.id),
              trailing: IconButton(
                tooltip: 'Lepas hubungan',
                icon: const Icon(Icons.link_off),
                onPressed: () => _run(
                  () => _tasks.unlinkSavedItem(t.id, item.id),
                  success: 'Hubungan dilepas',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Get.toNamed<dynamic>(
                  Routes.taskForm,
                  arguments: TaskFormArgs(
                    title: item.title,
                    savedItemIds: [item.id],
                    courseName: item.courseName,
                    groupName: item.groupName,
                  ),
                ),
                icon: const Icon(Icons.add_task),
                label: const Text('Buat tugas dari item ini'),
              ),
              OutlinedButton.icon(
                onPressed: _linkExistingTask,
                icon: const Icon(Icons.link),
                label: const Text('Hubungkan ke tugas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
