import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_settings.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildReportCard(
              context,
              'تقرير الأرباح الحقيقية',
              'حساب صافي الربح بعد خصم المرتجعات والمصروفات',
              Icons.analytics_rounded,
              const Color(0xFF059669),
              () => _showProfitReport(context),
            ),
            _buildReportCard(
              context,
              'ديون العملاء المستحقة',
              'قائمة بالعملاء المديونين وإجمالي المبالغ المطلوبة',
              Icons.people_alt_rounded,
              const Color(0xFFEF4444),
              () => _showCustomersDebt(context),
            ),
            _buildReportCard(
              context,
              'حالة المخزون وجرد البضاعة',
              'المنتجات الناقصة، الراكدة والجرد العام للمخزن',
              Icons.inventory_2_rounded,
              const Color(0xFF1E3A8A),
              () => _showStockStatus(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showProfitReport(BuildContext context) async {
    final sales = await FirebaseFirestore.instance.collection('sales').get();
    final expenses = await FirebaseFirestore.instance.collection('cash_transactions').where('reference', isEqualTo: 'EXPENSE').get();
    
    double totalProfit = 0;
    for (var doc in sales.docs) {
      final data = doc.data();
      if (data['status'] != 'RETURNED') {
        totalProfit += (data['profit'] ?? 0);
      }
    }
    
    double totalExpenses = 0;
    for (var doc in expenses.docs) {
      totalExpenses += (doc.data()['amount'] ?? 0);
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text('تحليل الأرباح', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFE2E8F0)),
            _buildRow('إجمالي ربح المبيعات:', '${totalProfit.toStringAsFixed(1)} ${AppSettings.currency}'),
            _buildRow('إجمالي المصروفات:', '- ${totalExpenses.toStringAsFixed(1)} ${AppSettings.currency}', valueColor: const Color(0xFFEF4444)),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildRow('صافي الربح الحقيقي:', '${(totalProfit - totalExpenses).toStringAsFixed(1)} ${AppSettings.currency}', isBold: true, valueColor: const Color(0xFF059669)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomersDebt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('customers').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('خطأ: ${snapshot.error}'));
              }
              
              final allDocs = snapshot.data?.docs ?? [];
              final debtorCustomers = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['balance'] ?? 0.0) > 0.0;
              }).toList();

              double totalDebt = 0.0;
              for (var doc in debtorCustomers) {
                final data = doc.data() as Map<String, dynamic>;
                totalDebt += (data['balance'] ?? 0.0);
              }

              return Column(
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
                  const Text(
                    'ديون العملاء المستحقة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجمالي المديونية المستحقة',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${totalDebt.toStringAsFixed(1)} ${AppSettings.currency}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.payment_rounded, color: Colors.white70, size: 36),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'قائمة العملاء المديونين (${debtorCustomers.length})',
                    style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: debtorCustomers.isEmpty
                        ? const Center(
                            child: Text('لا يوجد عملاء مديونين حالياً 🎉'),
                          )
                        : ListView.builder(
                            itemCount: debtorCustomers.length,
                            itemBuilder: (context, index) {
                              final doc = debtorCustomers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFFEF2F2),
                                      child: Icon(Icons.person_rounded, color: Colors.red.shade600),
                                    ),
                                    title: Text(
                                      data['storeName'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    subtitle: Text(
                                      'المسؤول: ${data['contactName'] ?? ''}\nهاتف: ${data['phone'] ?? ''}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      '${(data['balance'] ?? 0.0).toStringAsFixed(1)} ${AppSettings.currency}',
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    isThreeLine: true,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showStockStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('خطأ: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];
              int totalProducts = docs.length;
              int totalStockItems = 0;
              double totalCostValue = 0.0;
              double totalRetailValue = 0.0;
              List<QueryDocumentSnapshot> lowStockProducts = [];

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                int currentStock = data['currentStock'] ?? 0;
                int minStock = data['minStock'] ?? 5;
                double purchasePrice = (data['purchasePrice'] ?? 0.0).toDouble();
                double retailPrice = (data['retailPrice'] ?? 0.0).toDouble();

                totalStockItems += currentStock;
                totalCostValue += currentStock * purchasePrice;
                totalRetailValue += currentStock * retailPrice;

                if (currentStock <= minStock) {
                  lowStockProducts.add(doc);
                }
              }

              return Column(
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
                  const Text(
                    'جرد المخزون والنافذ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildDashboardStat('الأصناف', '$totalProducts صنف', const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      _buildDashboardStat('إجمالي القطع', '$totalStockItems قطعة', const Color(0xFF7C3AED)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDashboardStat('قيمة الشراء', '${totalCostValue.toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF059669)),
                      const SizedBox(width: 8),
                      _buildDashboardStat('قيمة البيع', '${totalRetailValue.toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF0D9488)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الأصناف منخفضة المخزون',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: lowStockProducts.isEmpty ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lowStockProducts.isEmpty ? 'المخزون كافٍ' : 'تحذير: متبقي ${lowStockProducts.length}',
                          style: TextStyle(
                            color: lowStockProducts.isEmpty ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: lowStockProducts.isEmpty
                        ? const Center(
                            child: Text('لا توجد نواقص في المخزن حالياً 👍'),
                          )
                        : ListView.builder(
                            itemCount: lowStockProducts.length,
                            itemBuilder: (context, index) {
                              final doc = lowStockProducts[index];
                              final data = doc.data() as Map<String, dynamic>;
                              int stock = data['currentStock'] ?? 0;
                              int min = data['minStock'] ?? 5;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: stock == 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7),
                                      child: Icon(
                                        stock == 0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                                        color: stock == 0 ? Colors.red : Colors.amber.shade900,
                                      ),
                                    ),
                                    title: Text(
                                      data['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    subtitle: Text('الباركود: ${data['barcode'] ?? ''}', style: const TextStyle(fontSize: 11)),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          stock == 0 ? 'نفذ بالكامل' : 'متبقي: $stock قطعة',
                                          style: TextStyle(
                                            color: stock == 0 ? Colors.red : Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'حد التنبيه: $min',
                                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDashboardStat(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF475569))),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (isBold ? const Color(0xFF059669) : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
