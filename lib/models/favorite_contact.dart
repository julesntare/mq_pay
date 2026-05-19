class FavoriteContact {
  final String name;
  final String phoneNumber;
  final String? originalPhone;

  const FavoriteContact({
    required this.name,
    required this.phoneNumber,
    this.originalPhone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phoneNumber': phoneNumber,
        if (originalPhone != null) 'originalPhone': originalPhone,
      };

  factory FavoriteContact.fromJson(Map<String, dynamic> json) =>
      FavoriteContact(
        name: json['name'] as String,
        phoneNumber: json['phoneNumber'] as String,
        originalPhone: json['originalPhone'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is FavoriteContact && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;
}
