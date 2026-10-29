import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/capture.dart';
import '../../../domain/usecases/usecases.dart';
import '../inbox_args.dart';

/// Quick capture starts with the content; other details can be added later.
class SavedItemFormPage extends StatefulWidget {
  const SavedItemFormPage({super.key});

  @override
  State<SavedItemFormPage> createState() => _SavedItemFormPageState();
}

class _SavedItemFormPageState extends State<SavedItemFormPage> {
  late final SavedItemFormArgs _args;
  SavedItem? get _existing => _args.existing;

  final _content = TextEditingController();
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _sourceLabel = TextEditingController();
  final _course = TextEditingController();
  final _group = TextEditingController();
  final _context = TextEditingController();

  SavedItemType _type = SavedItemType.note;
  bool _typeTouched = false;
  bool _needsReview = false;
  DateTime? _reminder;
  bool _saving = false;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    _args = (Get.arguments as SavedItemFormArgs?) ?? const SavedItemFormArgs();
    final e = _existing;
    if (e != null) {
      _content.text = e.contentText;
      _title.text = e.title;
      _url.text = e.sourceUrl ?? '';
      _sourceLabel.text = e.sourceLabel ?? '';
      _course.text = e.courseName ?? '';
      _group.text = e.groupName ?? '';
      _context.text = e.contextNote ?? '';
      _type = e.itemType;
      _typeTouched = true;
      _needsReview = e.needsReview;
      Get.find<ReminderRepository>()
          .getForTarget(ReminderTargetType.savedItem, e.id)
          .then((r) {
            if (mounted && r != null && r.isEnabled) {
              setState(() => _reminder = r.remindAt);
            }
          });
    } else if (_args.text != null) {
      _content.text = _args.text!;
      final s = CaptureSuggester.suggest(
        _args.text!,
        subject: _args.subject,
        fromShare: _args.fromShare,
      );
      if (!s.titleIsPlaceholder) _title.text = s.title;
      _url.text = s.url ?? '';
      _type = s.type;
      // Shared content may lack context, so flag it for review.
      _needsReview = _args.fromShare;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _content,
      _title,
      _url,
      _sourceLabel,
      _course,
      _group,
      _context,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final content = _content.text.trim();
    final title = _title.text.trim();
    if (content.isEmpty && title.isEmpty) {
      setState(
        () => _contentError = 'Add note content or a title',
      );
      return;
    }
    setState(() {
      _contentError = null;
      _saving = true;
    });

    final suggestion = CaptureSuggester.suggest(
      content.isEmpty ? title : content,
      subject: title.isEmpty ? _args.subject : null,
      fromShare: _args.fromShare,
    );
    final finalTitle = title.isNotEmpty ? title : suggestion.title;
    final url = _url.text.trim().isNotEmpty ? _url.text.trim() : suggestion.url;
    final type = _typeTouched ? _type : suggestion.type;
    final now = DateTime.now();
    final e = _existing;

    final item = SavedItem(
      id: e?.id ?? const Uuid().v4(),
      title: finalTitle,
      contentText: content,
      itemType: type,
      sourceApp: e?.sourceApp ?? (_args.fromShare ? 'share_sheet' : null),
      sourceLabel: _sourceLabel.text,
      sourceUrl: url,
      sourceLocation: e?.sourceLocation,
      courseName: _course.text,
      groupName: _group.text,
      contextNote: _context.text,
      // Judul sementara selalu perlu diperiksa.
      reviewStatus:
          (_needsReview || suggestion.titleIsPlaceholder && title.isEmpty)
          ? ReviewStatus.needsReview
          : (e?.reviewStatus == ReviewStatus.archived
                ? ReviewStatus.archived
                : ReviewStatus.reviewed),
      isFavorite: e?.isFavorite ?? false,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
      archivedAt: e?.archivedAt,
    );

    try {
      if (e == null && _args.fromShare) {
        // Share berulang dari sumber yang sama tidak menumpuk duplikat.
        final dup = await Get.find<SavedItemRepository>().findDuplicate(
          url: url,
          content: content,
        );
        if (dup != null) {
          Get.back<String>(result: dup.id);
          AppToast.show('Already saved: "${dup.title}"');
          await _maybeClose();
          return;
        }
      }
      final result = await Get.find<SaveSavedItem>()(
        item,
        isNew: e == null,
        reminderAt: _reminder,
      );
      Get.find<DataRevision>().bump();
      final msg = result.reminder?.message;
      Get.back<String>(result: item.id);
      AppToast.show(msg ?? 'Saved to Notes', isError: msg != null);
      if (e == null) await _maybeClose();
    } catch (err, st) {
      AppLog.error('savedItem.save', err, st);
      if (mounted) setState(() => _saving = false);
      AppToast.show(messageOf(err), isError: true);
    }
  }

  /// Return to the source app after saving shared content.
  Future<void> _maybeClose() async {
    if (!_args.fromShare) return;
    final v = await Get.find<SettingsRepository>().get(
      SettingKeys.closeAfterShare,
    );
    if (v != '0') await SystemNavigator.pop();
  }

  bool get _hasAdvanced =>
      _typeTouched ||
      _reminder != null ||
      [
        _title,
        _url,
        _sourceLabel,
        _course,
        _group,
        _context,
      ].any((c) => c.text.trim().isNotEmpty);

  late final bool _openAdvanced = _hasAdvanced;

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    return FormPage(
      title: isNew ? 'New note' : 'Edit note',
      onSave: _save,
      saving: _saving,
      children: [
        if (_args.fromShare)
          Text(
            'The sender or group name may not come through from the source app. '
            'Add it in More options if needed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        TextField(
          controller: _content,
          autofocus: isNew && !_args.fromShare,
          minLines: 4,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Content / link',
            alignLabelWithHint: true,
            errorText: _contentError,
          ),
          onChanged: (_) {
            if (_contentError != null) setState(() => _contentError = null);
          },
        ),
        AdvancedOptions(
          initiallyOpen: _openAdvanced,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs review'),
              value: _needsReview,
              onChanged: (v) => setState(() => _needsReview = v),
            ),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                helperText: 'Leave blank to create one from the content',
              ),
            ),
            EnumDropdown<SavedItemType>(
              label: 'Type',
              value: _type,
              items: SavedItemType.values,
              labelOf: (t) => t.label,
              onChanged: (v) => setState(() {
                _type = v;
                _typeTouched = true;
              }),
            ),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Source link',
                helperText:
                    'Only the link is saved, not the content behind it',
              ),
            ),
            TextField(
              controller: _sourceLabel,
              decoration: const InputDecoration(
                labelText: 'Source',
                helperText: 'e.g. WhatsApp, course portal, Professor Lee',
              ),
            ),
            TextField(
              controller: _course,
              decoration: const InputDecoration(
                labelText: 'Course / context',
              ),
            ),
            TextField(
              controller: _group,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            TextField(
              controller: _context,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Context notes',
                alignLabelWithHint: true,
              ),
            ),
            ReminderField(
              label: 'Remind me to review',
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
              anchor: DateTime.now(),
              presets: const [
                ReminderPreset('In 3 hours', Duration(hours: -3)),
                ReminderPreset('Tomorrow', Duration(hours: -24)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
