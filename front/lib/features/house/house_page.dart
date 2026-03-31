import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/utils/api_error_formatter.dart';
import 'package:planto/features/auth/login_page.dart';
import 'package:planto/features/house/house_members_page.dart';
import 'package:planto/features/house/vacation_page.dart';
import 'package:planto/features/room/room_list_page.dart';

class HousePage extends StatefulWidget {
  final HouseService? houseService;
  final AuthService? authService;
  final NotificationService? notificationService;
  final PlantService? plantService;

  const HousePage({
    super.key,
    this.houseService,
    this.authService,
    this.notificationService,
    this.plantService,
  });

  @override
  State<HousePage> createState() => _HousePageState();
}

class _HousePageState extends State<HousePage> {
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final NotificationService _notificationService =
      widget.notificationService ?? NotificationService();
  late final PlantService _plantService = widget.plantService ?? PlantService();

  House? _activeHouse;
  List<House> _allHouses = [];
  String? _userEmail;
  bool _isLoading = true;
  bool _notificationsEnabled = true; // Per-house notification preference

  void _showErrorSnackbar(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(formatApiError(error)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final email = await _authService.getUserEmail();
      final houses = await _houseService.getMyHouses();
      final activeHouse = houses.firstWhere(
        (h) => h.isActive,
        orElse: () => houses.isNotEmpty
            ? houses.first
            : House(
                id: '',
                name: '',
                inviteCode: '',
                memberCount: 0,
                roomCount: 0,
                isActive: false,
              ),
      );

      // Load notification preference for active house
      bool notifEnabled = true;
      if (activeHouse.id.isNotEmpty) {
        notifEnabled = await _notificationService.isHouseNotificationEnabled(
          activeHouse.id,
        );
      }

      if (mounted) {
        setState(() {
          _userEmail = email;
          _allHouses = houses;
          _activeHouse = activeHouse.id.isNotEmpty ? activeHouse : null;
          _notificationsEnabled = notifEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyInviteCode() {
    if (_activeHouse != null) {
      Clipboard.setData(ClipboardData(text: _activeHouse!.inviteCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Flexible(child: Text('Code copie dans le presse-papier !')),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showJoinHouseDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home_work, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Rejoindre une maison')),
          ],
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Code d\'invitation',
            filled: true,
            fillColor: AppTheme.inputFill(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.vpn_key, color: AppTheme.primaryColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textGrey(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final inviteCode = result.trim().toUpperCase();
      if (inviteCode.length != 8) {
        _showErrorSnackbar('Le code d\'invitation doit contenir 8 caracteres');
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Send a join request (creates a pending invitation)
        final invitation = await _houseService.requestJoinHouse(inviteCode);

        // Reload data
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demande envoyée pour "${invitation.houseName}" !'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar(e);
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showDeleteHouseDialog() async {
    if (_activeHouse == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Supprimer la maison ?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous êtes sur le point de supprimer "${_activeHouse!.name}".',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorBgLight(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorBorder(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Cette action est irreversible',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toutes les donnees seront supprimees :',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGreyDark(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildWarningItem('Toutes les plantes'),
                  _buildWarningItem('Toutes les pieces'),
                  _buildWarningItem('Tous les membres'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textGrey(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Supprimer definitivement'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _houseService.deleteHouse(_activeHouse!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maison supprimee avec succes'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          // Navigate back to home
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar(e);
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: AppTheme.textGrey(context)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textGreyDark(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateHouseDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_home, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Creer une maison')),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nom de la maison',
            filled: true,
            fillColor: AppTheme.inputFill(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.home, color: Colors.blue),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textGrey(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Creer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final houseName = result.trim();
      if (houseName.isEmpty) {
        _showErrorSnackbar('Veuillez entrer un nom de maison');
        return;
      }
      if (houseName.length > 100) {
        _showErrorSnackbar(
          'Le nom de la maison doit contenir au maximum 100 caracteres',
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Create the house and get the returned house object
        final createdHouse = await _houseService.createHouse(houseName);

        // Switch to the newly created house
        await _houseService.switchActiveHouse(createdHouse.id);

        // Reload data to show the new house
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maison "${createdHouse.name}" creee !'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar(e);
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _leaveHouse() async {
    if (_activeHouse == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.exit_to_app, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Quitter la maison ?')),
          ],
        ),
        content: const Text(
          'Vous ne pourrez plus voir les plantes de cette maison.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textGrey(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _houseService.leaveHouse(_activeHouse!.id);
        await _loadData();
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar(e);
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se deconnecter ?'),
        content: const Text(
          'Vous devrez vous reconnecter pour acceder a vos plantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textGrey(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Deconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg(context),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : CustomScrollView(
              slivers: [
                // Header with user info
                SliverAppBar(
                  expandedHeight: (MediaQuery.of(context).size.height * 0.3).clamp(180.0, 280.0),
                  pinned: true,
                  backgroundColor: AppTheme.primaryColor,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.overlayWhite(context, 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
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
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () {},
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withGreen(150),
                            AppTheme.primaryColor.withBlue(100),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Decorative circles
                          Positioned(
                            right: -40,
                            top: -40,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.4,
                              height: MediaQuery.of(context).size.width * 0.4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.overlayWhite(context, 0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -30,
                            bottom: 20,
                            child: Container(
                              width: (MediaQuery.of(context).size.width * 0.22).clamp(70.0, 120.0),
                              height: (MediaQuery.of(context).size.width * 0.22).clamp(70.0, 120.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.overlayWhite(context, 0.1),
                              ),
                            ),
                          ),
                          // User info
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 50),
                                // Avatar
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBg(context),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.shadow(context),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _userEmail
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          'U',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Email
                                Text(
                                  _userEmail ?? 'Utilisateur',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Role badge
                                if (_activeHouse != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.overlayWhite(
                                        context,
                                        0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _activeHouse!.isOwner
                                          ? 'Proprietaire'
                                          : 'Membre',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
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

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        if (_activeHouse != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.eco,
                                  value: '${_activeHouse!.roomCount * 3}',
                                  label: 'Plantes',
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.room,
                                  value: '${_activeHouse!.roomCount}',
                                  label: 'Pieces',
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.people,
                                  value: '${_activeHouse!.memberCount}',
                                  label: 'Membres',
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // House Section
                        _buildSectionTitle('Ma Maison', Icons.home_rounded),
                        const SizedBox(height: 12),

                        if (_activeHouse != null)
                          _buildHouseCard()
                        else
                          _buildNoHouseCard(),

                        const SizedBox(height: 24),

                        // Management Section (if has active house)
                        if (_activeHouse != null) ...[
                          _buildSectionTitle('Gestion', Icons.settings),
                          const SizedBox(height: 12),
                          _buildManagementCard(),
                          const SizedBox(height: 24),
                        ],

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Se deconnecter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryC(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHouseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          // House name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeHouse!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_activeHouse!.memberCount} membre${_activeHouse!.memberCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: AppTheme.textGrey(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_activeHouse!.isOwner)
                IconButton(
                  onPressed: _leaveHouse,
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  tooltip: 'Quitter',
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Invite code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.inputFill(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight(context)),
            ),
            child: Column(
              children: [
                Text(
                  'Code d\'invitation',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _activeHouse!.inviteCode,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _copyInviteCode,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copier le code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHouseCard() {
    return Container(
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
          Icon(
            Icons.home_work_outlined,
            size: 64,
            color: AppTheme.isDark(context)
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune maison',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGreyDark(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Creez ou rejoignez une maison pour commencer',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard() {
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
        children: [
          // Notification toggle for this house
          _buildNotificationToggle(),
          Divider(color: AppTheme.borderLight(context), height: 24),
          _buildActionTile(
            icon: Icons.meeting_room,
            title: 'Gerer les pieces',
            subtitle:
                '${_activeHouse!.roomCount} piece${_activeHouse!.roomCount > 1 ? 's' : ''} dans cette maison',
            color: Colors.blue,
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const RoomListPage()))
                  .then((_) => _loadData()); // Refresh after returning
            },
          ),
          Divider(color: AppTheme.borderLight(context), height: 24),
          _buildActionTile(
            icon: Icons.people,
            title: 'Gerer les membres',
            subtitle:
                '${_activeHouse!.memberCount} membre${_activeHouse!.memberCount > 1 ? 's' : ''} dans cette maison',
            color: Colors.purple,
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => HouseMembersPage(house: _activeHouse!),
                    ),
                  )
                  .then((_) => _loadData()); // Refresh after returning
            },
          ),
          Divider(color: AppTheme.borderLight(context), height: 24),
          _buildActionTile(
            icon: Icons.beach_access,
            title: 'Mode vacances',
            subtitle: 'Deleguez l\'entretien de vos plantes',
            color: Colors.orange,
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => VacationPage(house: _activeHouse!),
                    ),
                  )
                  .then((_) => _loadData());
            },
          ),
          // Delete house option (Owner only)
          if (_activeHouse!.isOwner) ...[
            Divider(color: AppTheme.borderLight(context), height: 24),
            _buildActionTile(
              icon: Icons.delete_forever,
              title: 'Supprimer la maison',
              subtitle: 'Action irreversible - Supprime tout le contenu',
              color: Colors.red,
              onTap: _showDeleteHouseDialog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _notificationsEnabled
              ? Icons.notifications_active
              : Icons.notifications_off,
          color: AppTheme.primaryColor,
        ),
      ),
      title: const Text(
        'Notifications',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _notificationsEnabled
            ? 'Rappels d\'arrosage actifs'
            : 'Rappels desactives pour cette maison',
        style: TextStyle(color: AppTheme.textGrey(context), fontSize: 12),
      ),
      value: _notificationsEnabled,
      activeColor: AppTheme.primaryColor,
      onChanged: (value) async {
        setState(() => _notificationsEnabled = value);

        // Save preference
        await _notificationService.setHouseNotificationEnabled(
          _activeHouse!.id,
          value,
        );

        // Schedule or cancel notifications for this house
        if (value) {
          // Enable: schedule notifications for plants in this house
          final plants = await _plantService.getMyPlants();
          await _notificationService.scheduleAllReminders(
            plants,
            houseId: _activeHouse!.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rappels actives pour cette maison'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } else {
          // Disable: cancel notifications for plants in this house
          final plants = await _plantService.getMyPlants();
          await _notificationService.cancelHouseReminders(plants);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rappels desactives pour cette maison'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textGrey(context), fontSize: 12),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.isDark(context)
            ? Colors.grey.shade600
            : Colors.grey.shade400,
      ),
    );
  }
}
