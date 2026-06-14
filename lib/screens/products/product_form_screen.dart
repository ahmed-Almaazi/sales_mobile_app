import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final String? productId;

  const ProductFormScreen({super.key, this.product, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // الأساسيات
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  String? _selectedCategory;
  late TextEditingController _manufacturerController;
  late TextEditingController _modelController;
  late TextEditingController _colorController;
  late TextEditingController _descriptionController;
  
  // الأسعار والكميات
  late TextEditingController _purchasePriceController; // سعر الشراء
  late TextEditingController _retailPriceController; // سعر البيع
  late TextEditingController _currentStockController;
  late TextEditingController _minStockController;

  void _goToAddCategory() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة صنف جديد سريعاً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم الصنف',
                    prefixIcon: const Icon(Icons.category_rounded, size: 20, color: Color(0xFF64748B)),
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
                  validator: (v) => v == null || v.trim().isEmpty ? 'الرجاء إدخال اسم الصنف' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'الوصف (اختياري)',
                    prefixIcon: const Icon(Icons.description_rounded, size: 20, color: Color(0xFF64748B)),
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
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final name = nameController.text.trim();
                Navigator.pop(context); // إغلاق الدايلوج فوراً

                try {
                  await FirebaseFirestore.instance.collection('categories').add({
                    'name': name,
                    'description': descController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    setState(() {
                      _selectedCategory = name;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة الصنف بنجاح')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ أثناء إضافة الصنف: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
  


  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?['name'] ?? '');
    _barcodeController = TextEditingController(text: p?['barcode'] ?? '');
    _selectedCategory = p?['category']?.toString();
    if (_selectedCategory != null && _selectedCategory!.isEmpty) {
      _selectedCategory = null;
    }
    _manufacturerController = TextEditingController(text: p?['manufacturer'] ?? '');
    _modelController = TextEditingController(text: p?['model'] ?? '');
    _colorController = TextEditingController(text: p?['color'] ?? '');
    _descriptionController = TextEditingController(text: p?['description'] ?? '');
    
    _purchasePriceController = TextEditingController(text: p?['purchasePrice']?.toString() ?? '');
    _retailPriceController = TextEditingController(text: p?['retailPrice']?.toString() ?? '');
    _currentStockController = TextEditingController(text: p?['currentStock']?.toString() ?? '');
    _minStockController = TextEditingController(text: p?['minStock']?.toString() ?? '5');
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final productData = {
      'name': _nameController.text.trim(),
      'barcode': _barcodeController.text.trim(),
      'category': _selectedCategory,
      'manufacturer': _manufacturerController.text.trim(),
      'model': _modelController.text.trim(),
      'color': _colorController.text.trim(),
      'description': _descriptionController.text.trim(),
      'purchasePrice': double.tryParse(_purchasePriceController.text) ?? 0.0,
      'wholesalePrice': 0.0,
      'retailPrice': double.tryParse(_retailPriceController.text) ?? 0.0,
      'representativePrice': 0.0,
      'currentStock': int.tryParse(_currentStockController.text) ?? 0,
      'minStock': int.tryParse(_minStockController.text) ?? 5,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // إظهار مؤشر تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (widget.productId == null) {
        await FirebaseFirestore.instance.collection('products').add(productData);
      } else {
        await FirebaseFirestore.instance.collection('products').doc(widget.productId).update(productData);
      }
      
      if (mounted) {
        Navigator.pop(context); // إغلاق مؤشر التحميل
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنتج بنجاح')));
        Navigator.pop(context); // إغلاق شاشة التعديل
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // إغلاق مؤشر التحميل
        debugPrint('خطأ في حفظ المنتج: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ بالسيرفر: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  void _scanBarcode() async {
    final String? barcode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (barcode != null) {
      setState(() {
        _barcodeController.text = barcode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('المعلومات الأساسية', Icons.info_outline_rounded),
                _buildTextField(_nameController, 'اسم المنتج', Icons.shopping_bag_outlined, validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                _buildTextField(_barcodeController, 'الباركود', Icons.qr_code_scanner_rounded, isLast: true, onIconTap: _scanBarcode),
                
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _buildSectionTitle('التفاصيل', Icons.tune_rounded),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
                        builder: (context, snapshot) {
                          List<DropdownMenuItem<String>> items = [];
                          if (snapshot.hasData) {
                            final docs = snapshot.data!.docs;
                            for (var doc in docs) {
                              final name = doc['name'] as String;
                              items.add(DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ));
                            }
                          }

                          if (_selectedCategory != null &&
                              !items.any((item) => item.value == _selectedCategory)) {
                            items.add(DropdownMenuItem(
                              value: _selectedCategory,
                              child: Text(_selectedCategory!),
                            ));
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'التصنيف (الصنف)',
                                labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                prefixIcon: const Icon(Icons.category_rounded, size: 20, color: Color(0xFF64748B)),
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
                              items: items,
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategory = val;
                                });
                              },
                              validator: (v) => v == null || v.isEmpty ? 'الرجاء اختيار صنف' : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton.filled(
                        onPressed: _goToAddCategory,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 24, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                _buildTextField(_manufacturerController, 'الشركة المصنعة', Icons.business_outlined),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_modelController, 'الموديل', Icons.model_training_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_colorController, 'اللون', Icons.palette_outlined)),
                  ],
                ),
                _buildTextField(_descriptionController, 'الوصف', Icons.description_outlined, maxLines: 2),
                
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _buildSectionTitle('الأسعار (بالمحلية)', Icons.payments_outlined),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _purchasePriceController,
                        'سعر الشراء',
                        Icons.shopping_cart_outlined,
                        isNumber: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'مطلوب';
                          final val = double.tryParse(v);
                          if (val == null || val < 0) return 'سعر غير صالح';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        _retailPriceController,
                        'سعر البيع',
                        Icons.sell_outlined,
                        isNumber: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'مطلوب';
                          final val = double.tryParse(v);
                          if (val == null || val < 0) return 'سعر غير صالح';
                          final purchaseVal = double.tryParse(_purchasePriceController.text) ?? 0.0;
                          if (val < purchaseVal) {
                            return 'لا يمكن أن يقل عن الشراء';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _buildSectionTitle('المخزون', Icons.inventory_2_outlined),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_currentStockController, 'الكمية الحالية', Icons.numbers_rounded, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_minStockController, 'حد التنبيه', Icons.warning_amber_rounded, isNumber: true)),
                  ],
                ),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saveProduct,
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      widget.productId == null ? 'إضافة المنتج' : 'تحديث البيانات',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F172A), size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool isNumber = false, 
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isLast = false,
    VoidCallback? onIconTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon: onIconTap != null
              ? IconButton(
                  icon: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
                  onPressed: onIconTap,
                )
              : Icon(icon, size: 20, color: const Color(0xFF64748B)),
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

