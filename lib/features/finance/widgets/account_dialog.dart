import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/fields_dialog.dart';
import '../../../domain/entities/enums.dart';
import '../controllers/finance_controller.dart';

Future<void> showAddAccountDialog(BuildContext context, FinanceController c) async {
  final r = await showFieldsDialog(
    context,
    title: 'New wallet',
    fields: [
      const FieldSpec(label: 'Name', helper: 'e.g. Cash, checking account, e-wallet'),
      FieldSpec(
        label: 'Type',
        options: [for (final t in AccountType.values) t.label],
      ),
      const FieldSpec(label: 'Current balance (Rp)', numeric: true),
    ],
  );
  if (r == null) return;
  await c.addAccount(
    r[0],
    AccountType.values[int.parse(r[1])],
    Formatters.parseRupiah(r[2]) ?? 0,
  );
}
