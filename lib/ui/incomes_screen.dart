import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/csv_import.dart' show currencies;
import '../core/format.dart';
import 'common.dart';
import 'files.dart';
import 'import_screen.dart';

class IncomesScreen extends StatelessWidget {
  const IncomesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Loader<List<dynamic>>(
      load: (s) async => await s.api.get('/api/incomes?year=${s.year}') as List<dynamic>,
      builder: (context, list) {
        final incomes = list.cast<Map<String, dynamic>>();
        final total = incomes.fold<num>(0, (sum, i) => sum + (Fmt.toNum(i['amount']) ?? 0));
        return AppPage(
          title: tr('inc.title'),
          subtitle: tr('inc.lead'),
          actions: [
            FilledButton.icon(
              key: const Key('open-import'),
              icon: const Icon(Icons.upload_file),
              label: Text(tr('inc.import')),
              onPressed: () => openImport(context),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: Text(tr('inc.export')),
              onPressed: () => exportFile(context, '/api/export/incomes.csv', 'incomes.csv', 'text/csv'),
            ),
          ],
          children: [
            const _IncomeForm(),
            Section(
              title: tr('inc.yearTotal', {'year': s.year, 'total': s.fmt.money(total)}),
              children: [
                if (incomes.isEmpty) Text(tr('common.empty')),
                for (final i in incomes) _IncomeTile(i),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _IncomeTile extends StatelessWidget {
  const _IncomeTile(this.i);

  final Map<String, dynamic> i;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.fmt;
    final fx = i['currency'] != 'AMD';
    final subtitle = [
      Fmt.date(i['date'] as String),
      if ((i['description'] as String).isNotEmpty) i['description'],
      if (fx) '${f.number(i['originalAmount'])} ${i['currency']} × ${f.number(i['rate'], 4)}',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text((i['client'] as String).isEmpty ? '—' : i['client'] as String),
      subtitle: Text(subtitle),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(f.money(i['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          tooltip: s.tr('common.delete'),
          icon: const Icon(Icons.delete_outline, color: Brand.bad),
          onPressed: () async {
            if (!await confirm(context, s.tr('inc.confirmDelete'))) return;
            if (!context.mounted) return;
            final ok = await guarded(context, () => s.api.delete('/api/incomes/${i['id']}'));
            if (ok && context.mounted) {
              toast(context, s.tr('inc.deleted'));
              s.changed();
            }
          },
        ),
      ]),
    );
  }
}

class _IncomeForm extends StatefulWidget {
  const _IncomeForm();

  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController(text: Fmt.today());
  final _amount = TextEditingController();
  final _original = TextEditingController();
  final _rate = TextEditingController();
  final _client = TextEditingController();
  final _desc = TextEditingController();
  String _currency = 'AMD';

  @override
  void dispose() {
    for (final c in [_date, _amount, _original, _rate, _client, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    final body = {
      'date': _date.text,
      'currency': _currency,
      if (_currency == 'AMD') 'amount': _amount.text else ...{'originalAmount': _original.text, 'rate': _rate.text},
      'client': _client.text,
      'description': _desc.text,
    };
    final ok = await guarded(context, () => s.api.post('/api/incomes', body));
    if (!ok || !mounted) return;
    toast(context, s.tr('inc.added'));
    _amount.clear();
    _original.clear();
    _client.clear();
    _desc.clear();
    s.changed();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final fx = _currency != 'AMD';
    String? required(String? v) => (v ?? '').trim().isEmpty ? tr('common.amount') : null;
    final amd = (double.tryParse(_original.text) ?? 0) * (double.tryParse(_rate.text) ?? 0);
    return Section(children: [
      Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldRow(children: [
            DateField(controller: _date, label: tr('common.date')),
            dropdown<String>(
              label: tr('inc.currency'),
              value: _currency,
              values: currencies,
              text: (c) => c,
              onChanged: (c) => setState(() => _currency = c!),
            ),
            if (!fx)
              TextFormField(
                key: const Key('income-amount'),
                controller: _amount,
                decoration: field(tr('inc.amountAmd'), hint: '150000'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: required,
              ),
            if (fx)
              TextFormField(
                controller: _original,
                decoration: field(tr('inc.original')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: required,
                onChanged: (_) => setState(() {}),
              ),
            if (fx)
              TextFormField(
                controller: _rate,
                decoration: field(tr('inc.rate'), helper: tr('inc.rateHint', {'amd': s.fmt.money(amd.round())})),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: required,
                onChanged: (_) => setState(() {}),
              ),
          ]),
          FieldRow(minWidth: 260, children: [
            TextFormField(controller: _client, decoration: field(tr('common.client'), hint: tr('inc.clientPh'))),
            TextFormField(controller: _desc, decoration: field(tr('common.description'), hint: tr('inc.descPh'))),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(key: const Key('income-add'), onPressed: _submit, child: Text(tr('inc.add'))),
          ),
        ]),
      ),
    ]);
  }
}

/// Поле даты ГГГГ-ММ-ДД с выбором в календаре.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.controller, required this.label, this.required = true});

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: field(label).copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
      validator: (v) => required && (v ?? '').isEmpty ? label : null,
      onTap: () async {
        final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) controller.text = Fmt.iso(picked);
      },
    );
  }
}
