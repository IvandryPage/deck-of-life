import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
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
  List<SavedItemAttachment> _attachments = const [];
  bool _loading = true;
  bool _addingAttachment = false;
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
      final linked = item == null
          ? <Task>[]
          : await _tasks.tasksForSavedItem(_id);
      final attachments = item == null
          ? <SavedItemAttachment>[]
          : await _items.attachmentsFor(_id);
      if (!mounted) return;
      setState(() {
        _item = item;
        _linked = linked;
        _attachments = attachments;
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
    final all = await _tasks.list(
      statuses: {
        TaskStatus.needsReview,
        TaskStatus.todo,
        TaskStatus.inProgress,
      },
    );
    final options = all.where((t) => !linkedIds.contains(t.id)).toList();
    if (!mounted) return;
    if (options.isEmpty) {
      AppToast.show('No active tasks to link.');
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
              child: Text('Link to a task'),
            ),
            for (final t in options)
              ListTile(
                title: Text(t.title),
                subtitle: t.dueAt == null
                    ? null
                    : Text(Formatters.dateTime(t.dueAt!)),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _run(
      () => _tasks.linkSavedItem(picked.id, _id),
      success: 'Linked to "${picked.title}"',
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      AppToast.show('This link is invalid.', isError: true);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok)
        AppToast.show('No app is available to open this link.', isError: true);
    } catch (_) {
      AppToast.show(
        'Could not open the link. You may be offline.',
        isError: true,
      );
    }
  }

  Future<void> _addAttachment() async {
    if (_addingAttachment) return;
    setState(() => _addingAttachment = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withReadStream: true,
      );
      final picked = result?.files.single;
      if (picked == null) return;
      if (picked.size > 10 * 1024 * 1024) {
        AppToast.show(
          'Each attachment must be 10 MB or smaller.',
          isError: true,
        );
        return;
      }
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.readStream != null) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in picked.readStream!) {
          if (builder.length + chunk.length > 10 * 1024 * 1024) {
            AppToast.show(
              'Each attachment must be 10 MB or smaller.',
              isError: true,
            );
            return;
          }
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
      } else if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        AppToast.show('Could not read the selected file.', isError: true);
        return;
      }
      final extension = p.extension(picked.name).toLowerCase();
      final mimeType = switch (extension) {
        '.pdf' => 'application/pdf',
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => null,
      };
      if (mimeType == null) return;
      await _items.addAttachment(
        SavedItemAttachment(
          id: const Uuid().v4(),
          savedItemId: _id,
          fileName: p.basename(picked.name),
          mimeType: mimeType,
          contentBase64: base64Encode(bytes),
          sizeBytes: bytes.length,
          createdAt: DateTime.now(),
        ),
      );
      Get.find<DataRevision>().bump();
      AppToast.show('Attachment added');
    } catch (e, st) {
      AppLog.error('savedItem.attachment.add', e, st);
      AppToast.show(messageOf(e), isError: true);
    } finally {
      if (mounted) setState(() => _addingAttachment = false);
    }
  }

  Future<void> _shareAttachment(SavedItemAttachment attachment) async {
    try {
      final directory = await getTemporaryDirectory();
      final path = p.join(
        directory.path,
        'deck-of-life-${attachment.id}-${p.basename(attachment.fileName)}',
      );
      final file = File(path);
      await file.writeAsBytes(
        base64Decode(attachment.contentBase64),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: attachment.mimeType)],
          subject: attachment.fileName,
        ),
      );
    } catch (e, st) {
      AppLog.error('savedItem.attachment.share', e, st);
      AppToast.show('Could not share this attachment.', isError: true);
    }
  }

  Future<void> _deleteAttachment(SavedItemAttachment attachment) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove attachment?',
      message: '"${attachment.fileName}" will be removed from this note.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    await _run(
      () => _items.deleteAttachment(attachment.id),
      success: 'Attachment removed',
    );
  }

  Future<void> _previewAttachment(SavedItemAttachment attachment) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: attachment.mimeType.startsWith('image/')
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Image.memory(
                    base64Decode(attachment.contentBase64),
                    fit: BoxFit.contain,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 48),
                    const SizedBox(height: 8),
                    Text(_attachmentSize(attachment.sizeBytes)),
                    const Text('Share the file to open it in a PDF reader.'),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pop();
                _shareAttachment(attachment);
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
            ),
          ],
        ),
      );

  String _attachmentSize(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

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
          title: 'Note not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            tooltip: 'Edit note',
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
                  success: 'Moved to Archive',
                );
              } else if (v == 'unarchive') {
                await _run(
                  () => _items.setReviewStatus(item.id, ReviewStatus.reviewed),
                  success: 'Restored from Archive',
                );
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete permanently?',
                  message:
                      'This note and its task links will be deleted permanently. This cannot be undone. Archive it if you only want to hide it.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!ok) return;
                await _run(() => Get.find<DeleteSavedItem>()(item.id));
                Get.back<void>();
                AppToast.show('Note deleted');
              }
            },
            itemBuilder: (_) => [
              if (item.reviewStatus == ReviewStatus.archived)
                const PopupMenuItem(
                  value: 'unarchive',
                  child: Text('Restore from Archive'),
                )
              else
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete permanently'),
              ),
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
              StatusTag(
                item.reviewStatus.label,
                icon: item.needsReview ? Icons.help_outline : null,
                tone: item.needsReview ? TagTone.info : null,
              ),
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
                title: Text(
                  item.sourceUrl!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Source link (content is not saved)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: item.sourceUrl!),
                        );
                        AppToast.show('Link copied');
                      },
                    ),
                    IconButton(
                      tooltip: 'Open link',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openUrl(item.sourceUrl!),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Attachments', style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Add attachment',
                onPressed: _addingAttachment ? null : _addAttachment,
                icon: _addingAttachment
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file),
              ),
            ],
          ),
          if (_attachments.isEmpty)
            Text(
              'No attachments. Add an image or PDF up to 10 MB.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final attachment in _attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: attachment.mimeType.startsWith('image/')
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(attachment.contentBase64),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              title: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_attachmentSize(attachment.sizeBytes)),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Share attachment',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareAttachment(attachment),
                  ),
                  IconButton(
                    tooltip: 'Remove attachment',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteAttachment(attachment),
                  ),
                ],
              ),
              onTap: () => _previewAttachment(attachment),
            ),
          const SizedBox(height: 16),
          if (item.sourceLabel != null)
            KeyValueRow('Source', item.sourceLabel!),
          if (item.contextNote != null)
            KeyValueRow('Context', item.contextNote!),
          KeyValueRow('Saved', Formatters.dateTime(item.createdAt)),
          if (item.updatedAt.difference(item.createdAt).inMinutes > 0)
            KeyValueRow('Edited', Formatters.dateTime(item.updatedAt)),
          const SizedBox(height: 16),
          if (item.needsReview)
            FilledButton.tonalIcon(
              onPressed: () => _run(
                () => _items.setReviewStatus(item.id, ReviewStatus.reviewed),
                success: 'Marked as reviewed',
              ),
              icon: const Icon(Icons.done_all),
              label: const Text('Mark as reviewed'),
            ),
          const SizedBox(height: 24),
          Text('Linked tasks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Saving a note does not automatically create a task.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final t in _linked)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.title),
              subtitle: Text(t.status.label),
              onTap: () =>
                  Get.toNamed<dynamic>(Routes.taskDetail, arguments: t.id),
              trailing: IconButton(
                tooltip: 'Unlink task',
                icon: const Icon(Icons.link_off),
                onPressed: () => _run(
                  () => _tasks.unlinkSavedItem(t.id, item.id),
                  success: 'Task unlinked',
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
                label: const Text('Make a task from this note'),
              ),
              OutlinedButton.icon(
                onPressed: _linkExistingTask,
                icon: const Icon(Icons.link),
                label: const Text('Link to a task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
