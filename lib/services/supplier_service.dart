import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';

class SupplierService {
  final CollectionReference _suppliers = FirebaseFirestore.instance.collection('suppliers');

  // إضافة مورد جديد
  Future<void> addSupplier(Supplier supplier) async {
    await _suppliers.add(supplier.toMap());
  }

  // تحديث مورد
  Future<void> updateSupplier(Supplier supplier) async {
    await _suppliers.doc(supplier.id).update(supplier.toMap());
  }

  // قائمة الموردين
  Stream<List<Supplier>> getSuppliers() {
    return _suppliers.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }
}
