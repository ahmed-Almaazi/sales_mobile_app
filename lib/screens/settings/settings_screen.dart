import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_settings.dart';
import 'printer_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _currencyController;
  late TextEditingController _storeNameController;
  late TextEditingController _storePhoneController;
  late TextEditingController _storeAddressController;
  late TextEditingController _userNameController;

  bool _isLoading = false;
  bool _biometricEnabled = false;
  bool _biometricSupported = false;
  bool _biometricToggleLoading = false;

  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _currencyController = TextEditingController(text: AppSettings.currency);
    _storeNameController = TextEditingController(text: AppSettings.storeName);
    _storePhoneController = TextEditingController(text: AppSettings.storePhone);
    _storeAddressController = TextEditingController(text: AppSettings.storeAddress);
    _userNameController = TextEditingController(text: AppSettings.userName);
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_enabled') ?? false;
      final hasSavedCredentials = (prefs.getString('saved_email') ?? '').isNotEmpty &&
          (prefs.getString('saved_password') ?? '').isNotEmpty;

      if (mounted) {
        setState(() {
          _biometricSupported = canCheck && isSupported;
          _biometricEnabled = enabled && hasSavedCredentials;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (_biometricToggleLoading) return;

    if (enable) {
      // ── تفعيل البصمة ──
      // 1. التحقق من وجود بيانات الدخول المحفوظة
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';

      if (savedEmail.isEmpty || savedPassword.isEmpty) {
        _showError('يجب تسجيل الدخول مرة واحدة بالإيميل وكلمة المرور أولاً لتفعيل البصمة');
        return;
      }

      // 2. طلب التحقق بالبصمة للتأكيد
      setState(() => _biometricToggleLoading = true);
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'ضع إصبعك على مستشعر البصمة لتفعيل ميزة الدخول بالبصمة',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (authenticated) {
          await prefs.setBool('biometric_enabled', true);
          setState(() => _biometricEnabled = true);
          _showSuccess('✅ تم تفعيل تسجيل الدخول بالبصمة بنجاح!');
        } else {
          _showError('لم يتم التحقق من البصمة. يرجى المحاولة مجدداً');
        }
      } catch (e) {
        _showError(_friendlyBiometricError(e.toString()));
      } finally {
        if (mounted) setState(() => _biometricToggleLoading = false);
      }
    } else {
      // ── إيقاف البصمة ──
      setState(() => _biometricToggleLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', false);
        setState(() => _biometricEnabled = false);
        _showSuccess('تم إيقاف تسجيل الدخول بالبصمة');
      } finally {
        if (mounted) setState(() => _biometricToggleLoading = false);
      }
    }
  }

  String _friendlyBiometricError(String error) {
    if (error.contains('NotAvailable') || error.contains('not_available')) {
      return 'البصمة غير مفعّلة على هذا الجهاز. يرجى إعدادها من إعدادات الهاتف أولاً';
    } else if (error.contains('NotEnrolled') || error.contains('no_fingerprints')) {
      return 'لا توجد بصمة مسجلة على الجهاز. يرجى إضافة بصمة من إعدادات الهاتف';
    } else if (error.contains('LockedOut') || error.contains('locked_out')) {
      return 'تم قفل البصمة بسبب محاولات خاطئة. يرجى الانتظار';
    } else if (error.contains('UserCancel') || error.contains('user_cancel')) {
      return 'تم الإلغاء من قِبل المستخدم';
    }
    return 'فشل التحقق بالبصمة. تأكد من إعداد البصمة على الجهاز';
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
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
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await AppSettings.saveSettings(
        name: _userNameController.text.trim(),
        newStoreName: _storeNameController.text.trim(),
        newStorePhone: _storePhoneController.text.trim(),
        newStoreAddress: _storeAddressController.text.trim(),
        newCurrency: _currencyController.text.trim(),
      );
      if (mounted) _showSuccess('تم حفظ الإعدادات بنجاح');
    } catch (e) {
      if (mounted) _showError('خطأ في حفظ الإعدادات: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _storeNameController.dispose();
    _storePhoneController.dispose();
    _storeAddressController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('الإعدادات العامة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ══════════════════════════════════
                  // قسم البصمة
                  // ══════════════════════════════════
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _biometricEnabled
                            ? const Color(0xFF1E3A8A).withOpacity(0.3)
                            : const Color(0xFFF1F5F9),
                        width: _biometricEnabled ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _biometricEnabled
                                    ? const Color(0xFF1E3A8A).withOpacity(0.1)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.fingerprint_rounded,
                                color: _biometricEnabled
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFF94A3B8),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'تسجيل الدخول بالبصمة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _biometricEnabled
                                        ? 'مُفعَّل ✅ — الدخول بالبصمة عند كل فتح'
                                        : !_biometricSupported
                                            ? 'غير مدعوم على هذا الجهاز'
                                            : 'غير مُفعَّل — سجّل الدخول مرة أولى بكلمة المرور',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _biometricEnabled
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_biometricToggleLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A8A)),
                              )
                            else
                              Switch(
                                value: _biometricEnabled,
                                onChanged: _biometricSupported ? _toggleBiometric : null,
                                activeColor: const Color(0xFF1E3A8A),
                                activeTrackColor: const Color(0xFF1E3A8A).withOpacity(0.3),
                              ),
                          ],
                        ),

                        // تعليمات إذا لم تكن البصمة مفعلة
                        if (!_biometricEnabled && _biometricSupported) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'لتفعيل البصمة:\n1. سجّل الدخول مرة واحدة بالإيميل وكلمة المرور\n2. ثم عُد لهنا وشغّل المفتاح\n3. ضع إصبعك للتأكيد',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // زر إعادة التحقق إذا كانت البصمة مفعلة
                        if (_biometricEnabled) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => _toggleBiometric(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.no_encryption_outlined, color: Color(0xFFDC2626), size: 16),
                                  SizedBox(width: 8),
                                  Text('إيقاف الدخول بالبصمة', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════
                  // إعدادات الطابعة
                  // ══════════════════════════════════
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 15)],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.print_rounded, color: Color(0xFFD97706)),
                      ),
                      title: const Text('إعدادات طابعة البلوتوث',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14)),
                      subtitle: const Text('الاتصال بالطابعة وإعدادات الورق',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      trailing: const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8)),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════
                  // إعدادات النظام
                  // ══════════════════════════════════
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 15)],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إعدادات النظام والعملة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        _buildInputField(_currencyController, 'عملة النظام الافتراضية', Icons.payments_outlined),
                        _buildInputField(_storeNameController, 'اسم المتجر الافتراضي', Icons.store_outlined),
                        _buildInputField(_storePhoneController, 'رقم هاتف الفواتير', Icons.phone_outlined, isNumber: true),
                        _buildInputField(_storeAddressController, 'عنوان المتجر للفواتير', Icons.location_on_outlined),
                        _buildInputField(_userNameController, 'اسم مدير النظام', Icons.person_outline_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('حفظ الإعدادات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
