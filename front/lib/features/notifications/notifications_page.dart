import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planto/core/services/fcm_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/services/notification_api_service.dart';
import 'package:planto/core/theme/app_theme.dart';

/// Page showing in-app notifications with accept/decline for house invitations.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationApiService _notifService = NotificationApiService();
  final HouseService _houseService = HouseService();

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    FcmService().addOnMessageListener(_onFcmMessage);
  }

  @override
  void dispose() {
    FcmService().removeOnMessageListener(_onFcmMessage);
    super.dispose();
  }

  void _onFcmMessage(Map<String, dynamic> data) {
    // Auto-refresh notifications when a push arrives
    _loadNotifications();
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'A l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notifService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptInvitation(AppNotification notif) async {
    if (notif.invitationId == null) return;
    setState(() => _processingIds.add(notif.id));

    try {
      await _houseService.acceptInvitation(notif.invitationId!);
      await _notifService.markAsRead(notif.id);
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande acceptee ! Le membre a rejoint la maison.'),
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
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(notif.id));
      }
    }
  }

  Future<void> _declineInvitation(AppNotification notif) async {
    if (notif.invitationId == null) return;
    setState(() => _processingIds.add(notif.id));

    try {
      await _houseService.declineInvitation(notif.invitationId!);
      await _notifService.markAsRead(notif.id);
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande refusee.'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(notif.id));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await _notifService.markAllAsRead();
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tout lire',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildNotificationTile(_notifications[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppTheme.textGrey(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textGrey(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notif) {
    final isProcessing = _processingIds.contains(notif.id);
    final timeAgo = _formatTimeAgo(notif.createdAt);

    return Container(
      color: notif.read
          ? null
          : AppTheme.primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconColor(notif.type).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _icon(notif.type),
                    color: _iconColor(notif.type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: notif.read ? FontWeight.normal : FontWeight.w600,
                          color: AppTheme.textPrimaryC(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread dot
                if (!notif.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            // Accept/Decline buttons for house invitations
            if (notif.isHouseInvitation && !notif.read)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 44),
                child: isProcessing
                    ? const SizedBox(
                        height: 36,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _declineInvitation(notif),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Refuser'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: const BorderSide(color: AppTheme.errorColor),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptInvitation(notif),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accepter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'HOUSE_INVITATION':
        return Icons.person_add;
      case 'MEMBER_JOINED':
        return Icons.group_add;
      case 'WATERING_REMINDER':
        return Icons.water_drop;
      case 'CARE_REMINDER':
        return Icons.spa;
      case 'PLANT_ADDED':
        return Icons.local_florist;
      default:
        return Icons.notifications;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'HOUSE_INVITATION':
        return Colors.blue;
      case 'MEMBER_JOINED':
        return AppTheme.successColor;
      case 'WATERING_REMINDER':
        return Colors.lightBlue;
      case 'CARE_REMINDER':
        return Colors.orange;
      case 'PLANT_ADDED':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }
}
