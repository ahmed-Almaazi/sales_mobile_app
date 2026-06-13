import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() async {
    final devices = await _printerService.getDevices();
    setState(() => _devices = devices);
    
    bool? connected = await _printerService.bluetooth.isConnected;
    setState(() => _isConnected = connected ?? false);
  }

  void _connect() async {
    if (_selectedDevice == null) return;
    try {
      bool success = await _printerService.connect(_selectedDevice!);
      if (!mounted) return;
      setState(() => _isConnected = success);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاتصال بالطابعة بنجاح')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاتصال: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطابعة'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر طابعة البلوتوث:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButton<BluetoothDevice>(
              isExpanded: true,
              value: _selectedDevice,
              hint: const Text('اختر جهازاً'),
              items: _devices.map((d) => DropdownMenuItem(value: d, child: Text(d.name ?? 'جهاز مجهول'))).toList(),
              onChanged: (v) => setState(() => _selectedDevice = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _connect,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                child: const Text('اتصال بالطابعة'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(_isConnected ? Icons.check_circle : Icons.error, color: _isConnected ? Colors.green : Colors.red, size: 50),
                  Text(_isConnected ? 'الطابعة متصلة' : 'الطابعة غير متصلة', style: TextStyle(fontSize: 16, color: _isConnected ? Colors.green : Colors.red)),
                ],
              ),
            ),
            const Spacer(),
            if (_isConnected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await _printerService.printInvoice(
                      invoiceNumber: 'TEST-001',
                      customerName: 'تجربة طباعة',
                      items: [{'name': 'منتج تجريبي', 'quantity': 1, 'price': 100.0}],
                      total: 100.0,
                      paid: 100.0,
                    );
                  },
                  child: const Text('طباعة فاتورة تجريبية'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
