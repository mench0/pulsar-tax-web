import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';

/// Налоговый резерв и прогноз денег: факт отдельно от оценки, с объяснением и допущениями.
class PlanningPanel extends StatelessWidget {
  const PlanningPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(Map<String, dynamic>, Map<String, dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/planning/reserve') as Map<String, dynamic>,
        await s.api.get('/api/planning/forecast?months=3') as Map<String, dynamic>,
      ),
      builder: (context, d) => Grid(minWidth: 420, children: [
        _Reserve(r: d.$1),
        _Forecast(f: d.$2),
      ]),
    );
  }
}

class _Reserve extends StatelessWidget {
  const _Reserve({required this.r});

  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final f = s.fmt;
    final obligations = (r['obligations'] as List).cast<Map<String, dynamic>>();
    final gap = Fmt.toNum(r['gap']);
    final theme = Theme.of(context);
    return Section(title: tr('plan.reserve'), children: [
      Row(children: [
        Expanded(child: Text(tr('plan.recommended'), style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(f.money(r['recommended']), key: const Key('reserve-recommended'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ]),
      const SizedBox(height: 4),
      if (r['actual'] != null)
        Text(
          gap! > 0 ? tr('plan.shortfall', {'amount': f.money(gap)}) : tr('plan.surplus', {'amount': f.money(-gap)}),
          style: TextStyle(color: gap > 0 ? Brand.bad : Brand.ok, fontWeight: FontWeight.w600),
        ),
      if (r['nextDeadline'] != null)
        Text(tr('plan.next', {'date': Fmt.date(r['nextDeadline'] as String), 'amount': f.money(r['nextDeadlineAmount'])})),
      const SizedBox(height: 8),
      for (final st in (r['steps'] as List).cast<Map<String, dynamic>>())
        Row(children: [
          Expanded(child: Text(tr('plan.step.${st['code']}', {
            ...((st['params'] as Map).cast<String, Object?>()),
            if ((st['params'] as Map)['receivables'] != null) 'receivables': f.money((st['params'] as Map)['receivables']),
            if ((st['params'] as Map)['rate'] != null) 'rate': '${(st['params'] as Map)['rate']}%',
          }))),
          Text(f.money(st['amount'])),
        ]),
      if (obligations.isNotEmpty) ...[
        const Divider(),
        for (final o in obligations)
          Text(
            tr('plan.obligation', {
              'period': '${tr('common.quarter', {'q': o['quarter']})} ${o['year']}',
              'accrued': f.money(o['accrued']),
              'paid': f.money(o['paid']),
              'due': f.money(o['due']),
              'state': tr('plan.state.${o['state']}'),
              'date': Fmt.date(o['deadline'] as String),
            }),
            style: TextStyle(color: o['state'] == 'OVERDUE' ? Brand.bad : null),
          ),
      ],
      const SizedBox(height: 8),
      for (final n in (r['notes'] as List).cast<String>())
        Text('· ${tr('plan.note.$n')}', style: theme.textTheme.bodySmall),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('balances-edit'),
          icon: const Icon(Icons.edit_outlined),
          label: Text(tr('plan.balances')),
          onPressed: () => _editBalances(context, r),
        ),
      ),
    ]);
  }
}

Future<void> _editBalances(BuildContext context, Map<String, dynamic> r) async {
  final s = AppScope.read(context);
  final tr = s.tr;
  final reserve = TextEditingController(text: r['actual'] == null ? '' : '${r['actual']}');
  final cash = TextEditingController();
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('plan.balances')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('balance-reserve'), controller: reserve, decoration: field(tr('plan.actualReserve'))),
        const SizedBox(height: 12),
        TextField(key: const Key('balance-cash'), controller: cash, decoration: field(tr('plan.cash'), helper: tr('plan.cashHelp'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('✕')),
        FilledButton(key: const Key('balance-save'), onPressed: () => Navigator.pop(c, true), child: Text(tr('common.save'))),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  String? num(String v) => v.trim().isEmpty ? null : v.trim().replaceAll(' ', '').replaceAll(',', '.');
  final ok = await guarded(context, () => s.api.put('/api/planning/balances', {
        'reserveBalance': num(reserve.text),
        'cashBalance': num(cash.text),
      }));
  if (ok) s.changed();
}

class _Forecast extends StatelessWidget {
  const _Forecast({required this.f});

  final Map<String, dynamic> f;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final fmt = s.fmt;
    final months = (f['projection'] as List).cast<Map<String, dynamic>>();
    final warnings = (f['warnings'] as List).cast<Map<String, dynamic>>();
    final theme = Theme.of(context);
    return Section(title: tr('plan.forecast'), children: [
      Text(tr('plan.forecastLead', {'n': f['historyMonths']}), style: theme.textTheme.bodySmall),
      for (final w in warnings)
        Notice(tr('plan.warn.${w['code']}', {
          ...((w['params'] as Map).cast<String, Object?>()),
          for (final k in ['taxes', 'closingLow', 'closing', 'amount'])
            if ((w['params'] as Map)[k] != null) k: fmt.money((w['params'] as Map)[k]),
          if ((w['params'] as Map)['deadline'] != null) 'deadline': Fmt.date((w['params'] as Map)['deadline'] as String),
        }), bad: w['code'] == 'POSSIBLE_SHORTFALL_FOR_TAX' || w['code'] == 'TAX_OVERDUE'),
      for (final m in months)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m['month'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(tr('plan.month', {
              'in': fmt.money(m['historyInflow']),
              'rec': fmt.money(m['receivables']),
              'out': fmt.money(m['historyOutflow']),
              'tax': fmt.money(m['taxes']),
            })),
            for (final t in (m['taxItems'] as List).cast<Map<String, dynamic>>())
              Text(tr(t['known'] == true ? 'plan.taxKnown' : 'plan.taxEstimate', {
                'period': t['period'],
                'amount': fmt.money(t['amount']),
                'date': Fmt.date(t['deadline'] as String?),
              }), style: theme.textTheme.bodySmall),
            Text(tr('plan.closing', {
              'low': fmt.money(m['closingLow']),
              'base': fmt.money(m['closing']),
              'high': fmt.money(m['closingHigh']),
            }), style: const TextStyle(fontWeight: FontWeight.w500)),
          ]),
        ),
      const Divider(),
      Text(tr('plan.assumptions'), style: theme.textTheme.titleSmall),
      for (final a in (f['assumptions'] as List).cast<String>()) Text('· ${tr('plan.assume.$a')}', style: theme.textTheme.bodySmall),
      Text(tr('plan.disclaimer'), style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
    ]);
  }
}
