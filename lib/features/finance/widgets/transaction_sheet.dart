import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../controllers/finance_controller.dart';
import 'account_dialog.dart';

const List<String> _expenseCategories = [
  'Makan', 'Transport', 'Belanja', 'Tagihan', 'Pendidikan', 'Lainnya',
];
const List<String> _incomeCategories = ['Gaji', 'Usaha', 'Kiriman', 'Lainnya'];

/// Catat transaksi: NOMINAL adalah elemen utama. Kategori sekali ketuk,
/// tanggal default hari ini, catatan opsional. Hanya nominal yang wajib.
Future<void> showTransactionSheet(
  BuildContext context,
  FinanceController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _TransactionForm(controller: controller),
    ),
  );
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({required this.controller});
  final FinanceController controller;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TransactionDirection _direction = TransactionDirection.expense;
  String? _category;
  Account? _account;
  DateTime _date = DateTime.now();
  bool _showNote = false;
  bool _saving = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final accounts = widget.controller.accounts;
    if (accounts.isNotEmpty) _account = accounts.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amount = Formatters.parseRupiah(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Isi nominal lebih dari 0');
      return;
    }
    final account = _account;
    if (account == null) return;
    setState(() {
      _saving = true;
      _amountError = null;
    });
    final today = DateTimeUtils.isSameDay(_date, DateTime.now());
    final ok = await widget.controller.addTransaction(
      account: account,
      amount: amount,
      direction: _direction,
      category: _category ?? '',
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      occurredAt: today ? DateTime.now() : DateTime(_date.year, _date.month, _date.day, 12),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      // Gagal: input tetap utuh agar bisa dicoba lagi.
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.accounts;
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: EmptyState(
          compact: true,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Tambahkan akun dulu',
          message: 'Transaksi dicatat pada sebuah akun (rekening atau uang tunai).',
          actionLabel: 'Tambah akun',
          onAction: () {
            Navigator.of(context).pop();
            showAddAccountDialog(context, widget.controller);
          },
        ),
      );
    }

    final isIncome = _direction == TransactionDirection.income;
    final sem = context.semantic;
    final accent = isIncome ? sem.income : sem.expense;
    final cats = isIncome ? _incomeCategories : _expenseCategories;
    final today = DateTimeUtils.isSameDay(_date, DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TransactionDirection>(
            showSelectedIcon: true,
            segments: [
              for (final d in TransactionDirection.values)
                ButtonSegment(
                  value: d,
                  label: Text(d.label),
                  icon: Icon(d == TransactionDirection.income
                      ? Icons.south_west
                      : Icons.north_east),
                ),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() {
              _direction = s.first;
              _category = null;
            }),
          ),
          const SizedBox(height: AppSpace.xl),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
            style: context.text.displaySmall
                ?.copyWith(color: accent, fontFeatures: AppText.tabular),
            decoration: InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              prefixStyle: context.text.headlineSmall?.copyWith(color: accent),
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final c in cats)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (v) => setState(() => _category = v ? c : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: AppSize.iconSm),
                  label: Text(today ? 'Hari ini' : Formatters.date(_date)),
                ),
              ),
              if (accounts.length > 1) ...[
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Account>(
                      value: _account,
                      isExpanded: true,
                      items: [
                        for (final a in accounts)
                          DropdownMenuItem(
                            value: a,
                            child: Text(a.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (a) => setState(() => _account = a),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_showNote)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showNote = true),
                child: const Text('Tambah catatan'),
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Hanya catatan: saldo terkonfirmasi tidak berubah. Perbarui saldo di Keuangan.',
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
