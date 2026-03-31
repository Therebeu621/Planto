import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/user_profile.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/gamification_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_service.dart';
import 'package:planto/core/services/plant_service.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/features/auth/login_page.dart';
import 'package:planto/features/house/house_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planto/core/theme/theme_provider.dart';

/// Profile page with user info, stats, settings, and account management
class ProfilePage extends StatefulWidget {
  final ProfileService? profileService;
  final AuthService? authService;
  final HouseService? houseService;
  final GamificationService? gamificationService;
  final NotificationService? notificationService;
  final PlantService? plantService;

  const ProfilePage({
    super.key,
    this.profileService,
    this.authService,
    this.houseService,
    this.gamificationService,
    this.notificationService,
    this.plantService,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileService _profileService = widget.profileService ?? ProfileService();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final GamificationService _gamificationService = widget.gamificationService ?? GamificationService();
  late final NotificationService _notificationService = widget.notificationService ?? NotificationService();
  late final PlantService _plantService = widget.plantService ?? PlantService();

  UserProfile? _user;
  UserStats? _stats;
  List<House> _houses = [];
  GamificationProfile? _gamification;
  bool _isLoading = true;
  String? _error;

  // Settings state
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'fr';
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  String _formatErrorMessage(Object error) {
    final message = error.toString();
    const prefix = 'Exception: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSettings();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _profileService.getCurrentUser(),
        _profileService.getUserStats(),
        _houseService.getMyHouses(),
        _gamificationService.getProfile(),
      ]);

      setState(() {
        _user = futures[0] as UserProfile;
        _stats = futures[1] as UserStats;
        _houses = futures[2] as List<House>;
        _gamification = futures[3] as GamificationProfile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'fr';
      final hour = prefs.getInt('reminder_hour') ?? 9;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
    await prefs.setString('language', _selectedLanguage);
    await prefs.setInt('reminder_hour', _reminderTime.hour);
    await prefs.setInt('reminder_minute', _reminderTime.minute);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text('Voulez-vous vraiment vous deconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Deconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Cette action est irreversible. Toutes vos donnees seront supprimees definitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _profileService.deleteAccount();
        await _authService.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
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
  }

  Future<void> _handleChangePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (currentPasswordController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le mot de passe actuel est requis'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              if (newPasswordController.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le nouveau mot de passe doit contenir au moins 8 caracteres'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Changer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _profileService.changePassword(
          currentPassword: currentPasswordController.text,
          newPassword: newPasswordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mot de passe modifie avec succes'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_formatErrorMessage(e)),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      await _saveSettings();

      // Reschedule all notifications with new time
      if (_notificationsEnabled) {
        await _notificationService.setNotificationTime(picked.hour, picked.minute);
        final plants = await _plantService.getMyPlants();
        await _notificationService.rescheduleAllReminders(plants);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rappels reprogrammes')),
          );
        }
      }
    }
  }

  Future<void> _leaveHouse(House house) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la maison'),
        content: Text('Voulez-vous vraiment quitter "${house.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _houseService.leaveHouse(house.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vous avez quitte "${house.name}"'),
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
  }

