import 'package:flutter/material.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/iot_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class IotSensorsPage extends StatefulWidget {
  final IotService? iotService;
  final HouseService? houseService;

  const IotSensorsPage({super.key, this.iotService, this.houseService});

  @override
  State<IotSensorsPage> createState() => _IotSensorsPageState();
}

class _IotSensorsPageState extends State<IotSensorsPage> {
  late final IotService _iotService = widget.iotService ?? IotService();
  late final HouseService _houseService = widget.houseService ?? HouseService();

  List<Map<String, dynamic>> _sensors = [];
  bool _isLoading = true;
  String? _houseId;

  static const _typeIcons = {
    'HUMIDITY': Icons.water_drop,
    'TEMPERATURE': Icons.thermostat,
    'LUMINOSITY': Icons.light_mode,
    'SOIL_PH': Icons.science,
  };
  static const _typeColors = {
    'HUMIDITY': Colors.blue,
    'TEMPERATURE': Colors.red,
    'LUMINOSITY': Colors.amber,
    'SOIL_PH': Colors.green,
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
          _sensors = await _iotService.getSensorsByHouse(_houseId!);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showAddSensorDialog() async {
    if (_houseId == null) return;

    String selectedType = 'HUMIDITY';
    final deviceIdController = TextEditingController();
    final labelController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter un capteur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type de capteur'),
                  items: const [
                    DropdownMenuItem(value: 'HUMIDITY', child: Text('Humidite')),
                    DropdownMenuItem(value: 'TEMPERATURE', child: Text('Temperature')),
                    DropdownMenuItem(value: 'LUMINOSITY', child: Text('Luminosite')),
                    DropdownMenuItem(value: 'SOIL_PH', child: Text('pH du sol')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deviceIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID appareil *',
                    hintText: 'Ex: arduino-001',
                    prefixIcon: Icon(Icons.device_hub),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    hintText: 'Ex: Capteur salon',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true && deviceIdController.text.isNotEmpty) {
      try {
        await _iotService.createSensor(_houseId!, {
          'sensorType': selectedType,
          'deviceId': deviceIdController.text.trim(),
          'label': labelController.text.trim().isEmpty ? null : labelController.text.trim(),
        });
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capteur ajoute')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Future<void> _showReadings(Map<String, dynamic> sensor) async {
    final readings = await _iotService.getReadings(sensor['id'], limit: 50);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_typeIcons[sensor['sensorType']] ?? Icons.sensors,
                      color: _typeColors[sensor['sensorType']] ?? Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sensor['label'] ?? sensor['sensorTypeDisplay'] ?? 'Capteur',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (sensor['lastValue'] != null)
                    Flexible(
                      child: Text(
                        '${sensor['lastValue']} ${sensor['unit'] ?? ''}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: _typeColors[sensor['sensorType']] ?? Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: readings.isEmpty
                  ? Center(child: Text('Aucune mesure', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: readings.length,
                      itemBuilder: (ctx, i) {
                        final r = readings[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (_typeColors[sensor['sensorType']] ?? Colors.grey).withOpacity(0.1),
                            child: Text(
                              '${r['value']}',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold,
                                color: _typeColors[sensor['sensorType']] ?? Colors.grey,
                              ),
                            ),
                          ),
                          title: Text('${r['value']} ${r['unit'] ?? ''}'),
                          subtitle: Text(r['recordedAt'] ?? ''),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capteurs IoT'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddSensorDialog)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sensors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sensors, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Aucun capteur', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Connectez un Arduino pour surveiller\nvos plantes en temps reel',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddSensorDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un capteur'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sensors.length,
                    itemBuilder: (ctx, i) => _buildSensorCard(_sensors[i]),
                  ),
                ),
    );
  }

  Widget _buildSensorCard(Map<String, dynamic> sensor) {
    final type = sensor['sensorType'] as String? ?? 'HUMIDITY';
    final color = _typeColors[type] ?? Colors.grey;
    final icon = _typeIcons[type] ?? Icons.sensors;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showReadings(sensor),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sensor['label'] ?? sensor['sensorTypeDisplay'] ?? type,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sensor['deviceId'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (sensor['plantNickname'] != null)
                      Text(
                        'Plante: ${sensor['plantNickname']}',
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (sensor['lastValue'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${sensor['lastValue']}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      sensor['unit'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                )
              else
                Text('--', style: TextStyle(fontSize: 20, color: Colors.grey.shade400)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
