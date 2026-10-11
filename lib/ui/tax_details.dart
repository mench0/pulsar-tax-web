import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import 'common.dart';
import 'files.dart';

/// Текст замечания расчёта или проверки отчёта по коду и параметрам.
String issueText(Tr tr, Map<String, dynamic> i, {String prefix = 'issue'}) {
  final p = ((i['params'] as Map?) ?? {}).cast<String, Object?>();
  final params = <String, Object?>{
    ...p,
    for (final e in p.entries)
      if (e.value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e.value as String)) e.key: Fmt.date(e.value as String),
  };
  final money = Fmt(tr.lang);
  for (final k in ['amount', 'turnover', 'limit', 'sum', 'expected', 'cbaRate', 'rate']) {
    if (p[k] != null && k != 'rate' && k != 'cbaRate') params[k] = money.money(p[k]);
    if (p[k] != null && (k == 'rate' || k == 'cbaRate')) params[k] = money.number(p[k], 6);
  }
  if (p['rule'] != null) params['rule'] = tr('rule.${p['rule']}');
  if (p['status'] != null) params['status'] = tr('basis.${p['status']}');
  if (p['activity'] != null) params['activity'] = tr('activity.${p['activity']}');
  if (p['regime'] != null) params['regime'] = tr('regime.${p['regime']}');
  if (p['months'] is List) params['months'] = (p['months'] as List).join(', ');
  return tr('$prefix.${i['code']}', params);
}

/// Подробный расчёт за период: итоги, шаги, правила с основаниями, операции и снимки.
class TaxExplanation extends StatelessWidget {
  const TaxExplanation({super.key, required this.year, required this.quarter});

  final int year;

  /// null — расчёт за год.
  final int? quarter;

  @override
  Widget build(BuildContext context) {
    final q = quarter == null ? '' : '&quarter=$quarter';
    return Loader<(Map<String, dynamic>, List<dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/tax/calculation?year=$year$q') as Map<String, dynamic>,
        await s.api.get('/api/tax/snapshots?year=$year') as List<dynamic>,
      ),
      builder: (context, d) => _Explanation(
        calc: d.$1,
        snapshots: d.$2.cast<Map<String, dynamic>>().where((x) => x['quarter'] == quarter).toList(),
        year: year,
        quarter: quarter,
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.calc, required this.snapshots, required this.year, required this.quarter});

  final Map<String, dynamic> calc;
  final List<Map<String, dynamic>> snapshots;
  final int year;
  final int? quarter;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final f = s.fmt;
    final t = (calc['totals'] as Map).cast<String, dynamic>();
    final issues = (calc['issues'] as List).cast<Map<String, dynamic>>();
    final rules = (calc['rules'] as List).cast<Map<String, dynamic>>();
    final lines = (calc['lines'] as List).cast<Map<String, dynamic>>();
    final steps = (calc['steps'] as List).cast<Map<String, dynamic>>();
    final theme = Theme.of(context);

