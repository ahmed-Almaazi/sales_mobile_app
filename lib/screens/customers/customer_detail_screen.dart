import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/customer.dart';
import '../../services/finance_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_settings.dart';
import 'customer_form_screen.dart';

class CustomerSearchDelegate extends SearchDelegate<Customer?> {
  @override
  String get searchFieldLabel => 'ابحث عن عميل...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestions(context);
  }

  Widget _buildSuggestions(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final results = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['storeName'] ?? '').toString().toLowerCase();
          final phone = (data['phone'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) || phone.contains(query.toLowerCase());
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('لا توجد نتائج مطابقة'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            final customer = Customer.fromMap(data, doc.id);
            return ListTile(
              title: Text(customer.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(customer.phone.isNotEmpty ? customer.phone : 'بدون هاتف'),
              trailing: Text('${customer.balance.toStringAsFixed(1)} ${AppSettings.currency}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => close(context, customer),
            );
          },
        );
      },
    );
  }
}

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CreatePaymentDialog extends StatefulWidget {
  final Customer customer;
  const _CreatePaymentDialog({required this.customer});

  @override
  State<_CreatePaymentDialog> createState() => _CreatePaymentDialogState();
}

class _CreatePaymentDialogState extends State<_CreatePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('سداد دفعة مالية', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع *'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال المبلغ';
                final amt = double.tryParse(v);
                if (amt == null || amt <= 0) return 'المبلغ يجب أن يكون أكبر من الصفر';
                if (amt > widget.customer.balance) {
                  return 'المبلغ المكتوب أكبر من مديونية العميل المتبقية';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات سداد'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submitPayment,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('تسجيل السداد'),
        ),
      ],
    );
  }

  void _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final amount = double.parse(_amountController.text);
        final notes = _notesController.text.trim();
        
        await FinanceService().recordCustomerPayment(
          customerId: widget.customer.id,
          customerName: widget.customer.storeName,
          amount: amount,
          notes: notes.isEmpty ? 'سداد مديونية عميل' : notes,
        );

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ الدفعة: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Customer _currentCustomer;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentCustomer = widget.customer;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPaymentDialog() async {
    if (_currentCustomer.balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مديونية مستحقة على هذا العميل لسدادها.')),
      );
      return;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CreatePaymentDialog(customer: _currentCustomer),
    );

    if (result == true) {
      _refreshCustomerData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل دفعة السداد وتحديث الحساب بنجاح')),
      );
    }
  }

  void _refreshCustomerData() async {
    final doc = await FirebaseFirestore.instance.collection('customers').doc(_currentCustomer.id).get();
    if (doc.exists && mounted) {
      setState(() {
        _currentCustomer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      });
    }
  }

  Future<void> _exportPdfReport() async {
    setState(() => _isExporting = true);
    try {
      // 1. جلب فواتير المبيعات
      final salesSnap = await FirebaseFirestore.instance
          .collection('sales')
          .where('customerId', isEqualTo: _currentCustomer.id)
          .get();

      // 2. جلب دفعات السداد
      final paymentsSnap = await FirebaseFirestore.instance
          .collection('cash_transactions')
          .where('reference', isEqualTo: _currentCustomer.id)
          .get();

      // 3. دمج العمليات وترتيبها زمنياً
      List<Map<String, dynamic>> transactions = [];

      for (var doc in salesSnap.docs) {
        final data = doc.data();
        final Timestamp? time = data['createdAt'] as Timestamp?;
        transactions.add({
          'type': 'INVOICE',
          'reference': data['invoiceNumber'] ?? '',
          'date': time?.toDate() ?? DateTime.now(),
          'description': 'فاتورة مبيعات رقم ${data['invoiceNumber'] ?? ''}',
          'amount': (data['totalAmount'] ?? 0.0).toDouble(),
          'paid': (data['paidAmount'] ?? 0.0).toDouble(),
          'remaining': ((data['totalAmount'] ?? 0.0) - (data['paidAmount'] ?? 0.0)).toDouble(),
        });
      }

      for (var doc in paymentsSnap.docs) {
        final data = doc.data();
        final Timestamp? time = data['timestamp'] as Timestamp?;
        transactions.add({
          'type': 'PAYMENT',
          'reference': 'سداد',
          'date': time?.toDate() ?? DateTime.now(),
          'description': data['description'] ?? 'سداد دفعة مالية',
          'amount': 0.0,
          'paid': (data['amount'] ?? 0.0).toDouble(),
          'remaining': -(data['amount'] ?? 0.0).toDouble(),
        });
      }

      // فرز تصاعدي حسب التاريخ
      transactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      // 4. إنشاء مستند PDF
      final pdf = pw.Document();
      
      // تحميل خط يدعم اللغة العربية من Google Fonts ديناميكياً
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBoldFont = await PdfGoogleFonts.cairoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicBoldFont,
          ),
          textDirection: pw.TextDirection.rtl,
          build: (context) {
            double cumulativeDebt = 0.0;
            
            // صفوف جدول العمليات
            final tableRows = <pw.TableRow>[
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('التاريخ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('البيان والعملية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('قيمة الفاتورة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('المسدد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('المتبقي (المديونية)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الرصيد المستحق', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
            ];

            for (var tx in transactions) {
              cumulativeDebt += tx['remaining'] as double;
              final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx['date'] as DateTime);
              tableRows.add(
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(tx['description'] as String, style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(tx['type'] == 'INVOICE' ? (tx['amount'] as double).toStringAsFixed(1) : '-', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((tx['paid'] as double).toStringAsFixed(1), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((tx['remaining'] as double).toStringAsFixed(1), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(cumulativeDebt.toStringAsFixed(1), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              );
            }

            return [
              // الهيدر والترويسة
              pw.Center(
                child: pw.Text(AppSettings.storeName.isNotEmpty ? AppSettings.storeName : 'نظام المبيعات الذكي', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('كشف حساب عميل تفصيلي (رسمي وقانوني)', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 20),
              
              // بيانات العميل المتروسة
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('اسم العميل: ${_currentCustomer.storeName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('تاريخ التصدير: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('رقم الهاتف: ${_currentCustomer.phone.isNotEmpty ? _currentCustomer.phone : "-"}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('العنوان/المنطقة: ${_currentCustomer.region.isNotEmpty ? _currentCustomer.region : "-"}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Divider(color: PdfColors.grey300),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الرصيد المتبقي الإجمالي المستحق للدفع:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.red800)),
                        pw.Text('${_currentCustomer.balance.toStringAsFixed(2)} ${AppSettings.currency}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.red800)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // جدول كشف الحساب
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: tableRows,
              ),
              pw.SizedBox(height: 40),

              // توقيع وختم
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('توقيع المحاسب / الإدارة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 30),
                      pw.Text('.................................', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('توقيع وختم العميل بالمطابقة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 30),
                      pw.Text('.................................', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // 5. فتح نافذة المشاركة وحفظ الملف في الهاتف
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'كشف_حساب_${_currentCustomer.storeName}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تصدير ملف PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentCustomer.storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isExporting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger),
            tooltip: 'تصدير كشف حساب PDF',
            onPressed: _isExporting ? null : _exportPdfReport,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.primary),
            tooltip: 'بحث عن عميل آخر',
            onPressed: () async {
              final selected = await showSearch<Customer?>(
                context: context,
                delegate: CustomerSearchDelegate(),
              );
              if (selected != null && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: selected)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CustomerFormScreen(customer: _currentCustomer)),
              );
              _refreshCustomerData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. بطاقة العميل المالية الأساسية
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentCustomer.storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          if (_currentCustomer.phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text("هاتف: ${_currentCustomer.phone}", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                          if (_currentCustomer.region.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text("العنوان: ${_currentCustomer.region}", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0x1A1E3A8A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                    )
                  ],
                ),
                const Divider(height: 30, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المديونية الحالية', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            "${_currentCustomer.balance.toStringAsFixed(2)} ${AppSettings.currency}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _currentCustomer.balance > 0 ? AppColors.danger : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showPaymentDialog,
                      icon: const Icon(Icons.add_card_rounded, size: 18),
                      label: const Text('تسجيل سداد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. شريط التبويبات لكشف الحساب
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
              tabs: const [
                Tab(text: 'فواتير المبيعات'),
                Tab(text: 'دفعات السداد والمتحصلات'),
              ],
            ),
          ),

          // 3. محتوى كشف الحساب بالتفصيل
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesTab(),
                _buildPaymentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .where('customerId', isEqualTo: _currentCustomer.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد فواتير مبيعات مسجلة لهذا العميل.', style: TextStyle(color: AppColors.textMuted)));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String invoiceNum = data['invoiceNumber'] ?? '';
            final double total = (data['totalAmount'] ?? 0.0).toDouble();
            final double paid = (data['paidAmount'] ?? 0.0).toDouble();
            final double remaining = total - paid;
            final Timestamp? time = data['createdAt'] as Timestamp?;
            final String dateStr = time != null ? DateFormat('yyyy-MM-dd HH:mm').format(time.toDate()) : '';
            final String status = data['status'] ?? 'COMPLETED';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('فاتورة رقم: $invoiceNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'RETURNED' ? AppColors.danger.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'RETURNED' ? 'مرتجعة' : 'مكتملة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status == 'RETURNED' ? AppColors.danger : AppColors.primary,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStat('الإجمالي', '${total.toStringAsFixed(1)} ${AppSettings.currency}', AppColors.textDark),
                        _buildMiniStat('المدفوع', '${paid.toStringAsFixed(1)} ${AppSettings.currency}', AppColors.secondary),
                        _buildMiniStat('المتبقي', '${remaining.toStringAsFixed(1)} ${AppSettings.currency}', remaining > 0 ? AppColors.danger : AppColors.textMuted),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cash_transactions')
          .where('reference', isEqualTo: _currentCustomer.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد دفعات سداد مسجلة حالياً.', style: TextStyle(color: AppColors.textMuted)));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final double amount = (data['amount'] ?? 0.0).toDouble();
            final String desc = data['description'] ?? '';
            final Timestamp? time = data['timestamp'] as Timestamp?;
            final String dateStr = time != null ? DateFormat('yyyy-MM-dd HH:mm').format(time.toDate()) : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(desc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Text(
                      "+ ${amount.toStringAsFixed(1)} ${AppSettings.currency}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.secondary),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
