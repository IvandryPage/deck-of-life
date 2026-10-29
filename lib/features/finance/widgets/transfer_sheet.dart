import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/design/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../controllers/finance_controller.dart';
import 'account_dialog.dart';

Future<void> showTransferSheet(
  BuildContext context,
  FinanceController controller, {
  MoneyTransaction? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _TransferForm(controller: controller, existing: existing),
    ),
  );
}

class _TransferForm extends StatefulWidget {
  const _TransferForm({required this.controller, this.existing});
  final FinanceController controller;
  final MoneyTransaction? existing;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Account? _from;
  Account? _to;
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts = widget.controller.accounts;
    final existing = widget.existing;
    final transferId = existing?.transferId;
    if (transferId != null) {
      final pair = widget.controller.transactions
          .where((entry) => entry.transferId == transferId)
          .toList();
      final outgoing = pair
          .where((entry) => entry.direction == TransactionDirection.expense)
          .toList();
      final incoming = pair
          .where((entry) => entry.direction == TransactionDirection.income)
          .toList();
      if (outgoing.length == 1 && incoming.length == 1) {
        _from = _accountFor(accounts, outgoing.single.accountId);
        _to = _accountFor(accounts, incoming.single.accountId);
        _amount.text = outgoing.single.amount.toString();
        _note.text = outgoing.single.note ?? '';
        _date = outgoing.single.occurredAt;
      } else {
        _error = 'Transfer pair not found.';
      }
    } else if (accounts.isNotEmpty) {
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

  Account? _accountFor(List<Account> accounts, String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
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
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    if (from == null || to == null || from.id == to.id) {
      setState(() => _error = 'Choose two different wallets');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final transferId = widget.existing?.transferId;
    final ok = transferId == null
        ? await widget.controller.transfer(
            from: from,
            to: to,
            amount: amount,
            note: note,
            occurredAt: _date,
          )
        : await widget.controller.updateTransfer(
            transferId: transferId,
            from: from,
            to: to,
            amount: amount,
            note: note,
            occurredAt: _date,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 10),
    );
    if (selected != null) setState(() => _date = selected);
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
          title: 'Add two wallets',
          message: 'A transfer needs a source and destination wallet.',
          actionLabel: 'Add wallet',
          onAction: () {
            Navigator.of(context).pop();
            showAddAccountDialog(context, widget.controller);
          },
        ),
      );
    }
    if (widget.existing != null && (_from == null || _to == null)) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: EmptyState(
          compact: true,
          icon: Icons.warning_amber_outlined,
          title: 'Transfer unavailable',
          message: _error ?? 'The source or destination wallet is no longer available.',
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
            decoration: const InputDecoration(labelText: 'From wallet'),
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
            decoration: const InputDecoration(labelText: 'To wallet'),
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
              labelText: 'Amount',
              prefixText: 'Rp ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(Formatters.date(_date)),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
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
                : Text(widget.existing == null ? 'Transfer' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
