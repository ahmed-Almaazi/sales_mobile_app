import 'package:cloud_firestore/cloud_firestore.dart';
import 'counter_service.dart';

class SaleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  /// توليد رقم الفاتورة للواجهة مسبقاً
  Future<String> generateInvoiceNumber(String prefix) => _counterService.getNextInvoiceNumber(prefix);

  /// إصدار فاتورة مبيعات جديدة مع معالجة المخزون والمالية
  Future<String> createSaleInvoice({
    String? invoiceNumber,
    required String? customerId,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    double discount = 0.0,
    String warehouseId = 'MAIN',
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async {
    // 0. التحقق من توفر المخزون الكافي للمنتجات قبل إتمام عملية البيع
    for (var item in items) {
      final productDoc = await _db.collection('products').doc(item['productId']).get();
      if (!productDoc.exists) {
        throw Exception('المنتج "${item['name'] ?? ''}" غير موجود في قاعدة البيانات');
      }
      final double currentStock = (productDoc.data()?['currentStock'] ?? 0.0).toDouble();
      final double requestedQty = (item['quantity'] ?? 0.0).toDouble();
      if (currentStock < requestedQty) {
        throw Exception('عذراً، الكمية المطلوبة للمنتج "${item['name'] ?? ''}" غير متوفرة. المتوفر حالياً: $currentStock');
      }
    }

    // التحقق من الحد الائتماني للعميل
    final double debt = totalAmount - paidAmount;
    if (debt > 0 && customerId != null) {
      final customerDoc = await _db.collection('customers').doc(customerId).get();
      if (customerDoc.exists) {
        final data = customerDoc.data()!;
        final double creditLimit = (data['creditLimit'] ?? 0.0).toDouble();
        final double currentBalance = (data['balance'] ?? 0.0).toDouble();
        if (creditLimit > 0 && (currentBalance + debt) > creditLimit) {
          throw Exception(
            'تجاوز الحد الائتماني للعميل "$customerName".\n'
            'الحد الائتماني: $creditLimit\n'
            'الرصيد الحالي: ${currentBalance.toStringAsFixed(1)}\n'
            'سيصبح الرصيد بعد الفاتورة: ${(currentBalance + debt).toStringAsFixed(1)}'
          );
        }
      }
    }

    final batch = _db.batch();

    // 1. توليد رقم فاتورة احترافي (SAL-000001)
    final String finalInvoiceNumber = invoiceNumber ?? await _counterService.getNextInvoiceNumber('SAL');
    final invoiceRef = _db.collection('sales').doc();

    // 2. حساب الربح بدقة بناءً على سعر الشراء (purchasePrice)
    double totalCost = 0;
    for (var item in items) {
      totalCost += (item['purchasePrice'] ?? 0) * item['quantity'];
    }
    double profit = totalAmount - totalCost;

    // 3. إنشاء الفاتورة
    batch.set(invoiceRef, {
      'invoiceNumber': finalInvoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'totalAmount': totalAmount,
      'discount': discount,
      'paidAmount': paidAmount,
      'remainingAmount': totalAmount - paidAmount,
      'profit': profit,
      'totalCost': totalCost,
      'items': items,
      'warehouseId': warehouseId,
      'status': 'COMPLETED',
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'createdAt': invoiceDate != null ? Timestamp.fromDate(invoiceDate) : FieldValue.serverTimestamp(),
    });

    // 4. خصم المخزون وتسجيل الحركات (تحديث الحقل العام currentStock)
    for (var item in items) {
      final productRef = _db.collection('products').doc(item['productId']);
      batch.update(productRef, {'currentStock': FieldValue.increment(-item['quantity'])});

      final movementRef = _db.collection('stock_movements').doc();
      batch.set(movementRef, {
        'productId': item['productId'],
        'warehouseId': warehouseId,
        'quantity': item['quantity'],
        'type': 'OUT',
        'reference': finalInvoiceNumber,
        'notes': 'بيع للعميل $customerName',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 5. معالجة الصندوق (تسجيل المبلغ المدفوع كدخل)
    if (paidAmount > 0) {
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': paidAmount,
        'type': 'IN',
        'description': 'دفعة من فاتورة مبيعات $finalInvoiceNumber',
        'reference': finalInvoiceNumber,
        'category': 'SALE',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(paidAmount)}, SetOptions(merge: true));
    }

    // 6. معالجة المديونية
    if (debt > 0 && customerId != null) {
      final customerRef = _db.collection('customers').doc(customerId);
      batch.update(customerRef, {'balance': FieldValue.increment(debt)});

      // إنشاء تذكير سداد في جدول reminders
      if (dueDate != null) {
        final reminderRef = _db.collection('reminders').doc();
        batch.set(reminderRef, {
          'customerId': customerId,
          'customerName': customerName,
          'invoiceNumber': finalInvoiceNumber,
          'invoiceId': invoiceRef.id,
          'amount': debt,
          'dueDate': Timestamp.fromDate(dueDate),
          'status': 'PENDING',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // 7. إضافة الربح لرأس المال
    if (profit != 0) {
      final capitalRef = _db.collection('counters').doc('capital');
      batch.set(capitalRef, {'balance': FieldValue.increment(profit)}, SetOptions(merge: true));
    }

    // 8. تحديث إحصاءات اليوم
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final statsRef = _db.collection('daily_stats').doc(dayKey);
    batch.set(statsRef, {
      'date': dayKey,
      'totalSales': FieldValue.increment(totalAmount),
      'totalProfit': FieldValue.increment(profit),
      'totalOrders': FieldValue.increment(1),
      'paidAmount': FieldValue.increment(paidAmount),
    }, SetOptions(merge: true));

    // 9. سجل المراقبة (Audit Log)
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'CREATE_SALE',
      'details': 'إنشاء فاتورة بيع رقم $finalInvoiceNumber للعميل $customerName بقيمة $totalAmount',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return finalInvoiceNumber;
  }

  /// إرجاع فاتورة (مرتجعات احترافية)
  Future<void> returnSale(String invoiceId) async {
    final invoiceDoc = await _db.collection('sales').doc(invoiceId).get();
    if (!invoiceDoc.exists) throw Exception('الفاتورة غير موجودة');

    final data = invoiceDoc.data()!;
    final items = data['items'] as List<dynamic>;
    final customerId = data['customerId'];
    final totalAmount = data['totalAmount'] as double;
    final paidAmount = data['paidAmount'] as double;
    final String invoiceNumber = data['invoiceNumber'] ?? invoiceId;
    final String warehouseId = data['warehouseId'] ?? 'MAIN';
    final double profit = (data['profit'] ?? 0.0).toDouble();

    final batch = _db.batch();

    // 1. استرجاع المخزون
    for (var item in items) {
      final productRef = _db.collection('products').doc(item['productId']);
      batch.update(productRef, {'currentStock': FieldValue.increment(item['quantity'])});

      final movementRef = _db.collection('stock_movements').doc();
      batch.set(movementRef, {
        'productId': item['productId'],
        'warehouseId': warehouseId,
        'quantity': item['quantity'],
        'type': 'IN',
        'reference': 'مرتجع $invoiceNumber',
        'notes': 'إرجاع بضاعة للفاتورة $invoiceNumber',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 2. رد المبلغ المالي من الصندوق
    if (paidAmount > 0) {
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': paidAmount,
        'type': 'OUT',
        'description': 'رد مبلغ لفاتورة مرتجعة $invoiceNumber',
        'reference': invoiceNumber,
        'category': 'SALE_RETURN',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(-paidAmount)}, SetOptions(merge: true));
    }

    // 3. تعديل مديونية العميل
    final double debt = totalAmount - paidAmount;
    if (debt > 0 && customerId != null) {
      final customerRef = _db.collection('customers').doc(customerId);
      batch.update(customerRef, {'balance': FieldValue.increment(-debt)});
    }

    // 4. خصم الأرباح الملغاة من رأس المال
    if (profit != 0) {
      final capitalRef = _db.collection('counters').doc('capital');
      batch.set(capitalRef, {'balance': FieldValue.increment(-profit)}, SetOptions(merge: true));
    }

    // 5. حذف التذكيرات المرتبطة بهذه الفاتورة
    final remindersQuery = await _db.collection('reminders')
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .get();
    for (var remDoc in remindersQuery.docs) {
      batch.delete(remDoc.reference);
    }

    // 6. تحديث إحصاءات اليوم بعكس المبيعات
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final statsRef = _db.collection('daily_stats').doc(dayKey);
    batch.set(statsRef, {
      'totalSales': FieldValue.increment(-totalAmount),
      'totalProfit': FieldValue.increment(-profit),
      'totalOrders': FieldValue.increment(-1),
      'paidAmount': FieldValue.increment(-paidAmount),
    }, SetOptions(merge: true));

    // 7. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'RETURN_SALE',
      'details': 'إرجاع فاتورة بيع رقم $invoiceNumber للعميل ${data['customerName']} بقيمة $totalAmount',
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(invoiceDoc.reference, {'status': 'RETURNED'});
    await batch.commit();
  }

  /// حذف فاتورة مبيعات بالكامل وعكس تأثيراتها على المخزون والمالية ورأس المال
  Future<void> deleteSaleInvoice(String invoiceId, Map<String, dynamic> data) async {
    final batch = _db.batch();
    
    final String invoiceNumber = data['invoiceNumber'] ?? '';
    final String? customerId = data['customerId'];
    final double totalAmount = (data['totalAmount'] ?? 0).toDouble();
    final double paidAmount = (data['paidAmount'] ?? 0).toDouble();
    final String warehouseId = data['warehouseId'] ?? 'MAIN';
    final List<dynamic> items = data['items'] ?? [];
    final double profit = (data['profit'] ?? 0.0).toDouble();

    // 1. إعادة المنتجات للمخزون وتسجيل حركات مخزنية
    for (var item in items) {
      final String productId = item['productId'];
      final int quantity = item['quantity'] ?? 0;
      
      final productRef = _db.collection('products').doc(productId);
      batch.update(productRef, {'currentStock': FieldValue.increment(quantity)});

      final movementRef = _db.collection('stock_movements').doc();
      batch.set(movementRef, {
        'productId': productId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        'type': 'IN',
        'reference': 'DEL-$invoiceNumber',
        'notes': 'إرجاع مخزون بسبب حذف الفاتورة $invoiceNumber',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 2. خصم المبلغ المدفوع من الصندوق إذا كان أكبر من الصفر
    if (paidAmount > 0) {
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': paidAmount,
        'type': 'OUT',
        'description': 'خصم من الصندوق بسبب حذف الفاتورة $invoiceNumber',
        'reference': 'DEL-$invoiceNumber',
        'category': 'SALE_DELETE',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(-paidAmount)}, SetOptions(merge: true));
    }

    // 3. خصم المديونية المضافة للعميل
    final double debt = totalAmount - paidAmount;
    if (debt > 0 && customerId != null) {
      final customerRef = _db.collection('customers').doc(customerId);
      batch.update(customerRef, {'balance': FieldValue.increment(-debt)});
    }

    // 4. خصم أرباح الفاتورة الملغاة من رأس المال
    if (profit != 0) {
      final capitalRef = _db.collection('counters').doc('capital');
      batch.set(capitalRef, {'balance': FieldValue.increment(-profit)}, SetOptions(merge: true));
    }

    // 5. حذف التذكيرات المرتبطة بهذه الفاتورة
    final remindersQuery = await _db.collection('reminders')
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .get();
    for (var remDoc in remindersQuery.docs) {
      batch.delete(remDoc.reference);
    }

    // 6. عكس إحصاءات اليوم
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final statsRef = _db.collection('daily_stats').doc(dayKey);
    batch.set(statsRef, {
      'totalSales': FieldValue.increment(-totalAmount),
      'totalProfit': FieldValue.increment(-profit),
      'totalOrders': FieldValue.increment(-1),
      'paidAmount': FieldValue.increment(-paidAmount),
    }, SetOptions(merge: true));

    // 7. حذف الفاتورة نفسها
    final invoiceRef = _db.collection('sales').doc(invoiceId);
    batch.delete(invoiceRef);

    // 8. سجل المراقبة (Audit Log)
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'DELETE_SALE',
      'details': 'حذف كامل لفاتورة بيع رقم $invoiceNumber بقيمة $totalAmount وعكس كافة آثارها ورأس المال',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// تعديل بيانات الفاتورة (العميل، المخزن، تاريخ الفاتورة، والمبلغ المدفوع)
  Future<void> updateSaleInvoice({
    required String invoiceId,
    required Map<String, dynamic> oldData,
    required String customerName,
    required String? customerId,
    required String warehouseId,
    required DateTime invoiceDate,
    required double newPaidAmount,
  }) async {
    final batch = _db.batch();
    final invoiceRef = _db.collection('sales').doc(invoiceId);

    final String invoiceNumber = oldData['invoiceNumber'] ?? '';
    final double totalAmount = (oldData['totalAmount'] ?? 0).toDouble();
    final double oldPaidAmount = (oldData['paidAmount'] ?? 0).toDouble();
    final String? oldCustomerId = oldData['customerId'];

    final double newRemainingAmount = totalAmount - newPaidAmount;

    // 1. تحديث مستند الفاتورة الرئيسي
    batch.update(invoiceRef, {
      'customerName': customerName,
      'customerId': customerId,
      'warehouseId': warehouseId,
      'createdAt': Timestamp.fromDate(invoiceDate),
      'paidAmount': newPaidAmount,
      'remainingAmount': newRemainingAmount,
    });

    // 2. معالجة الفارق المالي في الصندوق
    final double paidDiff = newPaidAmount - oldPaidAmount;
    if (paidDiff != 0) {
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': paidDiff.abs(),
        'type': paidDiff > 0 ? 'IN' : 'OUT',
        'description': 'تعديل المبلغ المدفوع للفاتورة $invoiceNumber',
        'reference': invoiceNumber,
        'category': 'SALE_UPDATE',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(paidDiff)}, SetOptions(merge: true));
    }

    // 3. معالجة الفارق المالي في حساب العميل
    final double debtChange = -paidDiff;

    if (oldCustomerId == customerId) {
      if (customerId != null && debtChange != 0) {
        final customerRef = _db.collection('customers').doc(customerId);
        batch.update(customerRef, {'balance': FieldValue.increment(debtChange)});
      }
    } else {
      // تغير العميل
      final double oldDebt = totalAmount - oldPaidAmount;
      if (oldDebt > 0 && oldCustomerId != null) {
        final oldCustomerRef = _db.collection('customers').doc(oldCustomerId);
        batch.update(oldCustomerRef, {'balance': FieldValue.increment(-oldDebt)});
      }
      final double newDebt = totalAmount - newPaidAmount;
      if (newDebt > 0 && customerId != null) {
        final newCustomerRef = _db.collection('customers').doc(customerId);
        batch.update(newCustomerRef, {'balance': FieldValue.increment(newDebt)});
      }
    }

    // 4. تحديث التذكيرات المرتبطة بهذه الفاتورة إذا تم سداد الدين بالكامل
    if (newRemainingAmount <= 0) {
      final remindersQuery = await _db.collection('reminders')
          .where('invoiceNumber', isEqualTo: invoiceNumber)
          .where('status', isEqualTo: 'PENDING')
          .get();
      for (var remDoc in remindersQuery.docs) {
        batch.update(remDoc.reference, {'status': 'COMPLETED'});
      }
    }

    // 5. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'UPDATE_SALE',
      'details': 'تعديل الفاتورة رقم $invoiceNumber: العميل $customerName، المدفوع الجديد $newPaidAmount',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
