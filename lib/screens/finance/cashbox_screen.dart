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
  String _filterType = 'ALL'; // ALL, IN, OUT

  @override
  void dispose() {
    _expenseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showEditCapitalDialog(double currentCapital) {
    final controller = TextEditingController(text: currentCapital.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل رأس المال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا التعديل سيُسجل في سجل المراقبة',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'قيمة رأس المال الجديد',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newCap = double.tryParse(controller.text) ?? 0;
              try {
                await _financeService.updateCapital(newCap);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تعديل رأس المال وتسجيله في سجل المراقبة')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCapitalDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة رأس مال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ المضاف',
                prefixIcon: const Icon(Icons.add_rounded, color: Color(0xFF059669)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'سبب الإضافة',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                try {
                  await _financeService.addCapital(
                    amount: amount,
                    notes: notesController.text.trim().isEmpty ? 'إضافة رأس مال' : notesController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تمت إضافة ${amount.toStringAsFixed(1)} ${AppSettings.currency} لرأس المال والصندوق')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog() {
    _selectedCategory = 'TRANSPORT';
    _expenseController.clear();
    _notesController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تسجيل مصروف جديد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _expenseController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: const Icon(Icons.money_off_rounded, color: Color(0xFFEF4444)),
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
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('صيانة')),
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
                    try {
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
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('⚠️ $e'), backgroundColor: const Color(0xFFEF4444)),
                        );
                      }
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

  void _showIncomeDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'OTHER';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تسجيل إيراد يدوي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: const Icon(Icons.add_circle_rounded, color: Color(0xFF059669)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'REFUND', child: Text('استرداد')),
                    DropdownMenuItem(value: 'COMMISSION', child: Text('عمولة')),
                    DropdownMenuItem(value: 'OTHER', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedCategory = v!),
                  decoration: InputDecoration(
                    labelText: 'نوع الإيراد',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'وصف الإيراد',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount > 0) {
                    try {
                      await _financeService.recordIncome(
                        amount: amount,
                        category: selectedCategory,
                        notes: notesController.text.trim().isEmpty ? 'إيراد يدوي' : notesController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم تسجيل إيراد ${amount.toStringAsFixed(1)} ${AppSettings.currency}')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
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
        title: const Text('حركة الصندوق والمالية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669)),
            tooltip: 'إضافة رأس مال',
            onPressed: _showAddCapitalDialog,
          ),
          IconButton(
            icon: const Icon(Icons.trending_up_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'تسجيل إيراد',
            onPressed: _showIncomeDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          _buildFilterRow(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildFilterChip('الكل', 'ALL'),
          const SizedBox(width: 8),
          _buildFilterChip('وارد ↑', 'IN'),
          const SizedBox(width: 8),
          _buildFilterChip('صادر ↓', 'OUT'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (type == 'IN'
                  ? const Color(0xFF059669)
                  : type == 'OUT'
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF1E3A8A))
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFE2E8F0),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cashbox Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
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
                          Text('رصيد الصندوق',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${balance.toStringAsFixed(1)} ${AppSettings.currency}',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balance < 0 ? '⚠️ رصيد سالب' : '✅ رصيد جيد',
                        style: TextStyle(
                          color: balance < 0 ? Colors.red.shade200 : Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Capital Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
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
                          const Text('رأس المال الحالي',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () => _showEditCapitalDialog(capital),
                            child: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${capital.toStringAsFixed(1)} ${AppSettings.currency}',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text('اضغط ✏️ للتعديل', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCategoryLabel(String key) {
    switch (key) {
      case 'SHIPPING': return 'شحن';
      case 'TRANSPORT': return 'مواصلات';
      case 'WORKERS': return 'عمال';
      case 'MAINTENANCE': return 'صيانة';
      case 'SUNDRIES': return 'نثريات';
      case 'CUSTOMER_PAYMENT': return 'دفعة عميل';
      case 'SUPPLIER_PAYMENT': return 'دفعة مورد';
      case 'SALE': return 'مبيعات';
      case 'SALE_RETURN': return 'مرتجع مبيعات';
      case 'PURCHASE_RETURN': return 'مرتجع مشتريات';
      case 'SALE_UPDATE': return 'تعديل فاتورة';
      case 'SALE_DELETE': return 'حذف فاتورة';
      case 'CAPITAL': return 'رأس مال';
      case 'INCOME': return 'إيراد';
      case 'REFUND': return 'استرداد';
      case 'COMMISSION': return 'عمولة';
      case 'OTHER': return 'أخرى';
      default: return key.isEmpty ? 'عام' : key;
    }
  }

  Widget _buildTransactionList() {
    Stream<QuerySnapshot> stream;
    if (_filterType == 'IN') {
      stream = FirebaseFirestore.instance
          .collection('cash_transactions')
          .where('type', isEqualTo: 'IN')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    } else if (_filterType == 'OUT') {
      stream = FirebaseFirestore.instance
          .collection('cash_transactions')
          .where('type', isEqualTo: 'OUT')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    } else {
      stream = FirebaseFirestore.instance
          .collection('cash_transactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
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
            final ts = data['timestamp'] as Timestamp?;
            final timeStr = ts != null
                ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')} - ${ts.toDate().day}/${ts.toDate().month}'
                : '';

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
                  title: Text(data['description'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '${_getCategoryLabel(data['category'] ?? '')}  •  $timeStr',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                  trailing: Text(
                    '${isIN ? "+" : "-"}${(data['amount'] ?? 0).toStringAsFixed(1)} ${AppSettings.currency}',
                    style: TextStyle(
                      color: isIN ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
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
