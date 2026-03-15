import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/core/models/user_profile.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/widgets/plant_card.dart';
import 'package:planto/features/auth/login_page.dart';
import 'package:planto/features/plant/plant_details_page.dart';
import 'package:planto/features/plant/add_plant_page.dart';
import 'package:planto/features/plant/plant_identification_page.dart';
import 'package:planto/features/calendar/calendar_page.dart';
import 'package:planto/features/house/house_page.dart';
import 'package:planto/features/pot/pot_stock_page.dart';
import 'package:planto/features/profile/profile_page.dart';
import 'package:planto/features/garden/garden_page.dart';
import 'package:planto/features/iot/iot_sensors_page.dart';
import 'package:planto/features/stats/stats_page.dart';
import 'package:planto/features/room/add_room_dialog.dart';

/// Home page showing rooms with plants
class HomePage extends StatefulWidget {
  final String userEmail;
  final AuthService? authService;
  final RoomService? roomService;
  final PlantService? plantService;
  final HouseService? houseService;
  final ProfileService? profileService;
  final NotificationService? notificationService;

  const HomePage({
    super.key,
    required this.userEmail,
    this.authService,
    this.roomService,
    this.plantService,
    this.houseService,
    this.profileService,
    this.notificationService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final RoomService _roomService = widget.roomService ?? RoomService();
  late final PlantService _plantService = widget.plantService ?? PlantService();
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final ProfileService _profileService = widget.profileService ?? ProfileService();
  late final NotificationService _notificationService = widget.notificationService ?? NotificationService();

  List<Room> _rooms = [];
  List<House> _houses = [];
  House? _activeHouse;
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // all, thirsty, room filter
  String _searchQuery = ''; // Search query for filtering plants
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadHouses();
    await _loadRooms();
    await _loadUserProfile();
    await _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    try {
      // Request permissions on first load
      await _notificationService.requestPermissions();

      // Schedule notifications for plants in the active house (if notifications enabled for this house)
      if (_activeHouse != null && _activeHouse!.id.isNotEmpty) {
        final plants = await _plantService.getMyPlants();
        await _notificationService.scheduleAllReminders(plants, houseId: _activeHouse!.id);
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getCurrentUser();
      setState(() {
        _userProfile = profile;
      });
    } catch (e) {
      // Ignore profile loading errors
    }
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getMyHouses();
      setState(() {
        _houses = houses;
        _activeHouse = houses.firstWhere(
          (h) => h.isActive,
          orElse: () => houses.isNotEmpty ? houses.first : House(
            id: '',
            name: 'Aucune maison',
            inviteCode: '',
            memberCount: 0,
            roomCount: 0,
            isActive: false,
          ),
        );
      });
    } catch (e) {
      // Fallback: create a dummy house
      setState(() {
        _activeHouse = House(
          id: 'demo',
          name: 'Ma Maison',
          inviteCode: '',
          memberCount: 1,
          roomCount: 0,
          isActive: true,
        );
      });
    }
  }

  Future<void> _switchHouse(House house) async {
    try {
      await _houseService.switchActiveHouse(house.id);
      setState(() {
        _activeHouse = house;
        _isLoading = true;
      });
      await _loadRooms();
    } catch (e) {
      if (mounted) {
        _messengerKey.currentState!.showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rooms = await _roomService.getRooms(includePlants: true);
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _waterPlant(String plantId) async {
    try {
      final updatedPlant = await _plantService.waterPlant(plantId);
      
      // Update the plant locally without reloading everything
      // This prevents the scroll from jumping to the top
      setState(() {
        for (int i = 0; i < _rooms.length; i++) {
          final roomPlants = _rooms[i].plants;
          for (int j = 0; j < roomPlants.length; j++) {
            if (roomPlants[j].id == plantId) {
              // Update the plant with fresh data from the response
              _rooms[i] = Room(
                id: _rooms[i].id,
                name: _rooms[i].name,
                type: _rooms[i].type,
                plantCount: _rooms[i].plantCount,
                plants: [
                  ...roomPlants.sublist(0, j),
                  PlantSummary(
                    id: updatedPlant.id,
                    nickname: updatedPlant.nickname,
                    speciesCommonName: updatedPlant.speciesCommonName ?? roomPlants[j].speciesCommonName,
                    photoUrl: updatedPlant.photoUrl ?? roomPlants[j].photoUrl,
                    needsWatering: updatedPlant.needsWatering,
                    nextWateringDate: updatedPlant.nextWateringDate,
                    isSick: roomPlants[j].isSick,
                    isWilted: roomPlants[j].isWilted,
                    needsRepotting: roomPlants[j].needsRepotting,
                  ),
                  ...roomPlants.sublist(j + 1),
                ],
              );
              break;
            }
          }
        }
      });
      
      // Reschedule all notifications (summary mode)
      await _scheduleNotifications();

      if (mounted) {
        _messengerKey.currentState!.showSnackBar(
          const SnackBar(
            content: Text('Plante arrosee !'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _messengerKey.currentState!.showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  /// Navigate to plant details page
  void _navigateToPlantDetails(PlantSummary plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantDetailsPage(
          plantId: plant.id,
          plantName: plant.nickname,
        ),
      ),
    ).then((result) {
      // Only refresh if something changed (deletion returns true)
      // Use silent refresh to preserve scroll position
      _silentRefresh();
    });
  }

  /// Refresh data without showing loading state (preserves scroll position)
  Future<void> _silentRefresh() async {
    try {
      final rooms = await _roomService.getRooms(includePlants: true);
      if (mounted) {
        setState(() {
          _rooms = rooms;
        });
      }
    } catch (e) {
      // Ignore errors on silent refresh
    }
  }

  /// Count of plants needing watering today
  int get _thirstyPlantsCount {
    int count = 0;
    for (final room in _rooms) {
      count += room.plants.where((p) => p.needsWatering).length;
    }
    return count;
  }

  /// Show notification bottom sheet with plants to water by house/room
  void _showNotificationSheet() {
    // Group thirsty plants by room
    final Map<String, List<PlantSummary>> plantsByRoom = {};
    for (final room in _rooms) {
      final thirstyPlants = room.plants.where((p) => p.needsWatering).toList();
      if (thirstyPlants.isNotEmpty) {
        plantsByRoom['${room.icon} ${room.name}'] = thirstyPlants;
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Aujourd\'hui',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _thirstyPlantsCount == 0
                              ? 'Aucune plante a arroser'
                              : '$_thirstyPlantsCount plante${_thirstyPlantsCount > 1 ? 's' : ''} a arroser',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: plantsByRoom.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: AppTheme.successColor),
                          const SizedBox(height: 16),
                          const Text(
                            'Tout est en ordre !',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aucune plante n\'a besoin d\'eau aujourd\'hui',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGrey(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // House name (current active house)
                        if (_activeHouse != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.home, size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  _activeHouse!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Rooms with plants
                        ...plantsByRoom.entries.map((entry) => _buildNotificationRoomSection(
                              entry.key,
                              entry.value,
                            )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationRoomSection(String roomName, List<PlantSummary> plants) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roomName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGreyDark(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plants.map((plant) => InkWell(
              onTap: () {
                Navigator.pop(context);
                _navigateToPlantDetails(plant);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.water_drop, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      plant.nickname,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  List<Room> get _filteredRooms {
    List<Room> result = _rooms;

    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      result = result.map((room) {
        final matchingPlants = room.plants.where((p) =>
            p.nickname.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
        return Room(
          id: room.id,
          name: room.name,
          type: room.type,
          plantCount: matchingPlants.length,
          plants: matchingPlants,
        );
      }).where((room) => room.plants.isNotEmpty).toList();
    }

    // Then apply room/thirsty filter
    if (_selectedFilter == 'thirsty') {
      result = result.map((room) {
        final thirstyPlants = room.plants.where((p) => p.needsWatering).toList();
        return Room(
          id: room.id,
          name: room.name,
          type: room.type,
          plantCount: thirstyPlants.length,
          plants: thirstyPlants,
        );
      }).where((room) => room.plants.isNotEmpty).toList();
    } else if (_selectedFilter != 'all') {
      result = result.where((r) => r.name == _selectedFilter).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorState()
                        : _buildRoomsList(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: _buildSmartFab(),
      ),
    );
  }

  Widget _buildSmartFab() {
    return FloatingActionButton(
      onPressed: () => _showAddMenu(),
      backgroundColor: AppTheme.primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Que souhaitez-vous ajouter ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildAddOption(
              icon: Icons.eco,
              label: 'Nouvelle Plante',
              subtitle: 'Ajouter une plante a ma collection',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showPlantAddMethodSheet(asBottomSheet: true);
              },
            ),
            if (_activeHouse?.isOwner == true) ...[
              const SizedBox(height: 16),
              _buildAddOption(
                icon: Icons.meeting_room,
                label: 'Nouvelle Pièce',
                subtitle: 'Créer un nouvel espace (Salon, Chambre...)',
                color: Colors.orange,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await showDialog(
                    context: context,
                    builder: (context) => const AddRoomDialog(),
                  );
                  if (result == true) {
                    _loadData();
                    _messengerKey.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('Pièce créée avec succès ! 🎉'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderLight(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppTheme.textGrey(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.divider(context)),
          ],
        ),
      ),
    );
  }

  /// Affiche le choix entre identification IA et saisie manuelle
  /// [asBottomSheet] = true pour afficher en bas (depuis le FAB +), false pour centrer (depuis carte vide)
  void _showPlantAddMethodSheet({bool asBottomSheet = false}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Comment ajouter votre plante ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Option 1: Identification IA
        _buildAddOption(
          icon: Icons.auto_awesome,
          label: 'Identifier une plante',
          subtitle: 'Prenez une photo et laissez l\'IA la reconnaitre',
          color: Colors.purple,
          onTap: () {
            Navigator.pop(context);
            _startAiIdentification();
          },
        ),

        const SizedBox(height: 16),

        // Option 2: Saisie manuelle
        _buildAddOption(
          icon: Icons.edit_note,
          label: 'Saisie manuelle',
          subtitle: 'Remplissez le formulaire vous-meme',
          color: Colors.blue,
          onTap: () {
            Navigator.pop(context);
            _navigateToAddPlant();
          },
        ),
      ],
    );

    if (asBottomSheet) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      );
    }
  }

  /// Demarre le processus d'identification IA
  Future<void> _startAiIdentification() async {
    // Afficher le choix camera/galerie
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Prendre une photo de votre plante',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Pour une meilleure identification, prenez une photo claire des feuilles',
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Appareil photo'),
                subtitle: Text('Prendre une nouvelle photo', style: TextStyle(color: AppTheme.textGrey(context))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                ),
                title: const Text('Galerie'),
                subtitle: Text('Choisir une photo existante', style: TextStyle(color: AppTheme.textGrey(context))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    // Prendre/selectionner la photo
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    // Naviguer vers l'ecran d'identification
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantIdentificationPage(imageBytes: bytes),
      ),
    );

    // Si on revient avec un resultat true (plante ajoutee), rafraichir
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _navigateToAddPlant() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddPlantPage()),
    );
    if (result == true) {
      _loadData();
      if (mounted) _showSuccessNotification('Plante ajoutee avec succes !');
    }
  }

  void _showSuccessNotification(String message) {
    _messengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // House Context Selector (Left/Center)
            InkWell(
              onTap: _showHouseContextSelector,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.overlayWhite(context, 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _activeHouse?.name ?? 'Ma Maison',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ],
                ),
              ),
            ),
            // Bell + User Avatar (Right)
            Row(
              children: [
                // Notification Bell
                GestureDetector(
                  onTap: _showNotificationSheet,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                        if (_thirstyPlantsCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _thirstyPlantsCount > 9 ? '9+' : '$_thirstyPlantsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // User Avatar
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    ).then((_) => _loadData());
                  },
                  child: _userProfile?.hasProfilePhoto == true
                      ? CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                            _profileService.getProfilePhotoFullUrl(_userProfile!.profilePhotoUrl) ?? '',
                          ),
                          onBackgroundImageError: (_, __) {},
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Text(
                            widget.userEmail.isNotEmpty
                                ? widget.userEmail[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHouseContextSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Mes Maisons',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _houses.length,
                itemBuilder: (context, index) {
                  final house = _houses[index];
                  final isActive = house.id == _activeHouse?.id;
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.lightBg(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.home,
                        color: isActive ? AppTheme.primaryColor : AppTheme.textGrey(context),
                      ),
                    ),
                    title: Text(
                      house.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? AppTheme.primaryColor : AppTheme.textPrimaryC(context),
                      ),
                    ),
                    trailing: isActive 
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (!isActive) {
                        _switchHouse(house);
                      }
                    },
                  );
                },
              ),
            ),
            const Divider(height: 32),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showCreateOrJoinDialog();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: AppTheme.textPrimaryC(context)),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Ajouter ou rejoindre une maison',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOrJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle Maison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_home, color: AppTheme.primaryColor),
              title: const Text('Créer une maison'),
              subtitle: const Text('Vous serez le propriétaire'),
              onTap: () {
                Navigator.pop(context);
                _showCreateHouseDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.login, color: AppTheme.primaryColor),
              title: const Text('Rejoindre une maison'),
              subtitle: const Text('Avec un code d\'invitation'),
              onTap: () {
                Navigator.pop(context);
                _showJoinHouseDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateHouseDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une maison'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom de la maison',
            hintText: 'Ex: Maison de vacances',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Show loading immediately
      setState(() => _isLoading = true);

      try {
        // Create the house and get the returned house object
        final createdHouse = await _houseService.createHouse(result);

        // Switch to the newly created house
        await _houseService.switchActiveHouse(createdHouse.id);

        // Update active house immediately in state
        setState(() {
          _activeHouse = createdHouse;
        });

        // Reload all data to show the new house
        await _loadData();

        if (mounted) {
          _messengerKey.currentState!.showSnackBar(
            SnackBar(
              content: Text('Maison "${createdHouse.name}" creee !'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          _messengerKey.currentState!.showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showJoinHouseDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejoindre une maison'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Code d\'invitation',
            hintText: 'Ex: A1B2C3',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Show loading immediately
      setState(() => _isLoading = true);

      try {
        // Join the house and get the returned house object
        final joinedHouse = await _houseService.joinHouse(result);

        // Switch to the newly joined house
        await _houseService.switchActiveHouse(joinedHouse.id);

        // Update active house immediately in state
        setState(() {
          _activeHouse = joinedHouse;
        });

        // Reload all data (houses list and rooms for the new house)
        await _loadData();

        if (mounted) {
          _messengerKey.currentState!.showSnackBar(
            SnackBar(
              content: Text('Bienvenue dans "${joinedHouse.name}" !'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          _messengerKey.currentState!.showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppTheme.cardBg(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final roomNames = _rooms.map((r) => r.name).toSet().toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('À arroser', 'thirsty', isWarning: true),
          const SizedBox(width: 8),
          ...roomNames.map((name) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(name, name),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isWarning = false}) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWarning) const Text('💧 ', style: TextStyle(fontSize: 12)),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      backgroundColor: AppTheme.cardBg(context),
      selectedColor: isWarning
          ? Colors.orange.shade100
          : AppTheme.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? (isWarning ? Colors.orange.shade800 : AppTheme.primaryColor)
            : AppTheme.textSecondaryC(context),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? (isWarning ? Colors.orange : AppTheme.primaryColor)
              : AppTheme.divider(context),
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_filteredRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 64, color: AppTheme.textSecondaryC(context).withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Aucune plante trouvée',
              style: TextStyle(color: AppTheme.textSecondaryC(context)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredRooms.length,
        itemBuilder: (context, index) {
          final room = _filteredRooms[index];
          return _buildRoomSection(room);
        },
      ),
    );
  }

  Widget _buildRoomSection(Room room) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(room.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                room.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryC(context),
                      letterSpacing: 1,
                    ),
              ),
              const Spacer(),
              Text(
                '${room.plants.length} plante${room.plants.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryC(context),
                ),
              ),
            ],
          ),
        ),
        // Plants or empty state
        if (room.plants.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.15),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.local_florist_outlined,
                  size: 36,
                  color: AppTheme.textSecondaryC(context).withOpacity(0.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Aucune plante dans cette piece',
                  style: TextStyle(
                    color: AppTheme.textSecondaryC(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showPlantAddMethodSheet(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter une plante'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          )
        else
          ...room.plants.map((plant) => PlantCard(
            plant: plant,
            onWater: () => _waterPlant(plant.id),
            onTap: () => _navigateToPlantDetails(plant),
          )),
        const SizedBox(height: 8),
      ],
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
            onPressed: _loadRooms,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textSecondaryC(context),
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.grass),
          label: 'Potager',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sensors),
          label: 'IoT',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Stats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GardenPage()),
          ).then((_) => _loadData());
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IotSensorsPage()),
          ).then((_) => _loadData());
        } else if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StatsPage()),
          ).then((_) => _loadData());
        } else if (index == 4) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ).then((_) => _loadData());
        }
      },
    );
  }
}
