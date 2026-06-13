import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import '../utils/app_settings.dart';

class PrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<bool> connect(BluetoothDevice device) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) return true;
    await bluetooth.connect(device);
    return (await bluetooth.isConnected) ?? false;
  }

  Future<void> printInvoice({
    required String invoiceNumber,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double total,
    required double paid,
  }) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true) return;

    // 1. حساب طول الفاتورة ديناميكياً بناءً على عدد الأصناف
    const double width = 384; // العرض القياسي لطابعات 58 مم بالبكسل
    double headerHeight = 150;
    if (AppSettings.storeAddress.isNotEmpty || AppSettings.storePhone.isNotEmpty) {
      headerHeight += 30;
    }
    const double itemHeight = 35;
    const double footerHeight = 280;
    final double height = headerHeight + (items.length * itemHeight) + footerHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // رسم خلفية بيضاء للفاتورة
    final paintBg = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paintBg);

    double y = 10;

    // دالة مساعدة لرسم نصوص عربية محاذية
    void drawText(String text, {double fontSize = 20, bool isCenter = false, bool isBold = false}) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: isCenter ? TextAlign.center : TextAlign.right,
      );
      textPainter.layout(maxWidth: width - 20);
      
      double x = 10;
      if (isCenter) {
        x = (width - textPainter.width) / 2;
      } else {
        x = width - textPainter.width - 10;
      }
      textPainter.paint(canvas, Offset(x, y));
    }

    // دالة مساعدة لرسم سطر ثنائي الأعمدة (يمين ويسار)
    void drawRow(String rightText, String leftText, {double fontSize = 18, bool isBold = false}) {
      // العمود الأيمن
      final rightPainter = TextPainter(
        text: TextSpan(
          text: rightText,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
      );
      rightPainter.layout(maxWidth: width - 100);
      rightPainter.paint(canvas, Offset(width - rightPainter.width - 10, y));

      // العمود الأيسر
      final leftPainter = TextPainter(
        text: TextSpan(
          text: leftText,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      leftPainter.layout(maxWidth: 90);
      leftPainter.paint(canvas, Offset(10, y));
    }

    // 2. كتابة ورسم تفاصيل الفاتورة
    drawText(AppSettings.storeName, fontSize: 22, isCenter: true, isBold: true);
    y += 35;
    if (AppSettings.storeAddress.isNotEmpty || AppSettings.storePhone.isNotEmpty) {
      String contact = AppSettings.storeAddress;
      if (AppSettings.storePhone.isNotEmpty) {
        contact += contact.isNotEmpty ? " | ت: ${AppSettings.storePhone}" : "ت: ${AppSettings.storePhone}";
      }
      drawText(contact, fontSize: 14, isCenter: true);
      y += 25;
    }
    y += 10;

    String date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    drawRow("رقم الفاتورة:", invoiceNumber);
    y += 25;
    drawRow("التاريخ:", date);
    y += 25;
    drawRow("العميل:", customerName);
    y += 30;

    drawText("------------------------------------------------", fontSize: 16, isCenter: true);
    y += 20;

    drawRow("الصنف", "المبلغ", isBold: true);
    y += 30;

    for (var item in items) {
      String name = item['name'] ?? '';
      if (name.length > 18) name = "${name.substring(0, 15)}...";
      String qtyText = "$name x${item['quantity']}";
      String priceText = "${((item['price'] ?? 0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}";
      
      drawRow(qtyText, priceText);
      y += 25;
    }

    drawText("------------------------------------------------", fontSize: 16, isCenter: true);
    y += 20;

    drawRow("الإجمالي:", "${total.toStringAsFixed(2)} ${AppSettings.currency}", isBold: true);
    y += 30;
    drawRow("المدفوع:", "${paid.toStringAsFixed(2)} ${AppSettings.currency}");
    y += 25;
    drawRow("المتبقي:", "${(total - paid).toStringAsFixed(2)} ${AppSettings.currency}");
    y += 35;

    drawText("شكراً لتعاملكم معنا", fontSize: 18, isCenter: true, isBold: true);
    y += 25;
    drawText("برمجة: Antigravity AI", fontSize: 12, isCenter: true);

    // 3. توليد وحفظ الصورة محلياً بصيغة PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/invoice_$invoiceNumber.png');
      await tempFile.writeAsBytes(pngBytes.buffer.asUint8List());

      // 4. طباعة الفاتورة كصورة عبر البلوتوث
      await bluetooth.printImage(tempFile.path);
      
      // تغذية الورق للقص
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();

      // حذف الملف المؤقت لتوفير مساحة التخزين
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
