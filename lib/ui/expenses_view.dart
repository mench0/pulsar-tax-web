import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';
import 'files.dart';
import 'incomes_screen.dart' show DateField, MoneyTabs;

const expenseCategories = ['RENT', 'EQUIPMENT', 'SOFTWARE', 'SERVICES', 'TRANSPORT', 'BANK_FEES', 'TAXES_FEES', 'OTHER'];

/// Учёт расходов. Пока только для сводки: на налог с оборота не влияет.
class ExpensesView extends StatelessWidget {
  const ExpensesView({super.key, required this.tabs});

  final MoneyTabs tabs;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Loader<List<dynamic>>(
      load: (s) async => await s.api.get('/api/expenses?year=${s.year}') as List<dynamic>,
      builder: (context, list) {
        final expenses = list.cast<Map<String, dynamic>>();
        final total = expenses.fold<num>(0, (sum, e) => sum + (Fmt.toNum(e['amount']) ?? 0));
        return AppPage(
          title: tr('inc.tabExpenses'),
          subtitle: tr('exp.lead'),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: Text(tr('inc.export')),
              onPressed: () => exportFile(context, '/api/export/expenses.csv', 'expenses.csv', 'text/csv'),
            ),
          ],
          children: [
            tabs,
            const _ExpenseForm(),
            Section(
              title: tr('exp.yearTotal', {'year': s.year, 'total': s.fmt.money(total)}),
              children: [
                if (expenses.isEmpty) Text(tr('common.empty')),
                for (final e in expenses)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('expcat.${e['category']}')),
                    subtitle: Text([
                      Fmt.date(e['date'] as String),
                      if ((e['description'] as String).isNotEmpty) e['description'],
                    ].join(' · ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.fmt.money(e['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                      IconButton(
                        tooltip: tr('common.delete'),
                        icon: const Icon(Icons.delete_outline, color: Brand.bad),
                        onPressed: () async {
                          if (!await confirm(context, tr('exp.confirmDelete'))) return;
                          if (!context.mounted) return;
                          final ok = await guarded(context, () => s.api.delete('/api/expenses/${e['id']}'));
                          if (ok && context.mounted) {
                            toast(context, tr('exp.deleted'));
                            s.changed();
                          }
                        },
                      ),
                    ]),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController(text: Fmt.today());
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'OTHER';

  @override
  void dispose() {
    for (final c in [_date, _amount, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    final ok = await guarded(context, () => s.api.post('/api/expenses', {
          'date': _date.text,
          'amount': _amount.text,
          'category': _category,
          'description': _desc.text,
        }));
    if (!ok || !mounted) return;
    toast(context, s.tr('exp.added'));
    _amount.clear();
    _desc.clear();
    s.changed();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    return Section(children: [
      Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldRow(children: [
            DateField(controller: _date, label: tr('common.date')),
            TextFormField(
              key: const Key('expense-amount'),
              controller: _amount,
              decoration: field(tr('inc.amountAmd')),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : tr('common.amount'),
            ),
            dropdown<String>(
              key: const Key('expense-category'),
              label: tr('exp.category'),
              value: _category,
              values: expenseCategories,
              text: (c) => tr('expcat.$c'),
              onChanged: (c) => setState(() => _category = c!),
            ),
          ]),
          FieldRow(minWidth: 260, children: [
            TextFormField(controller: _desc, maxLength: 500, decoration: field(tr('common.description'), hint: tr('exp.descPh'))),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(key: const Key('expense-add'), onPressed: _submit, child: Text(tr('exp.add'))),
          ),
        ]),
      ),
    ]);
  }
}
