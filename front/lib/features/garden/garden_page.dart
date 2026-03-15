import 'package:flutter/material.dart';
import 'package:planto/core/services/garden_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class GardenPage extends StatefulWidget {
  final GardenService? gardenService;
  final HouseService? houseService;

  const GardenPage({super.key, this.gardenService, this.houseService});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  late final GardenService _gardenService = widget.gardenService ?? GardenService();
  late final HouseService _houseService = widget.houseService ?? HouseService();

  List<Map<String, dynamic>> _cultures = [];
  bool _isLoading = true;
  String? _houseId;
  String _filterStatus = 'ALL';

  static const _statusFilters = ['ALL', 'SEMIS', 'GERMINATION', 'CROISSANCE', 'FLORAISON', 'RECOLTE', 'TERMINE'];
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final houses = await _houseService.getMyHouses();
      if (houses.isNotEmpty) {
        _houseId = houses.first.id;
        if (_houseId != null) {
          final status = _filterStatus == 'ALL' ? null : _filterStatus;
          _cultures = await _gardenService.getCultures(_houseId!, status: status);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    if (_houseId == null) return;
    final nameController = TextEditingController();
    final varietyController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouveau semis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom de la plante *', prefixIcon: Icon(Icons.eco)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: varietyController,
                decoration: const InputDecoration(labelText: 'Variete', prefixIcon: Icon(Icons.category)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note)),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Semer'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await _gardenService.createCulture(_houseId!, {
          'plantName': nameController.text.trim(),
          'variety': varietyController.text.trim().isEmpty ? null : varietyController.text.trim(),
          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        });
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semis ajoute')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Future<void> _showStatusUpdate(Map<String, dynamic> culture) async {
    final currentStatus = culture['status'] as String;
    final statuses = ['SEMIS', 'GERMINATION', 'CROISSANCE', 'FLORAISON', 'RECOLTE', 'TERMINE'];
    final currentIdx = statuses.indexOf(currentStatus);
    if (currentIdx >= statuses.length - 1) return;

    final nextStatus = statuses[currentIdx + 1];
    final notesController = TextEditingController();
    final harvestController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Passer a: ${_statusLabels[nextStatus]}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${culture['plantName']}${culture['variety'] != null ? ' - ${culture['variety']}' : ''}'),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note)),
                maxLines: 2,
              ),
              if (nextStatus == 'RECOLTE' || nextStatus == 'TERMINE') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: harvestController,
                  decoration: const InputDecoration(labelText: 'Quantite recoltee', prefixIcon: Icon(Icons.scale)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _statusColors[nextStatus]),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _gardenService.updateStatus(culture['id'], {
          'newStatus': nextStatus,
          'notes': notesController.text.isNotEmpty ? notesController.text : null,
          'harvestQuantity': harvestController.text.isNotEmpty ? harvestController.text : null,
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
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
              children: _statusFilters.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_statusLabels[s] ?? s),
                  selected: _filterStatus == s,
                  selectedColor: (s == 'ALL' ? AppTheme.primaryColor : _statusColors[s] ?? Colors.grey).withOpacity(0.2),
                  onSelected: (v) {
                    setState(() => _filterStatus = s);
                    _loadData();
                  },
                ),
              )).toList(),
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
                            Icon(Icons.grass, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Aucune culture', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
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
                          itemBuilder: (ctx, i) => _buildCultureCard(_cultures[i]),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: status != 'TERMINE' ? () => _showStatusUpdate(culture) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        if (culture['variety'] != null)
                          Text(culture['variety'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      culture['statusDisplay'] ?? status,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (culture['sowDate'] != null || culture['expectedHarvestDate'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (culture['sowDate'] != null)
                      _buildInfoChip(Icons.calendar_today, 'Seme: ${culture['sowDate']}'),
                    if (culture['expectedHarvestDate'] != null) ...[
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.event, 'Recolte: ${culture['expectedHarvestDate']}'),
                    ],
                  ],
                ),
              ],
              if (culture['harvestQuantity'] != null) ...[
                const SizedBox(height: 8),
                _buildInfoChip(Icons.scale, 'Recolte: ${culture['harvestQuantity']}'),
              ],
              if (growthLogs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Historique (${growthLogs.length})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                ...growthLogs.take(3).map((log) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${log['newStatusDisplay'] ?? log['newStatus']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      if (log['notes'] != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log['notes'],
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
              ],
              if (status != 'TERMINE') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showStatusUpdate(culture),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Etape suivante'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
