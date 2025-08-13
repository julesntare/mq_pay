class Store {
  final String id;
  final String name;
  final String paymentCode;
  final String paymentType;
  final double latitude;
  final double longitude;
  final String? address;
  final String? description;
  final List<String>? categories;
  final String? phoneNumber;
  final Map<String, String>? openingHours;
  final bool isActive;
  final DateTime? lastUpdated;

  // Calculated fields
  double? distance;
  bool isFavorite;

  Store({
    required this.id,
    required this.name,
    required this.paymentCode,
    required this.paymentType,
    required this.latitude,
    required this.longitude,
    this.address,
    this.description,
    this.categories,
    this.phoneNumber,
    this.openingHours,
    this.isActive = true,
    this.lastUpdated,
    this.distance,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'paymentCode': paymentCode,
      'paymentType': paymentType,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'description': description,
      'categories': categories,
      'phoneNumber': phoneNumber,
      'openingHours': openingHours,
      'isActive': isActive,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'distance': distance,
      'isFavorite': isFavorite,
    };
  }

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      paymentCode: json['paymentCode'] as String,
      paymentType: json['paymentType'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      description: json['description'] as String?,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : null,
      phoneNumber: json['phoneNumber'] as String?,
      openingHours: json['openingHours'] != null
          ? Map<String, String>.from(json['openingHours'])
          : null,
      isActive: json['isActive'] as bool? ?? true,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
      distance: json['distance'] as double?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Store copyWith({
    String? id,
    String? name,
    String? paymentCode,
    String? paymentType,
    double? latitude,
    double? longitude,
    String? address,
    String? description,
    List<String>? categories,
    String? phoneNumber,
    Map<String, String>? openingHours,
    bool? isActive,
    DateTime? lastUpdated,
    double? distance,
    bool? isFavorite,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      paymentCode: paymentCode ?? this.paymentCode,
      paymentType: paymentType ?? this.paymentType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      openingHours: openingHours ?? this.openingHours,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      distance: distance ?? this.distance,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
