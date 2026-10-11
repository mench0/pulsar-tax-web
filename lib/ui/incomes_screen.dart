import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/csv_import.dart' show currencies;
import '../core/format.dart';
import 'common.dart';
import 'expenses_view.dart';
import 'files.dart';
import 'import_screen.dart';
import 'rates.dart';

/// Вкладка «Доходы»: доходы и расходы с переключателем.
class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  bool _expenses = false;

  @override
  Widget build(BuildContext context) {
    final tabs = MoneyTabs(expenses: _expenses, onChanged: (v) => setState(() => _expenses = v));
    return _expenses ? ExpensesView(tabs: tabs) : _IncomesView(tabs: tabs);
  }
}

/// Переключатель «Доходы / Расходы».
class MoneyTabs extends StatelessWidget {
  const MoneyTabs({super.key, required this.expenses, required this.onChanged});

  final bool expenses;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SegmentedButton<bool>(
        key: const Key('money-tabs'),
        segments: [
          ButtonSegment(value: false, label: Text(tr('inc.tabIncomes')), icon: const Icon(Icons.south_west)),
          ButtonSegment(value: true, label: Text(tr('inc.tabExpenses')), icon: const Icon(Icons.north_east)),
        ],
        selected: {expenses},
        onSelectionChanged: (v) => onChanged(v.first),
      ),
    );
  }
}

class _IncomesView extends StatelessWidget {
  const _IncomesView({required this.tabs});

  final MoneyTabs tabs;

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
            tabs,
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

  /// Курс подставлен из ЦБ (а не введён вручную) — его можно заменять при смене даты или валюты.
  bool _rateFromCba = false;
  String? _rateNote;

  @override
  void initState() {
    super.initState();
    _date.addListener(_loadRate);
  }

  /// Подставляет курс ЦБ РА на дату поступления. Курс, введённый вручную, не трогает.
  Future<void> _loadRate() async {
    if (_currency == 'AMD' || _date.text.isEmpty) return;
    final s = AppScope.read(context);
    final date = _date.text, currency = _currency;
    try {
      final rate = await CbaRates.rate(s, date, currency);
      if (!mounted || date != _date.text || currency != _currency) return;
      setState(() {
        if (_rate.text.isEmpty || _rateFromCba) {
          _rate.text = '$rate';
          _rateFromCba = true;
        }
        _rateNote = s.tr('rates.cba', {'date': Fmt.date(date), 'rate': s.fmt.number(rate, 4)});
      });
    } catch (_) {
      if (mounted) setState(() => _rateNote = s.tr('rates.failed'));
    }
  }

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
    Map<String, dynamic>? added;
    final ok = await guarded(context, () async => added = await s.api.post('/api/incomes', body) as Map<String, dynamic>);
    if (!ok) return;
    final message = await _addedMessage(s, added!);
    if (!mounted) return;
    toast(context, message);
    _amount.clear();
    _original.clear();
    _client.clear();
    _desc.clear();
    s.changed();
  }

  /// «Отложите N ֏ на налог» — по ставке года поступления; если ставки нет, просто «Доход добавлен».
  Future<String> _addedMessage(AppState s, Map<String, dynamic> income) async {
    try {
      final year = (income['date'] as String).substring(0, 4);
      final summary = await s.api.get('/api/summary?year=$year') as Map<String, dynamic>;
      final percent = Fmt.toNum(summary['setAsidePercent']) ?? 0;
      final amount = Fmt.toNum(income['amount']) ?? 0;
      if (percent > 0) return s.tr('inc.setAside', {'amount': s.fmt.money((amount * percent / 100).round())});
    } catch (_) {
      // сводка недоступна — обойдёмся без суммы
    }
    return s.tr('inc.added');
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
              key: const Key('income-currency'),
              label: tr('inc.currency'),
              value: _currency,
              values: currencies,
              text: (c) => c,
              onChanged: (c) {
                setState(() {
                  _currency = c!;
                  _rateNote = null;
                  if (_rateFromCba) _rate.clear();
                });
                _loadRate();
              },
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
                key: const Key('income-original'),
                controller: _original,
                decoration: field(tr('inc.original')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: required,
                onChanged: (_) => setState(() {}),
              ),
            if (fx)
              TextFormField(
                controller: _rate,
                key: const Key('income-rate'),
                decoration: field(tr('inc.rate'), helper: [
                  ?_rateNote,
                  tr('inc.rateHint', {'amd': s.fmt.money(amd.round())}),
                ].join('\n')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: required,
                onChanged: (_) => setState(() => _rateFromCba = false),
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
