import 'package:flutter/material.dart';
import 'package:planto/core/models/house.dart';
import 'package:planto/core/models/house_member.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class HouseMembersPage extends StatefulWidget {
  final House house;
  final HouseService? houseService;
  final AuthService? authService;
  final ProfileService? profileService;

  const HouseMembersPage({
    super.key,
    required this.house,
    this.houseService,
    this.authService,
    this.profileService,
  });

  @override
  State<HouseMembersPage> createState() => _HouseMembersPageState();
}

class _HouseMembersPageState extends State<HouseMembersPage> {
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileService _profileService = widget.profileService ?? ProfileService();

  List<HouseMember> _members = [];
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _authService.getUserId();
      final members = await _houseService.getHouseMembers(widget.house.id);

      // Sort: owners first, then members, then guests, then by name
      int roleOrder(String role) {
        switch (role) {
          case 'OWNER': return 0;
          case 'MEMBER': return 1;
          case 'GUEST': return 2;
          default: return 3;
        }
      }
      members.sort((a, b) {
        final roleCompare = roleOrder(a.role).compareTo(roleOrder(b.role));
        if (roleCompare != 0) return roleCompare;
        return a.displayName.compareTo(b.displayName);
      });

      if (mounted) {
        setState(() {
          _currentUserId = userId;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showChangeRoleDialog(HouseMember member) async {
    final selectedRole = await showDialog<String>(
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
              child: const Icon(Icons.swap_vert, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Changer le role',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Role actuel : ${member.roleDisplayName}'),
            const SizedBox(height: 16),
            _buildRoleOption(context, 'OWNER', 'Proprietaire', Icons.star, Colors.amber, member.role),
            const SizedBox(height: 8),
            _buildRoleOption(context, 'MEMBER', 'Membre', Icons.person, AppTheme.primaryColor, member.role),
            const SizedBox(height: 8),
            _buildRoleOption(context, 'GUEST', 'Invite', Icons.visibility, Colors.grey, member.role),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textGrey(context))),
          ),
        ],
      ),
    );

    if (selectedRole != null && selectedRole != member.role) {
      try {
        await _houseService.updateMemberRole(widget.house.id, member.id, selectedRole);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Role modifie avec succes'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildRoleOption(BuildContext context, String role, String label, IconData icon, Color color, String currentRole) {
    final isSelected = role == currentRole;
    return InkWell(
      onTap: isSelected ? null : () => Navigator.pop(context, role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.divider(context),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            if (isSelected) Icon(Icons.check, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveMemberDialog(HouseMember member) async {
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
              child: const Icon(Icons.person_remove, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Exclure ce membre ?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous exclure "${member.displayName}" de la maison ?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette personne pourra rejoindre a nouveau avec le code d\'invitation.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textGrey(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Exclure'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _houseService.removeMember(widget.house.id, member.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.displayName} a ete exclu'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg(context),
      appBar: AppBar(
        title: const Text('Membres'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: AppTheme.primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.house.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${_members.length} membre${_members.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: AppTheme.textGrey(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Members list
                  ..._members.map((member) => _buildMemberCard(member)),
                ],
              ),
            ),
    );
  }

  Widget _buildMemberAvatar(HouseMember member) {
    final photoUrl = _profileService.getProfilePhotoFullUrl(member.profilePhotoPath);
    final hasPhoto = photoUrl != null;

    final avatarBgColor = member.isOwner
        ? Colors.amber.shade100
        : member.isGuest
            ? Colors.grey.shade100
            : AppTheme.primaryColor.withOpacity(0.1);
    final avatarTextColor = member.isOwner
        ? Colors.amber.shade800
        : member.isGuest
            ? Colors.grey.shade600
            : AppTheme.primaryColor;

    return CircleAvatar(
      radius: 25,
      backgroundColor: avatarBgColor,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      onBackgroundImageError: hasPhoto ? (exception, stackTrace) {} : null,
      child: hasPhoto
          ? null
          : Text(
              member.initials,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: avatarTextColor,
              ),
            ),
    );
  }

  Widget _buildMemberCard(HouseMember member) {
    final isCurrentUser = member.id == _currentUserId;
    final canManage = widget.house.isOwner && !isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar with profile photo or initials fallback
            _buildMemberAvatar(member),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Vous',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.email,
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Role badge
                  Builder(builder: (context) {
                    final Color badgeBg;
                    final Color badgeBorder;
                    final Color badgeColor;
                    final IconData badgeIcon;

                    if (member.isOwner) {
                      badgeBg = Colors.amber.shade50;
                      badgeBorder = Colors.amber.shade200;
                      badgeColor = Colors.amber.shade700;
                      badgeIcon = Icons.star;
                    } else if (member.isGuest) {
                      badgeBg = Colors.grey.shade50;
                      badgeBorder = Colors.grey.shade300;
                      badgeColor = Colors.grey.shade600;
                      badgeIcon = Icons.visibility;
                    } else {
                      badgeBg = AppTheme.inputFill(context);
                      badgeBorder = AppTheme.divider(context);
                      badgeColor = AppTheme.textGrey(context);
                      badgeIcon = Icons.person;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            member.roleDisplayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Actions (only for owner managing others)
            if (canManage) ...[
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textGrey(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'role') {
                    _showChangeRoleDialog(member);
                  } else if (value == 'remove') {
                    _showRemoveMemberDialog(member);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        const Icon(Icons.swap_vert, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Text('Changer le role'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(Icons.person_remove, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text('Exclure', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
