import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/app_settings.dart';

class PdfService {
  // ─── توليد رمز QR متوافق مع ZATCA (TLV – Base64) ───────────────────
  // يُشفّر الحقول الأساسية (seller, taxNumber, datetime, total, vat)
  static String generateZatcaQrBase64({
    required String sellerName,
    required String taxNumber,
    required String invoiceDate,
    required double totalWithVat,
    double vat = 0.0,
  }) {
    Uint8List tlvEncode(int tag, String value) {
      final bytes = utf8.encode(value);
      return Uint8List.fromList([tag, bytes.length, ...bytes]);
    }

    final data = Uint8List.fromList([
      ...tlvEncode(1, sellerName),
      ...tlvEncode(2, taxNumber.isEmpty ? '000000000000000' : taxNumber),
      ...tlvEncode(3, invoiceDate),
      ...tlvEncode(4, totalWithVat.toStringAsFixed(2)),
      ...tlvEncode(5, vat.toStringAsFixed(2)),
    ]);
    return base64Encode(data);
  }

  // ─── بناء مستند PDF احترافي ──────────────────────────────────────────
  static Future<Uint8List> generateInvoicePdf({
    required Map<String, dynamic> invoiceData,
  }) async {
    final doc = pw.Document();

    final String invoiceNumber = invoiceData['invoiceNumber'] ?? '';
    final String customerName  = invoiceData['customerName'] ?? 'عميل نقدي';
    final double totalAmount   = (invoiceData['totalAmount'] ?? 0.0).toDouble();
    final double discount      = (invoiceData['discount'] ?? 0.0).toDouble();
    final double subTotal      = totalAmount + discount;
    final double paidAmount    = (invoiceData['paidAmount'] ?? 0.0).toDouble();
    final double remaining     = totalAmount - paidAmount;
    final List<dynamic> items  = invoiceData['items'] ?? [];
    final String warehouse     = invoiceData['warehouseId'] == 'MAIN' ? 'المخزن الرئيسي' : 'السيارة';

    // تاريخ الفاتورة
    String invoiceDate = '';
    if (invoiceData['createdAt'] != null) {
      final ts = invoiceData['createdAt'];
      DateTime dt;
      if (ts is DateTime) {
        dt = ts;
      } else {
        dt = ts.toDate();
      }
      invoiceDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // QR Code
    final qrData = generateZatcaQrBase64(
      sellerName: AppSettings.storeName,
      taxNumber: '',
      invoiceDate: invoiceDate,
      totalWithVat: totalAmount,
    );

    // ألوان
    const primaryColor  = PdfColors.blue900;
    const accentGreen   = PdfColor.fromInt(0xFF059669);
    const accentRed     = PdfColor.fromInt(0xFFEF4444);
    const lightGrey     = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor   = PdfColor.fromInt(0xFFE2E8F0);

    // ─── الصفحة ────────────────────────────────────────────────────────
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── الترويسة ────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      AppSettings.storeName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    if (AppSettings.storeAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        AppSettings.storeAddress,
                        style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.7), fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                    if (AppSettings.storePhone.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'هاتف: ${AppSettings.storePhone}',
                        style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.7), fontSize: 10),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── معلومات الفاتورة ────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfRow('رقم الفاتورة', invoiceNumber),
                    if (invoiceDate.isNotEmpty) _buildPdfRow('التاريخ', invoiceDate),
                    _buildPdfRow('العميل', customerName),
                    _buildPdfRow('المستودع', warehouse),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── جدول الأصناف ────────────────────────────────────────
              pw.Text(
                'الأصناف والمنتجات',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.SizedBox(height: 8),

              // رأس الجدول
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const pw.BoxDecoration(color: primaryColor),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text('المنتج', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10), textDirection: pw.TextDirection.rtl),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text('الكمية', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('السعر', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('الإجمالي', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center),
                    ),
                  ],
                ),
              ),

              // صفوف المنتجات
              ...items.asMap().entries.map((entry) {
                final i    = entry.key;
                final item = entry.value;
                final price = (item['price'] ?? 0.0).toDouble();
                final qty   = (item['quantity'] ?? 1);
                final total = price * qty;
                final bgColor = i.isEven ? PdfColors.white : lightGrey;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: pw.BoxDecoration(
                    color: bgColor,
                    border: const pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(item['name'] ?? '', style: const pw.TextStyle(fontSize: 10), textDirection: pw.TextDirection.rtl),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${price.toStringAsFixed(1)} ${AppSettings.currency}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${total.toStringAsFixed(1)} ${AppSettings.currency}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 12),

              // ── ملخص المبالغ ────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    if (discount > 0) ...[
                      _buildPdfRow('المجموع الفرعي', '${subTotal.toStringAsFixed(1)} ${AppSettings.currency}'),
                      _buildPdfRow('الخصم الممنوح', '- ${discount.toStringAsFixed(1)} ${AppSettings.currency}', valueColor: accentRed),
                    ],
                    _buildPdfRow(
                      'الإجمالي',
                      '${totalAmount.toStringAsFixed(1)} ${AppSettings.currency}',
                      isBold: true,
                      valueColor: primaryColor,
                    ),
                    _buildPdfRow('المدفوع', '${paidAmount.toStringAsFixed(1)} ${AppSettings.currency}', valueColor: accentGreen),
                    if (remaining > 0)
                      _buildPdfRow('المتبقي (دين)', '${remaining.toStringAsFixed(1)} ${AppSettings.currency}', valueColor: accentRed),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── QR Code + تذييل ─────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 80,
                        height: 80,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('رمز التحقق الإلكتروني', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('شكراً لتعاملكم معنا', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor), textDirection: pw.TextDirection.rtl),
                      pw.SizedBox(height: 4),
                      pw.Text('نظام Antigravity AI', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ─── دالة مساعدة لصف في ملخص المبالغ ───────────────────────────────
  static pw.Widget _buildPdfRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.grey700,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ─── مشاركة الفاتورة كـ PDF عبر Share Sheet ────────────────────────
  static Future<void> shareInvoicePdf({
    required Map<String, dynamic> invoiceData,
    required BuildContext context,
  }) async {
    try {
      final pdfBytes = await generateInvoicePdf(invoiceData: invoiceData);
      final invoiceNumber = invoiceData['invoiceNumber'] ?? 'invoice';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/فاتورة_$invoiceNumber.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'فاتورة رقم $invoiceNumber - ${AppSettings.storeName}',
        text: 'مرفق فاتورة رقم $invoiceNumber بقيمة ${invoiceData['totalAmount']} ${AppSettings.currency}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء مشاركة الفاتورة: $e')),
        );
      }
    }
  }

  // ─── طباعة الفاتورة عبر نظام الطباعة ──────────────────────────────
  static Future<void> printInvoicePdf({
    required Map<String, dynamic> invoiceData,
    required BuildContext context,
  }) async {
    try {
      final pdfBytes = await generateInvoicePdf(invoiceData: invoiceData);
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'فاتورة_${invoiceData['invoiceNumber'] ?? ''}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الطباعة: $e')),
        );
      }
    }
  }
}
