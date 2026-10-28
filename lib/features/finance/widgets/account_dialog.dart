import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/fields_dialog.dart';
import '../../../domain/entities/enums.dart';
import '../controllers/finance_controller.dart';

Future<void> showAddAccountDialog(BuildContext context, FinanceController c) async {
  final r = await showFieldsDialog(
    context,
    title: 'Akun baru',
    fields: [
      const FieldSpec(label: 'Nama', helper: 'mis. BCA, Uang tunai, ShopeePay'),
      FieldSpec(
        label: 'Jenis',
        options: [for (final t in AccountType.values) t.label],
      ),
      const FieldSpec(label: 'Saldo sekarang (Rp)', numeric: true),
    ],
  );
  if (r == null) return;
  await c.addAccount(
    r[0],
    AccountType.values[int.parse(r[1])],
    Formatters.parseRupiah(r[2]) ?? 0,
  );
}