    Widget row(String label, Object? value, {bool strong = false, String? key}) => Padding(
          key: key == null ? null : Key(key),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
            Text(value is String ? value : f.money(value),
                style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );

    return Section(title: tr('calc.title'), children: [
      for (final i in issues.where((i) => i['severity'] != 'INFO')) Notice(issueText(tr, i), bad: i['severity'] == 'ERROR'),
      row(tr('calc.turnover'), t['turnover']),
      row(tr('calc.expenses'), t['expenses']),
      row(tr('calc.base'), t['taxBase']),
      row(tr('calc.unrounded'), t['taxUnrounded'] == null ? '—' : '${f.number(t['taxUnrounded'], 4)} ֏'),
      row(tr('calc.rounding'), t['rounding'] == null ? '—' : '${f.number(t['rounding'], 4)} ֏'),
      row(tr('calc.accrued'), t['accrued'], strong: true, key: 'calc-accrued'),
      row(tr('calc.paid'), t['paid']),
      row(tr('calc.due'), t['due'], strong: true),
      if ((Fmt.toNum(t['overpaid']) ?? 0) > 0) row(tr('calc.overpaid'), t['overpaid']),
      const SizedBox(height: 12),
      ExpansionTile(
        key: const Key('calc-steps'),
        tilePadding: EdgeInsets.zero,
        title: Text(tr('calc.how')),
        initiallyExpanded: true,
        children: [
          for (final (n, st) in steps.indexed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text('${n + 1}.'),
              title: Text(tr('step.${st['code']}', _stepParams(tr, f, st))),
              trailing: st['amount'] == null ? null : Text('${f.number(st['amount'], 4)} ֏'),
            ),
        ],
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tr('calc.rules', {'n': rules.length})),
        children: [
          for (final r in rules)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${tr('rule.${r['code']}')}: ${r['value']}'),
              subtitle: Text([
                tr('calc.since', {'date': Fmt.date(r['effectiveFrom'] as String?)}),
                (r['basis'] as Map)['reference'] as String,
                if (((r['basis'] as Map)['note'] as String?)?.isNotEmpty ?? false) (r['basis'] as Map)['note'] as String,
              ].join('\n')),
              trailing: _BasisChip(status: (r['basis'] as Map)['status'] as String),
              onTap: (r['basis'] as Map)['url'] == null ? null : () => openLink(context, (r['basis'] as Map)['url'] as String),
            ),
          Text(tr('calc.rulesNote'), style: theme.textTheme.bodySmall),
        ],
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tr('calc.lines', {'n': lines.length})),
        children: [
          for (final l in lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${Fmt.date(l['date'] as String)} · ${f.money(l['amountAmd'])}'
                  '${l['currency'] != 'AMD' ? ' (${f.number(l['originalAmount'])} ${l['currency']} × ${l['fxRate'] ?? '?'})' : ''}'),
              subtitle: Text([
                if ((l['client'] as String? ?? '').isNotEmpty) l['client'],
                l['inBase'] == true ? '${l['ratePercent']}%' : tr('excl.${l['exclusionReason']}'),
                if (l['fxCheck'] != 'AMD') tr('fx.${l['fxCheck']}'),
              ].join(' · ')),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          key: const Key('snapshot-save'),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(tr('calc.snapshot')),
          onPressed: () async {
            final ok = await guarded(context, () => s.api.post('/api/tax/snapshots', {'year': year, 'quarter': quarter}));
            if (ok && context.mounted) {
              toast(context, tr('calc.snapshotSaved'));
              s.changed();
            }
          },
        ),
      ]),
      for (final sn in snapshots.take(5))
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: Text(tr('calc.snapshotFrom', {'date': (sn['createdAt'] as String).substring(0, 16).replaceFirst('T', ' ')})),
          subtitle: Text('${tr('calc.accrued')}: ${f.money(sn['accrued'])}${(sn['reason'] as String).isEmpty ? '' : ' · ${sn['reason']}'}'),
          trailing: TextButton(
            child: Text(tr('calc.whatChanged')),
            onPressed: () => _showDiff(context, sn['id'] as int),
          ),
        ),
    ]);
  }

  static Map<String, Object?> _stepParams(Tr tr, dynamic f, Map<String, dynamic> st) {
    final p = ((st['params'] as Map?) ?? {}).cast<String, Object?>();
    return {
      ...p,
      if (p['rate'] != null) 'rate': '${p['rate']}%',
      if (p['base'] != null) 'base': f.money(p['base']),
      if (p['rule'] != null) 'rule': tr('rule.${p['rule']}'),
      if (p['from'] != null) 'from': Fmt.date(p['from'] as String),
      if (p['regime'] != null) 'regime': tr('regime.${p['regime']}'),
      if (p['unrounded'] != null) 'unrounded': f.number(p['unrounded'], 4),
    };
  }
}

Future<void> _showDiff(BuildContext context, int id) async {
  final s = AppScope.read(context);
  final tr = s.tr;
  Map<String, dynamic>? diff;
  final ok = await guarded(context, () async => diff = await s.api.get('/api/tax/snapshots/$id/diff') as Map<String, dynamic>);
  if (!ok || !context.mounted) return;
  await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: Text(tr('calc.whatChanged')),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: DiffView(diff: diff!))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ));
}

