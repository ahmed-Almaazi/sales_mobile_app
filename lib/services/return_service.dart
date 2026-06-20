import 'package:cloud_firestore/cloud_firestore.dart';
import 'counter_service.dart';

class ReturnService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  /// مرتجع مبيعات جزئي (من العميل)
  Future<String> createSaleReturn({
    required String originalInvoiceId,
    required String originalInvoiceNumber,
    required String? customerId,
    required List<Map<String, dynamic>> returnedItems,
    required double refundAmount, // المبلغ الذي سيتم رده للعميل أو خصمه من دينه
    required bool addToStock, // هل تعود للمخزن أم للتوالف
    required bool refundCash, // هل يُرد المبلغ نقداً للعميل أم يُخصم من دينه فقط
    String warehouseId = 'MAIN',
  }) async {
    final batch = _db.batch();

    // 1. توليد رقم مرتجع (SRT-000001)
    final String returnNumber = await _counterService.getNextInvoiceNumber('SRT');
    final returnRef = _db.collection('sale_returns').doc();

    // حساب تكلفة البضاعة المرتجعة لخصم الربح بدقة
    double returnedCost = 0;
    for (var item in returnedItems) {
      returnedCost += (item['purchasePrice'] ?? 0) * (item['quantity'] ?? 0);
    }
    // الربح المُلغى = قيمة المرتجع - تكلفته
    final double cancelledProfit = refundAmount - returnedCost;

    // 2. تسجيل المرتجع
    batch.set(returnRef, {
      'returnNumber': returnNumber,
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'customerId': customerId,
      'items': returnedItems,
      'refundAmount': refundAmount,
      'cancelledProfit': cancelledProfit,
      'addToStock': addToStock,
      'refundCash': refundCash,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. التأثير على المخزون
    for (var item in returnedItems) {
      final productRef = _db.collection('products').doc(item['productId']);

      if (addToStock) {
        // العودة للمخزن الرئيسي
        batch.update(productRef, {'currentStock': FieldValue.increment(item['quantity'])});
      } else {
        // العودة لمخزن التوالف (Damaged)
        final damagedRef = _db.collection('damaged_products').doc();
        batch.set(damagedRef, {
          'productId': item['productId'],
          'quantity': item['quantity'],
          'reason': 'مرتجع عميل تالف',
          'reference': returnNumber,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // تسجيل حركة المخزون
      final movementRef = _db.collection('stock_movements').doc();
      batch.set(movementRef, {
        'productId': item['productId'],
        'warehouseId': addToStock ? warehouseId : 'DAMAGED',
        'quantity': item['quantity'],
        'type': 'IN',
        'reference': returnNumber,
        'notes': 'مرتجع مبيعات للفاتورة $originalInvoiceNumber',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 4. التأثير المالي
    if (refundCash && refundAmount > 0) {
      // رد المبلغ نقداً: يخرج من الصندوق
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': refundAmount,
        'type': 'OUT',
        'description': 'رد نقدي لمرتجع مبيعات رقم $returnNumber - الفاتورة $originalInvoiceNumber',
        'reference': returnNumber,
        'category': 'SALE_RETURN',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(-refundAmount)}, SetOptions(merge: true));
    } else if (!refundCash && customerId != null && refundAmount > 0) {
      // خصم قيمة المرتجع من مديونية العميل (تقليل الدين)
      final customerRef = _db.collection('customers').doc(customerId);
      batch.update(customerRef, {'balance': FieldValue.increment(-refundAmount)});
    }

    // 5. خصم الربح الملغى من رأس المال
    if (cancelledProfit != 0) {
      final capitalRef = _db.collection('counters').doc('capital');
      batch.set(capitalRef, {'balance': FieldValue.increment(-cancelledProfit)}, SetOptions(merge: true));
    }

    // 6. تعديل الفاتورة الأصلية: خصم المبلغ المرتجع وتحديث الحالة
    final originalRef = _db.collection('sales').doc(originalInvoiceId);
    final originalDoc = await _db.collection('sales').doc(originalInvoiceId).get();
    if (originalDoc.exists) {
      final origData = originalDoc.data()!;
      final double origTotal = (origData['totalAmount'] ?? 0.0).toDouble();
      final double origPaid = (origData['paidAmount'] ?? 0.0).toDouble();
      final double origProfit = (origData['profit'] ?? 0.0).toDouble();

      final double newTotal = origTotal - refundAmount;
      final double newPaid = (origPaid - refundAmount).clamp(0, origPaid);
      final double newProfit = origProfit - cancelledProfit;

      batch.update(originalRef, {
        'totalAmount': newTotal,
        'paidAmount': newPaid,
        'remainingAmount': newTotal - newPaid,
        'profit': newProfit,
        'status': 'PARTIALLY_RETURNED',
        'lastReturnNumber': returnNumber,
      });
    }

    // 7. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'CREATE_SALE_RETURN',
      'details': 'تسجيل مرتجع مبيعات رقم $returnNumber للفاتورة $originalInvoiceNumber بقيمة $refundAmount',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return returnNumber;
  }

  /// مرتجع مشتريات (إلى المورد)
  Future<String> createPurchaseReturn({
    required String originalInvoiceId,
    required String originalInvoiceNumber,
    required String? supplierId,
    required List<Map<String, dynamic>> returnedItems,
    required double refundAmount,
    required bool receiveCash, // هل يُستلم المبلغ نقداً من المورد أم يُخصم من مديونيتنا له
    String warehouseId = 'MAIN',
  }) async {
    final batch = _db.batch();

    // 1. توليد رقم مرتجع (PRT-000001)
    final String returnNumber = await _counterService.getNextInvoiceNumber('PRT');
    final returnRef = _db.collection('purchase_returns').doc();

    batch.set(returnRef, {
      'returnNumber': returnNumber,
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'supplierId': supplierId,
      'items': returnedItems,
      'refundAmount': refundAmount,
      'receiveCash': receiveCash,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. خصم من المخزون
    for (var item in returnedItems) {
      final productRef = _db.collection('products').doc(item['productId']);
      batch.update(productRef, {'currentStock': FieldValue.increment(-item['quantity'])});

      final movementRef = _db.collection('stock_movements').doc();
      batch.set(movementRef, {
        'productId': item['productId'],
        'warehouseId': warehouseId,
        'quantity': item['quantity'],
        'type': 'OUT',
        'reference': returnNumber,
        'notes': 'مرتجع مشتريات للمورد للفاتورة $originalInvoiceNumber',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 3. التأثير المالي
    if (receiveCash && refundAmount > 0) {
      // استلام المبلغ نقداً من المورد: يدخل للصندوق
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': refundAmount,
        'type': 'IN',
        'description': 'استرداد نقدي لمرتجع مشتريات رقم $returnNumber - الفاتورة $originalInvoiceNumber',
        'reference': returnNumber,
        'category': 'PURCHASE_RETURN',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(refundAmount)}, SetOptions(merge: true));
    }

    // 4. تعديل حساب المورد (خصم المديونية التي لنا عنده أو تقليل ما علينا له)
    if (supplierId != null) {
      final supplierRef = _db.collection('suppliers').doc(supplierId);
      batch.update(supplierRef, {'balance': FieldValue.increment(-refundAmount)});
    }

    // 5. تحديث الفاتورة الأصلية
    final originalRef = _db.collection('purchases').doc(originalInvoiceId);
    final originalDoc = await _db.collection('purchases').doc(originalInvoiceId).get();
    if (originalDoc.exists) {
      final origData = originalDoc.data()!;
      final double origTotal = (origData['totalAmount'] ?? 0.0).toDouble();
      batch.update(originalRef, {
        'totalAmount': origTotal - refundAmount,
        'status': 'PARTIALLY_RETURNED',
        'lastReturnNumber': returnNumber,
      });
    }

    // 6. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'CREATE_PURCHASE_RETURN',
      'details': 'تسجيل مرتجع مشتريات رقم $returnNumber للفاتورة $originalInvoiceNumber بقيمة $refundAmount',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return returnNumber;
  }
}
