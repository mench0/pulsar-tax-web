import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../core/i18n.dart';

/// PDF счёта на оплату. Шрифты Noto Sans (кириллица) и Noto Sans Armenian (армянский и ֏) лежат в assets.
Future<Uint8List> invoicePdf(Map<String, dynamic> inv, Map<String, dynamic> profile, Tr tr, Fmt f,
    {AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  Future<pw.Font> font(String name) async => pw.Font.ttf(await b.load('assets/fonts/$name.ttf'));
  final theme = pw.ThemeData.withFont(
    base: await font('NotoSans-Regular'),
    bold: await font('NotoSans-Bold'),
    fontFallback: [await font('NotoSansArmenian-Regular'), await font('NotoSansArmenian-Bold')],
  );
  final muted = PdfColor.fromInt(0xFF5D6475);
  final small = pw.TextStyle(fontSize: 9, color: muted);
  final items = (inv['items'] as List).cast<Map<String, dynamic>>();
  final paid = inv['status'] == 'PAID';

  pw.Widget party(String label, List<String?> lines) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: small),
          pw.SizedBox(height: 4),
          for (final (i, l) in lines.whereType<String>().where((l) => l.isNotEmpty).indexed)
            pw.Text(l, style: i == 0 ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ],
      );

  final doc = pw.Document(theme: theme, title: tr('inv.heading', {'number': inv['number']}));
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(tr('inv.heading', {'number': inv['number']}),
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text([
              tr('inv.from', {'date': Fmt.date(inv['date'] as String)}),
              if (inv['dueDate'] != null) tr('inv.payBy', {'date': Fmt.date(inv['dueDate'] as String)}),
            ].join(' · '), style: small),
            if ((inv['eInvoiceNumber'] as String).isNotEmpty)
              pw.Text(tr('inv.einvoiceShort', {'n': inv['eInvoiceNumber']}), style: small),
          ]),
        ),
        pw.Text(paid ? tr('invs.paid') : tr('inv.waiting'),
            style: pw.TextStyle(color: paid ? PdfColor.fromInt(0xFF1F8A5B) : muted, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 24),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: party(tr('inv.seller'), [
            (profile['name'] as String).isEmpty ? tr('inv.noName') : profile['name'] as String,
            if ((profile['tin'] as String).isNotEmpty) tr('inv.tin', {'tin': profile['tin']}),
            profile['address'] as String,
            if ((profile['bankAccount'] as String).isNotEmpty) tr('inv.account', {'account': profile['bankAccount']}),
          ]),
        ),
        pw.Expanded(
          child: party(tr('inv.buyer'), [
            inv['client'] as String,
            if ((inv['clientTin'] as String).isNotEmpty) tr('inv.tin', {'tin': inv['clientTin']}),
          ]),
        ),
      ]),
      pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(
        headers: ['№', tr('inv.colName'), tr('invs.qty'), tr('invs.price'), tr('inv.colSum')],
        data: [
          for (final (n, it) in items.indexed)
            ['${n + 1}', it['name'], f.number(it['quantity'], 3), f.money(it['price']), f.money(it['sum'])],
        ],
        headerStyle: pw.TextStyle(fontSize: 9, color: muted, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(),
        cellAlignments: {0: pw.Alignment.centerLeft, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
        columnWidths: {0: const pw.FixedColumnWidth(24), 1: const pw.FlexColumnWidth(4)},
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE3DFD5))),
      ),
      pw.SizedBox(height: 16),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${tr('inv.totalLine')}: ${f.money(inv['total'])}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 48),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${tr('inv.seller')} ____________________', style: small),
        pw.Text('${tr('inv.buyer')} ____________________', style: small),
      ]),
    ]),
  ));
  return doc.save();
}