/// Что изменилось с момента снимка: итоги, операции, ставки.
class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.diff});

  final Map<String, dynamic> diff;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final f = s.fmt;
    if (diff['changed'] != true) return Text(tr('diff.none'));
    final totals = (diff['totals'] as Map).cast<String, dynamic>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final e in totals.entries)
        if ((e.value as List)[0] != (e.value as List)[1])
          Text('${tr('diff.total.${e.key}')}: ${f.money((e.value as List)[0])} → ${f.money((e.value as List)[1])}'),
      const SizedBox(height: 8),
      for (final r in (diff['rates'] as List).cast<Map<String, dynamic>>())
        Text(tr('diff.rate', {'rule': tr('rule.${r['ruleCode']}'), 'before': r['rateBefore'] ?? '—', 'after': r['rateAfter'] ?? '—'})),
      for (final l in (diff['lines'] as List).cast<Map<String, dynamic>>())
        Text(tr('diff.line.${l['kind']}', {
          'date': Fmt.date(((l['after'] ?? l['before']) as Map)['date'] as String),
          'delta': f.money(l['amountDelta']),
          'amount': f.money(((l['after'] ?? l['before']) as Map)['amountAmd']),
        })),
    ]);
  }
}

class _BasisChip extends StatelessWidget {
  const _BasisChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    final color = switch (status) {
      'OFFICIAL_TEXT' => Brand.ok,
      'OFFICIAL_SUMMARY' => Brand.ok,
      'SECONDARY_SOURCES' => Brand.warning,
      _ => Brand.bad,
    };
    return Tooltip(
      message: tr('basis.$status.long'),
      child: Chip(
        label: Text(tr('basis.$status'), style: TextStyle(color: color, fontSize: 12)),
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: color.withValues(alpha: .4)),
      ),
    );
  }
}

/// Подготовка отчёта к подаче: проверки, источники, версии, выгрузка и отметка о подаче.
class FilingPanel extends StatelessWidget {
  const FilingPanel({super.key, required this.year, required this.quarter});

  final int year;
  final int? quarter;

  @override
  Widget build(BuildContext context) {
    final q = quarter == null ? '' : '&quarter=$quarter';
    return Loader<(Map<String, dynamic>, List<dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/reports/readiness?year=$year$q') as Map<String, dynamic>,
        await s.api.get('/api/reports?year=$year') as List<dynamic>,
      ),
      builder: (context, d) => _Filing(
        r: d.$1,
        reports: d.$2.cast<Map<String, dynamic>>().where((x) => x['quarter'] == d.$1['quarter']).toList(),
      ),
    );
  }
}

class _Filing extends StatefulWidget {
  const _Filing({required this.r, required this.reports});

  final Map<String, dynamic> r;
  final List<Map<String, dynamic>> reports;

  @override
  State<_Filing> createState() => _FilingState();
}

class _FilingState extends State<_Filing> {
  bool _accept = false;

  Future<void> _prepare() async {
    final s = AppScope.read(context);
    final r = widget.r;
    final ok = await guarded(context, () => s.api.post('/api/reports', {
          'year': r['year'],
          'quarter': r['quarter'],
          'acceptWarnings': _accept,
        }));
    if (ok && mounted) {
      toast(context, s.tr('file.prepared'));
      s.changed();
    }
  }

