import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/features/plant/plant_details_page.dart';

/// Calendar page showing watering schedule and care history
class CalendarPage extends StatefulWidget {
  final RoomService? roomService;
  final PlantService? plantService;
  final HouseService? houseService;
  final NotificationService? notificationService;

  const CalendarPage({
    super.key,
    this.roomService,
    this.plantService,
    this.houseService,
    this.notificationService,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final RoomService _roomService = widget.roomService ?? RoomService();
  late final PlantService _plantService = widget.plantService ?? PlantService();
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final NotificationService _notificationService = widget.notificationService ?? NotificationService();

  List<PlantSummary> _allPlants = [];
  bool _isLoading = true;
  String? _error;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rooms = await _roomService.getRooms(includePlants: true);
      final plants = <PlantSummary>[];
      for (final room in rooms) {
        plants.addAll(room.plants);
      }

      setState(() {
        _allPlants = plants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Get plants that need watering on a specific day
  List<PlantSummary> _getPlantsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _allPlants.where((plant) {
      if (plant.nextWateringDate == null) return false;
      final wateringDay = DateTime(
        plant.nextWateringDate!.year,
        plant.nextWateringDate!.month,
        plant.nextWateringDate!.day,
      );
      return wateringDay.isAtSameMomentAs(normalizedDay);
    }).toList();
  }

  /// Get plants needing water today
  List<PlantSummary> get _plantsNeedingWaterToday {
    final today = DateTime.now();
    return _allPlants.where((plant) {
      if (plant.nextWateringDate == null) return plant.needsWatering;
      final wateringDay = DateTime(
        plant.nextWateringDate!.year,
        plant.nextWateringDate!.month,
        plant.nextWateringDate!.day,
      );
      final todayNormalized = DateTime(today.year, today.month, today.day);
      return wateringDay.isBefore(todayNormalized) ||
          wateringDay.isAtSameMomentAs(todayNormalized);
    }).toList();
  }

  /// Get upcoming waterings for the next 7 days
  List<MapEntry<DateTime, List<PlantSummary>>> get _upcomingWaterings {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final result = <MapEntry<DateTime, List<PlantSummary>>>[];

    for (int i = 0; i < 7; i++) {
      final day = todayNormalized.add(Duration(days: i));
      final plants = _getPlantsForDay(day);
      if (plants.isNotEmpty) {
        result.add(MapEntry(day, plants));
      }
    }

    return result;
  }

  Future<void> _waterPlant(PlantSummary plant) async {
    try {
      final updatedPlant = await _plantService.waterPlant(plant.id);
      // Reschedule notification for this plant (with house context)
      final activeHouse = await _houseService.getActiveHouse();
      if (activeHouse != null) {
        await _notificationService.scheduleWateringReminder(
          updatedPlant,
          houseId: activeHouse.id,
        );
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${plant.nickname} arrosee !'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('Calendrier'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCalendar(),
                        _buildSelectedDayTasks(),
                        _buildTodaySection(),
                        _buildUpcomingSection(),
                        const SizedBox(height: AppConstants.paddingXL),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Erreur: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.all(AppConstants.paddingM),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        locale: 'fr_FR',
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        eventLoader: (day) => _getPlantsForDay(day),
        calendarStyle: CalendarStyle(
          markersMaxCount: 3,
          markerDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.secondaryColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          weekendTextStyle: TextStyle(color: AppTheme.textSecondaryC(context)),
          outsideDaysVisible: false,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor),
            borderRadius: BorderRadius.circular(16),
          ),
          formatButtonTextStyle: TextStyle(color: AppTheme.primaryColor),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            final isOverdue = date.isBefore(DateTime.now());
            return Positioned(
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOverdue ? AppTheme.errorColor : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${events.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectedDayTasks() {
    final plants = _getPlantsForDay(_selectedDay);
    final isToday = isSameDay(_selectedDay, DateTime.now());
    final isPast = _selectedDay.isBefore(DateTime.now()) && !isToday;

    if (plants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingS,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: AppTheme.successColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun arrosage prevu ce jour',
                    style: TextStyle(color: AppTheme.textSecondaryC(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPast ? Icons.warning : Icons.water_drop,
                color: isPast ? AppTheme.errorColor : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isToday
                    ? 'Aujourd\'hui'
                    : isPast
                        ? 'En retard'
                        : _formatDate(_selectedDay),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPast ? AppTheme.errorColor : AppTheme.textPrimaryC(context),
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isPast
                      ? AppTheme.errorColor.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${plants.length} plante${plants.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: isPast ? AppTheme.errorColor : AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingS),
          ...plants.map((plant) => _buildPlantTaskCard(plant, isPast || isToday)),
        ],
      ),
    );
  }

  Widget _buildPlantTaskCard(PlantSummary plant, bool showWaterButton) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingS),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            plant.nickname.isNotEmpty ? plant.nickname[0].toUpperCase() : 'P',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          plant.nickname,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          plant.speciesCommonName ?? 'Espece inconnue',
          style: TextStyle(color: AppTheme.textSecondaryC(context), fontSize: 12),
        ),
        trailing: showWaterButton
            ? IconButton(
                icon: const Icon(Icons.water_drop, color: Colors.blue),
                onPressed: () => _waterPlant(plant),
                tooltip: 'Arroser',
              )
            : const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlantDetailsPage(
                plantId: plant.id,
                plantName: plant.nickname,
              ),
            ),
          ).then((_) => _loadData());
        },
      ),
    );
  }

  Widget _buildTodaySection() {
    final todayPlants = _plantsNeedingWaterToday;

    if (todayPlants.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.priority_high, color: AppTheme.errorColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'A arroser maintenant',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingM),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: todayPlants.length,
              itemBuilder: (context, index) {
                final plant = todayPlants[index];
                return _buildUrgentPlantCard(plant);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentPlantCard(PlantSummary plant) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppConstants.paddingM),
      child: Card(
        color: AppTheme.errorColor.withOpacity(0.05),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlantDetailsPage(
                  plantId: plant.id,
                  plantName: plant.nickname,
                ),
              ),
            ).then((_) => _loadData());
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                  child: Icon(Icons.eco, color: AppTheme.errorColor),
                ),
                const SizedBox(height: 8),
                Text(
                  plant.nickname,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _waterPlant(plant),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_drop, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Arroser',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    final upcoming = _upcomingWaterings;

    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 48,
                    color: AppTheme.successColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun arrosage prevu cette semaine',
                    style: TextStyle(color: AppTheme.textSecondaryC(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Prochains 7 jours',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingM),
          Card(
            child: Column(
              children: upcoming.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value.key;
                final plants = entry.value.value;
                final isToday = isSameDay(day, DateTime.now());

                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.white : AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              _getShortDayName(day),
                              style: TextStyle(
                                fontSize: 10,
                                color: isToday
                                    ? AppTheme.overlayWhite(context, 0.8)
                                    : AppTheme.textSecondaryC(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        isToday ? 'Aujourd\'hui' : _formatDate(day),
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        plants.map((p) => p.nickname).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondaryC(context),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.water_drop, color: Colors.blue, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${plants.length}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = day;
                        });
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final months = [
      'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre'
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  String _getShortDayName(DateTime date) {
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[date.weekday - 1];
  }
}
