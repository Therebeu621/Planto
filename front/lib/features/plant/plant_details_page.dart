import 'package:flutter/material.dart';
import 'package:planto/core/models/plant.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/models/pot_stock.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/pot_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/features/plant/photo_gallery_page.dart';
import 'package:planto/features/plant/qr_code_page.dart';

class PlantDetailsPage extends StatefulWidget {
  final String plantId;
  final String plantName;
  final PlantService? plantService;
  final RoomService? roomService;
  final HouseService? houseService;
  final NotificationService? notificationService;
  final PotService? potService;

  const PlantDetailsPage({
    super.key,
    required this.plantId,
    required this.plantName,
    this.plantService,
    this.roomService,
    this.houseService,
    this.notificationService,
    this.potService,
  });

  @override
  State<PlantDetailsPage> createState() => _PlantDetailsPageState();
}

class _PlantDetailsPageState extends State<PlantDetailsPage>
    with SingleTickerProviderStateMixin {
  late final PlantService _plantService = widget.plantService ?? PlantService();
  late final RoomService _roomService = widget.roomService ?? RoomService();
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final NotificationService _notificationService = widget.notificationService ?? NotificationService();
  late final PotService _potService = widget.potService ?? PotService();

  Plant? _plant;
  List<Room> _rooms = [];
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  String? _error;

  // Edit form controllers
  late TextEditingController _nicknameController;
  late TextEditingController _notesController;
  String? _selectedRoomId;
  int _wateringInterval = 7;
  String _exposure = 'PARTIAL_SHADE';
  bool _isSick = false;
  bool _isWilted = false;
  bool _needsRepotting = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _notesController = TextEditingController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _plantService.getPlantById(widget.plantId),
        _roomService.getRooms(),
      ]);

      final plant = results[0] as Plant;
      final rooms = results[1] as List<Room>;

      if (mounted) {
        setState(() {
          _plant = plant;
          _rooms = rooms;
          _isLoading = false;
          _initEditForm();
        });
        _animationController.forward();
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

  void _initEditForm() {
    if (_plant == null) return;
    _nicknameController.text = _plant!.nickname;
    _notesController.text = _plant!.notes ?? '';
    _selectedRoomId = _plant!.roomId ?? _plant!.room?.id;
    _wateringInterval = _plant!.wateringIntervalDays ?? 7;
    _exposure = _plant!.exposure ?? 'PARTIAL_SHADE';
    _isSick = _plant!.isSick;
    _isWilted = _plant!.isWilted;
    _needsRepotting = _plant!.needsRepotting;
  }

  Future<void> _saveChanges() async {
    if (_plant == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedPlant = await _plantService.updatePlant(
        plantId: _plant!.id,
        nickname: _nicknameController.text.trim(),
        roomId: _selectedRoomId,
        wateringIntervalDays: _wateringInterval,
        exposure: _exposure,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isSick: _isSick,
        isWilted: _isWilted,
        needsRepotting: _needsRepotting,
      );

      if (mounted) {
        setState(() {
          _plant = updatedPlant;
          _isEditMode = false;
          _isSaving = false;
        });
        _showSuccessSnackbar('Plante mise a jour');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorSnackbar('Erreur: $e');
      }
    }
  }

  Future<void> _waterPlant() async {
    if (_plant == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.water_drop, color: Colors.blue.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Arroser'),
          ],
        ),
        content: Text(
          'Confirmer l\'arrosage de ${_plant!.nickname} ?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textGrey(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Arroser'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final updatedPlant = await _plantService.waterPlant(_plant!.id);
      // Reschedule notification for this plant (with house context)
      final activeHouse = await _houseService.getActiveHouse();
      if (activeHouse != null) {
        await _notificationService.scheduleWateringReminder(
          updatedPlant,
          houseId: activeHouse.id,
        );
      }
      // Reload to get updated care logs
      await _loadData();
      if (mounted) {
        _showSuccessSnackbar('${_plant!.nickname} a ete arrosee');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erreur: $e');
      }
    }
  }

  Future<void> _deletePlant() async {
    if (_plant == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Supprimer'),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer ${_plant!.nickname} ?\n\nCette action est irreversible.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textGrey(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _plantService.deletePlant(_plant!.id);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${_plant!.nickname} a ete supprimee'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erreur: $e');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.lightBg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          title: Text(widget.plantName),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_error != null || _plant == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightBg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          title: Text(widget.plantName),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGreyDark(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Plante introuvable',
                style: TextStyle(color: AppTheme.textGrey(context)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg(context),
      body: _isEditMode ? _buildEditMode() : _buildViewMode(),
    );
  }

  Widget _buildViewMode() {
    final plant = _plant!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.overlayWhite(context, 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.overlayWhite(context, 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PhotoGalleryPage(plantId: widget.plantId, plantName: _plant!.nickname),
                )).then((_) => _loadData()),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.overlayWhite(context, 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => QrCodePage(plantId: widget.plantId, plantName: _plant!.nickname),
                )),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.overlayWhite(context, 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                onPressed: () => setState(() => _isEditMode = true),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(plant),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick actions
                  _buildQuickActions(plant),
                  const SizedBox(height: 24),

                  // Status cards
                  _buildStatusSection(plant),
                  const SizedBox(height: 24),

                  // Plant info
                  _buildInfoSection(plant),
                  const SizedBox(height: 24),

                  // Notes
                  if (plant.notes != null && plant.notes!.isNotEmpty) ...[
                    _buildNotesSection(plant),
                    const SizedBox(height: 24),
                  ],

                  // Care history
                  _buildCareHistorySection(plant),
                  const SizedBox(height: 24),

                  // Danger zone
                  _buildDangerZone(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(Plant plant) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withGreen(150),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.overlayWhite(context, 0.1),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.overlayWhite(context, 0.1),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Plant image
                  Hero(
                    tag: 'plant_${plant.id}',
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.shadow(context),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: plant.photoUrl != null
                            ? Image.network(
                                plant.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlantIcon(),
                              )
                            : plant.species?.imageUrl != null
                                ? Image.network(
                                    plant.species!.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildPlantIcon(),
                                  )
                                : _buildPlantIcon(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Plant name
                  Text(
                    plant.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Species name
                  if (plant.speciesCommonName != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.overlayWhite(context, 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        plant.speciesCommonName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],

                  // Scientific name
                  if (plant.species?.scientificName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      plant.species!.scientificName!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantIcon() {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: const Icon(Icons.eco, size: 50, color: AppTheme.primaryColor),
    );
  }

  Widget _buildQuickActions(Plant plant) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.water_drop,
                label: 'Arroser',
                color: plant.needsWatering ? Colors.orange.shade700 : Colors.grey,
                onTap: _waterPlant,
                badge: plant.needsWatering ? '!' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit,
                label: 'Modifier',
                color: AppTheme.primaryColor,
                onTap: () => setState(() => _isEditMode = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Care actions row
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.spa_outlined,
                label: 'Fertiliser',
                color: Colors.green.shade700,
                onTap: () => _showCareLogDialog('FERTILIZING', 'Fertilisation', Icons.spa_outlined, Colors.green.shade700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.content_cut,
                label: 'Tailler',
                color: Colors.purple.shade700,
                onTap: () => _showCareLogDialog('PRUNING', 'Taille', Icons.content_cut, Colors.purple.shade700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.healing,
                label: 'Traiter',
                color: Colors.red.shade700,
                onTap: () => _showCareLogDialog('TREATMENT', 'Traitement', Icons.healing, Colors.red.shade700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.note_add_outlined,
                label: 'Note',
                color: Colors.blueGrey,
                onTap: () => _showCareLogDialog('NOTE', 'Note', Icons.note_add_outlined, Colors.blueGrey),
              ),
            ),
          ],
        ),
        if (plant.needsRepotting) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              icon: Icons.yard_outlined,
              label: 'Rempoter',
              color: Colors.brown.shade700,
              onTap: _showRepotDialog,
              badge: '!',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showCareLogDialog(String action, String label, IconData icon, Color color) async {
    if (_plant == null) return;
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
        content: TextField(
          controller: notesController,
          decoration: InputDecoration(
            labelText: 'Notes (optionnel)',
            hintText: action == 'NOTE'
                ? 'Ecrivez votre observation...'
                : 'Ex: produit utilise, observations...',
            prefixIcon: const Icon(Icons.note_outlined),
          ),
          maxLines: 3,
          autofocus: action == 'NOTE',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textGrey(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _plantService.createCareLog(
          _plant!.id,
          action,
          notes: notesController.text.isNotEmpty ? notesController.text : null,
        );
        // Reload plant to refresh care logs
        final updated = await _plantService.getPlantById(_plant!.id);
        if (mounted) {
          setState(() => _plant = updated);
          _showSuccessSnackbar('$label enregistre');
        }
      } catch (e) {
        if (mounted) _showErrorSnackbar('Erreur: $e');
      }
    }
  }

  Future<void> _showRepotDialog() async {
    if (_plant == null) return;

    List<PotStock> suggestedPots = [];
    bool isLoadingPots = true;

    try {
      suggestedPots = await _potService.getSuggestedPots(_plant!.id);
    } catch (_) {}
    isLoadingPots = false;

    if (!mounted) return;

    PotStock? selectedPot;
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Rempoter ${_plant!.nickname}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_plant!.potDiameterCm != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Pot actuel: ${_plant!.potSizeDisplay}',
                      style: TextStyle(color: AppTheme.textSecondaryC(context)),
                    ),
                  ),
                if (isLoadingPots)
                  const Center(child: CircularProgressIndicator())
                else if (suggestedPots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Aucun pot disponible en stock. Ajoutez des pots dans votre inventaire.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                else ...[
                  const Text(
                    'Choisir un nouveau pot:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...suggestedPots.map((pot) => RadioListTile<PotStock>(
                        title: Text('Pot de ${pot.sizeDisplay}'),
                        subtitle: Text('${pot.quantity} disponible${pot.quantity > 1 ? 's' : ''}'),
                        value: pot,
                        groupValue: selectedPot,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (v) => setDialogState(() => selectedPot = v),
                      )),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                    hintText: 'Ex: Terreau universel',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler', style: TextStyle(color: AppTheme.textSecondaryC(context))),
            ),
            ElevatedButton(
              onPressed: selectedPot != null ? () => Navigator.pop(context, true) : null,
              child: const Text('Rempoter'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedPot != null) {
      try {
        final updatedPlant = await _potService.repotPlant(
          _plant!.id,
          selectedPot!.diameterCm,
          notes: notesController.text.isNotEmpty ? notesController.text : null,
        );
        setState(() => _plant = updatedPlant);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_plant!.nickname} rempotee dans un pot de ${selectedPot!.sizeDisplay}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: AppTheme.cardBg(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowSoft(context),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 20,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(Plant plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Statut', Icons.favorite_outline),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.water_drop,
                title: 'Arrosage',
                value: plant.wateringStatusText,
                color: plant.needsWatering ? Colors.orange : Colors.blue,
                isWarning: plant.needsWatering,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.health_and_safety,
                title: 'Sante',
                value: plant.healthStatus,
                color: plant.hasHealthIssues ? Colors.orange : AppTheme.successColor,
                isWarning: plant.hasHealthIssues,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: isWarning ? Border.all(color: color.withOpacity(0.5), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft(context),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (isWarning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Attention',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Plant plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informations', Icons.info_outline),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowSoft(context),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Emplacement',
                value: plant.room != null
                    ? '${plant.room!.icon} ${plant.room!.name}'
                    : plant.roomName ?? 'Non defini',
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.wb_sunny_outlined,
                label: 'Exposition',
                value: plant.exposureDisplay,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.water_drop_outlined,
                label: 'Frequence arrosage',
                value: plant.wateringIntervalDays != null
                    ? 'Tous les ${plant.wateringIntervalDays} jours'
                    : 'Non defini',
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.straighten,
                label: 'Taille du pot',
                value: plant.potSizeDisplay,
              ),
              if (plant.lastWatered != null) ...[
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.history,
                  label: 'Dernier arrosage',
                  value: _formatDate(plant.lastWatered!),
                ),
              ],
              if (plant.species?.family != null) ...[
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.eco_outlined,
                  label: 'Famille',
                  value: plant.species!.family!,
                ),
              ],
              if (plant.acquiredAt != null) ...[
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date d\'acquisition',
                  value: _formatDate(plant.acquiredAt!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(Plant plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Notes', Icons.note_outlined),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plant.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber.shade900,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCareHistorySection(Plant plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Historique des soins', Icons.history),
        const SizedBox(height: 12),
        if (plant.recentCareLogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowSoft(context),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.spa_outlined, size: 48, color: AppTheme.divider(context)),
                const SizedBox(height: 12),
                Text(
                  'Aucun soin enregistre',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Arrosez votre plante pour commencer',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowSoft(context),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plant.recentCareLogs.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderLight(context)),
              itemBuilder: (context, index) {
                final log = plant.recentCareLogs[index];
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
                          child: Text(log.actionIcon, style: const TextStyle(fontSize: 20)),
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
                          ],
                        ),
                      ),
                      Text(
                        log.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
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

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Zone de danger', Icons.warning_amber_outlined),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supprimer la plante',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cette action est irreversible',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _deletePlant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryC(context),
          ),
        ),
      ],
    );
  }

  // ============== EDIT MODE ==============

  Widget _buildEditMode() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              _initEditForm(); // Reset form
              setState(() => _isEditMode = false);
            },
          ),
          title: const Text(
            'Modifier',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nickname
                _buildSectionTitle('Identite', Icons.badge_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  _buildEditTextField(
                    controller: _nicknameController,
                    label: 'Petit nom',
                    hint: 'Ex: Monty, Ficus du salon...',
                    icon: Icons.favorite_outline,
                  ),
                ]),

                const SizedBox(height: 24),

                // Room
                _buildSectionTitle('Emplacement', Icons.location_on_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  _buildRoomSelector(),
                ]),

                const SizedBox(height: 24),

                // Conditions
                _buildSectionTitle('Conditions', Icons.settings_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  _buildExposureSelector(),
                  const SizedBox(height: 20),
                  _buildWateringSlider(),
                ]),

                const SizedBox(height: 24),

                // Health
                _buildSectionTitle('Etat de sante', Icons.healing_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  _buildSwitch(
                    'Malade',
                    'La plante a-t-elle des parasites ou maladies ?',
                    _isSick,
                    (v) => setState(() => _isSick = v),
                  ),
                  const Divider(),
                  _buildSwitch(
                    'Fanee',
                    'Les feuilles sont-elles molles ou tombantes ?',
                    _isWilted,
                    (v) => setState(() => _isWilted = v),
                  ),
                  const Divider(),
                  _buildSwitch(
                    'A rempoter',
                    'Le pot est-il devenu trop petit ?',
                    _needsRepotting,
                    (v) => setState(() => _needsRepotting = v),
                  ),
                ]),

                const SizedBox(height: 24),

                // Notes
                _buildSectionTitle('Notes', Icons.note_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  _buildEditTextField(
                    controller: _notesController,
                    label: 'Notes personnelles',
                    hint: 'Ajoutez des notes sur votre plante...',
                    icon: Icons.edit_note,
                    maxLines: 4,
                  ),
                ]),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft(context),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textGrey(context)),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: AppTheme.primaryColor, size: 22)
                : null,
            filled: true,
            fillColor: AppTheme.inputFill(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Piece',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey(context),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _rooms.map((room) {
            final isSelected = _selectedRoomId == room.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedRoomId = room.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.inputFill(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.divider(context),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(room.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      room.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textGreyDark(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  final List<Map<String, dynamic>> _exposureOptions = [
    {'value': 'SUN', 'label': 'Plein soleil', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'value': 'PARTIAL_SHADE', 'label': 'Mi-ombre', 'icon': Icons.wb_cloudy, 'color': Colors.blueGrey},
    {'value': 'SHADE', 'label': 'Ombre', 'icon': Icons.nights_stay, 'color': Colors.indigo},
  ];

  Widget _buildExposureSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exposition lumineuse',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey(context),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _exposureOptions.map((option) {
            final isSelected = _exposure == option['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _exposure = option['value']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: option != _exposureOptions.last ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (option['color'] as Color).withOpacity(0.15)
                        : AppTheme.inputFill(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? option['color'] as Color : AppTheme.divider(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        color: isSelected ? option['color'] as Color : AppTheme.textGrey(context),
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        option['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? option['color'] as Color : AppTheme.textGrey(context),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWateringSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Frequence d\'arrosage',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGrey(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$_wateringInterval jours',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue.shade400,
            inactiveTrackColor: Colors.blue.shade100,
            thumbColor: Colors.blue.shade600,
            overlayColor: Colors.blue.withOpacity(0.2),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _wateringInterval.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (value) => setState(() => _wateringInterval = value.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quotidien', style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context))),
            Text('Mensuel', style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context))),
          ],
        ),
      ],
    );
  }

  /// Format date to French format
  String _formatDate(DateTime date) {
    const months = [
      'jan', 'fev', 'mar', 'avr', 'mai', 'juin',
      'juil', 'aout', 'sep', 'oct', 'nov', 'dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context))),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
