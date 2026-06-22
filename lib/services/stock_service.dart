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

  /// تحويل كمية من مستودع لآخر — يُسجّل حركتين (OUT + IN) في batch واحد
  Future<void> transferStock({
    required String productId,
    required String productName,
    required int quantity,
    required String fromWarehouse, // 'MAIN' أو 'CAR'
    required String toWarehouse,   // 'MAIN' أو 'CAR'
    String notes = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('الكمية يجب أن تكون أكبر من صفر');
    }
    if (fromWarehouse == toWarehouse) {
      throw ArgumentError('لا يمكن التحويل من المستودع لنفسه');
    }

    final batch = _db.batch();
    final reference = 'TRF-${DateTime.now().millisecondsSinceEpoch}';

    // ── 1. تسجيل حركة الخروج من المستودع المصدر ─────────────────────
    final outRef = _db.collection('stock_movements').doc();
    batch.set(outRef, {
      'productId':    productId,
      'productName':  productName,
      'quantity':     quantity,
      'type':         'OUT',
      'warehouse':    fromWarehouse,
      'reference':    reference,
      'notes':        notes.isEmpty ? 'تحويل إلى ${_warehouseName(toWarehouse)}' : notes,
      'timestamp':    FieldValue.serverTimestamp(),
    });

    // ── 2. تسجيل حركة الدخول للمستودع الهدف ─────────────────────────
    final inRef = _db.collection('stock_movements').doc();
    batch.set(inRef, {
      'productId':    productId,
      'productName':  productName,
      'quantity':     quantity,
      'type':         'IN',
      'warehouse':    toWarehouse,
      'reference':    reference,
      'notes':        notes.isEmpty ? 'تحويل من ${_warehouseName(fromWarehouse)}' : notes,
      'timestamp':    FieldValue.serverTimestamp(),
    });

    // ── 3. لا نغير currentStock الكلي — فقط نغير توزيع المستودعات ─────
    // تحديث حقل المخزون الخاص بكل مستودع إن كان موجوداً
    final productRef = _db.collection('products').doc(productId);
    batch.update(productRef, {
      'warehouseStock.$fromWarehouse': FieldValue.increment(-quantity),
      'warehouseStock.$toWarehouse':   FieldValue.increment(quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ── 4. تسجيل سجل التحويل في collection منفصلة ───────────────────
    final transferRef = _db.collection('stock_transfers').doc();
    batch.set(transferRef, {
      'productId':     productId,
      'productName':   productName,
      'quantity':      quantity,
      'fromWarehouse': fromWarehouse,
      'toWarehouse':   toWarehouse,
      'reference':     reference,
      'notes':         notes,
      'timestamp':     FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// اسم المستودع بالعربية
  String _warehouseName(String id) {
    return id == 'MAIN' ? 'المخزن الرئيسي' : 'السيارة';
  }
}

