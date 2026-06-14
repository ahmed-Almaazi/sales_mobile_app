import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// تسجيل عملية مالية في الصندوق
  Future<void> recordCashTransaction({
    required double amount,
    required String type, // 'IN' (مقبوضات) or 'OUT' (مدفوعات)
    required String description,
    required String reference,
    String category = 'GENERAL',
    WriteBatch? batch,
  }) async {
    final cashRef = _db.collection('cash_transactions').doc();
    final double adjustment = type == 'IN' ? amount : -amount;
    final cashboxRef = _db.collection('counters').doc('cashbox');

    if (batch != null) {
      batch.set(cashRef, {
        'amount': amount,
        'type': type,
        'description': description,
        'reference': reference,
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
      });
      batch.set(cashboxRef, {'balance': FieldValue.increment(adjustment)}, SetOptions(merge: true));
    } else {
      final newBatch = _db.batch();
      newBatch.set(cashRef, {
        'amount': amount,
        'type': type,
        'description': description,
        'reference': reference,
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
      });
      newBatch.set(cashboxRef, {'balance': FieldValue.increment(adjustment)}, SetOptions(merge: true));
      await newBatch.commit();
    }
  }

  /// تسجيل مصروف (شحن، مواصلات، عمال، نثريات، إلخ) وعكسه على رأس المال والصندوق
  Future<void> recordExpense({
    required double amount,
    required String category, // 'SHIPPING', 'TRANSPORT', 'WORKERS', 'MAINTENANCE', 'SUNDRIES', 'OTHER'
    required String notes,
  }) async {
    final batch = _db.batch();
    
    // 1. تسجيل العملية في الصندوق
    final cashRef = _db.collection('cash_transactions').doc();
    batch.set(cashRef, {
      'amount': amount,
      'type': 'OUT',
      'description': 'مصروف: $notes',
      'reference': 'EXPENSE',
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. خصم من الصندوق
    final cashboxRef = _db.collection('counters').doc('cashbox');
    batch.set(cashboxRef, {'balance': FieldValue.increment(-amount)}, SetOptions(merge: true));

    // 3. خصم من رأس المال
    final capitalRef = _db.collection('counters').doc('capital');
    batch.set(capitalRef, {'balance': FieldValue.increment(-amount)}, SetOptions(merge: true));

    await batch.commit();
  }

  /// تسجيل دفعة سداد من عميل (خارج الفاتورة)
  Future<void> recordCustomerPayment({
    required String customerId,
    required String customerName,
    required double amount,
    required String notes,
  }) async {
    final batch = _db.batch();
    
    // 1. تسجيل العملية في الصندوق
    final cashRef = _db.collection('cash_transactions').doc();
    batch.set(cashRef, {
      'amount': amount,
      'type': 'IN',
      'description': 'سداد دفعة من العميل $customerName',
      'reference': customerId,
      'category': 'CUSTOMER_PAYMENT',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. خصم المبلغ من مديونية العميل العامة
    final customerRef = _db.collection('customers').doc(customerId);
    batch.update(customerRef, {'balance': FieldValue.increment(-amount)});

    // 3. خصم المبلغ من الفواتير المتبقية بالتوالي (FIFO)
    final salesQuery = await _db.collection('sales')
        .where('customerId', isEqualTo: customerId)
        .get();

    // تصفية وفرز الفواتير محلياً لتجنب الحاجة لفهرس مركب (Composite Index)
    final docs = salesQuery.docs.where((doc) {
      final data = doc.data();
      return data['status'] == 'COMPLETED';
    }).toList();

    docs.sort((a, b) {
      final aTime = a.data()['createdAt'] as Timestamp?;
      final bTime = b.data()['createdAt'] as Timestamp?;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });

    double remainingPayment = amount;
    for (var doc in docs) {
      if (remainingPayment <= 0) break;
      final data = doc.data();
      final double totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
      final double paidAmount = (data['paidAmount'] ?? 0.0).toDouble();
      final double invoiceRemaining = totalAmount - paidAmount;

      if (invoiceRemaining > 0) {
        if (remainingPayment >= invoiceRemaining) {
          // سداد الفاتورة بالكامل
          batch.update(doc.reference, {
            'paidAmount': totalAmount,
            'remainingAmount': 0.0,
          });
          remainingPayment -= invoiceRemaining;
          
          // تحديث التذكيرات المرتبطة بهذه الفاتورة إلى مكتملة (COMPLETED)
          final reminderQuery = await _db.collection('reminders')
              .where('invoiceNumber', isEqualTo: data['invoiceNumber'])
              .where('status', isEqualTo: 'PENDING')
              .get();
          for (var remDoc in reminderQuery.docs) {
            batch.update(remDoc.reference, {'status': 'COMPLETED'});
          }
        } else {
          // سداد جزء من الفاتورة
          batch.update(doc.reference, {
            'paidAmount': paidAmount + remainingPayment,
            'remainingAmount': invoiceRemaining - remainingPayment,
          });
          remainingPayment = 0;
        }
      }
    }

    // 4. تحديث الصندوق المجمع
    final cashboxRef = _db.collection('counters').doc('cashbox');
    batch.set(cashboxRef, {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));

    await batch.commit();
  }

  /// تسجيل دفعة سداد لمورد
  Future<void> recordSupplierPayment({
    required String supplierId,
    required String supplierName,
    required double amount,
    required String notes,
  }) async {
    final batch = _db.batch();
    
    // 1. تسجيل العملية في الصندوق (صادر)
    final cashRef = _db.collection('cash_transactions').doc();
    batch.set(cashRef, {
      'amount': amount,
      'type': 'OUT',
      'description': 'سداد دفعة للمورد $supplierName',
      'reference': supplierId,
      'category': 'SUPPLIER_PAYMENT',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. خصم المبلغ من مديونية المورد (ما علينا له)
    final supplierRef = _db.collection('suppliers').doc(supplierId);
    batch.update(supplierRef, {'balance': FieldValue.increment(-amount)});

    // 3. تحديث الصندوق المجمع
    final cashboxRef = _db.collection('counters').doc('cashbox');
    batch.set(cashboxRef, {'balance': FieldValue.increment(-amount)}, SetOptions(merge: true));

    await batch.commit();
  }

  /// الحصول على رصيد الصندوق الحالي
  Future<double> getCurrentCashBalance() async {
    final doc = await _db.collection('counters').doc('cashbox').get();
    if (doc.exists) {
      return (doc.data()?['balance'] ?? 0.0).toDouble();
    }
    return 0.0;
  }

  /// الحصول على رصيد رأس المال الحالي
  Future<double> getCurrentCapitalBalance() async {
    final doc = await _db.collection('counters').doc('capital').get();
    if (doc.exists) {
      return (doc.data()?['balance'] ?? 0.0).toDouble();
    }
    return 0.0;
  }

  /// تعديل رأس المال مباشرة
  Future<void> updateCapital(double newBalance) async {
    await _db.collection('counters').doc('capital').set({'balance': newBalance}, SetOptions(merge: true));
  }
}

