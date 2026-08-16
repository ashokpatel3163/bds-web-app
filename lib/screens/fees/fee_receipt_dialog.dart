import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../fees/fee_repository.dart';

/// Preview + print for a saved fee receipt.
Future<void> showFeeReceiptDialog(BuildContext context, FeeReceipt fee) async {
  final dateFmt = DateFormat('dd MMM yyyy');
  final heads = fee.feeItems.isNotEmpty
      ? fee.feeItems.map((e) => (e.feeHead, e.amount)).toList(growable: false)
      : <(String, double)>[(fee.feeHead, fee.amount)];
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Collection Receipt'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF4D4A84),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BDS SR, SEC, School',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ramseen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'LOGO',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'FEE RECEIPT',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Receipt No: ${fee.receiptNo}')),
                            Expanded(
                              child: Text(
                                'Date: ${dateFmt.format(fee.paidOn ?? DateTime.now())}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text('Student Name: ${fee.studentName}')),
                            Expanded(
                              child: Text(
                                'Class: ${fee.className.isEmpty ? '-' : fee.className}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Roll No: ${fee.rollNo.isEmpty ? '-' : fee.rollNo}',
                              ),
                            ),
                            Expanded(child: Text('Section: ${fee.section.isEmpty ? '-' : fee.section}')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade400),
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(2),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Color(0xFF4D4A84)),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'Fee Type',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'Amount (Rs.)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            ...List.generate(heads.length, (i) {
                              final row = heads[i];
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(row.$1, textAlign: TextAlign.center),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      row.$2 > 0 ? row.$2.toStringAsFixed(2) : '',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              );
                            }),
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade200),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'Total',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    fee.amount.toStringAsFixed(2),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4D4A84),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: const Text(
                                'Paid via Cash',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Authorized Signature',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (fee.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Note: ${fee.notes}'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final pdfDateFmt = DateFormat('dd MMM yyyy');
              final doc = pw.Document();
              doc.addPage(
                pw.Page(
                  margin: const pw.EdgeInsets.all(18),
                  build: (pw.Context pdfContext) {
                    final itemRows = fee.feeItems.isNotEmpty
                        ? fee.feeItems.map((it) => [it.feeHead, it.amount]).toList(growable: false)
                        : <List<Object>>[
                            [fee.feeHead, fee.amount]
                          ];
                    return pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromHex('#D6D6D6')),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF4D4A84),
                              borderRadius: pw.BorderRadius.only(
                                topLeft: pw.Radius.circular(8),
                                topRight: pw.Radius.circular(8),
                              ),
                            ),
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        'BDS SR, SEC, School',
                                        style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      pw.SizedBox(height: 4),
                                      pw.Text(
                                        'Ramseen',
                                        style: const pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Container(
                                  width: 62,
                                  height: 62,
                                  alignment: pw.Alignment.center,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(8),
                                    ),
                                  ),
                                  child: pw.Text(
                                    'LOGO',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Center(
                            child: pw.Text(
                              'FEE RECEIPT',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 26,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                            child: pw.Column(
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text('Receipt No: ${fee.receiptNo}'),
                                    ),
                                    pw.Expanded(
                                      child: pw.Text(
                                        'Date: ${pdfDateFmt.format(fee.paidOn ?? DateTime.now())}',
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 6),
                                pw.Row(
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text('Student Name: ${fee.studentName}'),
                                    ),
                                    pw.Expanded(
                                      child: pw.Text(
                                        'Class: ${fee.className.isEmpty ? '-' : fee.className}',
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 6),
                                pw.Row(
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text(
                                        'Roll No: ${fee.rollNo.isEmpty ? '-' : fee.rollNo}',
                                      ),
                                    ),
                                    pw.Expanded(
                                      child: pw.Text(
                                        'Section: ${fee.section.isEmpty ? '-' : fee.section}',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                            child: pw.TableHelper.fromTextArray(
                              headers: const ['Fee Type', 'Amount (Rs.)'],
                              data: [
                                ...itemRows.map(
                                  (r) => [
                                    r[0] as String,
                                    (r[1] as double).toStringAsFixed(2),
                                  ],
                                ),
                                ['Total', fee.amount.toStringAsFixed(2)],
                              ],
                              headerDecoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFF4D4A84),
                              ),
                              headerStyle: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              cellAlignment: pw.Alignment.center,
                              border: pw.TableBorder.all(
                                color: PdfColor.fromHex('#CFCFCF'),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 14),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColor.fromInt(0xFF4D4A84),
                                    borderRadius: pw.BorderRadius.all(
                                      pw.Radius.circular(20),
                                    ),
                                  ),
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: pw.Text(
                                    'Paid via Cash',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                pw.Spacer(),
                                pw.Text(
                                  'Authorized Signature',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (fee.notes.trim().isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: pw.Text('Note: ${fee.notes}'),
                            )
                          else
                            pw.SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
              );
              await Printing.layoutPdf(onLayout: (_) async => doc.save());
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
        ],
      );
    },
  );
}
