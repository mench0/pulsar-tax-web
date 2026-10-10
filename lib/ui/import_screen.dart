import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/csv_import.dart';
import '../core/format.dart';
import 'common.dart';

void openImport(BuildContext context) {
  final s = AppScope.read(context);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AppScope(state: s, child: const ImportScreen()),
  ));
}

/// Загрузка банковской выписки CSV.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.initialText});

  /// Текст выписки для тестов, без выбора файла.
  final String? initialText;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  Statement? _statement;
  List<StatementRow> _rows = [];
  String _defaultRate = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _load(widget.initialText!);
  }

  void _load(String text) {
    final st = Statement.parse(text);
    if (st == null) {
      toast(context, AppScope.read(context).tr('imp.empty'), error: true);
      return;
    }
    setState(() {
      _statement = st;
      _rebuild();
    });
  }

  void _rebuild() => _rows = _statement!.rows(defaultRate: _defaultRate);

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (files.isEmpty) return;
    final bytes = await files.single.readAsBytes();
    if (mounted) _load(decodeStatement(bytes));
  }

  Future<void> _submit() async {
    final s = AppScope.read(context);
    final chosen = _rows.where((r) => r.checked).toList();
    if (chosen.any((r) => r.currency != 'AMD' && !((double.tryParse(r.rate) ?? 0) > 0))) {
      toast(context, s.tr('imp.needRate'), error: true);
      return;
    }
    setState(() => _busy = true);
    await guarded(context, () async {
      final r = await s.api.post('/api/incomes/import', {'items': [for (final row in chosen) row.toJson()]})
          as Map<String, dynamic>;
      if (!mounted) return;
      toast(context, s.tr('imp.done', r));
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
    final chosen = _rows.where((r) => r.checked);
    final sum = chosen.fold<double>(0, (a, r) => a + r.amountAmd);
    return Scaffold(
      appBar: AppBar(title: Text(tr('imp.title'))),
      body: AppPage(subtitle: tr('imp.lead'), children: [
        Section(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(tr('imp.file')),
              onPressed: _pick,
            ),
          ),
          if (st != null) ...[
            const SizedBox(height: 16),
            Text(tr('imp.columns'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _mapping(st),
          ],
        ]),
        if (st != null)
          Section(children: [
            Text(tr('imp.rows', {'n': _rows.length, 'k': chosen.length, 'sum': s.fmt.money(sum.round())}),
                key: const Key('import-count')),
            const SizedBox(height: 8),
            for (final r in _rows) _row(r),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('import-submit'),
                onPressed: _busy || chosen.isEmpty ? null : _submit,
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
    Widget col(String label, int value, void Function(int) set, {bool none = true}) => dropdown<int>(
          label: label,
          value: value,
          values: [if (none) -1, ...cols],
          text: colName,
          onChanged: (v) => setState(() {
            set(v!);
            _rebuild();
          }),
        );
    return Column(children: [
      FieldRow(children: [
        col(tr('imp.colDate'), m.date, (v) => m.date = v, none: false),
        dropdown<String>(
          label: tr('imp.dateFormat'),
          value: m.dateFormat,
          values: dateFormats,
          text: (f) => f,
          onChanged: (v) => setState(() {
            m.dateFormat = v!;
            _rebuild();
          }),
        ),
        col(tr('imp.colAmount'), m.amount, (v) => m.amount = v, none: false),
        col(tr('imp.colDebit'), m.debit, (v) => m.debit = v),
      ]),
      FieldRow(children: [
        col(tr('imp.colDesc'), m.desc, (v) => m.desc = v),
        col(tr('imp.colCurrency'), m.currencyCol, (v) => m.currencyCol = v),
        dropdown<String>(
          label: tr('imp.currency'),
          value: m.currency,
          values: currencies,
          text: (c) => c,
          onChanged: (v) => setState(() {
            m.currency = v!;
            _rebuild();
          }),
        ),
        TextFormField(
          initialValue: _defaultRate,
          decoration: field(tr('imp.defaultRate')),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() {
            _defaultRate = v;
            for (final r in _rows) {
              if (r.currency != 'AMD') r.rate = v;
            }
          }),
        ),
      ]),
    ]);
  }

  Widget _row(StatementRow r) {
    final s = AppScope.of(context);
    final income = r.status == RowStatus.income;
    return Opacity(
      opacity: r.checked ? 1 : .55,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(
          value: r.checked,
          onChanged: r.selectable ? (v) => setState(() => r.checked = v!) : null,
        ),
        title: Text('${r.date == null ? '—' : Fmt.date(r.date)} · '
            '${r.amount == null ? '—' : s.fmt.number(r.amount)} ${r.currency}'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.description.isNotEmpty) Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (r.currency != 'AMD')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                width: 160,
                child: TextFormField(
                  key: ValueKey('rate-${r.key}-$_defaultRate'), // новый курс по умолчанию пересоздаёт поле
                  initialValue: r.rate,
                  decoration: InputDecoration(isDense: true, labelText: s.tr('inc.rate'), border: const OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() => r.rate = v),
                ),
              ),
            ),
        ]),
        trailing: Chip(
          label: Text(s.tr('imp.status.${r.status.name}')),
          backgroundColor: (income ? Brand.ok : Brand.amberDeep).withValues(alpha: .12),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
