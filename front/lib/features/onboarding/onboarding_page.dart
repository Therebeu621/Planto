import 'package:flutter/material.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/features/home/home_page.dart';

/// Onboarding page for new users without a house.
/// Guides them through creating their first house and room.
class OnboardingPage extends StatefulWidget {
  final String userEmail;
  final HouseService? houseService;
  final RoomService? roomService;

  const OnboardingPage({super.key, required this.userEmail, this.houseService, this.roomService});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: House name
  final _houseNameController = TextEditingController(text: 'Ma Maison');

  // Step 2: First room
  final _roomNameController = TextEditingController();
  String _selectedRoomType = 'LIVING_ROOM';

  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final RoomService _roomService = widget.roomService ?? RoomService();
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _roomTypes = [
    {'name': 'Salon', 'icon': Icons.weekend, 'value': 'LIVING_ROOM'},
    {'name': 'Chambre', 'icon': Icons.bed, 'value': 'BEDROOM'},
    {'name': 'Cuisine', 'icon': Icons.kitchen, 'value': 'KITCHEN'},
    {'name': 'Salle de bain', 'icon': Icons.bathtub, 'value': 'BATHROOM'},
    {'name': 'Bureau', 'icon': Icons.computer, 'value': 'OFFICE'},
    {'name': 'Balcon', 'icon': Icons.balcony, 'value': 'BALCONY'},
    {'name': 'Jardin', 'icon': Icons.grass, 'value': 'GARDEN'},
    {'name': 'Autre', 'icon': Icons.home, 'value': 'OTHER'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _houseNameController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_houseNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Donnez un nom a votre maison');
        return;
      }
      setState(() => _errorMessage = null);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Auto-fill room name from type if empty
      if (_roomNameController.text.trim().isEmpty) {
        final type = _roomTypes.firstWhere((t) => t['value'] == _selectedRoomType);
        _roomNameController.text = type['name'];
      }
      setState(() => _errorMessage = null);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 2);
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create house
      await _houseService.createHouse(_houseNameController.text.trim());

      // Create first room
      final roomName = _roomNameController.text.trim().isNotEmpty
          ? _roomNameController.text.trim()
          : _roomTypes.firstWhere((t) => t['value'] == _selectedRoomType)['name'];
      await _roomService.createRoom(roomName, _selectedRoomType);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(userEmail: widget.userEmail),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _skipToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(userEmail: widget.userEmail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(),
                  _buildRoomStep(),
                  _buildConfirmStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 1: Welcome + House name
  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Plant icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco,
              size: 50,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Bienvenue sur Planto !',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryC(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Commencez par donner un nom a votre maison pour organiser vos plantes.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryC(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // House name input
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowSoft(context),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _houseNameController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Ex: Mon Appartement',
                prefixIcon: const Icon(Icons.home_rounded, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.cardBg(context),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 32),
          // Next button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _skipToHome,
            child: Text(
              'Passer',
              style: TextStyle(color: AppTheme.textSecondaryC(context), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: Choose first room
  Widget _buildRoomStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.meeting_room_rounded,
              size: 40,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ajoutez votre premiere piece',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryC(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ou allez-vous mettre vos plantes ?',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryC(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Room type grid
          SizedBox(
            height: 220,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _roomTypes.length,
              itemBuilder: (context, index) {
                final type = _roomTypes[index];
                final isSelected = _selectedRoomType == type['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRoomType = type['value'];
                      _roomNameController.text = type['name'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.12)
                          : AppTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderLight(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          size: 28,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryC(context),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimaryC(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Custom room name
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _roomNameController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Nom personnalise (optionnel)',
                hintStyle: TextStyle(fontSize: 14, color: AppTheme.isDark(context) ? Colors.grey.shade600 : Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.borderLight(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.borderLight(context)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 3: Confirm and create
  Widget _buildConfirmStep() {
    final roomName = _roomNameController.text.trim().isNotEmpty
        ? _roomNameController.text.trim()
        : _roomTypes.firstWhere((t) => t['value'] == _selectedRoomType)['name'];
    final roomType = _roomTypes.firstWhere((t) => t['value'] == _selectedRoomType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 45,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tout est pret !',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voici ce que nous allons creer :',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondaryC(context)),
          ),
          const SizedBox(height: 32),
          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowSoft(context),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // House
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.home_rounded, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maison',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryC(context),
                          ),
                        ),
                        Text(
                          _houseNameController.text.trim(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: AppTheme.inputFill(context)),
                const SizedBox(height: 20),
                // Room
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        roomType['icon'] as IconData,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premiere piece',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryC(context),
                          ),
                        ),
                        Text(
                          roomName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'C\'est parti !',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
