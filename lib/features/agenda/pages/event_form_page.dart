import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  Event? _existing;
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

  DateTime? _start;
  DateTime? _end;
  DateTime? _reminder;
  EventType _type = EventType.other;
  bool _saving = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    // Argumen: Event (ubah) atau DateTime (hari yang dipilih di Kalender).
    final arg = Get.arguments;
    _existing = arg is Event ? arg : null;
    final presetDay = arg is DateTime ? arg : null;
    final e = _existing;
    if (e != null) {
      _title.text = e.title;
      _location.text = e.location ?? '';
      _description.text = e.description;
      _start = e.startsAt;
      _end = e.endsAt;
      _type = e.eventType;
      Get.find<ReminderRepository>()
          .getForTarget(ReminderTargetType.event, e.id)
          .then((r) {
        if (mounted && r != null && r.isEnabled) {
          setState(() => _reminder = r.remindAt);
        }
      });
    } else if (presetDay != null) {
      // Hari dari Kalender; jam awal 09:00 yang bisa diubah (bukan data palsu).
      _start = DateTime(presetDay.year, presetDay.month, presetDay.day, 9);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (_start == null) {
      setState(() => _timeError = 'Waktu mulai wajib diisi');
      return;
    }
    if (!valid) return;
    setState(() {
      _timeError = null;
      _saving = true;
    });
    final now = DateTime.now();
    final e = _existing;
    final event = Event(
      id: e?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      startsAt: _start!,
      endsAt: _end,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      eventType: _type,
      linkedTaskId: e?.linkedTaskId,
      linkedSavedItemId: e?.linkedSavedItemId,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final result = await Get.find<SaveEvent>()(
        event,
        isNew: e == null,
        reminderAt: _reminder,
      );
      Get.find<DataRevision>().bump();
      final msg = result.reminder?.message;
      Get.back<void>();
      AppToast.show(msg ?? 'Agenda tersimpan', isError: msg != null);
    } catch (err, st) {
      AppLog.error('event.save', err, st);
      if (mounted) setState(() => _saving = false);
      AppToast.show(messageOf(err), isError: true);
    }
  }

  bool get _hasAdvanced =>
      _end != null ||
      _type != EventType.other ||
      _location.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty;

  late final bool _openAdvanced = _hasAdvanced;

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    return FormPage(
      title: isNew ? 'Agenda baru' : 'Ubah agenda',
      formKey: _formKey,
      onSave: _save,
      saving: _saving,
      children: [
        TextFormField(
          controller: _title,
          autofocus: isNew,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(labelText: 'Judul agenda'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Judul agenda wajib diisi' : null,
        ),
        DateTimeField(
          label: 'Mulai',
          value: _start,
          emptyText: 'Pilih tanggal dan jam',
          onChanged: (v) => setState(() {
            _start = v;
            _timeError = null;
          }),
        ),
        if (_timeError != null)
          Text(
            _timeError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ReminderField(
          value: _reminder,
          anchor: _start,
          presets: const [
            ReminderPreset('15 menit sebelum', Duration(minutes: 15)),
            ReminderPreset('1 jam sebelum', Duration(hours: 1)),
            ReminderPreset('1 hari sebelum', Duration(days: 1)),
          ],
          onChanged: (v) => setState(() => _reminder = v),
        ),
        AdvancedOptions(
          initiallyOpen: _openAdvanced,
          children: [
            DateTimeField(
              label: 'Selesai',
              value: _end,
              emptyText: 'Tanpa waktu selesai',
              defaultTime: _start != null
                  ? TimeOfDay(hour: (_start!.hour + 1) % 24, minute: _start!.minute)
                  : const TimeOfDay(hour: 10, minute: 0),
              onChanged: (v) => setState(() => _end = v),
            ),
            EnumDropdown<EventType>(
              label: 'Jenis',
              value: _type,
              items: EventType.values,
              labelOf: (t) => t.label,
              onChanged: (v) => setState(() => _type = v),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Lokasi'),
            ),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
