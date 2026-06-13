import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/finance_service.dart';
import '../../utils/app_settings.dart';

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({super.key});

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  final _financeService = FinanceService();
  final _expenseController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = 'TRANSPORT';

  void _showEditCapitalDialog(double currentCapital) {
    final controller = TextEditingController(text: currentCapital.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل رأس المال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'قيمة رأس المال الجديد',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newCap = double.tryParse(controller.text) ?? 0;
              await _financeService.updateCapital(newCap);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog() {
    _selectedCategory = 'TRANSPORT'; // Reset to default on open
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تسجيل مصروف جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _expenseController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'SHIPPING', child: Text('شحن')),
                    DropdownMenuItem(value: 'TRANSPORT', child: Text('مواصلات')),
                    DropdownMenuItem(value: 'WORKERS', child: Text('عمال')),
                    DropdownMenuItem(value: 'SUNDRIES', child: Text('نثريات')),
                    DropdownMenuItem(value: 'OTHER', child: Text('أخرى')),
                  ],
                  onChanged: (v) {
                    setStateDialog(() {
                      _selectedCategory = v!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'التصنيف',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_expenseController.text) ?? 0;
                  if (amount > 0) {
                    await _financeService.recordExpense(
                      amount: amount,
                      category: _selectedCategory,
                      notes: _notesController.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      _expenseController.clear();
                      _notesController.clear();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('حركة الصندوق والمالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 22, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'آخر العمليات المالية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildTransactionList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExpenseDialog,
        label: const Text('تسجيل مصروف', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.remove_circle_outline_rounded),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('counters').snapshots(),
      builder: (context, snapshot) {
        double balance = 0;
        double capital = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            if (doc.id == 'cashbox') {
              balance = (doc.data() as Map<String, dynamic>)['balance']?.toDouble() ?? 0.0;
            } else if (doc.id == 'capital') {
              capital = (doc.data() as Map<String, dynamic>)['balance']?.toDouble() ?? 0.0;
            }
          }
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFE2E8F0),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Cashbox Card (Credit-Card Style)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF059669), Color(0xFF10B981)], // Emerald to Green
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('رصيد الصندوق', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${balance.toStringAsFixed(1)} ${AppSettings.currency}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Capital Card (Credit-Card Style)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)], // Slate to Indigo
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('رأس المال الحالي', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              GestureDetector(
                                onTap: () => _showEditCapitalDialog(capital),
                                child: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${capital.toStringAsFixed(1)} ${AppSettings.currency}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
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
  }

  String _getCategoryLabel(String key) {
    switch (key) {
      case 'SHIPPING':
        return 'شحن';
      case 'TRANSPORT':
        return 'مواصلات';
      case 'WORKERS':
        return 'عمال';
      case 'SUNDRIES':
        return 'نثريات';
      case 'CUSTOMER_PAYMENT':
        return 'دفعة عميل';
      case 'SUPPLIER_PAYMENT':
        return 'دفعة مورد';
      case 'OTHER':
        return 'أخرى';
      default:
        return key;
    }
  }

  Widget _buildTransactionList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cash_transactions').orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد عمليات مالية مسجلة بعد.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            bool isIN = data['type'] == 'IN';
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isIN ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIN ? Icons.add_rounded : Icons.remove_rounded,
                      color: isIN ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  title: Text(data['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(_getCategoryLabel(data['category'] ?? ''), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ),
                  trailing: Text(
                    '${isIN ? "+" : "-"}${data['amount']} ${AppSettings.currency}',
                    style: TextStyle(color: isIN ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