  Future<void> _handleChangePhoto() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_user?.hasProfilePhoto == true)
              ListTile(
                leading: Icon(Icons.delete, color: AppTheme.errorColor),
                title: Text('Supprimer la photo', style: TextStyle(color: AppTheme.errorColor)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == 'delete') {
      await _deletePhoto();
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: result == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    await _uploadPhoto(image);
  }

  Future<void> _uploadPhoto(XFile image) async {
    try {
      setState(() => _isLoading = true);
      final bytes = await image.readAsBytes();
      final fileName = image.name;
      final updatedUser = await _profileService.uploadProfilePhotoBytes(bytes, fileName);
      setState(() {
        _user = updatedUser;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise a jour'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _deletePhoto() async {
    try {
      setState(() => _isLoading = true);
      final updatedUser = await _profileService.deleteProfilePhoto();
      setState(() {
        _user = updatedUser;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo supprimee'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _handleEditDisplayName() async {
    final controller = TextEditingController(text: _user?.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nom d\'affichage',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _user?.displayName) {
      try {
        final updatedUser = await _profileService.updateProfile(displayName: result);
        setState(() => _user = updatedUser);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nom modifie avec succes'),
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
  }

  Future<void> _handleVerifyEmail() async {
    // First resend verification code
    try {
      await _profileService.resendVerification();
    } catch (_) {}

    if (!mounted) return;

    final codeController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Un code a 6 chiffres a ete envoye a ${_user?.email}',
              style: TextStyle(color: AppTheme.textSecondaryC(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, letterSpacing: 6),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, codeController.text.trim()),
            child: const Text('Verifier'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final updatedUser = await _profileService.verifyEmail(result);
        setState(() => _user = updatedUser);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verifie avec succes !'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString().replaceAll("Exception: ", "")}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('Mon Profil'),
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
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserInfoSection(),
                        const SizedBox(height: AppConstants.paddingL),
                        _buildGamificationSection(),
                        const SizedBox(height: AppConstants.paddingL),
                        _buildStatsSection(),
                        const SizedBox(height: AppConstants.paddingL),
                        _buildSettingsSection(),
                        const SizedBox(height: AppConstants.paddingL),
                        _buildAccountSection(),
                        const SizedBox(height: AppConstants.paddingXL),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      child: Center(
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingM),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: AppConstants.paddingS),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryC(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    if (_user == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informations', Icons.person),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Column(
              children: [
                // Avatar and name
                Row(
                  children: [
                    GestureDetector(
                      onTap: _handleChangePhoto,
                      child: Stack(
                        children: [
                          _user!.hasProfilePhoto
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(
                                    _profileService.getProfilePhotoFullUrl(_user!.profilePhotoUrl) ?? '',
                                  ),
                                  onBackgroundImageError: (_, __) {},
                                )
                              : CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Text(
                                    _user!.initials,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor,
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
                    const SizedBox(width: AppConstants.paddingL),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _user!.displayName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: _handleEditDisplayName,
                                tooltip: 'Modifier le nom',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user!.roleDisplay,
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                // Info rows
                Row(
                  children: [
                    Expanded(child: _buildInfoRow(Icons.email, 'Email', _user!.email)),
                    if (!_user!.emailVerified)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _handleVerifyEmail,
                        child: const Text('Verifier', style: TextStyle(fontSize: 12)),
                      )
                    else
                      const Icon(Icons.verified, color: AppTheme.primaryColor, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.calendar_today, 'Membre depuis', _user!.joinDateFormatted),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.eco, 'Plantes gerees', '${_stats?.totalPlants ?? 0}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondaryC(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppTheme.textSecondaryC(context)),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGamificationSection() {
    if (_gamification == null) return const SizedBox();
    final g = _gamification!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Progression', Icons.emoji_events),
        // Level card with XP bar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Column(
              children: [
                Row(
                  children: [
                    // Level circle
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${g.level}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.levelName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${g.xp} XP',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // XP progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Niveau suivant',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryC(context),
                          ),
                        ),
                        Text(
                          '${g.xpProgressInLevel} / ${g.xpForNextLevel} XP',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryC(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: g.xpProgress.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: AppTheme.lightBg(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingM),
        // Badges grid
        Text(
          'Badges (${g.unlockedBadges.length}/${g.badges.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryC(context),
              ),
        ),
        const SizedBox(height: AppConstants.paddingS),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: g.badges.length,
          itemBuilder: (context, index) {
            final badge = g.badges[index];
            return _buildBadgeItem(badge);
          },
        ),
      ],
    );
  }

  Widget _buildBadgeItem(BadgeInfo badge) {
    final baseUrl = AppConstants.apiBaseUrl;

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Opacity(
              opacity: badge.unlocked ? 1.0 : 0.35,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    '$baseUrl${badge.iconUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white,
                      child: Icon(
                        Icons.emoji_events,
                        color: badge.unlocked
                            ? AppTheme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: Center(
              child: Text(
                badge.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: badge.unlocked ? FontWeight.w600 : FontWeight.normal,
                  color: badge.unlocked
                      ? AppTheme.textPrimaryC(context)
                      : AppTheme.textSecondaryC(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(BadgeInfo badge) {
    final baseUrl = AppConstants.apiBaseUrl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Opacity(
                opacity: badge.unlocked ? 1.0 : 0.3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '$baseUrl${badge.iconUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.emoji_events,
                      size: 60,
                      color: badge.unlocked ? AppTheme.primaryColor : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryC(context)),
            ),
            const SizedBox(height: 8),
            if (badge.unlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Debloque !',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Verrouille',
                  style: TextStyle(
                    color: AppTheme.textSecondaryC(context),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Statistiques', Icons.bar_chart),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.water_drop,
                label: 'Arrosages ce mois',
                value: '${_stats!.wateringsThisMonth}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: AppConstants.paddingM),
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value: '${_stats!.wateringStreak} jours',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingM),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.favorite,
                label: 'Plantes en sante',
                value: '${_stats!.healthyPlantsPercentage}%',
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: AppConstants.paddingM),
            Expanded(
              child: _buildStatCard(
                icon: Icons.history,
                label: 'Plus ancienne',
                value: _stats!.oldestPlantName ?? 'Aucune',
                subtitle: _stats!.oldestPlantName != null ? _stats!.oldestPlantAgeText : null,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryC(context),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryC(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Parametres', Icons.settings),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                subtitle: const Text('Rappels d\'arrosage'),
                value: _notificationsEnabled,
                onChanged: (value) async {
                  setState(() => _notificationsEnabled = value);
                  await _saveSettings();
                  await _notificationService.setNotificationsEnabled(value);
                  if (value) {
                    // Request permissions and reschedule
                    await _notificationService.requestPermissions();
                    final plants = await _plantService.getMyPlants();
                    await _notificationService.scheduleAllReminders(plants);
                  }
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Mode sombre'),
                subtitle: const Text('Theme de l\'application'),
                value: _darkModeEnabled,
                onChanged: (value) async {
                  setState(() => _darkModeEnabled = value);
                  await _saveSettings();
                  // Apply dark mode via Riverpod provider
                  final container = ProviderScope.containerOf(context);
                  container.read(themeModeProvider.notifier).setDark(value);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Langue'),
                subtitle: Text(_selectedLanguage == 'fr' ? 'Francais' : 'English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Choisir la langue'),
                      children: [
                        RadioListTile<String>(
                          title: const Text('Francais'),
                          value: 'fr',
                          groupValue: _selectedLanguage,
                          onChanged: (value) => Navigator.pop(context, value),
                        ),
                        RadioListTile<String>(
                          title: const Text('English'),
                          value: 'en',
                          groupValue: _selectedLanguage,
                          onChanged: (value) => Navigator.pop(context, value),
                        ),
                      ],
                    ),
                  );
                  if (result != null) {
                    setState(() => _selectedLanguage = result);
                    await _saveSettings();
                    // TODO: Actually apply language change
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fonctionnalite a venir')),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Heure de rappel'),
                subtitle: Text(_reminderTime.format(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectReminderTime,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Gestion du compte', Icons.manage_accounts),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Mes Maisons'),
                subtitle: Text('${_houses.length} maison${_houses.length > 1 ? 's' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHousesDialog(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Changer le mot de passe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _handleChangePassword,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: AppTheme.errorColor),
                title: Text(
                  'Deconnexion',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                onTap: _handleLogout,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_forever, color: AppTheme.errorColor),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                onTap: _handleDeleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHousesDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes Maisons',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.paddingM),
            if (_houses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppConstants.paddingL),
                child: Center(
                  child: Text('Aucune maison'),
                ),
              )
            else
              ...List.generate(_houses.length, (index) {
                final house = _houses[index];
                return ListTile(
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HousePage()),
                    ).then((_) => _loadData()); // Refresh after returning
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.home, color: AppTheme.primaryColor),
                  ),
                  title: Text(house.name),
                  subtitle: Text(
                    '${house.memberCount} membre${house.memberCount > 1 ? 's' : ''} - ${house.roomCount} piece${house.roomCount > 1 ? 's' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (house.isOwner)
                        Flexible(
                          child: Chip(
                            label: const Text('Proprietaire'),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                );
              }),
            const SizedBox(height: AppConstants.paddingM),
          ],
        ),
      ),
    );
  }
}
