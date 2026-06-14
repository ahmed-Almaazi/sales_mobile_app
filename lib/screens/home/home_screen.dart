import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../products/product_form_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../invoices/create_purchase_screen.dart';
import '../customers/customer_list_screen.dart';
import '../suppliers/supplier_list_screen.dart';
import '../finance/cashbox_screen.dart';
import '../reports/reports_screen.dart';
import '../../services/sale_service.dart';
import '../settings/printer_settings_screen.dart';
import '../categories/category_list_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/app_settings.dart';
import '../../utils/app_colors.dart';
import 'widgets/home_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _saleService = SaleService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  int _selectedIndex = 0;

  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _storeNameController;
  late TextEditingController _storePhoneController;
  late TextEditingController _storeAddressController;
  late TextEditingController _currencyController;
  bool _isSettingsLoaded = false;
  bool _isEditingProfile = false;


  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    await AppSettings.loadSettings();
    _nameController = TextEditingController(text: AppSettings.userName);
    _storeNameController = TextEditingController(text: AppSettings.storeName);
    _storePhoneController = TextEditingController(text: AppSettings.storePhone);
    _storeAddressController = TextEditingController(text: AppSettings.storeAddress);
    _currencyController = TextEditingController(text: AppSettings.currency);
    if (mounted) {
      setState(() {
        _isSettingsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_isSettingsLoaded) {
      _nameController.dispose();
      _storeNameController.dispose();
      _storePhoneController.dispose();
      _storeAddressController.dispose();
      _currencyController.dispose();
    }
    super.dispose();
  }

  void _deleteProduct(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف منتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(id)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف المنتج بنجاح')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: HomeDrawer(onSettingsUpdated: _loadSettings),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text(
          'لوحة التحكم',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          _buildNotificationBell(),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF1E3A8A),
          unselectedItemColor: const Color(0xFF94A3B8),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              label: 'المخزون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'الفواتير',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_pin_rounded),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFAB() {
    if (_selectedIndex == 1) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة منتج'),
      );
    } else if (_selectedIndex == 2) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('فاتورة مبيعات'),
      );
    }
    return null;
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildProductsList();
      case 2:
        return _buildInvoicesList();
      case 3:
        return _buildProfile();
      default:
        return const Center(child: Text('قيد التطوير...'));
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0x1A1E3A8A),
                child: Icon(Icons.person_rounded, color: Color(0xFF1E3A8A), size: 24),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مرحباً بك مجدداً 👋', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  Text('مدير النظام', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('sales').snapshots(),
            builder: (context, invoiceSnapshot) {
              int totalOrders = 0;
              double totalSales = 0;

              if (invoiceSnapshot.hasData) {
                totalOrders = invoiceSnapshot.data!.docs.length;
                for (var doc in invoiceSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  totalSales += (data['totalAmount'] ?? 0).toDouble();
                }
              }

              return Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard(
                        'إجمالي المبيعات',
                        '${totalSales.toStringAsFixed(1)} ${AppSettings.currency}',
                        Icons.trending_up_rounded,
                        const Color(0xFF059669),
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'إجمالي الطلبات',
                        '$totalOrders طلب',
                        Icons.shopping_bag_rounded,
                        const Color(0xFFD97706),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('products').snapshots(),
                    builder: (context, productSnapshot) {
                      int totalProducts = productSnapshot.hasData ? productSnapshot.data!.docs.length : 0;
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                        builder: (context, custSnapshot) {
                          int totalCust = custSnapshot.hasData ? custSnapshot.data!.docs.length : 0;
                          return Row(
                            children: [
                              _buildStatCard(
                                'إجمالي المنتجات',
                                '$totalProducts منتج',
                                Icons.inventory_rounded,
                                const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'إجمالي العملاء',
                                '$totalCust عميل',
                                Icons.people_alt_rounded,
                                const Color(0xFF7C3AED),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    return Column(
      children: [
        // 1. الإحصائيات العلوية للمخزون
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('products').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final docs = snapshot.data!.docs;
            int totalProducts = docs.length;
            int totalStockItems = 0;
            double totalCostValue = 0.0;
            double totalRetailValue = 0.0;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              int currentStock = data['currentStock'] ?? 0;
              double purchasePrice = (data['purchasePrice'] ?? 0.0).toDouble();
              double retailPrice = (data['retailPrice'] ?? 0.0).toDouble();
              totalStockItems += currentStock;
              totalCostValue += currentStock * purchasePrice;
              totalRetailValue += currentStock * retailPrice;
            }
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMiniStat('أصناف المخزن', '$totalProducts صنف', const Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
                      _buildMiniStat('إجمالي القطع', '$totalStockItems قطعة', const Color(0xFF7C3AED)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMiniStat('قيمة الشراء', '${totalCostValue.toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF059669)),
                      const SizedBox(width: 8),
                      _buildMiniStat('قيمة البيع', '${totalRetailValue.toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF0D9488)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        
        // 2. أدوات البحث والفلترة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الباركود...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                  builder: (context, catSnapshot) {
                    List<DropdownMenuItem<String>> items = [
                      const DropdownMenuItem(value: 'ALL', child: Text('كل الأصناف', style: TextStyle(fontSize: 12))),
                    ];
                    if (catSnapshot.hasData) {
                      for (var doc in catSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        items.add(DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['name'] ?? '', style: const TextStyle(fontSize: 12)),
                        ));
                      }
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedCategoryFilter ?? 'ALL',
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                        ),
                      ),
                      items: items,
                      onChanged: (v) => setState(() => _selectedCategoryFilter = v == 'ALL' ? null : v),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // 3. قائمة المنتجات المفلترة
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('خطأ: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                final matchesSearch = name.contains(_searchQuery.toLowerCase()) || barcode.contains(_searchQuery.toLowerCase());
                
                if (_selectedCategoryFilter != null) {
                  final categoryId = data['categoryId'];
                  return matchesSearch && categoryId == _selectedCategoryFilter;
                }
                return matchesSearch;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('لا توجد منتجات مطابقة للبحث.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var doc = filteredDocs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  int currentStock = data['currentStock'] ?? 0;
                  int minStock = data['minStock'] ?? 5;
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    borderOnForeground: false,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: currentStock > minStock ? const Color(0xFFEEF2F6) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: currentStock > minStock ? const Color(0xFF1E3A8A) : const Color(0xFFEF4444),
                          ),
                        ),
                        title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'شراء: ${data['purchasePrice'] ?? 0} ${AppSettings.currency} | بيع: ${data['retailPrice'] ?? 0} ${AppSettings.currency}\nباركود: ${data['barcode'] ?? ""}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: currentStock > minStock ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$currentStock',
                                style: TextStyle(
                                  color: currentStock > minStock ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 20),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductFormScreen(product: data, productId: doc.id),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              onPressed: () => _deleteProduct(doc.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('حدث خطأ أثناء تحميل الفواتير: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد فواتير مبيعات بعد.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            var date = data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now();
            String status = data['status'] ?? 'COMPLETED';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: ListTile(
                  onTap: () => _showInvoiceDetails(doc.id, data),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: status == 'RETURNED' ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      status == 'RETURNED' ? Icons.assignment_return_rounded : Icons.receipt_long_rounded,
                      color: status == 'RETURNED' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                  title: Text(
                    data['invoiceNumber'] ?? 'فاتورة مبيعات',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'العميل: ${data['customerName']} \nالتاريخ: ${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${data['totalAmount']} ${AppSettings.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'RETURNED' ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'RETURNED' ? 'مرتجع' : 'مكتمل',
                          style: TextStyle(
                            color: status == 'RETURNED' ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInvoiceDetails(String invoiceId, Map<String, dynamic> data) {
    final date = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final status = data['status'] ?? 'COMPLETED';
    final List<dynamic> items = data['items'] ?? [];
    final double totalAmount = (data['totalAmount'] ?? 0).toDouble();
    final double paidAmount = (data['paidAmount'] ?? 0).toDouble();
    final double debt = totalAmount - paidAmount;
    final double profit = (data['profit'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['invoiceNumber'] ?? 'تفاصيل الفاتورة',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'RETURNED' ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'RETURNED' ? 'مرتجع' : 'مكتمل',
                          style: TextStyle(
                            color: status == 'RETURNED' ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE2E8F0)),
                  _buildDetailRow('العميل', data['customerName'] ?? 'عميل نقدي'),
                  _buildDetailRow('المستودع', data['warehouseId'] == 'MAIN' ? 'المخزن الرئيسي' : 'السيارة'),
                  _buildDetailRow('التاريخ', '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  const Text('الأصناف والمنتجات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final double itemTotal = (item['price'] ?? 0) * (item['quantity'] ?? 0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item['name']} (×${item['quantity']})', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                            Text('${itemTotal.toStringAsFixed(1)} ${AppSettings.currency}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0)),
                  _buildDetailRow('المبلغ الإجمالي', '${totalAmount.toStringAsFixed(1)} ${AppSettings.currency}', isBold: true),
                  _buildDetailRow('المبلغ المدفوع', '${paidAmount.toStringAsFixed(1)} ${AppSettings.currency}', color: const Color(0xFF059669)),
                  _buildDetailRow('المتبقي (الدين)', '${debt.toStringAsFixed(1)} ${AppSettings.currency}', color: debt > 0 ? const Color(0xFFEF4444) : Colors.black),
                  const Divider(color: Color(0xFFE2E8F0)),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildDetailRow('صافي الربح من الفاتورة', '${profit.toStringAsFixed(1)} ${AppSettings.currency}', color: const Color(0xFF1E3A8A), isBold: true),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (status != 'RETURNED') ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleReturn(invoiceId, data);
                            },
                            icon: const Icon(Icons.assignment_return_rounded, size: 18),
                            label: const Text('إرجاع'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditInvoiceDialog(invoiceId, data);
                            },
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('تعديل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDeleteInvoice(invoiceId, data);
                          },
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: const Text('حذف'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF475569),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditInvoiceDialog(String invoiceId, Map<String, dynamic> data) {
    final customerController = TextEditingController(text: data['customerName']);
    final paidController = TextEditingController(text: data['paidAmount']?.toString() ?? '0');
    DateTime selectedDate = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    String warehouse = data['warehouseId'] ?? 'MAIN';
    String? customerId = data['customerId'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تعديل بيانات الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: customerController,
                    decoration: InputDecoration(
                      labelText: 'اسم العميل',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المبلغ المدفوع الجديد',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: warehouse,
                    items: const [
                      DropdownMenuItem(value: 'MAIN', child: Text('المخزن الرئيسي')),
                      DropdownMenuItem(value: 'CAR', child: Text('السيارة')),
                    ],
                    onChanged: (v) => setStateDialog(() => warehouse = v!),
                    decoration: InputDecoration(
                      labelText: 'المخزن',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ الفاتورة',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final newPaid = double.tryParse(paidController.text) ?? 0.0;
                  Navigator.pop(context);
                  
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  try {
                    await _saleService.updateSaleInvoice(
                      invoiceId: invoiceId,
                      oldData: data,
                      customerName: customerController.text.trim(),
                      customerId: customerId,
                      warehouseId: warehouse,
                      invoiceDate: selectedDate,
                      newPaidAmount: newPaid,
                    );
                    if (context.mounted) {
                      Navigator.pop(context); // pop progress indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تعديل الفاتورة بنجاح')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // pop progress
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ أثناء التعديل: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmDeleteInvoice(String invoiceId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفاتورة نهائياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text(
          'هل أنت متأكد من حذف هذه الفاتورة بالكامل؟ سيتم إعادة البضاعة للمستودع وإلغاء حركتها وعكس كافة القيود المالية ورأس المال.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close confirm dialog
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await _saleService.deleteSaleInvoice(invoiceId, data);
                if (context.mounted) {
                  Navigator.pop(context); // pop loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف الفاتورة وعكس تأثيراتها بالكامل')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // pop loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ أثناء حذف الفاتورة: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReturn(String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرجاع الفاتورة بالكامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text(
            'هل أنت متأكد من إرجاع هذه الفاتورة بالكامل؟ سيتم إعادة البضاعة للمخزن وتعديل الرصيد، وخصم المبلغ من الصندوق ورأس المال.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog
              
              // Show progress indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await _saleService.returnSale(id);
                if (context.mounted) {
                  Navigator.pop(context); // Close progress indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرجاع الفاتورة وعكس حركاتها المالية بالكامل')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close progress indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ أثناء إرجاع الفاتورة: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد الإرجاع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoTile(IconData icon, String label, String value, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value.isEmpty ? 'غير محدد' : value,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    if (!_isSettingsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final String email = FirebaseAuth.instance.currentUser?.email ?? 'admin@example.com';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // User Avatar Header
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20),
              ],
            ),
            child: const CircleAvatar(
              radius: 46,
              backgroundColor: Color(0xFF0F172A),
              child: Icon(Icons.person_rounded, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppSettings.userName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          Text(
            email,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          if (!_isEditingProfile) ...[
            // Read-Only Premium Cards View
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 15),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'معلومات الحساب والنشاط',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileInfoTile(Icons.person_outline_rounded, 'اسم المستخدم / مدير النظام', AppSettings.userName, const Color(0xFF0F172A)),
                  _buildProfileInfoTile(Icons.store_outlined, 'اسم المتجر / النشاط التجاري', AppSettings.storeName, const Color(0xFF2563EB)),
                  _buildProfileInfoTile(Icons.phone_outlined, 'رقم هاتف المتجر', AppSettings.storePhone, const Color(0xFF0D9488)),
                  _buildProfileInfoTile(Icons.location_on_outlined, 'عنوان المتجر', AppSettings.storeAddress, const Color(0xFFD97706)),
                  _buildProfileInfoTile(Icons.payments_outlined, 'عملة النظام المعتمدة', AppSettings.currency, const Color(0xFF059669)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions Buttons
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditingProfile = true;
                    _nameController.text = AppSettings.userName;
                    _storeNameController.text = AppSettings.storeName;
                    _storePhoneController.text = AppSettings.storePhone;
                    _storeAddressController.text = AppSettings.storeAddress;
                    _currencyController.text = AppSettings.currency;
                  });
                },
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: const Text('تعديل البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  _loadSettings();
                },
                icon: const Icon(Icons.settings_rounded, size: 20),
                label: const Text('الإعدادات العامة للبرنامج', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFF0F172A)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                },
                icon: const Icon(Icons.print_rounded, size: 20),
                label: const Text('إعدادات طابعة البلوتوث', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _authService.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('تسجيل الخروج من الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            // Editable Form View
            Form(
              key: _profileFormKey,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 15),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تعديل بيانات الحساب والملف الشخصي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 16),
                        _buildProfileTextField(_nameController, 'الاسم الكامل', Icons.person_outline_rounded),
                        _buildProfileTextField(_storeNameController, 'اسم المتجر/النشاط', Icons.store_outlined),
                        _buildProfileTextField(_storePhoneController, 'رقم هاتف المتجر', Icons.phone_outlined, isPhone: true),
                        _buildProfileTextField(_storeAddressController, 'عنوان المتجر', Icons.location_on_outlined),
                        
                        // Currency Selection Field
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _currencyController,
                            decoration: InputDecoration(
                              labelText: 'العملة الافتراضية (مثال: ر.ي، ريال يمني)',
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF64748B)),
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
                            validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions Buttons in Edit Mode
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _saveProfileChanges,
                            icon: const Icon(Icons.save_rounded, size: 20),
                            label: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditingProfile = false;
                              });
                            },
                            icon: const Icon(Icons.close_rounded, size: 20),
                            label: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileTextField(TextEditingController controller, String label, IconData icon, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
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
        validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      ),
    );
  }

  void _saveProfileChanges() async {
    if (!_profileFormKey.currentState!.validate()) return;
    
    setState(() => _isSettingsLoaded = false);
    try {
      await AppSettings.saveSettings(
        name: _nameController.text.trim(),
        newStoreName: _storeNameController.text.trim(),
        newStorePhone: _storePhoneController.text.trim(),
        newStoreAddress: _storeAddressController.text.trim(),
        newCurrency: _currencyController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ البيانات والعملة بنجاح')),
        );
        setState(() {
          _isEditingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء حفظ البيانات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingsLoaded = true;
        });
      }
    }
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('currentStock', isLessThanOrEqualTo: 20)
          .snapshots(),
      builder: (context, productSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reminders')
              .where('status', isEqualTo: 'PENDING')
              .snapshots(),
          builder: (context, reminderSnapshot) {
            int alertCount = 0;
            List<DocumentSnapshot> lowStockDocs = [];
            List<DocumentSnapshot> reminderDocs = [];

            if (productSnapshot.hasData) {
              lowStockDocs = productSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['currentStock'] ?? 0) <= (data['minStock'] ?? 5);
              }).toList();
            }

            if (reminderSnapshot.hasData) {
              reminderDocs = reminderSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['dueDate'] == null) return false;
                final Timestamp dueTs = data['dueDate'] as Timestamp;
                final dueDate = dueTs.toDate();
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
                return dueDay.isBefore(today) || dueDay.isAtSameMomentAs(today);
              }).toList();
            }

            alertCount = lowStockDocs.length + reminderDocs.length;

            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
                  onPressed: () {
                    _showNotificationsBottomSheet(lowStockDocs, reminderDocs);
                  },
                ),
                if (alertCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$alertCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotificationsBottomSheet(List<DocumentSnapshot> lowStockDocs, List<DocumentSnapshot> reminderDocs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final hasNotifications = lowStockDocs.isNotEmpty || reminderDocs.isNotEmpty;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'التنبيهات والإشعارات',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  if (!hasNotifications)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, color: Color(0xFF94A3B8), size: 48),
                            SizedBox(height: 12),
                            Text('لا توجد إشعارات جديدة حالياً', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          if (reminderDocs.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('تذكيرات سداد المديونيات المستحقة', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 14)),
                            ),
                            ...reminderDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final String customerName = data['customerName'] ?? '';
                              final String invoiceNumber = data['invoiceNumber'] ?? '';
                              final double amount = (data['amount'] ?? 0.0).toDouble();
                              final Timestamp dueTs = data['dueDate'] as Timestamp;
                              final dateStr = DateFormat('yyyy-MM-dd').format(dueTs.toDate());

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.alarm_on_rounded, color: Color(0xFFDC2626)),
                                  title: Text('العميل: $customerName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                  subtitle: Text('فاتورة: $invoiceNumber | المبلغ: ${amount.toStringAsFixed(1)} ${AppSettings.currency}\nتاريخ الاستحقاق: $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // فتح شاشة العملاء للتحصيل وسداد الديون
                                      setState(() {
                                        _selectedIndex = 0; // الذهاب للشاشة الرئيسية
                                      });
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CustomerListScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('تحصيل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          if (lowStockDocs.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('نقص مخزون المنتجات', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 14)),
                            ),
                            ...lowStockDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final String name = data['name'] ?? '';
                              final int stock = data['currentStock'] ?? 0;
                              final int minStock = data['minStock'] ?? 5;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                  subtitle: Text('الكمية الحالية: $stock قطعة | الحد الأدنى: $minStock قطعة', style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _selectedIndex = 1; // Go to inventory tab
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('عرض', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
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
}
