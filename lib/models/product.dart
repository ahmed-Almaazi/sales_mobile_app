class Product {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final String manufacturer;
  final String color;
  final String model;
  final String description;
  final double purchasePrice; // سعر الشراء
  final double wholesalePrice; // سعر الجملة
  final double retailPrice; // سعر التجزئة (سعر البيع)
  final double representativePrice; // سعر المندوب
  final int currentStock;
  final int minStock;
  final String? imageUrl;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    this.category = '',
    this.manufacturer = '',
    this.color = '',
    this.model = '',
    this.description = '',
    required this.purchasePrice,
    required this.wholesalePrice,
    required this.retailPrice,
    required this.representativePrice,
    required this.currentStock,
    this.minStock = 5,
    this.imageUrl,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'category': category,
      'manufacturer': manufacturer,
      'color': color,
      'model': model,
      'description': description,
      'purchasePrice': purchasePrice,
      'wholesalePrice': wholesalePrice,
      'retailPrice': retailPrice,
      'representativePrice': representativePrice,
      'currentStock': currentStock,
      'minStock': minStock,
      'imageUrl': imageUrl,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      category: map['category'] ?? '',
      manufacturer: map['manufacturer'] ?? '',
      color: map['color'] ?? '',
      model: map['model'] ?? '',
      description: map['description'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      wholesalePrice: (map['wholesalePrice'] ?? 0).toDouble(),
      retailPrice: (map['retailPrice'] ?? 0).toDouble(),
      representativePrice: (map['representativePrice'] ?? 0).toDouble(),
      currentStock: map['currentStock'] ?? 0,
      minStock: map['minStock'] ?? 5,
      imageUrl: map['imageUrl'],
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as dynamic).toDate() : null,
    );
  }
}
