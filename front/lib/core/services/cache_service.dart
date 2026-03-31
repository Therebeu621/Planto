import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de cache local basique pour le mode hors-ligne.
/// Stocke les réponses JSON brutes dans SharedPreferences avec un timestamp.
class CacheService {
  static const String _prefix = 'cache_';
  static const String _tsPrefix = 'cache_ts_';

  /// Durée de validité du cache (4 heures)
  static const Duration cacheDuration = Duration(hours: 4);

  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  CacheService._();

  /// Sauvegarder une réponse JSON (liste) en cache
  Future<void> putList(String key, List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(data));
    await prefs.setInt('$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Sauvegarder un objet JSON en cache
  Future<void> putObject(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(data));
    await prefs.setInt('$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Récupérer une liste JSON depuis le cache (null si absent ou expiré)
  Future<List<dynamic>?> getList(String key) async {
    final raw = await _getRaw(key);
    if (raw == null) return null;
    return jsonDecode(raw) as List<dynamic>;
  }

  /// Récupérer un objet JSON depuis le cache (null si absent ou expiré)
  Future<Map<String, dynamic>?> getObject(String key) async {
    final raw = await _getRaw(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String?> _getRaw(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    final ts = prefs.getInt('$_tsPrefix$key');
    if (ts != null) {
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(cachedAt) > cacheDuration) {
        // Cache expiré — on le supprime
        await prefs.remove('$_prefix$key');
        await prefs.remove('$_tsPrefix$key');
        return null;
      }
    }
    return raw;
  }

  /// Vider tout le cache
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
