import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import 'common.dart';
import 'files.dart';
import 'incomes_screen.dart' show DateField;
import 'invoice_pdf.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Loader<List<dynamic>>(
      load: (s) async => await s.api.get('/api/invoices') as List<dynamic>,
      builder: (context, list) {
        final invoices = list.cast<Map<String, dynamic>>();
        return AppPage(
          title: tr('invs.title'),
          subtitle: tr('invs.lead'),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: Text(tr('inc.export')),
              onPressed: () => exportFile(context, '/api/export/invoices.csv', 'invoices.csv', 'text/csv'),
            ),
          ],
          children: [
            Notice(tr('invs.einvoiceNote')),
            const _InvoiceForm(),
            Section(title: tr('invs.all'), children: [
              if (invoices.isEmpty) Text(tr('invs.none')),
              for (final inv in invoices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => openInvoice(context, inv['id'] as int),
                  title: Text('${inv['number']} · ${inv['client']}'),
                  subtitle: Text([
                    Fmt.date(inv['date'] as String),
                    if ((inv['eInvoiceNumber'] as String).isNotEmpty) 'e-invoice ${inv['eInvoiceNumber']}',
                  ].join(' · ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.fmt.money(inv['total']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    StatusChip(paid: inv['status'] == 'PAID'),
                  ]),
                ),
            ]),
          ],
        );
      },
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.paid, this.long = false});

  final bool paid;
  final bool long;

  @override
  Widget build(BuildContext context) {
    final tr = AppScope.of(context).tr;
    return Chip(
      label: Text(paid ? tr('invs.paid') : tr(long ? 'inv.waiting' : 'invs.waiting')),
      backgroundColor: (paid ? Brand.ok : Brand.amberDeep).withValues(alpha: .12),
      visualDensity: VisualDensity.compact,
    );
  }
}

void openInvoice(BuildContext context, int id) {
  final s = AppScope.read(context);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScope(state: s, child: InvoiceScreen(id: id))));
}

/// Отмечает счёт оплаченным: спрашивает дату, доход записывается на сервере.
Future<bool> markPaid(BuildContext context, int id) async {
  final s = AppScope.read(context);
  final picked = await showDatePicker(
    context: context,
    helpText: s.tr('invs.paidPrompt'),
    initialDate: DateTime.parse(Fmt.today()),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (picked == null || !context.mounted) return false;
  final ok = await guarded(context, () => s.api.post('/api/invoices/$id/paid?date=${Fmt.iso(picked)}'));
  if (ok && context.mounted) {
    toast(context, s.tr('invs.paidDone'));
    s.changed();
  }
  return ok;
}

class _ItemRow {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class _InvoiceForm extends StatefulWidget {
  const _InvoiceForm();

  @override
  State<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<_InvoiceForm> {
  final _form = GlobalKey<FormState>();
  final _client = TextEditingController();
  final _clientTin = TextEditingController();
  final _date = TextEditingController(text: Fmt.today());
  final _due = TextEditingController();
  final _items = [_ItemRow()];

  @override
  void dispose() {
    for (final c in [_client, _clientTin, _date, _due]) {
      c.dispose();
    }
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  num get _total => _items.fold<num>(
      0, (sum, i) => sum + ((double.tryParse(i.qty.text) ?? 0) * (double.tryParse(i.price.text) ?? 0)).round());

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    await guarded(context, () async {
      final inv = await s.api.post('/api/invoices', {
        'client': _client.text,
        'clientTin': _clientTin.text,
        'date': _date.text,
        'dueDate': _due.text.isEmpty ? null : _due.text,
        'items': [
          for (final i in _items) {'name': i.name.text, 'quantity': i.qty.text, 'price': i.price.text},
        ],
      }) as Map<String, dynamic>;
      if (!mounted) return;
      toast(context, s.tr('invs.created', {'number': inv['number']}));
      s.changed();
      openInvoice(context, inv['id'] as int);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    String? need(String? v) => (v ?? '').trim().isEmpty ? '—' : null;
    return Section(title: tr('invs.new'), children: [
      Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldRow(children: [
            TextFormField(
              key: const Key('invoice-client'),
              controller: _client,
              decoration: field(tr('common.client'), hint: tr('inc.clientPh')),
              validator: need,
            ),
            TextFormField(controller: _clientTin, decoration: field(tr('invs.clientTin'))),
            DateField(controller: _date, label: tr('common.date')),
            DateField(controller: _due, label: tr('invs.due'), required: false),
          ]),
          for (final (n, item) in _items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    key: Key('item-name-$n'),
                    controller: item.name,
                    decoration: field(tr('invs.item'), hint: tr('invs.itemPh')),
                    validator: need,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.qty,
                    decoration: field(tr('invs.qty')),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: need,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: Key('item-price-$n'),
                    controller: item.price,
                    decoration: field(tr('invs.price')),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: need,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  tooltip: tr('invs.removeItem'),
                  icon: const Icon(Icons.close),
                  onPressed: _items.length == 1
                      ? null
                      : () => setState(() => _items.removeAt(n).dispose()),
                ),
              ]),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(onPressed: () => setState(() => _items.add(_ItemRow())), child: Text(tr('invs.addItem'))),
              Text('${tr('common.total')}: ${s.fmt.money(_total)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(key: const Key('invoice-create'), onPressed: _submit, child: Text(tr('invs.create'))),
          ),
        ]),
      ),
    ]);
  }
}

