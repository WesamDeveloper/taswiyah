import 'dart:io';
import 'package:flutter/services.dart';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/local_db_service.dart';

class ExportService {
  final LocalDbService _dbService = LocalDbService.instance;

  Future<void> exportCustomerStatement({
    required int customerId,
    required String customerName,
    required String format, // 'pdf' or 'excel'
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final debts = await _dbService.getCustomerDebts(customerId);
    final payments = await _dbService.getCustomerPayments(customerId);

    List transactions = [];
    for (var d in debts) {
      final map = Map<String, dynamic>.from(d);
      map['tx_type'] = 'debt';
      transactions.add(map);
    }
    for (var p in payments) {
      final map = Map<String, dynamic>.from(p);
      map['tx_type'] = 'payment';
      transactions.add(map);
    }

    // Sort ascending for ledger
    transactions.sort((a, b) {
      String dateA = a['created_at'] ?? '';
      String dateB = b['created_at'] ?? '';
      return dateA.compareTo(dateB);
    });

    // Filter by date
    final filteredTx = transactions.where((t) {
      if (t['created_at'] == null) return true;
      final date = DateTime.tryParse(t['created_at']);
      if (date == null) return true;

      if (startDate != null && date.isBefore(startDate)) return false;
      if (endDate != null && date.isAfter(endDate.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    // Calculate overall totals
    double overallDebts = 0;
    double overallPaid = 0;
    for (var tx in transactions) {
      final amt = double.parse((tx['amount'] ?? 0).toString());
      if (tx['tx_type'] == 'debt') {
        overallDebts += amt;
      } else if (tx['tx_type'] == 'payment') {
        overallPaid += amt;
      }
    }
    double overallRemaining = overallDebts - overallPaid;

    if (format == 'pdf') {
      await _generateCustomerPDF(
        customerName,
        filteredTx.cast<Map<String, dynamic>>(),
        startDate,
        endDate,
        overallDebts,
        overallPaid,
        overallRemaining,
      );
    } else if (format == 'excel') {
      await _generateCustomerExcel(
        customerName,
        filteredTx.cast<Map<String, dynamic>>(),
        startDate,
        endDate,
        overallDebts,
        overallPaid,
        overallRemaining,
      );
    }
  }

  Future<void> _generateCustomerPDF(
    String customerName,
    List<Map<String, dynamic>> transactions,
    DateTime? start,
    DateTime? end,
    double overallDebts,
    double overallPaid,
    double overallRemaining,
  ) async {
    final pdf = pw.Document();

    // Load local Arabic Font to support offline PDF generation
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    String periodText = 'الفترة: ';
    if (start == null && end == null) {
      periodText += 'الكل';
    } else {
      periodText +=
          '${start?.toString().split(' ')[0] ?? ''} إلى ${end?.toString().split(' ')[0] ?? ''}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildPdfHeader(customerName, periodText),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildPdfTable(transactions, font, fontBold),
          pw.SizedBox(height: 30),
          _buildPdfSummary(overallDebts, overallPaid, overallRemaining, fontBold),
        ],
      ),
    );

    // Save and Share
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/كشف_حساب_$customerName.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب $customerName');
  }

  Future<void> _generateCustomerExcel(
    String customerName,
    List<Map<String, dynamic>> transactions,
    DateTime? start,
    DateTime? end,
    double overallDebts,
    double overallPaid,
    double overallRemaining,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // Headers
    sheetObject.isRTL = true;
    sheetObject.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('البيان/الملاحظات'),
      TextCellValue('نوع العملية'),
      TextCellValue('المبلغ'),
    ]);

    for (var tx in transactions) {
      final date = tx['created_at'] != null
          ? tx['created_at'].toString().split('T')[0]
          : '';
      final notes = tx['notes'] ?? '';
      final amount = double.parse((tx['amount'] ?? 0).toString());
      final isDebt = tx['tx_type'] == 'debt';
      final typeText = isDebt ? 'سلفة' : 'تحصيل';

      sheetObject.appendRow([
        TextCellValue(date),
        TextCellValue(isDebt ? notes : 'دفعة من الحساب'),
        TextCellValue(typeText),
        DoubleCellValue(amount.toDouble()),
      ]);
    }

    // Totals
    sheetObject.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheetObject.appendRow([
      TextCellValue('الإجمالي الكلي للعميل'),
      TextCellValue(''),
      DoubleCellValue(overallDebts),
      DoubleCellValue(overallPaid),
      TextCellValue('المتبقي: $overallRemaining'),
    ]);

    // Save and Share
    var fileBytes = excel.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/كشف_حساب_$customerName.xlsx');

    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب $customerName');
  }

  // Helper UI functions for PDF
  pw.Widget _buildPdfHeader(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Taswiyah',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'كشف حساب: $title',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
      child: pw.Text(
        'تم الإصدار بتاريخ ${DateTime.now().toString().split('.')[0]} - صفحة ${context.pageNumber} من ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _buildPdfTable(
    List<Map<String, dynamic>> transactions,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['التاريخ', 'البيان', 'نوع العملية', 'المبلغ'],
      data: transactions.map((tx) {
        final date = tx['created_at'] != null
            ? tx['created_at'].toString().split('T')[0]
            : '';
        final isDebt = tx['tx_type'] == 'debt';
        final notes = isDebt ? (tx['notes'] ?? 'سلفة') : 'تحصيل دفعة';
        final typeStr = isDebt ? 'سلفة' : 'تحصيل';
        final amount = tx['amount']?.toString() ?? '0';
        return [date, notes, typeStr, amount];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(font: font),
      cellAlignment: pw.Alignment.center,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }

  pw.Widget _buildPdfSummary(
    double totalDebts,
    double totalPaid,
    double remaining,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                'إجمالي الديون',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              pw.Text(
                '$totalDebts',
                style: pw.TextStyle(font: fontBold, fontSize: 16),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'إجمالي المدفوعات',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              pw.Text(
                '$totalPaid',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'الرصيد المتبقي',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              pw.Text(
                '$remaining',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.red700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // All Customers Export
  Future<void> exportAllCustomersStatement({
    required String format, // 'pdf' or 'excel'
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final allDebts = await _dbService.getAllDebts();
    final allPayments = await _dbService.getAllPayments();

    List transactions = [];
    for (var d in allDebts) {
      final map = Map<String, dynamic>.from(d);
      map['tx_type'] = 'debt';
      transactions.add(map);
    }
    for (var p in allPayments) {
      final map = Map<String, dynamic>.from(p);
      map['tx_type'] = 'payment';
      transactions.add(map);
    }

    transactions.sort((a, b) {
      String dateA = a['created_at'] ?? '';
      String dateB = b['created_at'] ?? '';
      return dateA.compareTo(dateB);
    });

    final filteredTx = transactions.where((t) {
      if (t['created_at'] == null) return true;
      final date = DateTime.tryParse(t['created_at']);
      if (date == null) return true;

      if (startDate != null && date.isBefore(startDate)) return false;
      if (endDate != null && date.isAfter(endDate.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    if (format == 'pdf') {
      await _generateAllCustomersPDF(filteredTx.cast<Map<String, dynamic>>(), startDate, endDate);
    } else {
      await _generateAllCustomersExcel(filteredTx.cast<Map<String, dynamic>>(), startDate, endDate);
    }
  }

  Future<void> _generateAllCustomersPDF(
    List<Map<String, dynamic>> transactions,
    DateTime? start,
    DateTime? end,
  ) async {
    final pdf = pw.Document();

    // Load local Arabic Font
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    double totalDebts = 0;
    double totalPaid = 0;
    for (var tx in transactions) {
      if (tx['tx_type'] == 'debt') {
        totalDebts += double.parse((tx['amount'] ?? 0).toString());
      } else if (tx['tx_type'] == 'payment') {
        totalPaid += double.parse((tx['amount'] ?? 0).toString());
      }
    }
    double remaining = totalDebts - totalPaid;

    String periodText = 'الفترة: ';
    if (start == null && end == null) {
      periodText += 'الكل';
    } else {
      periodText +=
          '${start?.toString().split(' ')[0] ?? ''} إلى ${end?.toString().split(' ')[0] ?? ''}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) =>
            _buildPdfHeader('تقرير شامل لجميع العملاء', periodText),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'التاريخ',
              'اسم العميل',
              'البيان',
              'العملية',
              'المبلغ',
            ],
            data: transactions.map((tx) {
              final date = tx['created_at'] != null
                  ? tx['created_at'].toString().split('T')[0]
                  : '';
              final cName = tx['customer_name'] ?? 'غير معروف';
              final isDebt = tx['tx_type'] == 'debt';
              final notes = isDebt ? (tx['notes'] ?? 'سلفة') : 'تحصيل دفعة';
              final typeStr = isDebt ? 'سلفة' : 'تحصيل';
              final amount = tx['amount']?.toString() ?? '0';
              return [date, cName, notes, typeStr, amount];
            }).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: pw.TextStyle(font: font),
            cellAlignment: pw.Alignment.center,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          ),
          pw.SizedBox(height: 30),
          _buildPdfSummary(totalDebts, totalPaid, remaining, fontBold),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/كشف_عام_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب عام');
  }

  Future<void> _generateAllCustomersExcel(
    List<Map<String, dynamic>> transactions,
    DateTime? start,
    DateTime? end,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    sheetObject.isRTL = true;
    sheetObject.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('اسم العميل'),
      TextCellValue('البيان/الملاحظات'),
      TextCellValue('نوع العملية'),
      TextCellValue('المبلغ'),
    ]);

    double totalDebts = 0;
    double totalPaid = 0;

    for (var tx in transactions) {
      final date = tx['created_at'] != null
          ? tx['created_at'].toString().split('T')[0]
          : '';
      final cName = tx['customer_name'] ?? 'غير معروف';
      final isDebt = tx['tx_type'] == 'debt';
      final notes = isDebt ? (tx['notes'] ?? '') : 'تحصيل دفعة';
      final amount = double.parse((tx['amount'] ?? 0).toString());
      final typeStr = isDebt ? 'سلفة' : 'تحصيل';

      if (isDebt) {
        totalDebts += amount;
      } else {
        totalPaid += amount;
      }

      sheetObject.appendRow([
        TextCellValue(date),
        TextCellValue(cName),
        TextCellValue(notes),
        TextCellValue(typeStr),
        DoubleCellValue(amount.toDouble()),
      ]);
    }

    sheetObject.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheetObject.appendRow([
      TextCellValue('الإجمالي'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalDebts),
      DoubleCellValue(totalPaid),
      TextCellValue('المتبقي: ${totalDebts - totalPaid}'),
    ]);

    var fileBytes = excel.save();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/كشف_عام_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(fileBytes!);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب عام');
  }
}
