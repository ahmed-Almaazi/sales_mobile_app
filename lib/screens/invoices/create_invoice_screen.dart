import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/sale_service.dart';
import '../../models/customer.dart';
import '../shared/scanner_screen.dart';
import '../../utils/app_settings.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _customerNameController = TextEditingController();
  final _paidAmountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _selectedProducts = [];
  bool _isLoading = false;
  final SaleService _saleService = SaleService();
  
  Customer? _selectedCustomer;
  String _selectedWarehouse = 'MAIN';

  @override
  void initState() {
    super.initState();
    _paidAmountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _scanBarcode() async {
    final String? barcode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (barcode != null) {
      setState(() => _isLoading = true);
      try {
        final query = await FirebaseFirestore.instance
            .collection('products')
            .where('barcode', isEqualTo: barcode)
            .limit(1)
            .get()
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.'),
            );

        if (!mounted) return;

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final data = doc.data();
          _addProductToInvoice(doc.id, data);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنتج غير موجود')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في البحث: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _addProductToInvoice(String id, Map<String, dynamic> data) {
    setState(() {
      var existing = _selectedProducts.where((p) => p['productId'] == id).toList();
      if (existing.isEmpty) {
        _selectedProducts.add({
          'productId': id,
          'name': data['name'],
          'price': data['retailPrice'] ?? 0,
          'purchasePrice': data['purchasePrice'] ?? 0,
          'quantity': 1,
          'maxStock': data['currentStock'] ?? 0
        });
      } else {
        if (existing[0]['quantity'] < existing[0]['maxStock']) {
          existing[0]['quantity']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مخزون كافٍ')));
        }
      }
    });
  }

  void _showCustomerSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Text('اختر العميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('لا يوجد عملاء مضافين'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: ListTile(
                            title: Text(data['storeName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            subtitle: Text(data['phone'] ?? '', style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () {
                              setState(() {
                                _selectedCustomer = Customer.fromMap(data, doc.id);
                                _customerNameController.text = _selectedCustomer!.storeName;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text('اختر المنتج للإضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('products').where('currentStock', isGreaterThan: 0).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const Center(child: Text('لا توجد منتجات متوفرة بالمخزن'));
                        return ListView.builder(
                          controller: controller,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var doc = docs[index];
                            var data = doc.data() as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: ListTile(
                                title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                subtitle: Text('السعر: ${data['retailPrice']} | المخزون: ${data['currentStock']}', style: const TextStyle(fontSize: 11)),
                                trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A)),
                                onTap: () {
                                  _addProductToInvoice(doc.id, data);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double get _totalAmount => _selectedProducts.fold(0.0, (total, item) => total + (item['price'] * item['quantity']));

  double get _paidAmount {
    return double.tryParse(_paidAmountController.text) ?? 0;
  }

  double get _remainingAmount {
    double remaining = _totalAmount - _paidAmount;
    return remaining > 0 ? remaining : 0;
  }

  void _saveInvoice() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إضافة منتجات للفاتورة')));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      double paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
      
      // 1. توليد رقم الفاتورة محلياً فوراً لعرضه أو استخدامه
      final invoiceNumber = await _saleService.generateInvoiceNumber('SAL');

      // 2. بدء عملية الحفظ في الخلفية
      final saveFuture = _saleService.createSaleInvoice(
        invoiceNumber: invoiceNumber,
        customerId: _selectedCustomer?.id,
        customerName: _customerNameController.text.trim().isEmpty ? 'عميل نقدي' : _customerNameController.text.trim(),
        items: _selectedProducts,
        totalAmount: _totalAmount,
        paidAmount: paidAmount,
        warehouseId: _selectedWarehouse,
        invoiceDate: _selectedDate,
      );

      // 3. الانتظار لمدة أقصاها ثانيتين للتأكيد من الخادم
      bool completed = true;
      try {
        await saveFuture.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        completed = false;
      }

      if (mounted) {
        if (completed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إصدار الفاتورة بنجاح: $invoiceNumber')),
          );
        } else {
          // في حال تأخر الرد، نبلغ المستخدم بأنه تم الحفظ محلياً وسيتم المزامنة تلقائياً
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الفاتورة محلياً وسيتم مزامنتها فور توفر الإنترنت: $invoiceNumber'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ الفاتورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('فاتورة مبيعات جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'اسم العميل',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                      suffixIcon: IconButton(icon: const Icon(Icons.search_rounded, color: Color(0xFF0F172A)), onPressed: _showCustomerSelection),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _paidAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'المبلغ المدفوع',
                            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            prefixIcon: const Icon(Icons.payment_rounded, color: Color(0xFF64748B)),
                            suffixIcon: TextButton(
                              onPressed: () {
                                _paidAmountController.text = _totalAmount.toStringAsFixed(1);
                                setState(() {});
                              },
                              child: const Text('دفع كامل', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedWarehouse,
                          decoration: InputDecoration(
                            labelText: 'المخزن',
                            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'MAIN', child: Text('المخزن الرئيسي')),
                            DropdownMenuItem(value: 'CAR', child: Text('السيارة')),
                          ],
                          onChanged: (v) => setState(() => _selectedWarehouse = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ الفاتورة',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: Text(
                        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedProducts.isEmpty
                ? const Center(
                    child: Text('لم يتم إضافة أي منتجات بعد', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  )
                : ListView.builder(
                    itemCount: _selectedProducts.length,
                    itemBuilder: (context, index) {
                      var item = _selectedProducts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A)),
                          ),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${(item['price'] as num).toStringAsFixed(1)} ${AppSettings.currency} × ${item['quantity']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B)),
                                onPressed: () {
                                  setState(() {
                                    if (item['quantity'] > 1) {
                                      item['quantity']--;
                                    } else {
                                      _selectedProducts.removeAt(index);
                                    }
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A)),
                                onPressed: () {
                                  if (item['quantity'] < item['maxStock']) {
                                    setState(() => item['quantity']++);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وصلت للحد الأقصى للمخزون')));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    Text('${_totalAmount.toStringAsFixed(1)} ${AppSettings.currency}', style: const TextStyle(fontSize: 20, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_remainingAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المتبقي (آجل):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                      Text('${_remainingAmount.toStringAsFixed(1)} ${AppSettings.currency}', style: const TextStyle(fontSize: 18, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('إضافة منتج', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('مسح باركود', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('تأكيد وحفظ الفاتورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

