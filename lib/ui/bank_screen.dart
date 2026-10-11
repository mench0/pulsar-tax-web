import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';
import 'documents_screen.dart';
import 'import_screen.dart';

/// Банковские операции: очередь проверки, подтверждённые операции и загруженные выписки.
class BankScreen extends StatelessWidget {
  const BankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(List<dynamic>, List<dynamic>, List<dynamic>)>(
      load: (s) async => (
        await s.api.get('/api/bank/transactions?status=NEEDS_REVIEW') as List<dynamic>,
        await s.api.get('/api/bank/transactions?from=${s.year}-01-01&to=${s.year}-12-31') as List<dynamic>,
        await s.api.get('/api/bank/statements') as List<dynamic>,
      ),
      builder: (context, d) => _Bank(
        review: d.$1.cast<Map<String, dynamic>>(),
        year: d.$2.cast<Map<String, dynamic>>().where((t) => t['status'] != 'NEEDS_REVIEW').toList(),
        statements: d.$3.cast<Map<String, dynamic>>(),
      ),
    );
  }
}

class _Bank extends StatelessWidget {
  const _Bank({required this.review, required this.year, required this.statements});

  final List<Map<String, dynamic>> review;
  final List<Map<String, dynamic>> year;
  final List<Map<String, dynamic>> statements;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final sure = review.where((t) =>
        (Fmt.toNum(t['confidence']) ?? 0) >= confident &&
        t['suggestedKind'] != 'OTHER' &&
        t['suggestedKind'] != 'TAX_PAYMENT' &&
        (t['currency'] == 'AMD' || t['amountAmd'] != null));
    return AppPage(
      title: tr('bank.title'),
      subtitle: tr('bank.lead'),
      actions: [
        FilledButton.icon(
          key: const Key('bank-import'),
          icon: const Icon(Icons.upload_file),
          label: Text(tr('bank.import')),
          onPressed: () => openImport(context),
        ),
        OutlinedButton.icon(
          key: const Key('bank-documents'),
          icon: const Icon(Icons.description_outlined),
          label: Text(tr('docs.title')),
          onPressed: () => openDocuments(context),
        ),
      ],
      children: [
        Notice(tr('bank.noBankApi')),
        Section(title: tr('bank.reviewTitle', {'n': review.length}), children: [
          if (review.isEmpty) Text(tr('bank.reviewEmpty'), key: const Key('review-empty')),
          if (sure.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  key: const Key('confirm-confident'),
                  icon: const Icon(Icons.done_all),
                  label: Text(tr('bank.confirmConfident', {'n': sure.length})),
                  onPressed: () async {
                    final ok = await guarded(context, () async {
                      final r = await s.api.post('/api/bank/transactions/confirm-confident', {
                        'ids': [for (final t in sure) t['id']],
                      }) as Map<String, dynamic>;
                      if (context.mounted) toast(context, tr('bank.confirmed', {'n': r['confirmed']}));
                    });
                    if (ok) s.changed();
                  },
                ),
              ),
            ),
          for (final t in review) _ReviewTile(key: ValueKey('tx-${t['id']}'), t: t),
        ]),
        Section(title: tr('bank.yearTitle', {'year': s.year}), children: [
          if (year.isEmpty) Text(tr('bank.yearEmpty')),
          for (final t in year.take(200))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${Fmt.date(t['date'] as String)} · ${s.fmt.number(t['amount'])} ${t['currency']}'
                  ' · ${t['status'] == 'IGNORED' ? tr('bank.ignored') : tr('kind.${t['kind']}')}'),
              subtitle: Text([t['counterparty'], t['description']].where((x) => (x as String).isNotEmpty).join(' — '),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: TextButton(
                onPressed: () async {
                  final ok = await guarded(context, () => s.api.post('/api/bank/transactions/${t['id']}/review', {'reopen': true}));
                  if (ok) s.changed();
                },
                child: Text(tr('bank.reopen')),
              ),
            ),
        ]),
        Section(title: tr('bank.statements'), children: [
          if (statements.isEmpty) Text(tr('bank.statementsEmpty')),
          for (final st in statements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.description_outlined),
              title: Text('${st['fileName']}${(st['account'] as String).isEmpty ? '' : ' · ${st['account']}'}'),
              subtitle: Text(tr('bank.statementStats', st)),
            ),
        ]),
      ],
    );
  }
}

