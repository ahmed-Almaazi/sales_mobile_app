class Customer {
  final String id;
  final String storeName; // اسم المحل
  final String contactName; // اسم المسؤول
  final String phone;
  final String region; // المنطقة
  final double balance; // الرصيد الحالي
  final double creditLimit; // الحد الائتماني
  final String notes;

  Customer({
    required this.id,
    required this.storeName,
    required this.contactName,
    required this.phone,
    this.region = '',
    this.balance = 0.0,
    this.creditLimit = 0.0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'contactName': contactName,
      'phone': phone,
      'region': region,
      'balance': balance,
      'creditLimit': creditLimit,
      'notes': notes,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      storeName: map['storeName'] ?? '',
      contactName: map['contactName'] ?? '',
      phone: map['phone'] ?? '',
      region: map['region'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      creditLimit: (map['creditLimit'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
    );
  }
}
