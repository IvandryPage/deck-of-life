import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/recurrence.dart';
import '../../../domain/repositories/repositories.dart';
import '../controllers/finance_controller.dart';

/// Formulir tagihan (tambah / ubah) dalam bottom sheet.
Future<void> showBillSheet(
  BuildContext context,
  FinanceController controller, {
  Bill? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _BillForm(controller: controller, existing: existing),
    ),
  );
}

class _BillForm extends StatefulWidget {
  const _BillForm({required this.controller, this.existing});

  final FinanceController controller;
  final Bill? existing;

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime? _due;
  DateTime? _reminder;
  RecurrenceKind? _repeat;
  String? _dueError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b != null) {
      _title.text = b.title;
      _amount.text = b.amount.toString();
      _note.text = b.note ?? '';
      _due = b.dueAt;
      _repeat = RecurrenceRule.tryParse(b.recurrenceRule)?.kind;
      // Preserve the existing reminder when editing a bill.
      Get.find<ReminderRepository>()
          .getForTarget(ReminderTargetType.bill, b.id)
          .then((r) {
        if (mounted && r != null && r.isEnabled) {
          setState(() => _reminder = r.remindAt);
        }
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (_due == null) {
      setState(() => _dueError = 'Due date is required');
      return;
    }
    if (!valid) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final b = widget.existing;
    final bill = Bill(
      id: b?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amount: Formatters.parseRupiah(_amount.text) ?? 0,
      dueAt: _due!,
      status: b?.status ?? BillStatus.unpaid,
      paidAt: b?.paidAt,
      accountId: b?.accountId,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      recurrenceRule: _repeat == null
          ? null
          : RecurrenceRule.forDue(_repeat!, _due!).encoded,
      createdAt: b?.createdAt ?? now,
      updatedAt: now,
    );
    final ok = await widget.controller
        .saveBill(bill, isNew: b == null, reminderAt: _reminder);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final canRemind = isNew || widget.existing!.isUnpaid;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isNew ? 'New bill' : 'Edit bill',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            // Nominal sebagai elemen utama.
            TextFormField(
              controller: _amount,
              autofocus: isNew,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontFeatures: AppText.tabular),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final n = Formatters.parseRupiah(v ?? '');
                return (n == null || n <= 0) ? 'Enter an amount greater than 0' : null;
              },
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Bill name',
                helperText: 'e.g. November rent',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bill name is required' : null,
            ),
            const SizedBox(height: AppSpace.md),
            DateTimeField(
              label: 'Due date',
              value: _due,
              dateOnly: true,
              emptyText: 'Choose a date',
              onChanged: (v) => setState(() {
                _due = v;
                _dueError = null;
              }),
            ),
            if (_dueError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs + 2),
                child: Text(
                  _dueError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            AdvancedOptions(
              initiallyOpen: _repeat != null ||
                  _reminder != null ||
                  _note.text.trim().isNotEmpty,
              children: [
                DropdownButtonFormField<RecurrenceKind?>(
                  initialValue: _repeat,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    helperText: 'The next bill is created automatically when this one is paid',
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Does not repeat')),
                    for (final k in RecurrenceKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: (v) => setState(() => _repeat = v),
                ),
                if (canRemind)
                  ReminderField(
                    value: _reminder,
                    anchor: _due == null
                        ? null
                        : DateTime(_due!.year, _due!.month, _due!.day, 9),
                    presets: const [
                      ReminderPreset('On the due date', Duration.zero),
                      ReminderPreset('1 day before', Duration(days: 1)),
                      ReminderPreset('3 days before', Duration(days: 3)),
                    ],
                    onChanged: (v) => setState(() => _reminder = v),
                  ),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
