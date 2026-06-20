import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة التحليلات والإحصاءات المتقدمة
class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// الحصول على إحصاءات اليوم الحالي من daily_stats
  Future<Map<String, double>> getTodayStats() async {
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await _db.collection('daily_stats').doc(dayKey).get();
    if (!doc.exists) {
      return {
        'totalSales': 0,
        'totalProfit': 0,
        'totalOrders': 0,
        'paidAmount': 0,
      };
    }
    final data = doc.data()!;
    return {
      'totalSales': (data['totalSales'] ?? 0.0).toDouble(),
      'totalProfit': (data['totalProfit'] ?? 0.0).toDouble(),
      'totalOrders': (data['totalOrders'] ?? 0.0).toDouble(),
      'paidAmount': (data['paidAmount'] ?? 0.0).toDouble(),
    };
  }

  /// الحصول على إحصاءات آخر N يوم
  Future<List<Map<String, dynamic>>> getLastNDaysStats(int n) async {
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (int i = n - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final doc = await _db.collection('daily_stats').doc(dayKey).get();
      final data = doc.data() ?? {};
      result.add({
        'date': dayKey,
        'day': day,
        'totalSales': (data['totalSales'] ?? 0.0).toDouble(),
        'totalProfit': (data['totalProfit'] ?? 0.0).toDouble(),
        'totalOrders': (data['totalOrders'] ?? 0.0).toDouble(),
      });
    }
    return result;
  }

  /// الحصول على إحصاءات الشهر الحالي
  Future<Map<String, double>> getCurrentMonthStats() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final snapshot = await _db.collection('daily_stats').get();
    
    double totalSales = 0;
    double totalProfit = 0;
    double totalOrders = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String dateStr = data['date'] ?? doc.id;
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final docDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (!docDate.isBefore(startOfMonth) && !docDate.isAfter(now)) {
            totalSales += (data['totalSales'] ?? 0.0).toDouble();
            totalProfit += (data['totalProfit'] ?? 0.0).toDouble();
            totalOrders += (data['totalOrders'] ?? 0.0).toDouble();
          }
        }
      } catch (_) {}
    }

    return {
      'totalSales': totalSales,
      'totalProfit': totalProfit,
      'totalOrders': totalOrders,
    };
  }

  /// أعلى العملاء مبيعاً (Top Customers)
  Future<List<Map<String, dynamic>>> getTopCustomers({int limit = 5}) async {
    final salesSnapshot = await _db.collection('sales').get();

    final Map<String, Map<String, dynamic>> customerMap = {};

    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'RETURNED') continue;
      final String? customerId = data['customerId'];
      final String customerName = data['customerName'] ?? 'عميل نقدي';
      final double amount = (data['totalAmount'] ?? 0.0).toDouble();

      if (customerId == null) continue;

      if (customerMap.containsKey(customerId)) {
        customerMap[customerId]!['totalPurchases'] =
            (customerMap[customerId]!['totalPurchases'] ?? 0.0) + amount;
        customerMap[customerId]!['orderCount'] =
            (customerMap[customerId]!['orderCount'] ?? 0) + 1;
      } else {
        customerMap[customerId] = {
          'customerId': customerId,
          'customerName': customerName,
          'totalPurchases': amount,
          'orderCount': 1,
        };
      }
    }

    final sorted = customerMap.values.toList()
      ..sort((a, b) => (b['totalPurchases'] as double).compareTo(a['totalPurchases'] as double));

    return sorted.take(limit).toList();
  }

  /// أكثر المنتجات مبيعاً (Top Products)
  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 5}) async {
    final salesSnapshot = await _db.collection('sales').get();

    final Map<String, Map<String, dynamic>> productMap = {};

    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'RETURNED') continue;
      final List<dynamic> items = data['items'] ?? [];

      for (var item in items) {
        final String productId = item['productId'] ?? '';
        final String productName = item['name'] ?? '';
        final int qty = (item['quantity'] ?? 0) as int;
        final double revenue = (item['price'] ?? 0.0) * qty;

        if (productId.isEmpty) continue;

        if (productMap.containsKey(productId)) {
          productMap[productId]!['totalQty'] =
              (productMap[productId]!['totalQty'] ?? 0) + qty;
          productMap[productId]!['totalRevenue'] =
              (productMap[productId]!['totalRevenue'] ?? 0.0) + revenue;
        } else {
          productMap[productId] = {
            'productId': productId,
            'productName': productName,
            'totalQty': qty,
            'totalRevenue': revenue,
          };
        }
      }
    }

    final sorted = productMap.values.toList()
      ..sort((a, b) => (b['totalQty'] as int).compareTo(a['totalQty'] as int));

    return sorted.take(limit).toList();
  }

  /// تقرير الأرباح الصحيح (يستبعد المرتجعات الكاملة)
  Future<Map<String, double>> getProfitReport() async {
    final salesSnapshot = await _db.collection('sales').get();
    final expensesSnapshot = await _db.collection('cash_transactions')
        .where('reference', isEqualTo: 'EXPENSE')
        .get();

    double totalRevenue = 0;
    double totalProfit = 0;
    int completedCount = 0;
    int returnedCount = 0;

    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] ?? 'COMPLETED';

      if (status != 'RETURNED') {
        totalRevenue += (data['totalAmount'] ?? 0.0).toDouble();
        totalProfit += (data['profit'] ?? 0.0).toDouble();
        completedCount++;
      } else {
        returnedCount++;
      }
    }

    double totalExpenses = 0;
    for (var doc in expensesSnapshot.docs) {
      totalExpenses += (doc.data()['amount'] ?? 0.0).toDouble();
    }

    return {
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
      'totalExpenses': totalExpenses,
      'netProfit': totalProfit - totalExpenses,
      'completedCount': completedCount.toDouble(),
      'returnedCount': returnedCount.toDouble(),
    };
  }

  /// ملخص المخزون الكامل
  Future<Map<String, dynamic>> getInventorySummary() async {
    final productsSnapshot = await _db.collection('products').get();

    int totalProducts = 0;
    int totalQty = 0;
    double totalCostValue = 0;
    double totalRetailValue = 0;
    int lowStockCount = 0;
    int outOfStockCount = 0;

    for (var doc in productsSnapshot.docs) {
      final data = doc.data();
      final int stock = data['currentStock'] ?? 0;
      final int minStock = data['minStock'] ?? 5;
      final double purchasePrice = (data['purchasePrice'] ?? 0.0).toDouble();
      final double retailPrice = (data['retailPrice'] ?? 0.0).toDouble();

      totalProducts++;
      totalQty += stock;
      totalCostValue += stock * purchasePrice;
      totalRetailValue += stock * retailPrice;

      if (stock == 0) {
        outOfStockCount++;
      } else if (stock <= minStock) {
        lowStockCount++;
      }
    }

    return {
      'totalProducts': totalProducts,
      'totalQty': totalQty,
      'totalCostValue': totalCostValue,
      'totalRetailValue': totalRetailValue,
      'potentialProfit': totalRetailValue - totalCostValue,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
    };
  }
}
