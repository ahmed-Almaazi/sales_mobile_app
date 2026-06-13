import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

class CustomerService {
  final CollectionReference _customers = FirebaseFirestore.instance.collection('customers');

  // إضافة عميل جديد
  Future<void> addCustomer(Customer customer) async {
    await _customers.add(customer.toMap());
  }

  // تحديث بيانات عميل
  Future<void> updateCustomer(Customer customer) async {
    await _customers.doc(customer.id).update(customer.toMap());
  }

  // الحصول على قائمة العملاء
  Stream<List<Customer>> getCustomers() {
    return _customers.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // البحث عن عميل بالاسم أو الهاتف
  Future<List<Customer>> searchCustomers(String query) async {
    final snapshot = await _customers
        .where('storeName', isGreaterThanOrEqualTo: query)
        .where('storeName', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    
    return snapshot.docs.map((doc) {
      return Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }
}