  Future<void> _markFiled(Map<String, dynamic> report) async {
    final s = AppScope.read(context);
    final tr = s.tr;
    final date = TextEditingController(text: Fmt.today());
    final ref = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('file.markFiled')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('file.markFiledNote')),
          const SizedBox(height: 12),
          TextField(controller: date, decoration: field(tr('common.date'))),
          const SizedBox(height: 12),
          TextField(controller: ref, decoration: field(tr('file.reference'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('✕')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('file.markFiled'))),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final ok = await guarded(context,
        () => s.api.post('/api/reports/${report['id']}/filed', {'filedOn': date.text.trim(), 'reference': ref.text.trim()}));
    if (ok) s.changed();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final f = s.fmt;
    final r = widget.r;
    final checks = (r['checks'] as List).cast<Map<String, dynamic>>();
    final sources = (r['sources'] as Map).cast<String, dynamic>();
    final instructions = (r['instructions'] as List).cast<Map<String, dynamic>>();
    final hasWarnings = checks.any((c) => c['level'] == 'WARNING');
    final theme = Theme.of(context);
    return Section(title: tr('file.title'), children: [
      Text(tr('file.noApi'), style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      Text(r['ready'] == true ? tr('file.ready') : tr('file.notReady'),
          key: const Key('filing-ready'),
          style: TextStyle(fontWeight: FontWeight.w700, color: r['ready'] == true ? Brand.ok : Brand.bad)),
      const SizedBox(height: 8),
      for (final c in checks)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            switch (c['level']) { 'BLOCKER' => Icons.block, 'WARNING' => Icons.warning_amber, _ => Icons.info_outline },
            color: switch (c['level']) { 'BLOCKER' => Brand.bad, 'WARNING' => Brand.warning, _ => theme.hintColor },
          ),
          title: Text(issueText(tr, c)),
        ),
      const SizedBox(height: 8),
      Text(tr('file.sources', {
        'bank': sources['bankIncomes'],
        'bankSum': f.money(sources['bankSum']),
        'manual': sources['manualIncomes'],
        'manualSum': f.money(sources['manualSum']),
      })),
      const SizedBox(height: 12),
      if (hasWarnings && r['ready'] == true)
        CheckboxListTile(
          key: const Key('accept-warnings'),
          contentPadding: EdgeInsets.zero,
          value: _accept,
          onChanged: (v) => setState(() => _accept = v!),
          title: Text(tr('file.accept')),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: const Key('report-prepare'),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(tr('file.prepare')),
          onPressed: r['ready'] == true && (!hasWarnings || _accept) ? _prepare : null,
        ),
      ),
      const SizedBox(height: 12),
      for (final rep in widget.reports)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('file.version', {'v': rep['version'], 'status': tr('file.status.${rep['status']}')})),
          subtitle: Text([
            '${tr('calc.turnover')}: ${f.money(rep['turnover'])}',
            '${tr('calc.accrued')}: ${f.money(rep['accrued'])}',
            '${tr('calc.due')}: ${f.money(rep['due'])}',
            if (rep['filedOn'] != null) tr('file.filedOn', {'date': Fmt.date(rep['filedOn'] as String), 'ref': rep['filingReference']}),
          ].join(' · ')),
          trailing: Wrap(spacing: 4, children: [
            IconButton(
              tooltip: tr('file.export'),
              icon: const Icon(Icons.download),
              onPressed: () => exportFile(context, '/api/reports/${rep['id']}/export.csv', 'report.csv', 'text/csv'),
            ),
            if (rep['status'] == 'PREPARED')
              TextButton(onPressed: () => _markFiled(rep), child: Text(tr('file.markFiled'))),
            if (rep['status'] == 'FILED_MANUALLY')
              TextButton(
                onPressed: () async {
                  final ok = await guarded(context, () => s.api.delete('/api/reports/${rep['id']}/filed'));
                  if (ok) s.changed();
                },
                child: Text(tr('file.unmark')),
              ),
          ]),
        ),
      const Divider(),
      Text(tr('file.howTo'), style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      for (final (n, step) in instructions.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('${n + 1}. ${issueText(tr, {'code': step['code'], 'params': _money(f, step['params'] as Map)}, prefix: 'howto')}'),
        ),
    ]);
  }

  static Map<String, Object?> _money(dynamic f, Map p) => {
        ...p.cast<String, Object?>(),
        if (p['turnover'] != null) 'turnover': f.money(p['turnover']),
        if (p['amount'] != null) 'amount': f.money(p['amount']),
      };
}
