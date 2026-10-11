import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';
import 'files.dart';

void openDocuments(BuildContext context) {
  final s = AppScope.read(context);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScope(state: s, child: const DocumentsScreen())));
}

const docTypes = ['SUPPLIER_INVOICE', 'RECEIPT', 'ACT', 'CONTRACT', 'OTHER'];

/// Документы: счета поставщиков, чеки, акты. Распознанное — подсказка, в учёт идёт подтверждённое.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Scaffold(
      appBar: AppBar(title: Text(tr('docs.title'))),
      body: Loader<List<dynamic>>(
        load: (s) async => await s.api.get('/api/documents') as List<dynamic>,
        builder: (context, list) {
          final docs = list.cast<Map<String, dynamic>>();
          return AppPage(subtitle: tr('docs.lead'), actions: const [], children: [
            Section(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('doc-upload'),
                  icon: const Icon(Icons.upload_file),
                  label: Text(tr('docs.upload')),
                  onPressed: () => _upload(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(tr('docs.privacy'), style: Theme.of(context).textTheme.bodySmall),
            ]),
            Section(children: [
              if (docs.isEmpty) Text(tr('docs.empty')),
              for (final d in docs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(d['contentType'] == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
                  title: Text(d['fileName'] as String),
                  subtitle: Text('${tr('docs.status.${d['status']}')} · ${tr('docs.extraction.${d['extraction']}')}'),
                  trailing: d['amount'] == null ? null : Text(s.fmt.number(d['amount'])),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AppScope(state: s, child: DocumentScreen(id: d['id'] as int)),
                  )),
                ),
            ]),
          ]);
        },
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    final s = AppScope.read(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (files.isEmpty || !context.mounted) return;
    final f = files.single;
    final bytes = await f.readAsBytes();
    if (!context.mounted) return;
    await guarded(context, () async {
      final d = await s.api.upload('/api/documents', f.name, bytes) as Map<String, dynamic>;
      s.changed();
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AppScope(state: s, child: DocumentScreen(id: d['id'] as int)),
      ));
    });
  }
}

/// Карточка документа: распознанные значения с уверенностью и форма подтверждения.
class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    return Scaffold(
      appBar: AppBar(title: Text(tr('docs.card'))),
      body: Loader<Map<String, dynamic>>(
        load: (s) async => await s.api.get('/api/documents/$id') as Map<String, dynamic>,
        builder: (context, d) => _DocumentForm(key: ValueKey(d['status']), d: d),
      ),
    );
  }
}

class _DocumentForm extends StatefulWidget {
  const _DocumentForm({super.key, required this.d});

  final Map<String, dynamic> d;

