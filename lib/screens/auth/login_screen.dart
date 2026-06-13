import 'package:flutter/material.dart';
import 'dart:async';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _hasSavedEmail = false;
  String _savedEmail = '';

  late AnimationController _fadeController;
  late AnimationController _fingerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _fingerPulse;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fingerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fingerPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fingerController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _loadSavedData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _fingerController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email') ?? '';
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _savedEmail = savedEmail;
          _hasSavedEmail = savedEmail.isNotEmpty;
          _biometricAvailable = canCheck && isSupported && biometricEnabled && savedEmail.isNotEmpty;
          if (savedEmail.isNotEmpty) {
            _emailController.text = savedEmail;
          }
        });

        // تشغيل البصمة تلقائياً بعد ثانية واحدة من فتح التطبيق
        if (_biometricAvailable) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) _authenticateWithBiometric();
        }
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isBiometricLoading || _isLoading) return;
    setState(() => _isBiometricLoading = true);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'ضع إصبعك على مستشعر البصمة للدخول',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('saved_email') ?? '';
        final password = prefs.getString('saved_password') ?? '';

        if (email.isNotEmpty && password.isNotEmpty) {
          setState(() => _isLoading = true);
          await _authService.loginWithEmail(email, password).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(_friendlyError(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBiometricLoading = false;
        });
      }
    }
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني');
      return;
    }
    if (password.isEmpty) {
      _showError('يرجى إدخال كلمة المرور');
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('صيغة البريد الإلكتروني غير صحيحة');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.loginWithEmail(email, password).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال. تحقق من الإنترنت.'),
      );

      // حفظ بيانات الدخول لاستخدامها مع البصمة لاحقاً
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
        final canCheck = await _localAuth.canCheckBiometrics;
        if (canCheck) {
          await prefs.setBool('biometric_enabled', true);
        }
      }
    } catch (e) {
      if (mounted) _showError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String error) {
    if (error.contains('invalid-email') || error.contains('badly formatted')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    } else if (error.contains('user-not-found')) {
      return 'لا يوجد حساب بهذا البريد الإلكتروني';
    } else if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'كلمة المرور غير صحيحة';
    } else if (error.contains('too-many-requests')) {
      return 'محاولات كثيرة. يرجى الانتظار قليلاً';
    } else if (error.contains('network') || error.contains('Timeout') || error.contains('timeout')) {
      return 'مشكلة في الاتصال. تحقق من الإنترنت';
    } else if (error.contains('user-disabled')) {
      return 'تم تعطيل هذا الحساب';
    } else if (error.contains('NotAvailable') || error.contains('biometric')) {
      return 'البصمة غير متاحة. يرجى إدخال كلمة المرور';
    }
    return 'حدث خطأ. يرجى المحاولة مجدداً';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 60),

              // App Logo
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 30, spreadRadius: 5),
                  ],
                ),
                child: const Icon(Icons.shopping_cart_checkout_rounded, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 14),
              const Text(
                'نظام المبيعات الذكي',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'مرحباً بك مجدداً 👋',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),

              // Form Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Biometric Section (إذا كان هناك إيميل محفوظ + البصمة مفعلة) ──
                        if (_biometricAvailable) ...[
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'تسجيل الدخول بالبصمة',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _savedEmail,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 24),

                                // Fingerprint Button
                                ScaleTransition(
                                  scale: _fingerPulse,
                                  child: GestureDetector(
                                    onTap: _isBiometricLoading || _isLoading
                                        ? null
                                        : _authenticateWithBiometric,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF1E3A8A).withOpacity(0.4),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: _isBiometricLoading
                                          ? const Center(
                                              child: SizedBox(
                                                width: 40,
                                                height: 40,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.fingerprint_rounded,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'اضغط على البصمة للدخول',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 28),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'أو أدخل كلمة المرور',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ] else ...[
                          // ── Header بدون بصمة ──
                          const Text(
                            'تسجيل الدخول',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'أدخل بيانات حسابك للمتابعة',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Email Field ──
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                            // زر مسح الإيميل لتغييره
                            suffixIcon: _hasSavedEmail
                                ? IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
                                    tooltip: 'تغيير الحساب',
                                    onPressed: () async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.remove('saved_email');
                                      await prefs.remove('saved_password');
                                      await prefs.setBool('biometric_enabled', false);
                                      setState(() {
                                        _emailController.clear();
                                        _hasSavedEmail = false;
                                        _biometricAvailable = false;
                                        _savedEmail = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Password Field ──
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF64748B),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Login Button ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                              shadowColor: const Color(0xFF0F172A).withOpacity(0.4),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'تسجيل الدخول',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Register Link ──
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            ),
                            child: RichText(
                              text: const TextSpan(
                                text: 'ليس لديك حساب؟ ',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontFamily: 'Cairo'),
                                children: [
                                  TextSpan(
                                    text: 'سجل الآن',
                                    style: TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
