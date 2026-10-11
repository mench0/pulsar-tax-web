import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';
import 'tax_details.dart';
import 'incomes_screen.dart' show DateField;
import 'overview_screen.dart' show warningText;

/// Цифры для расчёта в налоговой, шаги подачи и учёт уплаты налога.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(Map<String, dynamic>, List<dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/summary?year=${s.year}') as Map<String, dynamic>,
        await s.api.get('/api/payments?year=${s.year}') as List<dynamic>,
      ),
      builder: (context, data) => _Report(summary: data.$1, payments: data.$2.cast<Map<String, dynamic>>()),
    );
  }
}

class _Report extends StatefulWidget {
  const _Report({required this.summary, required this.payments});

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> payments;

  @override
  State<_Report> createState() => _ReportState();
}

class _ReportState extends State<_Report> {
  late int _period;
  final _payDate = TextEditingController(text: Fmt.today());
  final _payAmount = TextEditingController();
  final _payForm = GlobalKey<FormState>();

  Map<String, dynamic> get s => widget.summary;

  bool get _turnover => s['regime'] == 'TURNOVER';

  List<int> get _periods => _turnover ? [1, 2, 3, 4] : [0];

  @override
  void initState() {
    super.initState();
    final asked = AppScope.read(context).reportPeriod;
    if (asked != null && _periods.contains(asked)) {
      _period = asked;
    } else if (_turnover) {
      // По умолчанию — первый квартал, за который ещё есть что платить, иначе текущий.
      final owed = (s['quarters'] as List).cast<Map<String, dynamic>>().where((q) => (Fmt.toNum(q['due']) ?? 0) > 0);
      _period = owed.isNotEmpty ? owed.first['quarter'] as int : (int.parse(Fmt.today().substring(5, 7)) + 2) ~/ 3;
    } else {
      _period = 0;
    }
    _fillAmount();
  }

  @override
  void dispose() {
    _payDate.dispose();
    _payAmount.dispose();
    super.dispose();
  }

  Map<String, Object?> get _figures {
    if (_period == 0) {
      final paid = widget.payments.where((p) => p['quarter'] == 0).fold<num>(0, (a, p) => a + Fmt.toNum(p['amount'])!);
      final tax = Fmt.toNum(s['totalTax']);
      return {'income': s['totalIncome'], 'tax': tax, 'paid': paid, 'due': tax == null ? null : (tax - paid).clamp(0, double.infinity), 'dueDate': null};
    }
    return (s['quarters'] as List).cast<Map<String, dynamic>>()[_period - 1];
  }

  void _fillAmount() {
    final due = Fmt.toNum(_figures['due']);
    _payAmount.text = due != null && due > 0 ? '${due.round()}' : '';
  }

  String _periodLabel(int p) {
    final tr = AppScope.read(context).tr;
    return p == 0 ? tr('rep.periodYear') : tr('common.quarter', {'q': p});
  }