/// Операция на проверке: предложенный тип, причины и решение пользователя.
class _ReviewTile extends StatefulWidget {
  const _ReviewTile({super.key, required this.t});

  final Map<String, dynamic> t;

  @override
  State<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<_ReviewTile> {
  late String _kind = widget.t['suggestedKind'] as String;
  final _rate = TextEditingController();

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _decide(Map<String, Object?> body) async {
    final s = AppScope.read(context);
    final ok = await guarded(context, () => s.api.post('/api/bank/transactions/${widget.t['id']}/review', body));
    if (ok) s.changed();
  }

  Future<void> _confirm() async {
    final s = AppScope.read(context);
    final body = <String, Object?>{'kind': _kind};
    if (_rate.text.trim().isNotEmpty) body['rate'] = _rate.text.trim().replaceAll(',', '.');
    if (_kind == 'TAX_PAYMENT') {
      final q = await _askQuarter(context);
      if (q == null) return;
      body['taxYear'] = q.$1;
      body['taxQuarter'] = q.$2;
    }
    if (!mounted) return;
    await _decide(body);
    if (mounted) toast(context, s.tr('bank.done'));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final t = widget.t;
    final amount = Fmt.toNum(t['amount']) ?? 0;
    final noRate = t['currency'] != 'AMD' && t['amountAmd'] == null;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${Fmt.date(t['date'] as String)} · ${s.fmt.number(amount)} ${t['currency']}'
          '${t['currency'] != 'AMD' && t['amountAmd'] != null ? ' = ${s.fmt.money(t['amountAmd'])}' : ''}',
          style: TextStyle(fontWeight: FontWeight.w600, color: amount > 0 ? Brand.ok : null),
        ),
        Text([t['counterparty'], t['description']].where((x) => (x as String).isNotEmpty).join(' — '),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(suggestionText(tr, t['suggestedKind'] as String, t['confidence'], (t['reasons'] as List).cast<String>()),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 260,
            child: dropdown<String>(
              key: Key('review-kind-${t['id']}'),
              label: tr('bank.kind'),
              value: _kind,
              values: kindsFor(amount),
              text: (k) => tr('kind.$k'),
              onChanged: (k) => setState(() => _kind = k!),
            ),
          ),
          if (noRate)
            SizedBox(
              width: 160,
              child: TextField(controller: _rate, decoration: field(tr('inc.rate')), keyboardType: TextInputType.number),
            ),
          FilledButton(key: Key('review-confirm-${t['id']}'), onPressed: _confirm, child: Text(tr('bank.confirm'))),
          TextButton(onPressed: () => _decide({'ignore': true}), child: Text(tr('bank.ignore'))),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(tr('bank.effect.$_kind'), style: theme.textTheme.bodySmall),
        ),
        const Divider(height: 16),
      ]),
    );
  }
}

/// Год и квартал уплаты налога (0 — за год).
Future<(int, int)?> _askQuarter(BuildContext context) {
  final s = AppScope.read(context);
  var year = s.year;
  var quarter = 1;
  return showDialog<(int, int)>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(s.tr('bank.taxPeriod')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          dropdown<int>(
            label: s.tr('nav.year'),
            value: year,
            values: [for (var y = Fmt.currentYear(); y >= Fmt.currentYear() - 3; y--) y],
            text: (y) => '$y',
            onChanged: (v) => set(() => year = v!),
          ),
          const SizedBox(height: 12),
          dropdown<int>(
            label: s.tr('rep.period'),
            value: quarter,
            values: const [1, 2, 3, 4, 0],
            text: (q) => q == 0 ? s.tr('rep.periodYear') : s.tr('common.quarter', {'q': q}),
            onChanged: (v) => set(() => quarter = v!),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('✕')),
          FilledButton(onPressed: () => Navigator.pop(c, (year, quarter)), child: Text(s.tr('bank.confirm'))),
        ],
      ),
    ),
  );
}
