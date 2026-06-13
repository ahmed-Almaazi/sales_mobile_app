import 'package:cloud_firestore/cloud_firestore.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// يسجل حركة المخزون ويحدث الرصيد الفعلي للمنتج
  Future<void> recordMovement({
    required String productId,
    required int quantity,
    required String type, // 'IN' (وارد) or 'OUT' (صادر)
    required String reference, // رقم الفاتورة أو المستند
    required String notes,
  }) async {
    final batch = _db.batch();
    final productRef = _db.collection('products').doc(productId);
    final movementRef = _db.collection('stock_movements').doc();

    // 1. حساب الكمية الجديدة (إذا صادر تكون بالسالب)
    final int adjustment = type == 'OUT' ? -quantity : quantity;

    // 2. تحديث كمية المنتج
    batch.update(productRef, {
      'currentStock': FieldValue.increment(adjustment),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. تسجيل الحركة في السجل المركزي
    batch.set(movementRef, {
      'productId': productId,
      'quantity': quantity,
      'type': type,
      'reference': reference,
      'notes': notes,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
