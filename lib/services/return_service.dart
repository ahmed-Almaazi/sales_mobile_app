import 'package:cloud_firestore/cloud_firestore.dart';
import 'counter_service.dart';

class ReturnService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  /// مرتجع مبيعات (من العميل)
  Future<String> createSaleReturn({
    required String originalInvoiceId,
    required String originalInvoiceNumber,
    required String? customerId,
    required List<Map<String, dynamic>> returnedItems,
    required double refundAmount, // المبلغ الذي سيتم رده للعميل أو خصمه من دينه
    required bool addToStock, // هل تعود للمخزن أم للتوالف
    String warehouseId = 'MAIN',
  }) async {
    final batch = _db.batch();
    
    // 1. توليد رقم مرتجع (SRT-000001)
    final String returnNumber = await _counterService.getNextInvoiceNumber('SRT');
    final returnRef = _db.collection('sale_returns').doc();

    // 2. تسجيل المرتجع
    batch.set(returnRef, {
      'returnNumber': returnNumber,
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'customerId': customerId,
      'items': returnedItems,
      'refundAmount': refundAmount,
      'addToStock': addToStock,
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
        // يمكننا إضافة حقل خاص في المنتج أو تسجيلها في جدول التوالف فقط
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

    // 4. التأثير المالي (تعديل مديونية العميل)
    if (customerId != null) {
      final customerRef = _db.collection('customers').doc(customerId);
      // خصم قيمة المرتجع من مديونية العميل
      batch.update(customerRef, {'balance': FieldValue.increment(-refundAmount)});
    }

    // 5. تعديل حالة الفاتورة الأصلية (اختياري: وسمها كمرتجعة جزئياً)
    final originalRef = _db.collection('sales').doc(originalInvoiceId);
    batch.update(originalRef, {'status': 'PARTIALLY_RETURNED'});

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

    // 3. تعديل حساب المورد (خصم المديونية التي لنا عنده أو تقليل ما علينا له)
    if (supplierId != null) {
      final supplierRef = _db.collection('suppliers').doc(supplierId);
      batch.update(supplierRef, {'balance': FieldValue.increment(-refundAmount)});
    }

    await batch.commit();
    return returnNumber;
  }
}
