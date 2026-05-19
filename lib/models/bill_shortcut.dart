class BillShortcut {
  final String id;
  final String label;
  final String recipient; // phone number or MoMo code
  final double? defaultAmount;
  final String? icon; // emoji or icon name

  const BillShortcut({
    required this.id,
    required this.label,
    required this.recipient,
    this.defaultAmount,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'recipient': recipient,
        if (defaultAmount != null) 'defaultAmount': defaultAmount,
        if (icon != null) 'icon': icon,
      };

  factory BillShortcut.fromJson(Map<String, dynamic> json) => BillShortcut(
        id: json['id'] as String,
        label: json['label'] as String,
        recipient: json['recipient'] as String,
        defaultAmount: (json['defaultAmount'] as num?)?.toDouble(),
        icon: json['icon'] as String?,
      );
}
