import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';

/// Состояние оплаты счёта по сверке: открыт, частично, оплачен, переплата; просрочка.
class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.state});

  final Map<String, dynamic>? state;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = state?['state'] as String? ?? 'OPEN';
    final overdue = state?['overdue'] == true;
    final color = switch (st) {
      'PAID' => Brand.okFill,
      'OVERPAID' => Brand.warningFill,
      _ => overdue ? Brand.badFill : Brand.warningFill,
    };
    final balance = Fmt.toNum(state?['balance']) ?? 0;
    final label = st == 'PARTIAL' ? s.tr('rec.state.PARTIAL', {'left': s.fmt.money(balance)}) : s.tr('rec.state.$st');
    return Chip(
      label: Text(overdue ? '$label · ${s.tr('rec.overdue')}' : label),
      backgroundColor: color.withValues(alpha: .12),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Сверка: задолженность, подсказки «этот платёж похож на оплату счёта» и поступления без счёта.
class ReconciliationPanel extends StatelessWidget {
  const ReconciliationPanel({super.key, required this.rec});

  final Map<String, dynamic> rec;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final f = s.fmt;
    final invoices = {for (final i in (rec['invoices'] as List).cast<Map<String, dynamic>>()) i['id']: i};
    final incomes = {for (final i in (rec['unmatchedIncomes'] as List).cast<Map<String, dynamic>>()) i['id']: i};
    final suggestions = (rec['suggestions'] as List).cast<Map<String, dynamic>>();
    final open = invoices.values.where((i) => (Fmt.toNum(i['balance']) ?? 0) > 0).toList();
    return Section(title: tr('rec.title'), children: [
      Text(tr('rec.totals', {
        'receivable': f.money(rec['receivable']),
        'overdue': f.money(rec['overdue']),
        'open': open.length,
        'unmatched': incomes.length,
      }), key: const Key('rec-totals')),
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(tr('rec.suggestions'), style: Theme.of(context).textTheme.titleSmall),
      ],
      for (final sg in suggestions)
        Builder(builder: (context) {
          final inv = invoices[sg['invoiceId']]!;
          final inc = incomes[sg['incomeId']]!;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('rec.suggestion', {
              'number': inv['number'],
              'client': inv['client'],
              'date': Fmt.date(inc['date'] as String),
              'amount': f.money(sg['amount']),
            })),
            subtitle: Text((sg['reasons'] as List).map((r) => tr('rec.reason.$r')).join(', ')),
            trailing: FilledButton(
              key: Key('rec-link-${sg['invoiceId']}-${sg['incomeId']}'),
              onPressed: () async {
                final ok = await guarded(context, () => s.api.post('/api/reconciliation/allocations', {
                      'invoiceId': sg['invoiceId'],
                      'incomeId': sg['incomeId'],
                      'fromSuggestion': true,
                    }));
                if (ok) s.changed();
              },
              child: Text(tr('rec.link')),
            ),
          );
        }),
      if (open.isNotEmpty && incomes.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.link),
            label: Text(tr('rec.manual')),
            onPressed: () => _manualLink(context, open, incomes.values.toList()),
          ),
        ),
      Text(tr('rec.note'), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Future<void> _manualLink(BuildContext context, List<Map<String, dynamic>> open, List<Map<String, dynamic>> incomes) async {
    final s = AppScope.read(context);
    final tr = s.tr;
    final f = s.fmt;
    var invoice = open.first['id'] as int;
    var income = incomes.first['id'] as int;
    final amount = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(tr('rec.manual')),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              dropdown<int>(
                label: tr('rec.invoice'),
                value: invoice,
                values: [for (final i in open) i['id'] as int],
                text: (id) {
                  final i = open.firstWhere((x) => x['id'] == id);
                  return '${i['number']} · ${i['client']} · ${f.money(i['balance'])}';
                },
                onChanged: (v) => set(() => invoice = v!),
              ),
              const SizedBox(height: 12),
              dropdown<int>(
                label: tr('rec.income'),
                value: income,
                values: [for (final i in incomes) i['id'] as int],
                text: (id) {
                  final i = incomes.firstWhere((x) => x['id'] == id);
                  return '${Fmt.date(i['date'] as String)} · ${f.money(i['remaining'])} · ${i['client']}';
                },
                onChanged: (v) => set(() => income = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: amount, decoration: field(tr('rec.amount'), helper: tr('rec.amountHelp'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('✕')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('rec.link'))),
          ],
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final ok = await guarded(context, () => s.api.post('/api/reconciliation/allocations', {
          'invoiceId': invoice,
          'incomeId': income,
          if (amount.text.trim().isNotEmpty) 'amount': amount.text.trim().replaceAll(',', '.'),
        }));
    if (ok) s.changed();
  }
}
