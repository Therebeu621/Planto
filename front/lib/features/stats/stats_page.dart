import 'package:flutter/material.dart';
import 'package:planto/core/services/stats_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class StatsPage extends StatefulWidget {
  final StatsService? statsService;

  const StatsPage({super.key, this.statsService});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with SingleTickerProviderStateMixin {
  late final StatsService _statsService = widget.statsService ?? StatsService();
  late TabController _tabController;

  Map<String, dynamic> _dashboard = {};
  Map<String, dynamic> _annualStats = {};
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _statsService.getDashboard(),
        _statsService.getAnnualStats(year: _selectedYear),
      ]);
      _dashboard = results[0];
      _annualStats = results[1];
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Retrospective'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(),
                _buildAnnualStats(),
              ],
            ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Plantes', '${_dashboard['totalPlants'] ?? 0}', Icons.eco, AppTheme.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('En forme', '${_dashboard['healthyPlants'] ?? 0}', Icons.favorite, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('A arroser', '${_dashboard['needsWateringToday'] ?? 0}', Icons.water_drop, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Malades', '${_dashboard['sickPlants'] ?? 0}', Icons.healing, Colors.red)),
            ],
          ),

          // Gamification
          const SizedBox(height: 24),
          _buildSectionTitle('Gamification'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildGamifCircle(_dashboard['level'] ?? 1, _dashboard['levelName'] ?? 'Graine'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_dashboard['xp'] ?? 0} XP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Streak: ${_dashboard['wateringStreak'] ?? 0} jours',
                            style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text('Badges: ${_dashboard['badgesUnlocked'] ?? 0}/${_dashboard['totalBadges'] ?? 12}',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rankings
          if ((_dashboard['houseRankings'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Classement maison'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (final r in _dashboard['houseRankings'] as List)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: r['rank'] == 1 ? Colors.amber : Colors.grey.shade200,
                        child: Text('${r['rank']}', style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: r['rank'] == 1 ? Colors.white : Colors.grey.shade700)),
                      ),
                      title: Text(r['userName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Niv. ${r['level']} - ${r['levelName'] ?? ''}'),
                      trailing: Text('${r['xp']} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],

          // Waterings last 7 days
          if ((_dashboard['wateringsLast7Days'] as Map?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Arrosages (7 derniers jours)'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in (_dashboard['wateringsLast7Days'] as Map).entries)
                      _buildBarChartItem(entry.key, entry.value ?? 0, 8),
                  ],
                ),
              ),
            ),
          ],

          // Recent activity
          if ((_dashboard['recentActivity'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Activite recente'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (final a in (_dashboard['recentActivity'] as List).take(10))
                    ListTile(
                      dense: true,
                      leading: _buildActivityIcon(a['type'] ?? ''),
                      title: Text('${a['userName'] ?? ''} ${a['description'] ?? ''} ${a['plantName'] ?? ''}',
                          style: const TextStyle(fontSize: 13)),
                      trailing: Text(a['timeAgo'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ),
          ],

          // Plants by room
          if ((_dashboard['plantsByRoom'] as Map?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Plantes par piece'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final entry in (_dashboard['plantsByRoom'] as Map).entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 14))),
                            Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: LinearProgressIndicator(
                                value: (_dashboard['totalPlants'] ?? 1) > 0
                                    ? (entry.value as int) / (_dashboard['totalPlants'] as int)
                                    : 0,
                                backgroundColor: Colors.grey.shade200,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAnnualStats() {
    if (_annualStats.isEmpty) {
      return Center(child: Text('Pas de donnees pour $_selectedYear', style: TextStyle(color: Colors.grey.shade600)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Year selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear--);
                  _loadData();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$_selectedYear', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: _selectedYear < DateTime.now().year ? () {
                  setState(() => _selectedYear++);
                  _loadData();
                } : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Arrosages', '${_annualStats['totalWaterings'] ?? 0}', Icons.water_drop, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Soins', '${_annualStats['totalCareActions'] ?? 0}', Icons.healing, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Plantes +', '${_annualStats['plantsAdded'] ?? 0}', Icons.add_circle, AppTheme.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Meilleur streak', '${_annualStats['bestStreak'] ?? 0}j', Icons.local_fire_department, Colors.orange)),
            ],
          ),

          if (_annualStats['mostCaredPlant'] != null) ...[
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.star, color: Colors.amber)),
                title: Text('Plante la plus soignee: ${_annualStats['mostCaredPlant']}'),
                subtitle: Text('${_annualStats['mostCaredPlantActions']} actions'),
              ),
            ),
          ],

          // Monthly waterings
          if ((_annualStats['wateringsByMonth'] as Map?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Arrosages par mois'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in (_annualStats['wateringsByMonth'] as Map).entries)
                      _buildBarChartItem(entry.key.toString().substring(0, 1), entry.value ?? 0, 50),
                  ],
                ),
              ),
            ),
          ],

          // Care actions breakdown
          if ((_annualStats['careActionsByType'] as Map?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Types de soins'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final entry in (_annualStats['careActionsByType'] as Map).entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            _buildActivityIcon(entry.key),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_careActionLabel(entry.key), style: const TextStyle(fontSize: 14))),
                            Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGamifCircle(int level, String name) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildBarChartItem(String label, int value, int maxExpected) {
    final height = maxExpected > 0 ? (value / maxExpected * 80).clamp(4.0, 80.0) : 4.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 20, height: height,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildActivityIcon(String type) {
    final icons = {
      'WATERING': Icons.water_drop,
      'FERTILIZING': Icons.spa,
      'PRUNING': Icons.content_cut,
      'TREATMENT': Icons.healing,
      'REPOTTING': Icons.yard,
      'NOTE': Icons.note,
    };
    final colors = {
      'WATERING': Colors.blue,
      'FERTILIZING': Colors.green,
      'PRUNING': Colors.purple,
      'TREATMENT': Colors.red,
      'REPOTTING': Colors.brown,
      'NOTE': Colors.blueGrey,
    };
    return CircleAvatar(
      radius: 14,
      backgroundColor: (colors[type] ?? Colors.grey).withOpacity(0.1),
      child: Icon(icons[type] ?? Icons.eco, size: 14, color: colors[type] ?? Colors.grey),
    );
  }

  String _careActionLabel(String type) {
    return {
      'WATERING': 'Arrosages',
      'FERTILIZING': 'Fertilisations',
      'PRUNING': 'Tailles',
      'TREATMENT': 'Traitements',
      'REPOTTING': 'Rempotages',
      'NOTE': 'Notes',
    }[type] ?? type;
  }
}