  Future<void> _pay() async {
    if (!_payForm.currentState!.validate()) return;
    final st = AppScope.read(context);
    final ok = await guarded(context, () => st.api.post('/api/payments', {
          'year': st.year,
          'quarter': _period,
          'date': _payDate.text,
          'amount': _payAmount.text,
        }));
    if (ok && mounted) {
      toast(context, st.tr('rep.payAdded'));
      st.go(AppTab.report, period: _period);
      st.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final tr = st.tr;
    final f = st.fmt;
    final fig = _figures;
    final params = {
      'period': '${_periodLabel(_period)} ${st.year}',
      'year': st.year,
      'turnover': f.money(fig['income']),
      'activity': tr('activity.${s['activity']}'),
      'tax': f.money(fig['tax']),
      'toPay': f.money(fig['due']),
      'date': fig['dueDate'] == null ? '—' : Fmt.date(fig['dueDate'] as String),
    };
    final warnings = (s['warnings'] as List).cast<Map<String, dynamic>>();

    Widget figure(String label, String value, {Object? copy, bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: strong ? const TextStyle(fontWeight: FontWeight.w700) : TextStyle(color: Theme.of(context).hintColor)),
            ),
            Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500, fontSize: strong ? 18 : null)),
            SizedBox(
              width: 48,
              child: copy == null
                  ? null
                  : IconButton(
                      tooltip: tr('common.copy'),
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => copyText(context, '$copy'),
                    ),
            ),
          ]),
        );

    return AppPage(title: tr('rep.title'), subtitle: tr('rep.lead'), children: [
      for (final w in warnings.where((w) => w['code'] == 'REGIME_NOT_ALLOWED')) Notice(warningText(tr, w), bad: true),
      if (s['regime'] == 'GENERAL')
        Notice(tr('rep.general'))
      else
        Grid(minWidth: 380, children: [
          Section(children: [
            dropdown<int>(
              key: const Key('period'),
              label: tr('rep.period'),
              value: _period,
              values: _periods,
              text: _periodLabel,
              onChanged: (p) => setState(() {
                _period = p!;
                _fillAmount();
              }),
            ),
            const SizedBox(height: 8),
            figure(tr('rep.turnover'), f.money(fig['income']), copy: fig['income']),
            figure(tr('rep.rate'), s['ratePercent'] == null ? '—' : '${s['ratePercent']}%'),
            figure(tr('rep.tax'), f.money(fig['tax']), copy: fig['tax']),
            figure(tr('rep.paid'), f.money(fig['paid'])),
            KeyedSubtree(key: const Key('to-pay'), child: figure(tr('rep.toPay'), f.money(fig['due']), strong: true)),
            if (fig['dueDate'] != null) figure(tr('rep.deadline'), Fmt.date(fig['dueDate'] as String)),
          ]),
          Section(title: tr('rep.stepsTitle'), children: [
            for (final (i, step) in [
              tr('rep.step1'),
              tr(_turnover ? 'rep.step2turnover' : 'rep.step2micro', params),
              if (_turnover) ...[tr('rep.step3', params), tr('rep.step4', params), tr('rep.step5')],
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${i + 1}. $step'),
              ),
            Text(tr('rep.stepsNote'), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      if (s['regime'] != 'GENERAL') ...[
        TaxExplanation(key: ValueKey('calc-${st.year}-$_period'), year: st.year, quarter: _period == 0 ? null : _period),
        FilingPanel(key: ValueKey('file-${st.year}-$_period'), year: st.year, quarter: _period == 0 ? null : _period),
      ],
      Section(title: tr('rep.payTitle'), children: [
        Form(
          key: _payForm,
          child: FieldRow(children: [
            DateField(controller: _payDate, label: tr('common.date')),
            TextFormField(
              key: const Key('pay-amount'),
              controller: _payAmount,
              decoration: field('${tr('common.amount')}, ֏'),
              keyboardType: TextInputType.number,
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : tr('common.amount'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(key: const Key('pay-add'), onPressed: _pay, child: Text(tr('rep.payAdd'))),
            ),
          ]),
        ),
        if (widget.payments.isEmpty) Text(tr('rep.payEmpty')),
        for (final p in widget.payments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.money(p['amount'])),
            subtitle: Text('${Fmt.date(p['date'] as String)} · ${_periodLabel(p['quarter'] as int)}'),
            trailing: IconButton(
              tooltip: tr('common.delete'),
              icon: const Icon(Icons.delete_outline, color: Brand.bad),
              onPressed: () async {
                if (!await confirm(context, tr('rep.payConfirm'))) return;
                if (!context.mounted) return;
                final ok = await guarded(context, () => st.api.delete('/api/payments/${p['id']}'));
                if (ok && context.mounted) {
                  toast(context, tr('rep.payDeleted'));
                  st.changed();
                }
              },
            ),
          ),
      ]),
    ]);
  }
}
