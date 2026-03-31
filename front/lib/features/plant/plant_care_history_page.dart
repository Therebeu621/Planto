import 'package:flutter/material.dart';
import 'package:planto/core/models/care_log.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class PlantCareHistoryPage extends StatefulWidget {
  final String plantId;
  final String plantName;
  final bool canManage;
  final PlantService? plantService;

  const PlantCareHistoryPage({
    super.key,
    required this.plantId,
    required this.plantName,
    this.canManage = true,
    this.plantService,
  });

  @override
  State<PlantCareHistoryPage> createState() => _PlantCareHistoryPageState();
}

class _PlantCareHistoryPageState extends State<PlantCareHistoryPage> {
  late final PlantService _plantService;
  List<CareLog> _careLogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plantService = widget.plantService ?? PlantService();
    _loadCareLogs();
  }

  Future<void> _loadCareLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await _plantService.getCareLogs(widget.plantId);
      if (mounted) {
        setState(() {
          _careLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCareLog(CareLog log) async {
    if (log.action != 'NOTE') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce memo ?'),
        content: const Text(
          "Ce memo sera retire de l'historique de la plante.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textSecondaryC(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _plantService.deleteCareLog(widget.plantId, log.id);
      await _loadCareLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Memo supprime'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Color _getCareLogColor(String action) {
    switch (action) {
      case 'WATERING':
        return Colors.blue;
      case 'FERTILIZING':
        return Colors.green;
      case 'REPOTTING':
        return Colors.brown;
      case 'PRUNING':
        return Colors.purple;
      case 'TREATMENT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCareLogTrailing(CareLog log) {
    final timeLabel = Text(
      log.timeAgo,
      style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
    );

    if (log.action != 'NOTE' || !widget.canManage) {
      return timeLabel;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        timeLabel,
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _deleteCareLog(log),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.delete_outline,
              size: 18,
              color: Colors.red.shade400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCareLogItem(CareLog log) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCareLogColor(log.action).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                log.actionIcon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.actionDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.performedByName != null
                      ? 'Par ${log.performedByName}'
                      : 'Effectue',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryC(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildCareLogTrailing(log),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historique - ${widget.plantName}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: AppTheme.textGrey(context))),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadCareLogs,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reessayer'),
                      ),
                    ],
                  ),
                )
              : _careLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.spa_outlined,
                              size: 48,
                              color: AppTheme.divider(context)),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun soin enregistre',
                            style: TextStyle(
                              color: AppTheme.textGrey(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCareLogs,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _careLogs.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: AppTheme.borderLight(context)),
                        itemBuilder: (context, index) {
                          return _buildCareLogItem(_careLogs[index]);
                        },
                      ),
                    ),
    );
  }
}