/// Карточка счёта: номер e-invoice, оплата, PDF, удаление.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Scaffold(
      appBar: AppBar(title: Text(tr('invs.title'))),
      body: Loader<(Map<String, dynamic>, Map<String, dynamic>)>(
        load: (s) async => (
          await s.api.get('/api/invoices/$id') as Map<String, dynamic>,
          await s.api.get('/api/profile') as Map<String, dynamic>,
        ),
        builder: (context, data) => _InvoiceView(inv: data.$1, profile: data.$2),
      ),
    );
  }
}

class _InvoiceView extends StatefulWidget {
  const _InvoiceView({required this.inv, required this.profile});

  final Map<String, dynamic> inv;
  final Map<String, dynamic> profile;

  @override
  State<_InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends State<_InvoiceView> {
  late final _eInvoice = TextEditingController(text: widget.inv['eInvoiceNumber'] as String);

  @override
  void dispose() {
    _eInvoice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    final f = s.fmt;
    final inv = widget.inv;
    final p = widget.profile;
    final paid = inv['status'] == 'PAID';
    final items = (inv['items'] as List).cast<Map<String, dynamic>>();
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);

    return AppPage(
      title: tr('inv.heading', {'number': inv['number']}),
      actions: [
        if (!paid)
          OutlinedButton(onPressed: () => markPaid(context, inv['id'] as int), child: Text(tr('inv.markPaid'))),
        FilledButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(tr('inv.print')),
          onPressed: () => guarded(context, () async {
            final bytes = await invoicePdf(inv, p, tr, f);
            await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${inv['number']}.pdf');
          }),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Brand.bad),
          onPressed: () async {
            if (!await confirm(context, tr('inv.confirmDelete', {'number': inv['number']}))) return;
            if (!context.mounted) return;
            final ok = await guarded(context, () => s.api.delete('/api/invoices/${inv['id']}'));
            if (ok && context.mounted) {
              toast(context, tr('inv.deleted'));
              s.changed();
              Navigator.of(context).pop();
            }
          },
          child: Text(tr('common.delete')),
        ),
      ],
      children: [
        Section(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                key: const Key('einvoice'),
                controller: _eInvoice,
                maxLength: 50,
                decoration: field(tr('inv.einvoice'), helper: tr('inv.einvoiceHint')),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                key: const Key('einvoice-save'),
                onPressed: () => guarded(context, () async {
                  await s.api.put('/api/invoices/${inv['id']}/einvoice', {'eInvoiceNumber': _eInvoice.text});
                  if (context.mounted) toast(context, tr('common.saved'));
                  s.changed();
                }),
                child: Text(tr('common.save')),
              ),
            ),
          ]),
        ]),
        Section(children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text([
              tr('inv.from', {'date': Fmt.date(inv['date'] as String)}),
              if (inv['dueDate'] != null) tr('inv.payBy', {'date': Fmt.date(inv['dueDate'] as String)}),
            ].join(' · ')),
            StatusChip(paid: paid, long: true),
          ]),
          const SizedBox(height: 16),
          Grid(minWidth: 260, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('inv.seller').toUpperCase(), style: small),
              Text((p['name'] as String).isEmpty ? tr('inv.noName') : p['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if ((p['tin'] as String).isNotEmpty) Text(tr('inv.tin', {'tin': p['tin']})),
              if ((p['address'] as String).isNotEmpty) Text(p['address'] as String),
              if ((p['bankAccount'] as String).isNotEmpty) Text(tr('inv.account', {'account': p['bankAccount']})),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('inv.buyer').toUpperCase(), style: small),
              Text(inv['client'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
              if ((inv['clientTin'] as String).isNotEmpty) Text(tr('inv.tin', {'tin': inv['clientTin']})),
            ]),
          ]),
          const Divider(height: 32),
          for (final (n, it) in items.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('${n + 1}'),
              title: Text(it['name'] as String),
              subtitle: Text('${f.number(it['quantity'], 3)} × ${f.money(it['price'])}'),
              trailing: Text(f.money(it['sum'])),
            ),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${tr('inv.totalLine')}: ${f.money(inv['total'])}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
      ],
    );
  }
}