  @override
  State<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<_DocumentForm> {
  late final Map<String, dynamic> x = (widget.d['extracted'] as Map).cast<String, dynamic>();
  late String _type = widget.d['docType'] as String;
  late final _number = TextEditingController(text: _initial('number', widget.d['number']));
  late final _date = TextEditingController(text: _initial('date', widget.d['docDate']));
  late final _amount = TextEditingController(text: _initial('amount', widget.d['amount']));
  late final _currency = TextEditingController(text: _initial('currency', widget.d['currency']));
  late final _party = TextEditingController(text: _initial('counterparty', widget.d['counterparty']));
  late final _tin = TextEditingController(text: _initial('counterpartyTin', widget.d['counterpartyTin']));
  int? _tx;
  bool _createExpense = false;

  /// Подтверждённое значение, иначе — распознанное (пользователь проверит его перед сохранением).
  String _initial(String key, Object? confirmed) {
    if (confirmed != null && '$confirmed'.isNotEmpty) return '$confirmed';
    final v = (x[key] as Map?)?['value'];
    return v == null ? '' : '$v';
  }

  @override
  void initState() {
    super.initState();
    _tx = widget.d['bankTransactionId'] as int?;
  }

  @override
  void dispose() {
    for (final c in [_number, _date, _amount, _currency, _party, _tin]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _hint(String key) {
    final tr = AppScope.of(context).tr;
    final f = x[key] as Map?;
    if (f == null) return const SizedBox.shrink();
    final pct = ((Fmt.toNum(f['confidence']) ?? 0) * 100).round();
    final alts = (f['alternatives'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Text(
        tr('docs.recognized', {'pct': pct}) + (alts.isEmpty ? '' : ' · ${tr('docs.alternatives')}: ${alts.join(', ')}'),
        style: TextStyle(fontSize: 12, color: pct < 60 ? Brand.warning : Theme.of(context).hintColor),
      ),
    );
  }

  Future<void> _confirm() async {
    final s = AppScope.read(context);
    final ok = await guarded(context, () => s.api.post('/api/documents/${widget.d['id']}/confirm', {
          'docType': _type,
          'number': _number.text,
          'date': _date.text.trim().isEmpty ? null : _date.text.trim(),
          'currency': _currency.text.trim().isEmpty ? null : _currency.text.trim().toUpperCase(),
          'amount': _amount.text.trim().isEmpty ? null : _amount.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
          'counterparty': _party.text,
          'counterpartyTin': _tin.text,
          'bankTransactionId': _tx,
          'createExpense': _createExpense,
        }));
    if (ok && mounted) {
      toast(context, s.tr('docs.confirmed'));
      s.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final d = widget.d;
    final matches = (d['matches'] as List).cast<Map<String, dynamic>>();
    final confirmed = d['status'] == 'CONFIRMED';
    return AppPage(title: d['fileName'] as String, actions: [
      OutlinedButton.icon(
        icon: const Icon(Icons.download),
        label: Text(tr('docs.file')),
        onPressed: () => exportFile(context, '/api/documents/${d['id']}/file', d['fileName'] as String, d['contentType'] as String),
      ),
    ], children: [
      if (d['extraction'] != 'TEXT_LAYER' && d['extraction'] != 'OCR') Notice(tr('docs.extraction.${d['extraction']}.long')),
      if (!confirmed) Notice(tr('docs.checkValues')),
      if (confirmed) Notice(tr('docs.isConfirmed')),
      Section(children: [
        dropdown<String>(
          label: tr('docs.type'),
          value: _type,
          values: docTypes,
          text: (t) => tr('docs.type.$t'),
          onChanged: (v) => setState(() => _type = v!),
        ),
        const SizedBox(height: 12),
        TextField(key: const Key('doc-number'), controller: _number, decoration: field(tr('docs.number'))),
        _hint('number'),
        TextField(key: const Key('doc-date'), controller: _date, decoration: field(tr('common.date'), hint: 'ГГГГ-ММ-ДД')),
        _hint('date'),
        FieldRow(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(key: const Key('doc-amount'), controller: _amount, decoration: field(tr('common.amount'))),
            _hint('amount'),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _currency, decoration: field(tr('imp.currency'))),
            _hint('currency'),
          ]),
        ]),
        TextField(controller: _party, decoration: field(tr('docs.counterparty'))),
        _hint('counterparty'),
        TextField(controller: _tin, decoration: field(tr('docs.tin'))),
        _hint('counterpartyTin'),
      ]),
      Section(title: tr('docs.link'), children: [
        if (matches.isEmpty) Text(tr('docs.noMatches')),
        if (matches.isNotEmpty)
          RadioGroup<int?>(
            groupValue: _tx,
            onChanged: (v) => setState(() => _tx = v),
            child: Column(children: [
              for (final m in matches)
                RadioListTile<int?>(
                  contentPadding: EdgeInsets.zero,
                  value: m['bankTransactionId'] as int,
                  title: Text('${Fmt.date(m['date'] as String)} · ${s.fmt.number(m['amount'])} ${m['currency']}'
                      '${m['kind'] == null ? '' : ' · ${tr('kind.${m['kind']}')}'}'),
                  subtitle: Text(m['counterparty'] as String),
                ),
              RadioListTile<int?>(contentPadding: EdgeInsets.zero, value: null, title: Text(tr('docs.noLink'))),
            ]),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _createExpense,
          onChanged: (v) => setState(() => _createExpense = v!),
          title: Text(tr('docs.createExpense')),
          subtitle: Text(tr('docs.createExpenseHelp')),
        ),
      ]),
      Wrap(spacing: 8, children: [
        FilledButton(key: const Key('doc-confirm'), onPressed: _confirm, child: Text(tr('docs.confirm'))),
        TextButton(
          onPressed: () async {
            final ok = await guarded(context, () => s.api.post('/api/documents/${d['id']}/reject'));
            if (ok) s.changed();
          },
          child: Text(tr('docs.reject')),
        ),
      ]),
    ]);
  }
}
