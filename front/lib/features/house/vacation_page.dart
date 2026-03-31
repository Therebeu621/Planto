import 'package:flutter/material.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/house_member.dart';
import 'package:planto/core/models/vacation_delegation.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/utils/api_error_formatter.dart';

class VacationPage extends StatefulWidget {
  final House house;
  final HouseService? houseService;
  final AuthService? authService;

  const VacationPage({
    super.key,
    required this.house,
    this.houseService,
    this.authService,
  });

  @override
  State<VacationPage> createState() => _VacationPageState();
}

class _VacationPageState extends State<VacationPage> {
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final AuthService _authService = widget.authService ?? AuthService();

  bool _isLoading = true;
  VacationDelegation? _activeVacation;
  List<VacationDelegation> _houseDelegations = [];
  List<VacationDelegation> _myDelegations = [];
  List<HouseMember> _members = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _authService.getUserId(),
        _houseService.getVacationStatus(widget.house.id),
        _houseService.getHouseDelegations(widget.house.id),
        _houseService.getMyDelegations(widget.house.id),
        _houseService.getHouseMembers(widget.house.id),
      ]);

      if (mounted) {
        setState(() {
          _currentUserId = results[0] as String?;
          _activeVacation = results[1] as VacationDelegation?;
          _houseDelegations = results[2] as List<VacationDelegation>;
          _myDelegations = results[3] as List<VacationDelegation>;
          _members = results[4] as List<HouseMember>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              formatApiError(
                e,
                fallbackMessage: 'Impossible de charger le mode vacances',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showActivateVacationDialog() async {
    HouseMember? selectedDelegate;
    DateTime? startDate;
    DateTime? endDate;
    final messageController = TextEditingController();

    // Exclude guests and the current user from the delegate list.
    final otherMembers = _members
        .where((m) => !m.isGuest && m.id != _currentUserId)
        .toList();

    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Il faut au moins un autre membre non invite pour deleguer vos plantes',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.beach_access, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Mode vacances')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deleguez l\'entretien de vos plantes a un membre de la maison.',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                // Delegate picker
                Text(
                  'Deleguer a',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryC(context),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<HouseMember>(
                      isExpanded: true,
                      value: selectedDelegate,
                      hint: const Text('Choisir un membre'),
                      items: otherMembers.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            '${m.displayName} (${m.roleDisplayName})',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedDelegate = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start date
                Text(
                  'Date de depart',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryC(context),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            startDate != null
                                ? '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}'
                                : 'Selectionner',
                            style: TextStyle(
                              color: startDate != null
                                  ? AppTheme.textPrimaryC(context)
                                  : AppTheme.textGrey(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // End date
                Text(
                  'Date de retour',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryC(context),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          startDate ??
                          DateTime.now().add(const Duration(days: 1)),
                      firstDate:
                          startDate ??
                          DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            endDate != null
                                ? '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}'
                                : 'Selectionner',
                            style: TextStyle(
                              color: endDate != null
                                  ? AppTheme.textPrimaryC(context)
                                  : AppTheme.textGrey(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  'Message (optionnel)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryC(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ex: Arroser les orchidees tous les 2 jours',
                    filled: true,
                    fillColor: AppTheme.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
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
              onPressed:
                  (selectedDelegate != null &&
                      startDate != null &&
                      endDate != null)
                  ? () => Navigator.pop(context, {
                      'delegateId': selectedDelegate!.id,
                      'startDate': _formatDate(startDate!),
                      'endDate': _formatDate(endDate!),
                      'message': messageController.text.trim(),
                    })
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Activer'),
            ),
          ],
        ),
      ),
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        if (result['delegateId'] == _currentUserId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vous ne pouvez pas vous deleguer vos plantes a vous-meme',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() => _isLoading = true);
        try {
          await _houseService.activateVacation(
            widget.house.id,
            delegateId: result['delegateId'],
            startDate: result['startDate'],
            endDate: result['endDate'],
            message: result['message'],
          );
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mode vacances active !'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  formatApiError(
                    e,
                    fallbackMessage: 'Impossible d\'activer le mode vacances',
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
        }
      }
    });
  }

  Future<void> _cancelVacation() async {
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
              child: const Icon(Icons.cancel, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Annuler les vacances ?')),
          ],
        ),
        content: const Text(
          'La delegation sera annulee et vous reprendrez l\'entretien de vos plantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Non',
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
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _houseService.cancelVacation(widget.house.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mode vacances desactive'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                formatApiError(
                  e,
                  fallbackMessage: 'Impossible d\'annuler le mode vacances',
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg(context),
      appBar: AppBar(
        title: const Text('Mode vacances'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Active vacation banner
                  if (_activeVacation != null) _buildActiveVacationCard(),

                  // Activate button (only if no active vacation)
                  if (_activeVacation == null) _buildActivateCard(),

                  // My delegations received
                  if (_myDelegations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'Plantes a ma charge',
                      Icons.volunteer_activism,
                    ),
                    const SizedBox(height: 12),
                    ..._myDelegations.map(
                      (d) => _buildDelegationCard(d, isReceived: true),
                    ),
                  ],

                  // House delegations
                  if (_houseDelegations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Delegations de la maison', Icons.group),
                    const SizedBox(height: 12),
                    ..._houseDelegations.map(
                      (d) => _buildDelegationCard(d, isReceived: false),
                    ),
                  ],

                  // Empty state
                  if (_activeVacation == null &&
                      _myDelegations.isEmpty &&
                      _houseDelegations.isEmpty)
                    _buildEmptyState(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveVacationCard() {
    final v = _activeVacation!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.beach_access, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vacances en cours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  v.daysRemaining >= 0
                      ? '${v.daysRemaining}j restants'
                      : 'Termine',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person, 'Delegue a', v.delegateName),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.date_range,
            'Du',
            '${_formatDisplayDate(v.startDate)} au ${_formatDisplayDate(v.endDate)}',
          ),
          if (v.message != null && v.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.message, 'Message', v.message!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cancelVacation,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Annuler les vacances'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivateCard() {
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.beach_access,
              color: Colors.orange,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Partez l\'esprit tranquille',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deleguez l\'arrosage de vos plantes a un membre de la maison pendant votre absence.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showActivateVacationDialog,
              icon: const Icon(Icons.flight_takeoff, size: 20),
              label: const Text('Activer le mode vacances'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationCard(
    VacationDelegation d, {
    required bool isReceived,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isReceived ? Colors.blue : Colors.orange).withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isReceived ? Icons.volunteer_activism : Icons.beach_access,
              color: isReceived ? Colors.blue : Colors.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceived
                      ? '${d.delegatorName} est en vacances'
                      : '${d.delegatorName} → ${d.delegateName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDisplayDate(d.startDate)} - ${_formatDisplayDate(d.endDate)}',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 12,
                  ),
                ),
                if (d.message != null && d.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    d.message!,
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.isActive
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.textGrey(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              d.isActive
                  ? '${d.daysRemaining}j'
                  : d.isCancelled
                  ? 'Annule'
                  : 'Termine',
              style: TextStyle(
                color: d.isActive
                    ? AppTheme.successColor
                    : AppTheme.textGrey(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 64,
            color: AppTheme.isDark(context)
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune delegation en cours',
            style: TextStyle(fontSize: 16, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }
}
