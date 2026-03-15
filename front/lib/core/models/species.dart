/// Species model for plant species from Trefle API
class Species {
  final String id;
  final int? trefleId;
  final String commonName;
  final String? scientificName;
  final String? family;
  final String? genus;
  final String? imageUrl;

  Species({
    required this.id,
    this.trefleId,
    required this.commonName,
    this.scientificName,
    this.family,
    this.genus,
    this.imageUrl,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    // Handle both Trefle (id is UUID string) and Perenual (id is null, use trefleId)
    String id;
    if (json['id'] != null) {
      id = json['id'] as String;
    } else if (json['trefleId'] != null) {
      // Use Perenual ID as fallback identifier
      id = 'perenual_${json['trefleId']}';
    } else {
      id = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }

    return Species(
      id: id,
      trefleId: json['trefleId'] as int?,
      commonName: json['commonName'] as String? ?? 'Espèce inconnue',
      scientificName: json['scientificName'] as String?,
      family: json['family'] as String?,
      genus: json['genus'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// Display name showing common name with scientific name if available
  String get displayName {
    if (scientificName != null && scientificName!.isNotEmpty) {
      return '$commonName ($scientificName)';
    }
    return commonName;
  }
}
