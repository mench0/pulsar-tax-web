import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import 'common.dart';
import 'import_screen.dart';

/// Текст предупреждения из кода и параметров сервера.
String warningText(Tr tr, Map<String, dynamic> w) {
  final p = Map<String, Object?>.from(w['params'] as Map);
  if (p['activity'] != null) p['activity'] = tr('activity.${p['activity']}');
  if (p['regime'] != null) p['regime'] = tr('regime.${p['regime']}');
  return tr('warn.${w['code']}', p);
}

bool warningIsBad(Map<String, dynamic> w) => w['code'] == 'THRESHOLD_EXCEEDED' || w['code'] == 'REGIME_NOT_ALLOWED';

String deadlineText(Tr tr, Map<String, dynamic> d) => tr('deadline.${d['code']}', Map<String, Object?>.from(d['params'] as Map));

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(Map<String, dynamic>, Map<String, dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/summary?year=${s.year}') as Map<String, dynamic>,
        await s.api.get('/api/profile') as Map<String, dynamic>,
      ),
      builder: (context, data) => _Overview(summary: data.$1, profile: data.$2),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary, required this.profile});

  final Map<String, dynamic> summary;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final tr = st.tr;
    final f = st.fmt;
    final s = summary;
    final rate = s['ratePercent'] == null ? tr('ov.noRate') : tr('ov.rate', {'rate': s['ratePercent']});
    final needsSetup = (profile['name'] as String).isEmpty;
    final status = s['thresholdStatus'];
    final percent = ((Fmt.toNum(s['thresholdPercent']) ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    final meterColor = status == 'EXCEEDED' ? Brand.badFill : status == 'WARNING' ? Brand.warningFill : Brand.okFill;
    final warnings = (s['warnings'] as List).cast<Map<String, dynamic>>();
    final deadlines = (s['deadlines'] as List).cast<Map<String, dynamic>>();
    final quarters = (s['quarters'] as List).cast<Map<String, dynamic>>();

    return AppPage(
      title: needsSetup ? tr('ov.welcome') : profile['name'] as String,
      subtitle: [
        tr('regime.${s['regime']}'),
        tr('activity.${s['activity']}'),
        rate,
        tr('common.year', {'y': s['year']}),
      ].join(' · '),
      children: [
        if (needsSetup) Notice(tr('ov.setup'), onTap: () => st.go(AppTab.settings)),
        for (final w in warnings) Notice(warningText(tr, w), bad: warningIsBad(w)),
        if ((Fmt.toNum(s['setAsidePercent']) ?? 0) > 0)
          Notice(
            tr('ov.setAside', {'percent': s['setAsidePercent'], 'due': f.money(s['totalDue'])}),
            key: const Key('set-aside'),
            onTap: () => st.go(AppTab.report),
          ),
        Grid(minWidth: 200, children: [
          _Stat(label: tr('ov.income'), value: f.money(s['totalIncome']), sub: tr('ov.incomeSub')),
          _Stat(label: tr('ov.tax'), value: f.money(s['totalTax']), sub: rate),
          _Stat(
            key: const Key('due'),
            label: tr('ov.due'),
            value: f.money(s['totalDue']),
            sub: tr('ov.dueSub', {'paid': f.money(s['totalPaid'])}),
            onTap: () => st.go(AppTab.report),
          ),
          _Stat(
            key: const Key('expenses'),
            label: tr('ov.expenses'),
            value: f.money(s['totalExpenses']),
            sub: tr('ov.expensesSub'),
            onTap: () => st.go(AppTab.incomes),
          ),
          _Stat(
            label: tr('ov.threshold'),
            value: s['threshold'] == null ? '—' : f.money(s['remaining']),
            sub: s['threshold'] == null ? tr('ov.noThreshold') : null,
            footer: s['threshold'] == null
                ? null
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: percent, minHeight: 8, color: meterColor),
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${s['thresholdPercent']}%', style: Theme.of(context).textTheme.bodySmall),
                      Flexible(
                        child: Text(tr('ov.limit', {'limit': f.money(s['threshold'])}),
                            style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.end),
                      ),
                    ]),
                  ]),
          ),
        ]),
        const SizedBox(height: 16),
        Grid(minWidth: 420, children: [
          Section(title: tr('ov.quarters'), children: [
            Grid(minWidth: 130, children: [for (final q in quarters) _Quarter(q)]),
          ]),
          Section(title: tr('ov.deadlines'), children: [
            if (deadlines.isEmpty) Text(tr('ov.noDeadlines')),
            for (final d in deadlines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 96,
                    child: Text(d['date'] == null ? '—' : Fmt.date(d['date'] as String),
                        style: const TextStyle(color: Brand.warning, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Text(deadlineText(tr, d))),
                ]),
              ),
          ]),
        ]),
        if ((Fmt.toNum(s['totalIncome']) ?? 0) == 0)
          Section(children: [
            Text(tr('ov.importHint')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(tr('ov.importBtn')),
                onPressed: () => openImport(context),
              ),
            ),
          ]),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.label, required this.value, this.sub, this.footer, this.onTap});

  final String label;
  final String value;
  final String? sub;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (sub != null) Text(sub!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            ?footer,
          ]),
        ),
      ),
    );
  }
}

class _Quarter extends StatelessWidget {
  const _Quarter(this.q);

  final Map<String, dynamic> q;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final tr = st.tr;
    final f = st.fmt;
    final small = Theme.of(context).textTheme.bodySmall;
    final due = Fmt.toNum(q['due']);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.topLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => st.go(AppTab.report, period: q['quarter'] as int),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('common.quarter', {'q': q['quarter']}), style: small),
        Text(f.money(q['income']), style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(tr('ov.qTax', {'tax': f.money(q['tax'])}), style: small),
        if (due != null)
          Text(due > 0 ? tr('ov.qToPay', {'due': f.money(due)}) : tr('ov.qPaid'),
              style: small?.copyWith(color: due > 0 ? Brand.bad : Brand.ok)),
        if (q['dueDate'] != null) Text(tr('ov.qDue', {'date': Fmt.date(q['dueDate'] as String)}), style: small),
      ]),
    );
  }
}
