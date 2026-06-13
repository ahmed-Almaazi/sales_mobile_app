import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppSettings {
  static String currency = "ر.ي";
  static String storeName = "نظام الموزع الذكي";
  static String storePhone = "";
  static String storeAddress = "";
  static String userName = "مدير النظام";

  static Future<void> loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            currency = data['currency'] ?? "ر.ي";
            storeName = data['storeName'] ?? "نظام الموزع الذكي";
            storePhone = data['storePhone'] ?? "";
            storeAddress = data['storeAddress'] ?? "";
            userName = data['name'] ?? "مدير النظام";
          }
        }
      }
    } catch (e) {
      // Keep defaults in case of error or offline
    }
  }

  static Future<void> saveSettings({
    required String name,
    required String newStoreName,
    required String newStorePhone,
    required String newStoreAddress,
    required String newCurrency,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'storeName': newStoreName,
        'storePhone': newStorePhone,
        'storeAddress': newStoreAddress,
        'currency': newCurrency,
      }, SetOptions(merge: true));
      
      userName = name;
      storeName = newStoreName;
      storePhone = newStorePhone;
      storeAddress = newStoreAddress;
      currency = newCurrency;
    }
  }
}
