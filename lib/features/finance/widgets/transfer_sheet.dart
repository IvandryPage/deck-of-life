import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../controllers/finance_controller.dart';
import 'account_dialog.dart';

Future<void> showTransferSheet(
  BuildContext context,
  FinanceController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _TransferForm(controller: controller),
    ),
  );
}

class _TransferForm extends StatefulWidget {
  const _TransferForm({required this.controller});
  final FinanceController controller;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Account? _from;
  Account? _to;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts = widget.controller.accounts;
    if (accounts.isNotEmpty) {
      final lastUsed = widget.controller.lastUsedAccountId.value;
      _from = accounts.firstWhere(
        (account) => account.id == lastUsed,
        orElse: () => accounts.first,
      );
      _to = accounts.firstWhere(
        (account) => account.id != _from!.id,
        orElse: () => accounts.first,
      );
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Formatters.parseRupiah(_amount.text);
    final from = _from;
    final to = _to;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Isi nominal lebih dari 0');
      return;
    }
    if (from == null || to == null || from.id == to.id) {
      setState(() => _error = 'Pilih dua wallet yang berbeda');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.controller.transfer(
      from: from,
      to: to,
      amount: amount,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.accounts;
    if (accounts.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: EmptyState(
          compact: true,
          icon: Icons.swap_horiz,
          title: 'Tambahkan dua wallet',
          message: 'Transfer membutuhkan wallet asal dan tujuan.',
          actionLabel: 'Tambah wallet',
          onAction: () {
            Navigator.of(context).pop();
            showAddAccountDialog(context, widget.controller);
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Transfer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          DropdownButtonFormField<Account>(
            initialValue: _from,
            decoration: const InputDecoration(labelText: 'Dari wallet'),
            items: [
              for (final account in accounts)
                DropdownMenuItem(value: account, child: Text(account.name)),
            ],
            onChanged: (account) => setState(() {
              _from = account;
              if (_to?.id == account?.id) {
                _to = accounts.firstWhere((item) => item.id != account?.id);
              }
            }),
          ),
          const SizedBox(height: AppSpace.md),
          DropdownButtonFormField<Account>(
            initialValue: _to,
            decoration: const InputDecoration(labelText: 'Ke wallet'),
            items: [
              for (final account in accounts.where((a) => a.id != _from?.id))
                DropdownMenuItem(value: account, child: Text(account.name)),
            ],
            onChanged: (account) => setState(() => _to = account),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
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
                : const Text('Transfer'),
          ),
        ],
      ),
    );
  }
}
