import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:planto/core/services/garden_service.dart';
import 'package:planto/core/services/gemini_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GardenPage extends StatefulWidget {
  final GardenService? gardenService;
  final HouseService? houseService;

  const GardenPage({super.key, this.gardenService, this.houseService});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  late final GardenService _gardenService =
      widget.gardenService ?? GardenService();
  late final HouseService _houseService =
      widget.houseService ?? HouseService();
  final GeminiService _geminiService = GeminiService();

  List<Map<String, dynamic>> _cultures = [];
  bool _isLoading = true;
  String? _houseId;
  String _filterStatus = 'ALL';

  // Base de données plantes chargée depuis l'asset JSON
  List<Map<String, dynamic>> _plantsDb = [];
  // Liste complète de noms pour l'autocomplétion
  List<String> _plantNames = [];

  // Cache des conseils Gemini par culture+status
  final Map<String, Map<String, dynamic>> _adviceCache = {};

  static const _statusFilters = [
    'ALL',
    'SEMIS',
    'GERMINATION',
    'CROISSANCE',
    'FLORAISON',
    'RECOLTE',
    'TERMINE'
  ];
  static const _statusLabels = {
    'ALL': 'Tout',
    'SEMIS': 'Semis',
    'GERMINATION': 'Germination',
    'CROISSANCE': 'Croissance',
    'FLORAISON': 'Floraison',
    'RECOLTE': 'Recolte',
    'TERMINE': 'Termine',
  };
  static const _statusColors = {
    'SEMIS': Colors.brown,
    'GERMINATION': Colors.lightGreen,
    'CROISSANCE': Colors.green,
    'FLORAISON': Colors.pink,
    'RECOLTE': Colors.orange,
    'TERMINE': Colors.grey,
  };
  static const _statusIcons = {
    'SEMIS': Icons.grass,
    'GERMINATION': Icons.eco,
    'CROISSANCE': Icons.trending_up,
    'FLORAISON': Icons.local_florist,
    'RECOLTE': Icons.agriculture,
    'TERMINE': Icons.check_circle,
  };

  static const _allStatuses = [
    'SEMIS',
    'GERMINATION',
    'CROISSANCE',
    'FLORAISON',
    'RECOLTE',
    'TERMINE'
  ];

  @override
  void initState() {
    super.initState();
    _loadPlantsDb();
    _loadCachedAdvice();
    _loadData();
  }

  Future<void> _loadPlantsDb() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/plants-database.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _plantsDb = List<Map<String, dynamic>>.from(data['plants'] ?? []);
    } catch (e) {
      debugPrint('Erreur chargement plants-database.json: $e');
    }
    try {
      final namesStr = await rootBundle.loadString('assets/plants-names-only.json');
      final names = (jsonDecode(namesStr) as List).cast<String>();
      setState(() => _plantNames = names);
    } catch (e) {
      debugPrint('Erreur chargement plants-names-only.json: $e');
      // Fallback sur l'ancienne base
      setState(() => _plantNames = _plantsDb.map((p) => p['name'] as String).toList());
    }
  }

  /// Trouve une plante dans la base par nom (recherche flexible)
  Map<String, dynamic>? _findPlantInDb(String name) {
    final lower = name.toLowerCase().trim();
    return _plantsDb.cast<Map<String, dynamic>?>().firstWhere(
      (p) => (p!['name'] as String).toLowerCase() == lower,
      orElse: () => null,
    );
  }

  Future<void> _loadCachedAdvice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('garden_advice_cache');
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _adviceCache[entry.key] = entry.value as Map<String, dynamic>;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCachedAdvice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('garden_advice_cache', jsonEncode(_adviceCache));
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final houses = await _houseService.getMyHouses();
      debugPrint('GardenPage: ${houses.length} maisons trouvées, houseId=${houses.isNotEmpty ? houses.first.id : "AUCUNE"}');
      if (houses.isNotEmpty) {
        _houseId = houses.first.id;
        if (_houseId != null) {
          final status = _filterStatus == 'ALL' ? null : _filterStatus;
          _cultures =
              await _gardenService.getCultures(_houseId!, status: status);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _adviceCacheKey(String plantName, String status) =>
      '${plantName.toLowerCase().trim()}_$status';

  Future<Map<String, dynamic>?> _getAdvice(
      Map<String, dynamic> culture) async {
    final plantName = culture['plantName'] as String? ?? '';
    final status = culture['status'] as String? ?? '';
    final key = _adviceCacheKey(plantName, status);

    if (_adviceCache.containsKey(key)) return _adviceCache[key];

    try {
      final advice = await _geminiService.getGardenAdvice(
        plantName: plantName,
        variety: culture['variety'] as String?,
        status: status,
        sowDate: culture['sowDate'] as String?,
        notes: culture['notes'] as String?,
      );
      _adviceCache[key] = advice;
      _saveCachedAdvice();
      return advice;
    } catch (e) {
      debugPrint('GardenPage: Erreur conseils IA - $e');
      return null;
    }
  }

  Future<void> _showAddDialog() async {
    debugPrint('GardenPage: _showAddDialog appelé, _houseId=$_houseId');
    if (_houseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez d\'abord créer une maison depuis la page d\'accueil pour utiliser le potager.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final nameController = TextEditingController();
    final varietyController = TextEditingController();
    final notesController = TextEditingController();
    Map<String, dynamic>? selectedPlant;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grass, color: Colors.brown),
              ),
              const SizedBox(width: 12),
              const Flexible(child: Text('Nouveau semis')),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la plante *',
                      prefixIcon: Icon(Icons.eco),
                      hintText: 'Ex: Ma tomate du balcon',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _plantNames.where((plant) =>
                          plant.toLowerCase().startsWith(query)).take(10);
                    },
                    onSelected: (name) {
                      varietyController.text = name;
                      setDialogState(() {
                        selectedPlant = _findPlantInDb(name);
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      controller.addListener(() => varietyController.text = controller.text);
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Espèce / Variété *',
                          prefixIcon: Icon(Icons.category),
                          hintText: 'Ex: Tomate Cerise, Basilic...',
                        ),
                        onChanged: (value) {
                          final found = _findPlantInDb(value);
                          if (found != null) {
                            setDialogState(() => selectedPlant = found);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Fiche info si plante reconnue dans la base détaillée
                  if (selectedPlant != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedPlant!['latin'] != null)
                            Text(
                              selectedPlant!['latin'],
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (selectedPlant!['exposure'] != null)
                                _buildInfoChip(Icons.wb_sunny, selectedPlant!['exposure']),
                              if (selectedPlant!['watering'] != null)
                                _buildInfoChip(Icons.water_drop, selectedPlant!['watering']),
                              if (selectedPlant!['difficulty'] != null)
                                _buildInfoChip(Icons.speed, selectedPlant!['difficulty']),
                              if (selectedPlant!['germination_days'] != null)
                                _buildInfoChip(Icons.timer, 'Germination: ${selectedPlant!['germination_days']}j'),
                              if (selectedPlant!['harvest_days'] != null)
                                _buildInfoChip(Icons.agriculture, 'Récolte: ${selectedPlant!['harvest_days']}j'),
                              if (selectedPlant!['spacing_cm'] != null)
                                _buildInfoChip(Icons.straighten, '${selectedPlant!['spacing_cm']}cm'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                        labelText: 'Notes', prefixIcon: Icon(Icons.note)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Semer'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty && varietyController.text.isNotEmpty) {
      try {
        await _gardenService.createCulture(_houseId!, {
          'plantName': nameController.text.trim(),
          'variety': varietyController.text.trim().isEmpty
              ? null
              : varietyController.text.trim(),
          'notes': notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        });
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Semis ajoute !')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Future<void> _showStatusUpdate(Map<String, dynamic> culture) async {
    final currentStatus = culture['status'] as String;
    final currentIdx = _allStatuses.indexOf(currentStatus);
    if (currentIdx >= _allStatuses.length - 1) return;

    final nextStatus = _allStatuses[currentIdx + 1];
    final notesController = TextEditingController();
    final harvestController = TextEditingController();
    final heightController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_statusIcons[nextStatus], color: _statusColors[nextStatus]),
            const SizedBox(width: 10),
            Flexible(
                child: Text('Passer a: ${_statusLabels[nextStatus]}')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${culture['plantName']}${culture['variety'] != null ? ' - ${culture['variety']}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: heightController,
                decoration: const InputDecoration(
                  labelText: 'Hauteur (cm)',
                  prefixIcon: Icon(Icons.straighten),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                    labelText: 'Observations',
                    prefixIcon: Icon(Icons.note)),
                maxLines: 2,
              ),
              if (nextStatus == 'RECOLTE' || nextStatus == 'TERMINE') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: harvestController,
                  decoration: const InputDecoration(
                      labelText: 'Quantite recoltee',
                      prefixIcon: Icon(Icons.scale)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _statusColors[nextStatus]),
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final data = <String, dynamic>{'newStatus': nextStatus};
        if (notesController.text.isNotEmpty) {
          data['notes'] = notesController.text;
        }
        if (heightController.text.isNotEmpty) {
          data['heightCm'] = double.tryParse(heightController.text);
        }
        if (harvestController.text.isNotEmpty) {
          data['harvestQuantity'] = harvestController.text;
        }
        await _gardenService.updateStatus(culture['id'], data);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Future<void> _showAdviceSheet(Map<String, dynamic> culture) async {
    final plantName = culture['plantName'] as String? ?? '';
    final status = culture['status'] as String? ?? '';
    final color = _statusColors[status] ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => FutureBuilder<Map<String, dynamic>?>(
          future: _getAdvice(culture),
          builder: (ctx, snapshot) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.lightbulb_outline, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conseils pour $plantName',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Etape: ${_statusLabels[status] ?? status}',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('L\'IA analyse ta plante...'),
                          ],
                        ),
                      ),
                    )
                  else if (snapshot.data == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_off,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('Conseils indisponibles',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildAdviceContent(snapshot.data!, culture),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdviceContent(Map<String, dynamic> advice, Map<String, dynamic> culture) {
    // Calculer la date estimée de fin d'étape
    String dureeText = '${advice['duree_estimee_jours'] ?? '?'} jours environ';
    final dureeJours = advice['duree_estimee_jours'];
    final sowDateStr = culture['sowDate'] as String?;
    if (dureeJours is int && sowDateStr != null) {
      try {
        final sowDate = DateTime.parse(sowDateStr);
        final estimatedDate = sowDate.add(Duration(days: dureeJours));
        final dateFormatted = '${estimatedDate.day.toString().padLeft(2, '0')}/${estimatedDate.month.toString().padLeft(2, '0')}/${estimatedDate.year}';
        dureeText = '$dureeJours jours environ\n(estimee vers le $dateFormatted)';
      } catch (_) {}
    }

    return Column(
      children: [
        _buildAdviceCard(
          icon: Icons.timer_outlined,
          color: Colors.blue,
          title: 'Duree estimee de cette etape',
          content: dureeText,
        ),
        const SizedBox(height: 12),
        _buildAdviceCard(
          icon: Icons.tips_and_updates,
          color: Colors.amber.shade700,
          title: 'Conseils',
          content:
              advice['conseils'] as String? ?? 'Pas de conseils disponibles',
        ),
        const SizedBox(height: 12),
        _buildAdviceCard(
          icon: Icons.water_drop_outlined,
          color: Colors.blue.shade600,
          title: 'Arrosage',
          content: advice['arrosage_conseil'] as String? ?? '-',
        ),
        const SizedBox(height: 12),
        _buildAdviceCard(
          icon: Icons.thermostat,
          color: Colors.red.shade400,
          title: 'Temperature ideale',
          content: advice['temperature_ideale'] as String? ?? '-',
        ),
        const SizedBox(height: 12),
        _buildAdviceCard(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          title: 'Erreurs a eviter',
          content: advice['erreurs_courantes'] as String? ?? '-',
        ),
        const SizedBox(height: 12),
        _buildAdviceCard(
          icon: Icons.arrow_circle_right_outlined,
          color: Colors.green,
          title: 'Quand passer a l\'etape suivante ?',
          content: advice['prochaine_etape_signe'] as String? ?? '-',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Potager'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
      ]),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _statusFilters
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_statusLabels[s] ?? s),
                          selected: _filterStatus == s,
                          selectedColor: (s == 'ALL'
                                  ? AppTheme.primaryColor
                                  : _statusColors[s] ?? Colors.grey)
                              .withOpacity(0.2),
                          onSelected: (v) {
                            setState(() => _filterStatus = s);
                            _loadData();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cultures.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grass,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Aucune culture',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _showAddDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Premier semis'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cultures.length,
                          itemBuilder: (ctx, i) =>
                              _buildCultureCard(_cultures[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCultureCard(Map<String, dynamic> culture) {
    final status = culture['status'] as String;
    final color = _statusColors[status] ?? Colors.grey;
    final icon = _statusIcons[status] ?? Icons.eco;
    final growthLogs = culture['growthLogs'] as List? ?? [];

    // Calculate progression
    final currentIdx = _allStatuses.indexOf(status);

    // Calculate days since sow
    int? daysSinceSow;
    if (culture['sowDate'] != null) {
      try {
        final sowDate = DateTime.parse(culture['sowDate']);
        daysSinceSow = DateTime.now().difference(sowDate).inDays;
      } catch (_) {}
    }

    // Durées moyennes par étape (en jours) pour estimation
    const defaultStageDurations = {
      'SEMIS': 10,
      'GERMINATION': 14,
      'CROISSANCE': 45,
      'FLORAISON': 30,
      'RECOLTE': 20,
    };

    // Calculer la date estimée de prochaine étape
    String? estimatedDateStr;
    if (culture['sowDate'] != null && status != 'TERMINE') {
      try {
        final sowDate = DateTime.parse(culture['sowDate']);
        // Additionner les durées des étapes précédentes + étape courante
        int totalDays = 0;
        for (final s in _allStatuses) {
          totalDays += defaultStageDurations[s] ?? 0;
          if (s == status) break;
        }
        final estimatedDate = sowDate.add(Duration(days: totalDays));
        estimatedDateStr = '${estimatedDate.day.toString().padLeft(2, '0')}/${estimatedDate.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // Extract heights from growth logs for mini chart
    final heights = <double>[];
    for (final log in growthLogs.reversed) {
      if (log['heightCm'] != null) {
        heights.add((log['heightCm'] as num).toDouble());
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: AppTheme.shadow(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAdviceSheet(culture),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + name + status badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          culture['plantName'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        if (culture['variety'] != null)
                          Text(culture['variety'],
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      culture['statusDisplay'] ?? status,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progress bar with stage labels
              _buildProgressBar(currentIdx, color),

              const SizedBox(height: 14),

              // Info chips row
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (daysSinceSow != null)
                    _buildInfoChip(Icons.calendar_today,
                        '$daysSinceSow jour${daysSinceSow > 1 ? 's' : ''}'),
                  if (culture['sowDate'] != null)
                    _buildInfoChip(
                        Icons.eco_outlined, 'Seme: ${culture['sowDate']}'),
                  if (culture['expectedHarvestDate'] != null)
                    _buildInfoChip(Icons.event,
                        'Recolte: ${culture['expectedHarvestDate']}'),
                  if (culture['harvestQuantity'] != null)
                    _buildInfoChip(
                        Icons.scale, 'Recolte: ${culture['harvestQuantity']}'),
                  if (heights.isNotEmpty)
                    _buildInfoChip(Icons.straighten,
                        '${heights.last.toStringAsFixed(0)} cm'),
                  if (estimatedDateStr != null && status != 'TERMINE')
                    _buildInfoChip(Icons.event_outlined,
                        'Etape suiv. ~$estimatedDateStr'),
                ],
              ),

              // Mini height chart
              if (heights.length >= 2) ...[
                const SizedBox(height: 14),
                _buildMiniHeightChart(heights, color),
              ],

              // Growth logs
              if (growthLogs.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildGrowthTimeline(growthLogs, status),
              ],

              // Action buttons
              const SizedBox(height: 12),
              Row(
                children: [
                  // Advice button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAdviceSheet(culture),
                      icon: const Icon(Icons.lightbulb_outline, size: 16),
                      label: const Text('Conseils IA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (status != 'TERMINE') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showStatusUpdate(culture),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Etape suivante'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int currentIdx, Color color) {
    return Column(
      children: [
        // Stage dots
        Row(
          children: List.generate(_allStatuses.length, (i) {
            final isCompleted = i <= currentIdx;
            final isCurrent = i == currentIdx;
            return Expanded(
              child: Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i <= currentIdx
                            ? color
                            : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: isCurrent ? 14 : 10,
                    height: isCurrent ? 14 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? color : Colors.grey.shade300,
                      border: isCurrent
                          ? Border.all(color: color, width: 2)
                          : null,
                    ),
                    child: isCompleted && !isCurrent
                        ? const Icon(Icons.check, size: 7, color: Colors.white)
                        : null,
                  ),
                  if (i < _allStatuses.length - 1 && i == 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: 1 <= currentIdx
                            ? color
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        // Stage labels
        Row(
          children: _allStatuses
              .map((s) => Expanded(
                    child: Text(
                      s == 'GERMINATION'
                          ? 'Germ.'
                          : s == 'CROISSANCE'
                              ? 'Crois.'
                              : s == 'FLORAISON'
                                  ? 'Flor.'
                                  : _statusLabels[s] ?? s,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        color: _allStatuses.indexOf(s) <= currentIdx
                            ? _statusColors[s]
                            : Colors.grey.shade400,
                        fontWeight: s == _allStatuses[currentIdx]
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMiniHeightChart(List<double> heights, Color color) {
    final maxH = heights.reduce((a, b) => a > b ? a : b);
    if (maxH <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Croissance',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
              const Spacer(),
              Text('${heights.last.toStringAsFixed(1)} cm',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: CustomPaint(
              size: const Size(double.infinity, 40),
              painter: _HeightChartPainter(heights, color, maxH),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTimeline(List growthLogs, String currentStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historique (${growthLogs.length})',
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        ...growthLogs.take(4).map((log) {
          final logStatus = log['newStatus'] as String? ??
              log['newStatusDisplay'] as String? ??
              '';
          final logColor = _statusColors[logStatus] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: logColor,
                      ),
                    ),
                    Container(width: 1, height: 20, color: Colors.grey.shade300),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              log['newStatusDisplay'] ?? logStatus,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: logColor),
                            ),
                          ),
                          if (log['heightCm'] != null) ...[
                            const SizedBox(width: 8),
                            Text('${log['heightCm']} cm',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                      if (log['notes'] != null)
                        Text(
                          log['notes'],
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

}

/// Custom painter for mini height chart
class _HeightChartPainter extends CustomPainter {
  final List<double> heights;
  final Color color;
  final double maxHeight;

  _HeightChartPainter(this.heights, this.color, this.maxHeight);

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < heights.length; i++) {
      final x = (i / (heights.length - 1)) * size.width;
      final y = size.height - (heights[i] / maxHeight) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < heights.length; i++) {
      final x = (i / (heights.length - 1)) * size.width;
      final y = size.height - (heights[i] / maxHeight) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
