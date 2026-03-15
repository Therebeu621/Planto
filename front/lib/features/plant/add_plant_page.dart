import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planto/core/models/plant_identification_result.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/services/species_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class AddPlantPage extends StatefulWidget {
  /// Donnees pre-remplies par l'IA (optionnel)
  final PlantIdentificationResult? aiData;

  /// Photo prise pour l'identification IA (optionnel)
  final Uint8List? aiPhoto;

  final PlantService? plantService;
  final RoomService? roomService;
  final SpeciesService? speciesService;

  const AddPlantPage({
    super.key,
    this.aiData,
    this.aiPhoto,
    this.plantService,
    this.roomService,
    this.speciesService,
  });

  @override
  State<AddPlantPage> createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final _formKey = GlobalKey<FormState>();
  late final PlantService _plantService = widget.plantService ?? PlantService();
  late final RoomService _roomService = widget.roomService ?? RoomService();
  late final SpeciesService _speciesService = widget.speciesService ?? SpeciesService();

  String _nickname = '';
  String? _roomId;
  int _wateringInterval = 7;
  String _exposure = 'PARTIAL_SHADE';
  String? _selectedSpeciesId;
  PlantResult? _selectedPlant;  // Selected plant from database
  
  // Health flags
  bool _isSick = false;
  bool _isWilted = false;
  bool _needsRepotting = false;

  // Pot diameter
  final _potDiameterController = TextEditingController();

  // Last watering
  String? _lastWateredOption; // null = not selected

  // Photo
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;

  List<Room> _rooms = [];
  bool _isLoadingRooms = true;
  bool _isSubmitting = false;

  // Text controllers
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController();
  final FocusNode _speciesFocusNode = FocusNode();
  final GlobalKey _nicknameFieldKey = GlobalKey();
  List<PlantResult> _plantSuggestions = [];  // Plant search results
  bool _isSearchingSpecies = false;
  bool _showSpeciesSuggestions = false;
  Timer? _debounceTimer;

  final List<Map<String, dynamic>> _exposureOptions = [
    {'value': 'SUN', 'label': 'Plein soleil', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'value': 'PARTIAL_SHADE', 'label': 'Mi-ombre', 'icon': Icons.wb_cloudy, 'color': Colors.blueGrey},
    {'value': 'SHADE', 'label': 'Ombre', 'icon': Icons.nights_stay, 'color': Colors.indigo},
  ];

  final List<Map<String, dynamic>> _lastWateredOptions = [
    {'value': 'today', 'label': 'Aujourd\'hui', 'icon': Icons.water_drop, 'days': 0},
    {'value': 'yesterday', 'label': 'Hier', 'icon': Icons.water_drop_outlined, 'days': 1},
    {'value': 'few_days', 'label': 'Il y a 2-3 jours', 'icon': Icons.schedule, 'days': 3},
    {'value': 'week', 'label': 'Il y a ~1 semaine', 'icon': Icons.date_range, 'days': 7},
    {'value': 'long_ago', 'label': 'Plus longtemps', 'icon': Icons.history, 'days': 14},
    {'value': 'unknown', 'label': 'Je ne sais pas', 'icon': Icons.help_outline, 'days': null},
  ];

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _initializeFromAiData();
    _speciesFocusNode.addListener(() {
      if (!_speciesFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSpeciesSuggestions = false);
        });
      }
    });
  }

  /// Initialise les champs avec les donnees de l'IA si disponibles
  void _initializeFromAiData() {
    if (widget.aiData != null) {
      final data = widget.aiData!;
      _nickname = data.petitNom;
      _nicknameController.text = data.petitNom;
      _speciesController.text = data.espece;
      _wateringInterval = data.arrosageJours.clamp(1, 30);
      _exposure = data.exposureValue;
    }
    if (widget.aiPhoto != null) {
      _selectedPhotoBytes = widget.aiPhoto;
      _selectedPhotoName = 'photo_ia.jpg';
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _speciesController.dispose();
    _speciesFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _roomService.getRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoadingRooms = false;
          if (_rooms.isNotEmpty) {
            _roomId = _rooms.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Handle species search with 300ms debounce (uses local JSON database)
  void _onSpeciesSearchChanged(String query) {
    _debounceTimer?.cancel();

    // Clear selection if text changed
    if (_selectedPlant != null && query != _selectedPlant!.nomFrancais) {
      setState(() {
        _selectedPlant = null;
        _selectedSpeciesId = null;
      });
    }

    if (query.length < 2) {
      setState(() {
        _plantSuggestions = [];
        _isSearchingSpecies = false;
        _showSpeciesSuggestions = false;
      });
      return;
    }

    setState(() {
      _isSearchingSpecies = true;
      _showSpeciesSuggestions = true;
    });

    // Debounce 300ms - uses local JSON database
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _speciesService.searchPlants(query);
      if (mounted) {
        setState(() {
          _plantSuggestions = results;
          _isSearchingSpecies = false;
        });
      }
    });
  }

  /// Select a plant from database and apply its care info
  void _selectPlant(PlantResult plant) {
    setState(() {
      _selectedPlant = plant;
      _selectedSpeciesId = null;
      _speciesController.text = plant.nomFrancais;
      _plantSuggestions = [];
      _showSpeciesSuggestions = false;
      _wateringInterval = plant.arrosageFrequenceJours;
      _exposure = plant.getExposureValue();
    });
    _speciesFocusNode.unfocus();
    
    // Show confirmation toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🌱 ${plant.arrosageFrequenceJours} jours, ${plant.luminosite}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Get icon for light exposure
  IconData _getExposureIcon(String luminosite) {
    switch (luminosite) {
      case 'Plein soleil':
        return Icons.wb_sunny;
      case 'Ombre':
        return Icons.nights_stay;
      default:
        return Icons.wb_cloudy;
    }
  }

  /// Get color for light exposure
  Color _getExposureColor(String luminosite) {
    switch (luminosite) {
      case 'Plein soleil':
        return Colors.orange;
      case 'Ombre':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _handlePickPhoto() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ajouter une photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryC(context),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              ),
              title: const Text('Choisir depuis la galerie'),
              subtitle: Text('Selectionnez une photo existante', style: TextStyle(color: AppTheme.textGrey(context))),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Prendre une photo'),
              subtitle: Text('Utilisez l\'appareil photo', style: TextStyle(color: AppTheme.textGrey(context))),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_selectedPhotoBytes != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == 'delete') {
      setState(() {
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
      });
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: result == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _selectedPhotoBytes = bytes;
      _selectedPhotoName = image.name;
    });
  }

  void _scrollToError() {
    final keyContext = _nicknameFieldKey.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToError();
      return;
    }
    if (_roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez selectionner une piece')),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    try {
      final speciesText = _speciesController.text.trim();
      // Only use speciesId if it's a valid UUID (not perenual_xxx or unknown_xxx)
      final isValidUuid = _selectedSpeciesId != null &&
          !_selectedSpeciesId!.startsWith('perenual_') &&
          !_selectedSpeciesId!.startsWith('unknown_');

      // Create the plant
      final createdPlant = await _plantService.createPlant(
        nickname: _nickname,
        roomId: _roomId,
        wateringIntervalDays: _wateringInterval,
        exposure: _exposure,
        speciesId: isValidUuid ? _selectedSpeciesId : null,
        customSpecies: !isValidUuid && speciesText.isNotEmpty ? speciesText : null,
        isSick: _isSick,
        isWilted: _isWilted,
        needsRepotting: _needsRepotting,
        potDiameterCm: _potDiameterController.text.isNotEmpty
            ? double.tryParse(_potDiameterController.text)
            : null,
        lastWatered: _getLastWateredDate(),
      );

      // Upload photo if selected
      debugPrint('AddPlantPage: Photo bytes = ${_selectedPhotoBytes?.length}, name = $_selectedPhotoName');
      if (_selectedPhotoBytes != null && _selectedPhotoName != null) {
        try {
          debugPrint('AddPlantPage: Uploading photo for plant ${createdPlant.id}...');
          await _plantService.uploadPlantPhoto(
            createdPlant.id,
            _selectedPhotoBytes!,
            _selectedPhotoName!,
          );
          debugPrint('AddPlantPage: Photo uploaded successfully');
        } catch (photoError) {
          // Plant was created, but photo upload failed
          debugPrint('AddPlantPage: Photo upload failed: $photoError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Plante creee, mais erreur photo: $photoError'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        debugPrint('AddPlantPage: No photo to upload');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : CustomScrollView(
              slivers: [
                // Custom App Bar with plant image
                SliverAppBar(
                  expandedHeight: 200,
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
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
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
                            right: -30,
                            top: -30,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.overlayWhite(context, 0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -50,
                            bottom: -20,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.overlayWhite(context, 0.1),
                              ),
                            ),
                          ),
                          // Plant icon or image - tap to add photo
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                GestureDetector(
                                  onTap: _handlePickPhoto,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.shadow(context),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: _selectedPhotoBytes != null
                                            ? ClipOval(
                                                child: Image.memory(
                                                  _selectedPhotoBytes!,
                                                  fit: BoxFit.cover,
                                                  width: 90,
                                                  height: 90,
                                                ),
                                              )
                                            : const Icon(
                                                    Icons.eco,
                                                    size: 45,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                      ),
                                      // Camera icon overlay
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                                  Icons.camera_alt,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedPlant?.nomFrancais ?? 'Nouvelle plante',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_selectedPhotoBytes == null)
                                  Text(
                                    'Touchez pour ajouter une photo',
                                    style: TextStyle(
                                      color: AppTheme.overlayWhite(context, 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Form content
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banniere IA si pre-rempli
                          if (widget.aiData != null) ...[
                            _buildAiBanner(),
                            const SizedBox(height: 20),
                          ],

                          // Section: Identite
                          _buildSectionTitle('Identite', Icons.badge_outlined),
                          const SizedBox(height: 12),
                          _buildCard([
                            _buildTextField(
                              key: _nicknameFieldKey,
                              label: 'Petit nom',
                              hint: 'Ex: Monty, Ficus du salon...',
                              icon: Icons.favorite_outline,
                              controller: _nicknameController,
                              validator: (v) {
                                if (v?.isEmpty ?? true) return 'Donnez un nom a votre plante';
                                if (_roomId != null) {
                                  final room = _rooms.where((r) => r.id == _roomId).firstOrNull;
                                  if (room != null && room.plants.any((p) => p.nickname.toLowerCase() == v!.trim().toLowerCase())) {
                                    return 'Une plante avec ce nom existe deja dans cette piece';
                                  }
                                }
                                return null;
                              },
                              onSaved: (v) => _nickname = v!,
                            ),
                            const SizedBox(height: 16),
                            _buildSpeciesField(),
                          ]),

                          const SizedBox(height: 24),

                          // Section: Photo
                          _buildSectionTitle('Photo', Icons.photo_camera_outlined),
                          const SizedBox(height: 12),
                          _buildPhotoSection(),

                          const SizedBox(height: 24),

                          // Section: Recommendation (if plant selected)
                          if (_selectedPlant != null) ...[
                            _buildRecommendationCard(),
                            const SizedBox(height: 24),
                          ],

                          // Section: Emplacement
                          _buildSectionTitle('Emplacement', Icons.location_on_outlined),
                          const SizedBox(height: 12),
                          _buildCard([
                            _buildRoomSelector(),
                          ]),

                          const SizedBox(height: 24),

                          // Section: Conditions
                          _buildSectionTitle('Conditions', Icons.settings_outlined),
                          const SizedBox(height: 12),
                          _buildCard([
                            _buildExposureSelector(),
                            // Inline warning for exposure
                            _buildInlineWarning('exposure'),
                            const SizedBox(height: 20),
                            _buildWateringSlider(),
                            // Inline warning for watering
                            _buildInlineWarning('watering'),
                          ]),

                          const SizedBox(height: 24),

                          // Section: Dernier arrosage
                          _buildSectionTitle('Historique', Icons.history_outlined),
                          const SizedBox(height: 12),
                          _buildCard([
                            _buildLastWateredSelector(),
                          ]),

                          const SizedBox(height: 24),

                          // Warnings section removed - will handle with plantEnrichment if needed

                          // Section: Etat de sante
                          _buildSectionTitle('Etat de sante', Icons.healing_outlined),
                          const SizedBox(height: 12),
                          _buildCard([
                            _buildSwitch('Malade', 'La plante a-t-elle des parasites ou maladies ?', _isSick, (v) => setState(() => _isSick = v)),
                            const Divider(),
                            _buildSwitch('Fanee', 'Les feuilles sont-elles molles ou tombantes ?', _isWilted, (v) => setState(() => _isWilted = v)),
                            const Divider(),
                            _buildSwitch('A rempoter', 'Le pot est-il devenu trop petit ?', _needsRepotting, (v) => setState(() => _needsRepotting = v)),
                          ]),

                          const SizedBox(height: 24),

                          // Section: Pot
                          _buildSectionTitle('Taille du pot', Icons.straighten),
                          const SizedBox(height: 12),
                          _buildCard([
                            TextFormField(
                              controller: _potDiameterController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Diametre du pot (cm)',
                                hintText: 'Ex: 14',
                                prefixIcon: const Icon(Icons.straighten),
                                suffixText: 'cm',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: AppTheme.primaryColor),
                                ),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 32),

                          // Submit button
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAiBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('✨', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Identifiee par IA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.aiData?.description ?? 'Verifiez et ajustez les informations si necessaire.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildPhotoSection() {
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
        children: [
          Text(
            'Photo de votre plante (optionnel)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedPhotoBytes != null) ...[
            // Show selected photo
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _selectedPhotoBytes!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPhotoBytes = null;
                        _selectedPhotoName = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _handlePickPhoto,
                icon: const Icon(Icons.edit),
                label: const Text('Changer la photo'),
              ),
            ),
          ] else ...[
            // Show buttons to add photo
            Row(
              children: [
                Expanded(
                  child: _buildPhotoButton(
                    icon: Icons.photo_library,
                    label: 'Galerie',
                    color: AppTheme.primaryColor,
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1200,
                        maxHeight: 1200,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setState(() {
                          _selectedPhotoBytes = bytes;
                          _selectedPhotoName = image.name;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1200,
                        maxHeight: 1200,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setState(() {
                          _selectedPhotoBytes = bytes;
                          _selectedPhotoName = image.name;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    TextEditingController? controller,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    Widget? suffix,
  }) {
    return Column(
      key: key,
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
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textGrey(context)),
            prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 22),
            suffixIcon: suffix,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: validator,
          onSaved: onSaved,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSpeciesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Espece',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _speciesController,
          focusNode: _speciesFocusNode,
          decoration: InputDecoration(
            hintText: 'Rechercher ou saisir...',
            hintStyle: TextStyle(color: AppTheme.textGrey(context)),
            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
            suffixIcon: _isSearchingSpecies
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                    ),
                  )
                : _selectedPlant != null
                    ? const Icon(Icons.check_circle, color: AppTheme.successColor)
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: _onSpeciesSearchChanged,
        ),
        if (_selectedPlant != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        _selectedPlant!.nomLatin,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedPlant!.arrosageFrequenceJours}j',
                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getExposureColor(_selectedPlant!.luminosite).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getExposureIcon(_selectedPlant!.luminosite), 
                           size: 12, 
                           color: _getExposureColor(_selectedPlant!.luminosite)),
                      const SizedBox(width: 2),
                      Text(
                        _selectedPlant!.luminosite,
                        style: TextStyle(fontSize: 11, color: _getExposureColor(_selectedPlant!.luminosite)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Suggestions dropdown
        if (_showSpeciesSuggestions && _plantSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight(context)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadow(context),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _plantSuggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderLight(context)),
              itemBuilder: (context, index) {
                final plant = _plantSuggestions[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.eco, color: AppTheme.primaryColor),
                  ),
                  title: Text(plant.nomFrancais, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${plant.nomLatin} • ${plant.arrosageFrequenceJours}j • ${plant.luminosite}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    _getExposureIcon(plant.luminosite),
                    size: 18,
                    color: _getExposureColor(plant.luminosite),
                  ),
                  onTap: () => _selectPlant(plant),
                );
              },
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
            final isSelected = _roomId == room.id;
            return GestureDetector(
              onTap: () {
                setState(() => _roomId = room.id);
                // Re-validate nickname for duplicate check in new room
                _formKey.currentState?.validate();
              },
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
                    Text(
                      room.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
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
                    color: isSelected ? (option['color'] as Color).withOpacity(0.15) : AppTheme.inputFill(context),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_circle_outline, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Ajouter ma plante',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
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

  Widget _buildRecommendationCard() {
    if (_selectedPlant == null) return const SizedBox.shrink();
    
    final plant = _selectedPlant!;
    const accentColor = AppTheme.primaryColor;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.1),
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline, 
                  color: accentColor, 
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recommandations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      'Pour ${plant.nomFrancais}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Care info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.water_drop_outlined, 
                'Tous les ${plant.arrosageFrequenceJours} jours',
                Colors.blue,
              ),
              _buildInfoChip(
                _getSunlightIcon(plant.luminosite),
                plant.luminosite,
                Colors.orange,
              ),
              _buildInfoChip(
                Icons.science_outlined,
                plant.nomLatin,
                AppTheme.primaryColor,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Text(
            'Vous pouvez ajuster ces paramètres selon vos conditions.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppTheme.textGrey(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCareColor(String careLevel) {
    switch (careLevel.toLowerCase()) {
      case 'facile':
        return Colors.green;
      case 'moyen':
        return Colors.orange;
      case 'attention requise':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getSunlightIcon(String sunlight) {
    final lower = sunlight.toLowerCase();
    if (lower.contains('soleil') || lower.contains('sun')) return Icons.wb_sunny;
    if (lower.contains('ombre') && !lower.contains('mi')) return Icons.nights_stay;
    return Icons.wb_cloudy;
  }

  /// Get list of warnings based on user choices vs recommendations
  List<Map<String, dynamic>> _getWarnings() {
    if (_selectedPlant == null) return [];

    final warnings = <Map<String, dynamic>>[];
    final plant = _selectedPlant!;

    // Check exposure mismatch
    final recommendedExposure = plant.getExposureValue();
    if (_exposure != recommendedExposure) {
      final exposureSeverity = _getExposureMismatchSeverity(recommendedExposure, _exposure);
      if (exposureSeverity != null) {
        final recommendedLabel = _getExposureLabel(recommendedExposure);
        final chosenLabel = _getExposureLabel(_exposure);
        warnings.add({
          'type': 'exposure',
          'severity': exposureSeverity, // 'warning' or 'danger'
          'icon': Icons.wb_sunny_outlined,
          'title': 'Exposition non optimale',
          'message': exposureSeverity == 'danger'
              ? 'Cette plante a besoin de $recommendedLabel, mais vous avez choisi $chosenLabel. Cela pourrait nuire a sa sante.'
              : 'Recommande: $recommendedLabel. Vous avez choisi $chosenLabel.',
        });
      }
    }

    // Check watering interval mismatch
    final recommendedInterval = plant.arrosageFrequenceJours;
    final diff = (_wateringInterval - recommendedInterval).abs();
    final percentDiff = diff / recommendedInterval;

    if (percentDiff > 0.5) {
      // More than 50% difference
      final severity = percentDiff > 1.0 ? 'danger' : 'warning';
      warnings.add({
        'type': 'watering',
        'severity': severity,
        'icon': Icons.water_drop_outlined,
        'title': 'Frequence d\'arrosage inhabituelle',
        'message': severity == 'danger'
            ? 'Recommande: tous les $recommendedInterval jours. Vous avez choisi $_wateringInterval jours. Cette difference importante pourrait stresser la plante.'
            : 'Recommande: tous les $recommendedInterval jours. Vous avez choisi $_wateringInterval jours.',
      });
    }

    return warnings;
  }

  /// Get severity of exposure mismatch (null = ok, 'warning' = minor, 'danger' = major)
  String? _getExposureMismatchSeverity(String recommended, String chosen) {
    // SUN <-> SHADE is dangerous (opposite extremes)
    if ((recommended == 'SUN' && chosen == 'SHADE') ||
        (recommended == 'SHADE' && chosen == 'SUN')) {
      return 'danger';
    }
    // SUN <-> PARTIAL_SHADE or SHADE <-> PARTIAL_SHADE is just a warning
    if (recommended != chosen) {
      return 'warning';
    }
    return null;
  }

  String _getExposureLabel(String exposure) {
    switch (exposure) {
      case 'SUN':
        return 'plein soleil';
      case 'SHADE':
        return 'ombre';
      case 'PARTIAL_SHADE':
        return 'mi-ombre';
      default:
        return exposure;
    }
  }

  /// Build inline warning for a specific type ('exposure' or 'watering')
  Widget _buildInlineWarning(String type) {
    final warnings = _getWarnings();
    final warning = warnings.where((w) => w['type'] == type).firstOrNull;
    if (warning == null) return const SizedBox.shrink();

    final isDanger = warning['severity'] == 'danger';
    final color = isDanger ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              warning['message'] as String,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textGreyDark(context),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard() {
    final warnings = _getWarnings();
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Column(
      children: warnings.map((warning) {
        final isDanger = warning['severity'] == 'danger';
        final color = isDanger ? Colors.red : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDanger ? Colors.red.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      warning['message'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGreyDark(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  DateTime? _getLastWateredDate() {
    if (_lastWateredOption == null || _lastWateredOption == 'unknown') return null;

    final option = _lastWateredOptions.firstWhere(
      (o) => o['value'] == _lastWateredOption,
      orElse: () => {'days': null},
    );

    final days = option['days'] as int?;
    if (days == null) return null;

    return DateTime.now().subtract(Duration(days: days));
  }

  Widget _buildLastWateredSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.water_drop, size: 18, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text(
              'Dernier arrosage',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGrey(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Quand avez-vous arrose cette plante pour la derniere fois ?',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textGrey(context),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _lastWateredOptions.map((option) {
            final isSelected = _lastWateredOption == option['value'];
            final color = option['value'] == 'unknown'
                ? Colors.grey
                : Colors.blue;

            return GestureDetector(
              onTap: () => setState(() => _lastWateredOption = option['value']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : AppTheme.inputFill(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.divider(context),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      size: 18,
                      color: isSelected ? color : AppTheme.textGrey(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? color : AppTheme.textGreyDark(context),
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
}
