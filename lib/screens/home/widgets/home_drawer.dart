import 'package:flutter/material.dart';
import '../../invoices/create_purchase_screen.dart';
import '../../categories/category_list_screen.dart';
import '../../customers/customer_list_screen.dart';
import '../../suppliers/supplier_list_screen.dart';
import '../../finance/cashbox_screen.dart';
import '../../reports/reports_screen.dart';
import '../../settings/printer_settings_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../utils/app_colors.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/app_settings.dart';

class HomeDrawer extends StatelessWidget {
  final VoidCallback onSettingsUpdated;

  const HomeDrawer({
    super.key,
    required this.onSettingsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String userEmail = user?.email ?? 'بدون بريد إلكتروني';
    final String displayName = AppSettings.userName.isNotEmpty ? AppSettings.userName : 'مدير النظام';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.textDark, AppColors.primary],
              ),
            ),
            accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            accountEmail: Text(userEmail, style: const TextStyle(color: Colors.white70)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 44, color: AppColors.primary),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildDrawerTile(Icons.shopping_cart_checkout_rounded, 'فاتورة مشتريات جديدة', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePurchaseScreen()));
                }),
                const Divider(color: Color(0xFFF1F5F9)),
                _buildDrawerTile(Icons.category_rounded, 'إدارة الأصناف', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen()));
                }),
                _buildDrawerTile(Icons.people_alt_rounded, 'إدارة العملاء', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                }),
                _buildDrawerTile(Icons.local_shipping_rounded, 'إدارة الموردين', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen()));
                }),
                _buildDrawerTile(Icons.account_balance_wallet_rounded, 'المالية والصندوق', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CashboxScreen()));
                }),
                _buildDrawerTile(Icons.bar_chart_rounded, 'التقارير والإحصائيات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                }),
                const Divider(color: Color(0xFFF1F5F9)),
                _buildDrawerTile(Icons.print_rounded, 'إعدادات الطابعة', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                }),
                _buildDrawerTile(Icons.settings_rounded, 'الإعدادات', () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  onSettingsUpdated();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: Color(0xFF64748B), size: 22),
        title: Text(title, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
