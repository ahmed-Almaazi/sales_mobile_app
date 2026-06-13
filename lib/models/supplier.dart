class Supplier {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String email;
  final double balance; // الرصيد الحالي للمورد
  final String notes;

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.email = '',
    this.balance = 0.0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'balance': balance,
      'notes': notes,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map, String id) {
    return Supplier(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      email: map['email'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
    );
  }
}
