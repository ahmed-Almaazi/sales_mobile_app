import 'package:flutter/material.dart';
import '../../utils/app_settings.dart';
import '../../utils/app_colors.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import 'customer_form_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final customerService = CustomerService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('قائمة العملاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Customer>>(
        stream: customerService.getCustomers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'لا يوجد عملاء مضافين حالياً.\nاضغط على الزر بالأسفل لإضافة عميل جديد.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            );
          }

          final customers = snapshot.data!;

          return ListView.builder(
            itemCount: customers.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final customer = customers[index];
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0F172A)),
                    ),
                    title: Text(customer.storeName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'المديونية: ${customer.balance.toStringAsFixed(1)} ${AppSettings.currency}',
                        style: TextStyle(
                          fontSize: 11,
                          color: customer.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                          fontWeight: customer.balance > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerDetailScreen(customer: customer),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
          );
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة عميل', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
    );
  }
}
