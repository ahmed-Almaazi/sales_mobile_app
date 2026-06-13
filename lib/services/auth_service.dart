import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream to track auth state
  Stream<User?> get user {
    return _auth.authStateChanges();
  }

  // الحصول على بيانات المستخدم الحالي (بما في ذلك الدور)
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data();
    }
    return null;
  }

  // تسجيل حساب جديد مع تعيين دور افتراضي
  Future<UserCredential?> registerWithEmail(String email, String password, {String role = 'SALES'}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // إنشاء مستند للمستخدم في Firestore
      await _db.collection('users').doc(result.user!.uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result;
    } catch (e) {
      debugPrint('Registration Error: $e');
      rethrow;
    }
  }

  // Login with email and password
  Future<UserCredential?> loginWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Login Error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

