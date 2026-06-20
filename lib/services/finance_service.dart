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
    // التحقق من أن رصيد الصندوق كافٍ
    final cashbalance = await getCurrentCashBalance();
    if (cashbalance < amount) {
      throw Exception(
        'رصيد الصندوق غير كافٍ لتسجيل هذا المصروف.\n'
        'الرصيد الحالي: ${cashbalance.toStringAsFixed(1)}\n'
        'المبلغ المطلوب: ${amount.toStringAsFixed(1)}'
      );
    }

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

    // 4. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'RECORD_EXPENSE',
      'details': 'تسجيل مصروف: $notes - المبلغ: $amount - الفئة: $category',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// تسجيل إيراد يدوي (إضافة مبلغ للصندوق ورأس المال)
  Future<void> recordIncome({
    required double amount,
    required String category,
    required String notes,
  }) async {
    final batch = _db.batch();

    final cashRef = _db.collection('cash_transactions').doc();
    batch.set(cashRef, {
      'amount': amount,
      'type': 'IN',
      'description': 'إيراد: $notes',
      'reference': 'INCOME',
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final cashboxRef = _db.collection('counters').doc('cashbox');
    batch.set(cashboxRef, {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));

    final capitalRef = _db.collection('counters').doc('capital');
    batch.set(capitalRef, {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));

    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'RECORD_INCOME',
      'details': 'تسجيل إيراد: $notes - المبلغ: $amount - الفئة: $category',
      'timestamp': FieldValue.serverTimestamp(),
    });

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
      return data['status'] == 'COMPLETED' || data['status'] == 'PARTIALLY_RETURNED';
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

    // 5. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'CUSTOMER_PAYMENT',
      'details': 'استلام دفعة من العميل $customerName بقيمة $amount - $notes',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// تسجيل دفعة سداد لمورد
  Future<void> recordSupplierPayment({
    required String supplierId,
    required String supplierName,
    required double amount,
    required String notes,
  }) async {
    // التحقق من أن رصيد الصندوق كافٍ
    final cashbalance = await getCurrentCashBalance();
    if (cashbalance < amount) {
      throw Exception(
        'رصيد الصندوق غير كافٍ لتسجيل هذا السداد.\n'
        'الرصيد الحالي: ${cashbalance.toStringAsFixed(1)}\n'
        'المبلغ المطلوب: ${amount.toStringAsFixed(1)}'
      );
    }

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

    // 4. سجل المراقبة
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'SUPPLIER_PAYMENT',
      'details': 'سداد دفعة للمورد $supplierName بقيمة $amount - $notes',
      'timestamp': FieldValue.serverTimestamp(),
    });

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

  /// تعديل رأس المال مباشرة مع تسجيل الحدث في سجل المراقبة
  Future<void> updateCapital(double newBalance) async {
    final batch = _db.batch();

    final currentBalance = await getCurrentCapitalBalance();
    final double difference = newBalance - currentBalance;

    // تحديث رأس المال
    final capitalRef = _db.collection('counters').doc('capital');
    batch.set(capitalRef, {'balance': newBalance}, SetOptions(merge: true));

    // سجل المراقبة — إلزامي لأي تعديل على رأس المال
    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'UPDATE_CAPITAL',
      'details': 'تعديل يدوي لرأس المال من $currentBalance إلى $newBalance (الفرق: ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)})',
      'oldBalance': currentBalance,
      'newBalance': newBalance,
      'difference': difference,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// إضافة مبلغ لرأس المال يدوياً (رأس مال مُضاف)
  Future<void> addCapital({
    required double amount,
    required String notes,
  }) async {
    final batch = _db.batch();

    final capitalRef = _db.collection('counters').doc('capital');
    batch.set(capitalRef, {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));

    // تسجيل الإضافة في الصندوق أيضاً كدخل
    final cashRef = _db.collection('cash_transactions').doc();
    batch.set(cashRef, {
      'amount': amount,
      'type': 'IN',
      'description': 'إضافة رأس مال: $notes',
      'reference': 'CAPITAL_ADD',
      'category': 'CAPITAL',
      'timestamp': FieldValue.serverTimestamp(),
    });

    final cashboxRef = _db.collection('counters').doc('cashbox');
    batch.set(cashboxRef, {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));

    final auditRef = _db.collection('audit_logs').doc();
    batch.set(auditRef, {
      'action': 'ADD_CAPITAL',
      'details': 'إضافة رأس مال بقيمة $amount - $notes',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// الحصول على ملخص مالي شامل
  Future<Map<String, double>> getFinancialSummary() async {
    final cashboxDoc = await _db.collection('counters').doc('cashbox').get();
    final capitalDoc = await _db.collection('counters').doc('capital').get();

    double cashBalance = 0.0;
    double capitalBalance = 0.0;

    if (cashboxDoc.exists) {
      cashBalance = (cashboxDoc.data()?['balance'] ?? 0.0).toDouble();
    }
    if (capitalDoc.exists) {
      capitalBalance = (capitalDoc.data()?['balance'] ?? 0.0).toDouble();
    }

    // حساب إجمالي الديون
    double totalCustomerDebt = 0.0;
    final customersSnapshot = await _db.collection('customers').get();
    for (var doc in customersSnapshot.docs) {
      final balance = (doc.data()['balance'] ?? 0.0).toDouble();
      if (balance > 0) totalCustomerDebt += balance;
    }

    double totalSupplierDebt = 0.0;
    final suppliersSnapshot = await _db.collection('suppliers').get();
    for (var doc in suppliersSnapshot.docs) {
      final balance = (doc.data()['balance'] ?? 0.0).toDouble();
      if (balance > 0) totalSupplierDebt += balance;
    }

    return {
      'cashBalance': cashBalance,
      'capitalBalance': capitalBalance,
      'totalCustomerDebt': totalCustomerDebt,
      'totalSupplierDebt': totalSupplierDebt,
      'netPosition': cashBalance + totalCustomerDebt - totalSupplierDebt,
    };
  }
}
