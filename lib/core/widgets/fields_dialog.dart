import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Spesifikasi satu kolom pada [showFieldsDialog].
class FieldSpec {
  const FieldSpec({
    required this.label,
    this.initial = '',
    this.required = true,
    this.helper,
    this.numeric = false,
    this.multiline = false,
    this.options,
    this.optionInitial = 0,
    this.advanced = false,
  });

  final String label;
  final String initial;
  final bool required;
  final String? helper;

  /// Hanya angka (untuk nominal rupiah / jumlah hari).
  final bool numeric;
  final bool multiline;

  /// Bila diisi, kolom ditampilkan sebagai dropdown; hasil = indeks pilihan (string).
  final List<String>? options;
  final int optionInitial;

  /// Disembunyikan di balik tombol kecil "Opsi lanjutan" sampai dibuka.
  final bool advanced;
}

/// Dialog isian sederhana. Mengembalikan nilai tiap kolom (urutan sama dengan
/// [fields]) atau null bila dibatalkan.
Future<List<String>?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  String confirmLabel = 'Simpan',
  String? message,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _FieldsDialog(
      title: title,
      fields: fields,
      confirmLabel: confirmLabel,
      message: message,
    ),
  );
}

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({
    required this.title,
    required this.fields,
    required this.confirmLabel,
    this.message,
  });

  final String title;
  final List<FieldSpec> fields;
  final String confirmLabel;
  final String? message;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late final List<int> _choices;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final f in widget.fields) TextEditingController(text: f.initial),
    ];
    _choices = [for (final f in widget.fields) f.optionInitial];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop([
      for (var i = 0; i < widget.fields.length; i++)
        widget.fields[i].options != null
            ? _choices[i].toString()
            : _controllers[i].text.trim(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message != null) ...[
                Text(widget.message!),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < widget.fields.length; i++)
                if (!widget.fields[i].advanced || _showAdvanced) ...[
                  _buildField(i),
                  const SizedBox(height: 12),
                ],
              if (!_showAdvanced && widget.fields.any((f) => f.advanced))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      textStyle: Theme.of(context).textTheme.labelMedium,
                    ),
                    onPressed: () => setState(() => _showAdvanced = true),
                    icon: const Icon(Icons.expand_more, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Opsi lanjutan'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  Widget _buildField(int i) {
    final f = widget.fields[i];
    if (f.options != null) {
      return DropdownButtonFormField<int>(
        initialValue: _choices[i],
        isExpanded: true,
        decoration: InputDecoration(
          labelText: f.label,
        ),
        items: [
          for (var k = 0; k < f.options!.length; k++)
            DropdownMenuItem(value: k, child: Text(f.options![k])),
        ],
        onChanged: (v) => setState(() => _choices[i] = v ?? 0),
      );
    }
    return TextFormField(
      controller: _controllers[i],
      autofocus: i == 0,
      keyboardType: f.numeric
          ? TextInputType.number
          : (f.multiline ? TextInputType.multiline : TextInputType.text),
      inputFormatters:
          f.numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      minLines: f.multiline ? 2 : 1,
      maxLines: f.multiline ? 4 : 1,
      textCapitalization: f.numeric
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: f.required ? f.label : '${f.label} (opsional)',
        helperText: f.helper,
      ),
      validator: (v) {
        if (f.required && (v == null || v.trim().isEmpty)) {
          return '${f.label} wajib diisi';
        }
        return null;
      },
      onFieldSubmitted: (_) => i == widget.fields.length - 1 ? _submit() : null,
    );
  }
}
