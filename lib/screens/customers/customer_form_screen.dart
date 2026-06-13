import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerService = CustomerService();
  
  late TextEditingController _storeNameController;
  late TextEditingController _contactNameController;
  late TextEditingController _phoneController;
  late TextEditingController _regionController;
  late TextEditingController _creditLimitController;
  late TextEditingController _notesController;
  


  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _storeNameController = TextEditingController(text: c?.storeName ?? '');
    _contactNameController = TextEditingController(text: c?.contactName ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _regionController = TextEditingController(text: c?.region ?? '');
    _creditLimitController = TextEditingController(text: c?.creditLimit.toString() ?? '0.0');
    _notesController = TextEditingController(text: c?.notes ?? '');
  }

  void _saveCustomer() {
    if (!_formKey.currentState!.validate()) return;

    final customer = Customer(
      id: widget.customer?.id ?? '',
      storeName: _storeNameController.text.trim(),
      contactName: _contactNameController.text.trim(),
      phone: _phoneController.text.trim(),
      region: _regionController.text.trim(),
      creditLimit: double.tryParse(_creditLimitController.text) ?? 0.0,
      balance: widget.customer?.balance ?? 0.0,
      notes: _notesController.text.trim(),
    );

    if (widget.customer == null) {
      _customerService.addCustomer(customer).catchError((e) {
        debugPrint('خطأ في مزامنة إضافة العميل: $e');
      });
    } else {
      _customerService.updateCustomer(customer).catchError((e) {
        debugPrint('خطأ في مزامنة تعديل العميل: $e');
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات العميل')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.customer == null ? 'إضافة عميل جديد' : 'تعديل بيانات العميل',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(_storeNameController, 'اسم المحل / النشاط', Icons.store_outlined, validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                _buildTextField(_contactNameController, 'اسم المسؤول', Icons.person_outline_rounded),
                _buildTextField(_phoneController, 'رقم الهاتف', Icons.phone_outlined, isNumber: true),
                _buildTextField(_regionController, 'المنطقة / العنوان', Icons.location_on_outlined),
                _buildTextField(_creditLimitController, 'السقف الائتماني', Icons.credit_card_outlined, isNumber: true),
                _buildTextField(_notesController, 'ملاحظات', Icons.note_outlined, maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saveCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('حفظ العميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }
}
