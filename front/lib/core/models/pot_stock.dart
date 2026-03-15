/// Pot stock model - represents a pot entry in the house inventory
class PotStock {
  final String id;
  final double diameterCm;
  final int quantity;
  final String? label;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PotStock({
    required this.id,
    required this.diameterCm,
    required this.quantity,
    this.label,
    this.createdAt,
    this.updatedAt,
  });

  factory PotStock.fromJson(Map<String, dynamic> json) {
    return PotStock(
      id: json['id'] as String,
      diameterCm: (json['diameterCm'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 0,
      label: json['label'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Display text like "14 cm (x3)"
  String get displayText {
    final labelPart = label != null && label!.isNotEmpty ? ' - $label' : '';
    return '${diameterCm.toStringAsFixed(diameterCm.truncateToDouble() == diameterCm ? 0 : 1)} cm (x$quantity)$labelPart';
  }

  /// Short display "14 cm"
  String get sizeDisplay {
    return '${diameterCm.toStringAsFixed(diameterCm.truncateToDouble() == diameterCm ? 0 : 1)} cm';
  }

  bool get isAvailable => quantity > 0;
}
