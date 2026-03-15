/// Resultat de l'identification d'une plante par IA (Gemini)
class PlantIdentificationResult {
  final String petitNom;
  final String espece;
  final int arrosageJours;
  final String luminosite;
  final String description;

  PlantIdentificationResult({
    required this.petitNom,
    required this.espece,
    required this.arrosageJours,
    required this.luminosite,
    required this.description,
  });

  /// Parse depuis le JSON retourne par Gemini
  factory PlantIdentificationResult.fromJson(Map<String, dynamic> json) {
    return PlantIdentificationResult(
      petitNom: json['petit_nom'] as String? ?? 'Ma plante',
      espece: json['espece'] as String? ?? 'Espece inconnue',
      arrosageJours: json['arrosage_jours'] as int? ?? 7,
      luminosite: json['luminosite'] as String? ?? 'Mi-ombre',
      description: json['description'] as String? ?? '',
    );
  }

  /// Convertit la luminosite Gemini vers la valeur du formulaire
  String get exposureValue {
    switch (luminosite.toLowerCase()) {
      case 'plein soleil':
        return 'SUN';
      case 'ombre':
        return 'SHADE';
      case 'mi-ombre':
      default:
        return 'PARTIAL_SHADE';
    }
  }

  @override
  String toString() {
    return 'PlantIdentificationResult(petitNom: $petitNom, espece: $espece, arrosageJours: $arrosageJours, luminosite: $luminosite)';
  }
}
