import 'package:cloud_firestore/cloud_firestore.dart';
import 'counter_service.dart';

class PurchaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  /// توليد رقم الفاتورة للواجهة مسبقاً
  Future<String> generateInvoiceNumber(String prefix) => _counterService.getNextInvoiceNumber(prefix);

  /// تسجيل فاتورة مشتريات جديدة
  Future<String> createPurchaseInvoice({
    String? invoiceNumber,
    required String? supplierId,
    required String supplierName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    String warehouseId = 'MAIN',
    DateTime? purchaseDate,
    String? referenceNumber,
  }) async {
    final batch = _db.batch();
    
    // 1. توليد رقم فاتورة احترافي (PUR-000001)
    final String finalInvoiceNumber = invoiceNumber ?? await _counterService.getNextInvoiceNumber('PUR');
    final purchaseRef = _db.collection('purchases').doc();

    // 2. إنشاء فاتورة المشتريات
    batch.set(purchaseRef, {
      'invoiceNumber': finalInvoiceNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'items': items,
      'warehouseId': warehouseId,
      'status': 'COMPLETED',
      'createdAt': purchaseDate != null ? Timestamp.fromDate(purchaseDate) : FieldValue.serverTimestamp(),
      'referenceNumber': referenceNumber ?? '',
    });

    // 3. زيادة المخزون وتحديث سعر الشراء
    for (var item in items) {
      final productRef = _db.collection('products').doc(item['productId']);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(item['quantity']),
        'purchasePrice': item['price'], // تحديث سعر الشراء الأخير
      });
      
      final movementRef = _db.collection('stock_movements').doc();
      batch.set(movementRef, {
        'productId': item['productId'],
        'warehouseId': warehouseId,
        'quantity': item['quantity'],
        'type': 'IN',
        'reference': finalInvoiceNumber,
        'notes': 'توريد من $supplierName',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 4. معالجة الصندوق (تسجيل المبلغ المدفوع كصادر)
    if (paidAmount > 0) {
      final cashRef = _db.collection('cash_transactions').doc();
      batch.set(cashRef, {
        'amount': paidAmount,
        'type': 'OUT',
        'description': 'دفعة لمورد لفاتورة مشتريات $finalInvoiceNumber',
        'reference': finalInvoiceNumber,
        'timestamp': FieldValue.serverTimestamp(),
      });
      final cashboxRef = _db.collection('counters').doc('cashbox');
      batch.set(cashboxRef, {'balance': FieldValue.increment(-paidAmount)}, SetOptions(merge: true));
    }

    // 5. معالجة مديونية المورد
    final double debt = totalAmount - paidAmount;
    if (debt > 0 && supplierId != null) {
      final supplierRef = _db.collection('suppliers').doc(supplierId);
      batch.update(supplierRef, {'balance': FieldValue.increment(debt)});
    }

    // 6. سجل المراقبة (Audit Log)
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'CREATE_PURCHASE',
      'details': 'إنشاء فاتورة مشتريات رقم $finalInvoiceNumber من $supplierName بقيمة $totalAmount',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return finalInvoiceNumber;
  }
}
