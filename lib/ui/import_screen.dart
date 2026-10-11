import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/csv_import.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import 'common.dart';

void openImport(BuildContext context) {
  final s = AppScope.read(context);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AppScope(state: s, child: const ImportScreen()),
  ));
}

/// Типы банковских операций (как в API).
const transactionKinds = [
  'INCOME', 'EXPENSE', 'OWN_TRANSFER', 'REFUND_RECEIVED', 'REFUND_ISSUED', 'BANK_FEE', 'TAX_PAYMENT', 'OTHER',
];

/// Типы, подходящие к направлению денег.
List<String> kindsFor(num amount) => transactionKinds
    .where((k) => amount > 0
        ? !['EXPENSE', 'REFUND_ISSUED', 'BANK_FEE', 'TAX_PAYMENT'].contains(k)
        : !['INCOME', 'REFUND_RECEIVED'].contains(k))
    .toList();

/// С какой уверенности подсказка по умолчанию отмечена «подтвердить сразу».
const confident = 0.85;

/// Загрузка банковской выписки CSV: разбор и проверка на сервере, решения пользователя по строкам.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.initialText, this.fileName = 'statement.csv'});

  /// Текст выписки для тестов, без выбора файла.
  final String? initialText;
  final String fileName;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

/// Решение по строке: подтвердить тип сразу, оставить на проверку или пропустить.
enum RowAction { confirm, review, skip }

