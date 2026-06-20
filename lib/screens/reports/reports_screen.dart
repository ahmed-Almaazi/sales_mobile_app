import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/analytics_service.dart';
import '../../utils/app_settings.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
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
              'ديون الموردين المستحقة',
              'قائمة بالموردين وما علينا لهم من مستحقات',
              Icons.local_shipping_rounded,
              const Color(0xFFD97706),
              () => _showSuppliersDebt(context),
            ),
            _buildReportCard(
              context,
              'حالة المخزون وجرد البضاعة',
              'المنتجات الناقصة، الراكدة والجرد العام للمخزن',
              Icons.inventory_2_rounded,
              const Color(0xFF1E3A8A),
              () => _showStockStatus(context),
            ),
            _buildReportCard(
              context,
              'أعلى العملاء مشتريات',
              'أفضل العملاء من حيث حجم الشراء والطلبات',
              Icons.emoji_events_rounded,
              const Color(0xFF7C3AED),
              () => _showTopCustomers(context),
            ),
            _buildReportCard(
              context,
              'أكثر المنتجات مبيعاً',
              'ترتيب المنتجات حسب الكميات المبيعة والإيرادات',
              Icons.bar_chart_rounded,
              const Color(0xFF0D9488),
              () => _showTopProducts(context),
            ),
            _buildReportCard(
              context,
              'سجل المراقبة والتدقيق',
              'جميع العمليات الحساسة والتغييرات المالية',
              Icons.shield_rounded,
              const Color(0xFF475569),
              () => _showAuditLog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
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
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          onTap: onTap,
        ),
      ),
    );
  }

  // ===== تقرير الأرباح =====
  void _showProfitReport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final analyticsService = AnalyticsService();
    final report = await analyticsService.getProfitReport();
    final monthStats = await analyticsService.getCurrentMonthStats();

    if (!context.mounted) return;
    Navigator.pop(context);

    final double totalRevenue = report['totalRevenue'] ?? 0;
    final double totalProfit = report['totalProfit'] ?? 0;
    final double totalExpenses = report['totalExpenses'] ?? 0;
    final double netProfit = report['netProfit'] ?? 0;
    final int completedCount = (report['completedCount'] ?? 0).toInt();
    final int returnedCount = (report['returnedCount'] ?? 0).toInt();
    final double monthSales = monthStats['totalSales'] ?? 0;
    final double monthProfit = monthStats['totalProfit'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 45, height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Text('تحليل الأرباح الكامل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            // إحصاءات الشهر الحالي
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مبيعات الشهر الحالي',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('إجمالي المبيعات', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        Text('${monthSales.toStringAsFixed(1)} ${AppSettings.currency}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('صافي الربح', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        Text('${monthProfit.toStringAsFixed(1)} ${AppSettings.currency}',
                            style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 16, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0)),
            _buildRow('إجمالي إيرادات المبيعات:', '${totalRevenue.toStringAsFixed(1)} ${AppSettings.currency}'),
            _buildRow('إجمالي ربح المبيعات:', '${totalProfit.toStringAsFixed(1)} ${AppSettings.currency}'),
            _buildRow('إجمالي المصروفات:', '- ${totalExpenses.toStringAsFixed(1)} ${AppSettings.currency}',
                valueColor: const Color(0xFFEF4444)),
            _buildRow('فواتير مكتملة:', '$completedCount فاتورة'),
            _buildRow('فواتير مرتجعة:', '$returnedCount فاتورة',
                valueColor: returnedCount > 0 ? const Color(0xFFEF4444) : null),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: netProfit >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildRow(
                'صافي الربح الحقيقي:',
                '${netProfit.toStringAsFixed(1)} ${AppSettings.currency}',
                isBold: true,
                valueColor: netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ديون العملاء =====
  void _showCustomersDebt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
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
                return (data['balance'] ?? 0.0) > 0.01;
              }).toList();

              debtorCustomers.sort((a, b) {
                final aBalance = (a.data() as Map<String, dynamic>)['balance'] ?? 0.0;
                final bBalance = (b.data() as Map<String, dynamic>)['balance'] ?? 0.0;
                return (bBalance as double).compareTo(aBalance as double);
              });

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
                      width: 45, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Text('ديون العملاء المستحقة',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إجمالي المديونية المستحقة',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('${totalDebt.toStringAsFixed(1)} ${AppSettings.currency}',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('${debtorCustomers.length} عميل مديون',
                                style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        const Icon(Icons.payment_rounded, color: Colors.white70, size: 36),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'قائمة العملاء المديونين (${debtorCustomers.length})',
                    style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: debtorCustomers.isEmpty
                        ? const Center(child: Text('لا يوجد عملاء مديونين حالياً 🎉'))
                        : ListView.builder(
                            itemCount: debtorCustomers.length,
                            itemBuilder: (context, index) {
                              final doc = debtorCustomers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final double balance = (data['balance'] ?? 0.0).toDouble();
                              final double creditLimit = (data['creditLimit'] ?? 0.0).toDouble();
                              final bool isOverLimit = creditLimit > 0 && balance > creditLimit;

                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isOverLimit ? const Color(0xFFFCA5A5) : const Color(0xFFF1F5F9),
                                      width: isOverLimit ? 1.5 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFFEF2F2),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontSize: 13),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(data['storeName'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                        ),
                                        if (isOverLimit)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('تجاوز الحد',
                                                style: TextStyle(fontSize: 9, color: Color(0xFF991B1B), fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'المسؤول: ${data['contactName'] ?? ''} | هاتف: ${data['phone'] ?? ''}${creditLimit > 0 ? '\nالحد الائتماني: ${creditLimit.toStringAsFixed(1)} ${AppSettings.currency}' : ''}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      '${balance.toStringAsFixed(1)} ${AppSettings.currency}',
                                      style: TextStyle(
                                        color: isOverLimit ? const Color(0xFFDC2626) : const Color(0xFFEF4444),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    isThreeLine: creditLimit > 0,
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

  // ===== ديون الموردين (جديد) =====
  void _showSuppliersDebt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('خطأ: ${snapshot.error}'));
              }

              final allDocs = snapshot.data?.docs ?? [];
              final debtorSuppliers = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['balance'] ?? 0.0) > 0.01;
              }).toList();

              debtorSuppliers.sort((a, b) {
                final aBalance = (a.data() as Map<String, dynamic>)['balance'] ?? 0.0;
                final bBalance = (b.data() as Map<String, dynamic>)['balance'] ?? 0.0;
                return (bBalance as double).compareTo(aBalance as double);
              });

              double totalDebt = 0.0;
              for (var doc in debtorSuppliers) {
                final data = doc.data() as Map<String, dynamic>;
                totalDebt += (data['balance'] ?? 0.0);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Text('ديون الموردين المستحقة',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إجمالي ما علينا للموردين',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('${totalDebt.toStringAsFixed(1)} ${AppSettings.currency}',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('${debtorSuppliers.length} مورد مستحق',
                                style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        const Icon(Icons.local_shipping_rounded, color: Colors.white70, size: 36),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'قائمة الموردين المستحقين (${debtorSuppliers.length})',
                    style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: debtorSuppliers.isEmpty
                        ? const Center(child: Text('لا يوجد موردون مستحقون حالياً 🎉'))
                        : ListView.builder(
                            itemCount: debtorSuppliers.length,
                            itemBuilder: (context, index) {
                              final doc = debtorSuppliers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final double balance = (data['balance'] ?? 0.0).toDouble();

                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                      backgroundColor: const Color(0xFFFFF7ED),
                                      child: Icon(Icons.local_shipping_rounded,
                                          color: Colors.orange.shade700),
                                    ),
                                    title: Text(data['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                    subtitle: Text(
                                      'هاتف: ${data['phone'] ?? 'غير محدد'}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      '${balance.toStringAsFixed(1)} ${AppSettings.currency}',
                                      style: const TextStyle(
                                        color: Color(0xFFD97706),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
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

  // ===== حالة المخزون =====
  void _showStockStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
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
              List<QueryDocumentSnapshot> outOfStockProducts = [];

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                int currentStock = data['currentStock'] ?? 0;
                int minStock = data['minStock'] ?? 5;
                double purchasePrice = (data['purchasePrice'] ?? 0.0).toDouble();
                double retailPrice = (data['retailPrice'] ?? 0.0).toDouble();

                totalStockItems += currentStock;
                totalCostValue += currentStock * purchasePrice;
                totalRetailValue += currentStock * retailPrice;

                if (currentStock == 0) {
                  outOfStockProducts.add(doc);
                } else if (currentStock <= minStock) {
                  lowStockProducts.add(doc);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Text('جرد المخزون والنافذ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  Row(children: [
                    _buildDashboardStat('الأصناف', '$totalProducts صنف', const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    _buildDashboardStat('إجمالي القطع', '$totalStockItems قطعة', const Color(0xFF7C3AED)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _buildDashboardStat('قيمة الشراء', '${totalCostValue.toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF059669)),
                    const SizedBox(width: 8),
                    _buildDashboardStat('قيمة البيع', '${totalRetailValue.toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF0D9488)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _buildDashboardStat('نافذ', '${outOfStockProducts.length} صنف', const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    _buildDashboardStat('متوقع الربح', '${(totalRetailValue - totalCostValue).toStringAsFixed(1)} ${AppSettings.currency}', const Color(0xFF059669)),
                  ]),
                  const SizedBox(height: 16),
                  if (outOfStockProducts.isNotEmpty) ...[
                    const Text('⛔ منتجات نافذة بالكامل',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444))),
                    const SizedBox(height: 8),
                    ...outOfStockProducts.take(3).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildStockItem(data, 0, 0, isOutOfStock: true);
                    }),
                    if (outOfStockProducts.length > 3)
                      Text('... و${outOfStockProducts.length - 3} صنف آخر',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الأصناف منخفضة المخزون',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: lowStockProducts.isEmpty ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lowStockProducts.isEmpty ? 'المخزون كافٍ' : 'تحذير: ${lowStockProducts.length} صنف',
                          style: TextStyle(
                            color: lowStockProducts.isEmpty ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            fontSize: 11, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: lowStockProducts.isEmpty
                        ? const Center(child: Text('لا توجد نواقص في المخزن حالياً 👍'))
                        : ListView.builder(
                            itemCount: lowStockProducts.length,
                            itemBuilder: (context, index) {
                              final doc = lowStockProducts[index];
                              final data = doc.data() as Map<String, dynamic>;
                              int stock = data['currentStock'] ?? 0;
                              int min = data['minStock'] ?? 5;
                              return _buildStockItem(data, stock, min);
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

  Widget _buildStockItem(Map<String, dynamic> data, int stock, int min, {bool isOutOfStock = false}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            backgroundColor: isOutOfStock ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7),
            child: Icon(
              isOutOfStock ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              color: isOutOfStock ? Colors.red : Colors.amber.shade900,
            ),
          ),
          title: Text(data['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          subtitle: Text('الباركود: ${data['barcode'] ?? ''}', style: const TextStyle(fontSize: 11)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isOutOfStock ? 'نفذ بالكامل' : 'متبقي: $stock قطعة',
                style: TextStyle(
                  color: isOutOfStock ? Colors.red : Colors.amber.shade900,
                  fontWeight: FontWeight.bold, fontSize: 13,
                ),
              ),
              if (!isOutOfStock)
                Text('حد التنبيه: $min', style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  // ===== أعلى العملاء مبيعاً (جديد) =====
  void _showTopCustomers(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final analytics = AnalyticsService();
    final topCustomers = await analytics.getTopCustomers(limit: 10);

    if (!context.mounted) return;
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45, height: 5, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Text('🏆 أعلى العملاء مشتريات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            Expanded(
              child: topCustomers.isEmpty
                  ? const Center(child: Text('لا توجد بيانات كافية بعد'))
                  : ListView.builder(
                      itemCount: topCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = topCustomers[index];
                        final icons = ['🥇', '🥈', '🥉'];
                        final medal = index < 3 ? icons[index] : '${index + 1}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: index == 0
                                ? const Color(0xFFFFFBEB)
                                : index == 1
                                    ? const Color(0xFFF8FAFC)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: index == 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(medal, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer['customerName'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                    Text('${customer['orderCount']} فاتورة',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Text(
                                '${(customer['totalPurchases'] as double).toStringAsFixed(1)} ${AppSettings.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== أكثر المنتجات مبيعاً (جديد) =====
  void _showTopProducts(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final analytics = AnalyticsService();
    final topProducts = await analytics.getTopProducts(limit: 10);

    if (!context.mounted) return;
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45, height: 5, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Text('📦 أكثر المنتجات مبيعاً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            Expanded(
              child: topProducts.isEmpty
                  ? const Center(child: Text('لا توجد بيانات كافية بعد'))
                  : ListView.builder(
                      itemCount: topProducts.length,
                      itemBuilder: (context, index) {
                        final product = topProducts[index];
                        final icons = ['🥇', '🥈', '🥉'];
                        final medal = index < 3 ? icons[index] : '${index + 1}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: index == 0 ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: index == 0 ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(medal, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product['productName'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                    Text('${product['totalRevenue']?.toStringAsFixed(1)} ${AppSettings.currency} إيراد',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${product['totalQty']} قطعة',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== سجل المراقبة (جديد) =====
  void _showAuditLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45, height: 5, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('🛡️ سجل المراقبة والتدقيق',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('audit_logs')
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('لا توجد سجلات بعد'));

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final action = data['action'] ?? '';
                        final details = data['details'] ?? '';
                        final ts = data['timestamp'] as Timestamp?;
                        final dateStr = ts != null
                            ? '${ts.toDate().year}-${ts.toDate().month.toString().padLeft(2, '0')}-${ts.toDate().day.toString().padLeft(2, '0')} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                            : '';

                        Color actionColor = const Color(0xFF1E3A8A);
                        IconData actionIcon = Icons.info_rounded;
                        if (action.contains('DELETE') || action.contains('RETURN')) {
                          actionColor = const Color(0xFFEF4444);
                          actionIcon = Icons.warning_rounded;
                        } else if (action.contains('CREATE')) {
                          actionColor = const Color(0xFF059669);
                          actionIcon = Icons.check_circle_rounded;
                        } else if (action.contains('UPDATE') || action.contains('CAPITAL')) {
                          actionColor = const Color(0xFFD97706);
                          actionIcon = Icons.edit_rounded;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: actionColor.withOpacity(0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(actionIcon, color: actionColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(action,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: actionColor)),
                                    const SizedBox(height: 2),
                                    Text(details,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                    if (dateStr.isNotEmpty)
                                      Text(dateStr,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                            ],
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
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF475569))),
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
