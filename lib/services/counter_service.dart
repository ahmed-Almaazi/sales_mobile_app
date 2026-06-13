import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CounterService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getNextInvoiceNumber(String prefix) async {
    // توليد الرقم محلياً فوراً لضمان عدم تعليق عمليات البيع والشراء وسرعة الاستجابة المطلقة
    final String userSuffix = _getUserSuffix();
    final String timestamp = DateFormat('yyMMdd-HHmmss').format(DateTime.now());
    return '$prefix-$userSuffix-$timestamp';
  }

  String _getUserSuffix() {
    final user = _auth.currentUser;
    if (user != null && user.uid.length >= 4) {
      // استخدام أول 4 أحرف من معرف المستخدم لضمان عدم التكرار بين الشركاء
      return user.uid.substring(0, 4).toUpperCase();
    }
    return 'OFFL';
  }
}