class _ImportScreenState extends State<ImportScreen> {
  Statement? _statement;
  String _fileName = 'statement.csv';
  String _sha = '';
  final _account = TextEditingController();
  Map<String, dynamic>? _preview;
  final Map<int, String> _kinds = {};
  final Map<int, RowAction> _actions = {};
  final Map<int, String> _rates = {};
  bool _busy = false;
  bool _checking = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    final text = widget.initialText;
    if (text != null) {
      _fileName = widget.fileName;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(text, utf8.encode(text)));
    }
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  Future<void> _load(String text, List<int> bytes) async {
    final s = AppScope.read(context);
    final st = Statement.parse(text);
    if (st == null) {
      toast(context, s.tr('imp.empty'), error: true);
      return;
    }
    var restored = false;
    try {
      final profiles = await s.api.get('/api/import-profiles') as Map<String, dynamic>;
      final saved = profiles[st.signature];
      if (saved is Map<String, dynamic>) restored = st.mapping.apply(saved, st.header.length);
    } catch (_) {
      // без сохранённых настроек остаётся автоматическое определение колонок
    }
    if (!mounted) return;
    setState(() {
      _statement = st;
      _sha = sha256.convert(bytes).toString();
    });
    if (restored) toast(context, s.tr('imp.profileApplied'));
    await _check();
  }

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (files.isEmpty) return;
    final bytes = await files.single.readAsBytes();
    _fileName = files.single.name;
    if (mounted) _load(decodeStatement(bytes), bytes);
  }

  Map<String, Object?> _upload({bool withOverrides = false}) {
    final st = _statement!;
    return {
      'fileName': _fileName,
      'fileSha256': _sha,
      'account': _account.text.trim(),
      'header': st.header,
      'rows': st.data,
      'mapping': st.mapping.toJson(),
      'overrides': [
        for (final r in _rows)
          if (withOverrides && _actions[r['row']] == RowAction.skip)
            {'row': r['row'], 'skip': true}
          else if (withOverrides && _actions[r['row']] == RowAction.confirm)
            {'row': r['row'], 'kind': _kinds[r['row']], if (_rates[r['row']] != null) 'rate': _rates[r['row']]}
          else if (_rates[r['row']] != null)
            {'row': r['row'], 'rate': _rates[r['row']]},
      ],
    };
  }

  List<Map<String, dynamic>> get _rows => ((_preview?['rows'] as List?) ?? []).cast<Map<String, dynamic>>();

  /// Проверка на сервере: разбор по колонкам, ошибки, дубли, курсы ЦБ и подсказки типа.
  Future<void> _check() async {
    final s = AppScope.read(context);
    setState(() => _checking = true);
    await guarded(context, () async {
      final p = await s.api.post('/api/bank/statements/preview', _upload()) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _preview = p;
        _version++;
        for (final r in _rows) {
          final n = r['row'] as int;
          _kinds[n] = _kinds[n] ?? r['suggestedKind'] as String;
          final bad = (r['errors'] as List).isNotEmpty || r['duplicate'] == true;
          final sure = (Fmt.toNum(r['confidence']) ?? 0) >= confident && r['suggestedKind'] != 'OTHER';
          _actions[n] = bad ? RowAction.skip : _actions[n] ?? (sure ? RowAction.confirm : RowAction.review);
        }
      });
    });
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _submit() async {
    final s = AppScope.read(context);
    final needRate = _rows.any((r) =>
        _actions[r['row']] == RowAction.confirm &&
        r['amountAmd'] == null &&
        _rates[r['row']] == null &&
        ['INCOME', 'EXPENSE', 'BANK_FEE'].contains(_kinds[r['row']]));
    if (needRate) {
      toast(context, s.tr('imp.needRate'), error: true);
      return;
    }
    setState(() => _busy = true);
    await guarded(context, () async {
      final r = await s.api.post('/api/bank/statements', _upload(withOverrides: true)) as Map<String, dynamic>;
      final st = _statement!;
      await s.api.put('/api/import-profiles/${st.signature}', st.mapping.toJson()).catchError((_) => null);
      if (!mounted) return;
      toast(context, s.tr('imp.saved', r));
      s.changed();
      Navigator.of(context).pop();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final st = _statement;
    final p = _preview;
    int count(RowAction a) => _rows.where((r) => _actions[r['row']] == a).length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('imp.title'))),
      body: AppPage(subtitle: tr('imp.lead'), children: [
        Section(children: [
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.icon(icon: const Icon(Icons.folder_open), label: Text(tr('imp.file')), onPressed: _pick),
            SizedBox(
              width: 280,
              child: TextField(
                key: const Key('import-account'),
                controller: _account,
                decoration: field(tr('imp.account'), helper: tr('imp.accountHelp')),
              ),
            ),
          ]),
          if (st != null) ...[
            const SizedBox(height: 16),
            Text(tr('imp.columns'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _mapping(st),
          ],
        ]),
        if (p != null && p['sameFileImportId'] != null) Notice(tr('imp.sameFile')),
        if (p != null)
          Section(children: [
            Text(
              tr('imp.summary', {
                'n': p['total'],
                'confirm': count(RowAction.confirm),
                'review': count(RowAction.review),
                'skip': count(RowAction.skip),
                'errors': p['errors'],
                'dups': p['duplicates'],
              }),
              key: const Key('import-count'),
            ),
            const SizedBox(height: 4),
            Text(tr('imp.reviewNote'), style: Theme.of(context).textTheme.bodySmall),
            if (_checking) Text(tr('imp.checking'), key: const Key('import-checking')),
            const SizedBox(height: 8),
            for (final r in _rows) _row(r),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('import-submit'),
                onPressed: _busy || _checking || count(RowAction.skip) == _rows.length ? null : _submit,
                child: Text(tr('imp.submit')),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _mapping(Statement st) {
    final tr = AppScope.of(context).tr;
    final m = st.mapping;
    final cols = [for (var i = 0; i < st.header.length; i++) i];
    String colName(int i) => i < 0 ? tr('imp.none') : (st.header[i].isEmpty ? '#${i + 1}' : st.header[i]);
    Widget col(String label, int value, void Function(int) set, {bool none = true, String? key}) => dropdown<int>(
          key: key == null ? null : Key(key),
          label: label,
          value: value,
          values: [if (none) -1, ...cols],
          text: colName,
          onChanged: (v) {
            setState(() => set(v!));
            _check();
          },
        );
    return Column(children: [
      FieldRow(children: [
        col(tr('imp.colDate'), m.date, (v) => m.date = v, none: false),
        dropdown<String>(
          label: tr('imp.dateFormat'),
          value: m.dateFormat,
          values: dateFormats,
          text: (f) => f,
          onChanged: (v) {
            setState(() => m.dateFormat = v!);
            _check();
          },
        ),
        col(tr('imp.colAmount'), m.amount, (v) => m.amount = v, none: false),
        col(tr('imp.colDebit'), m.debit, (v) => m.debit = v),
      ]),
      FieldRow(children: [
        col(tr('imp.colDesc'), m.desc, (v) => m.desc = v, key: 'map-desc'),
        col(tr('imp.colCounterparty'), m.counterparty, (v) => m.counterparty = v, key: 'map-counterparty'),
        col(tr('imp.colCurrency'), m.currencyCol, (v) => m.currencyCol = v),
        dropdown<String>(
          label: tr('imp.currency'),
          value: m.currency,
          values: currencies,
          text: (c) => c,
          onChanged: (v) {
            setState(() => m.currency = v!);
            _check();
          },
        ),
      ]),
    ]);
  }

  Widget _row(Map<String, dynamic> r) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final n = r['row'] as int;
    final errors = (r['errors'] as List).cast<String>();
    final warnings = (r['warnings'] as List).cast<String>();
    final dup = r['duplicate'] == true;
    final amount = Fmt.toNum(r['amount']);
    final action = _actions[n] ?? RowAction.review;
    final bad = errors.isNotEmpty || dup;
    final theme = Theme.of(context);
    return Opacity(
      opacity: action == RowAction.skip ? .55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${tr('imp.row', {'n': n})} · ${r['date'] == null ? '—' : Fmt.date(r['date'] as String)} · '
            '${amount == null ? '—' : s.fmt.number(amount)} ${r['currency'] ?? ''}'
            '${r['amountAmd'] != null && r['currency'] != 'AMD' ? ' = ${s.fmt.money(r['amountAmd'])}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if ((r['counterparty'] as String? ?? '').isNotEmpty || (r['description'] as String? ?? '').isNotEmpty)
            Text([r['counterparty'], r['description']].where((x) => (x as String? ?? '').isNotEmpty).join(' — '),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          for (final e in errors) Text('✕ ${tr('imp.err.$e')}', style: const TextStyle(color: Brand.bad)),
          if (dup) Text('⧉ ${tr('imp.dup.${r['duplicateOf']}')}', style: const TextStyle(color: Brand.warning)),
          for (final w in warnings) Text('! ${tr('imp.warn.$w')}', style: const TextStyle(color: Brand.warning)),
          if (!bad) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 260,
                child: dropdown<String>(
                  key: ValueKey('kind-$n-$_version'),
                  label: tr('bank.kind'),
                  value: _kinds[n]!,
                  values: kindsFor(amount ?? 0),
                  text: (k) => tr('kind.$k'),
                  onChanged: (k) => setState(() {
                    _kinds[n] = k!;
                    _actions[n] = RowAction.confirm;
                  }),
                ),
              ),
              SegmentedButton<RowAction>(
                key: ValueKey('action-$n'),
                segments: [
                  for (final a in RowAction.values) ButtonSegment(value: a, label: Text(tr('imp.action.${a.name}'))),
                ],
                selected: {action},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _actions[n] = v.first),
              ),
              if (r['currency'] != 'AMD' && r['currency'] != null)
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    key: ValueKey('rate-$n-$_version'),
                    initialValue: _rates[n] ?? (r['rate'] == null ? '' : '${r['rate']}'),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: tr('inc.rate'),
                      helperText: r['rateSource'] == 'CBA' ? tr('imp.rateCba') : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _rates[n] = v.trim().isEmpty ? '' : v.trim().replaceAll(',', '.'),
                    onFieldSubmitted: (_) => _check(),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                suggestionText(tr, r['suggestedKind'] as String, r['confidence'], (r['reasons'] as List).cast<String>()),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
          ],
          const Divider(height: 16),
        ]),
      ),
    );
  }
}

/// «Похоже на: доход (уверенность 80%) — назначение платежа, история решений».
String suggestionText(Tr tr, String kind, Object? confidence, List<String> reasons) {
  final pct = ((Fmt.toNum(confidence) ?? 0) * 100).round();
  final why = reasons.where((r) => !r.startsWith('SIGN_')).map((r) => tr('reason.$r')).join(', ');
  return tr('bank.suggestion', {'kind': tr('kind.$kind'), 'pct': pct, 'why': why.isEmpty ? tr('reason.SIGN_ONLY') : why});
}
