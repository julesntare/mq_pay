class UssdServiceShortcut {
  final String id;
  final String label; // "Cash Power", "Yego Cab", ...
  final String serviceKey; // 'umutekano' | 'efashe' | 'canalbox' | 'yego' | 'custom:<id>'
  final String? ussdCode; // null = no-dial / manual-trigger service (e.g. Yego Cab)
  final String? defaultUssdCode; // set for built-ins, used by "reset to default"
  final String? icon;
  final bool isBuiltIn;
  final bool isFavorite; // pinned to the home-screen quick-access row
  final double? fee; // flat fee applied to this service's transactions; null/unset = 0

  const UssdServiceShortcut({
    required this.id,
    required this.label,
    required this.serviceKey,
    this.ussdCode,
    this.defaultUssdCode,
    this.icon,
    this.isBuiltIn = false,
    this.isFavorite = false,
    this.fee,
  });

  UssdServiceShortcut copyWith({
    String? label,
    String? ussdCode,
    bool clearUssdCode = false,
    String? icon,
    bool? isFavorite,
    double? fee,
    bool clearFee = false,
  }) {
    return UssdServiceShortcut(
      id: id,
      label: label ?? this.label,
      serviceKey: serviceKey,
      ussdCode: clearUssdCode ? null : (ussdCode ?? this.ussdCode),
      defaultUssdCode: defaultUssdCode,
      icon: icon ?? this.icon,
      isBuiltIn: isBuiltIn,
      isFavorite: isFavorite ?? this.isFavorite,
      fee: clearFee ? null : (fee ?? this.fee),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'serviceKey': serviceKey,
        if (ussdCode != null) 'ussdCode': ussdCode,
        if (defaultUssdCode != null) 'defaultUssdCode': defaultUssdCode,
        if (icon != null) 'icon': icon,
        'isBuiltIn': isBuiltIn,
        'isFavorite': isFavorite,
        if (fee != null) 'fee': fee,
      };

  factory UssdServiceShortcut.fromJson(Map<String, dynamic> json) =>
      UssdServiceShortcut(
        id: json['id'] as String,
        label: json['label'] as String,
        serviceKey: json['serviceKey'] as String,
        ussdCode: json['ussdCode'] as String?,
        defaultUssdCode: json['defaultUssdCode'] as String?,
        icon: json['icon'] as String?,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        fee: json['fee'] != null ? (json['fee'] as num).toDouble() : null,
      );
}
