import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isAdmin = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.refreshInbox();
    });
  }

  void _checkAdminStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final isAdmin = userData?['userType'] == 'admin';
          if (mounted) {
            setState(() => _isAdmin = isAdmin);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear all?'),
          content: const Text('All notifications will be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear all'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await NotificationService.clearAllNotifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id, String title) async {
    try {
      await NotificationService.clearNotification(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed: $title')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.showNotification(
      title: 'Test notification',
      body: 'Time: ${DateFormat.jm().format(DateTime.now())}',
    );
  }

  DateTime _safeCreatedAt(Map<String, dynamic> n) {
    final v = n['createdAt'];
    if (v is DateTime) return v;
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? null
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await NotificationService.refreshInbox();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Updated'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: NotificationService.notificationsList,
            builder: (context, notifications, child) {
              if (notifications.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear all',
                onPressed: _clearAllNotifications,
              );
            },
          ),
          if (_isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'send_test') _sendTestNotification();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'send_test',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Send test'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: NotificationService.notificationsList,
        builder: (context, notifications, child) {
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 56,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No notifications yet',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Draw updates and win alerts show up here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => NotificationService.refreshInbox(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(
                  notification: n,
                  createdAt: _safeCreatedAt(n),
                  onTap: () => NotificationService.markAsRead(n['id'] as String),
                  onDismiss: () => _deleteNotification(
                    n['id'] as String,
                    (n['title'] ?? '').toString(),
                  ),
                  iconForType: _iconForType,
                  colorForType: _colorForType,
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'WINNING_BOND':
      case 'WINNER':
        return Icons.emoji_events_rounded;
      case 'DRAW_ANNOUNCEMENT':
        return Icons.upload_file_rounded;
      case 'DRAW_UPDATE':
        return Icons.update_rounded;
      case 'SYSTEM':
        return Icons.notifications_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForType(String? type, ColorScheme cs) {
    switch (type) {
      case 'WINNING_BOND':
      case 'WINNER':
        return Colors.amber.shade800;
      case 'DRAW_ANNOUNCEMENT':
        return cs.primary;
      default:
        return cs.primary;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.createdAt,
    required this.onTap,
    required this.onDismiss,
    required this.iconForType,
    required this.colorForType,
  });

  final Map<String, dynamic> notification;
  final DateTime createdAt;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final IconData Function(String?) iconForType;
  final Color Function(String?, ColorScheme) colorForType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final id = notification['id'] as String;
    final title = (notification['title'] ?? 'Notification').toString();
    final body = (notification['body'] ?? '').toString();
    final type = notification['type']?.toString();
    final isRead = notification['isRead'] == true;
    final bond = notification['bondNumber'];
    final draw = notification['drawNumber'];
    final prizeType = notification['prizeType'];

    return Dismissible(
      key: Key('n_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: isRead
                  ? theme.cardColor
                  : AppColors.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead ? theme.dividerColor.withValues(alpha: 0.3) : AppColors.primaryColor.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorForType(type, cs).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      iconForType(type),
                      color: colorForType(type, cs),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                  fontSize: 15,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6, top: 4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            body,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              height: 1.35,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (bond != null || draw != null || prizeType != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (bond != null)
                                _chip(Icons.tag, 'Bond $bond', cs),
                              if (draw != null)
                                _chip(Icons.event_note_outlined, 'Draw $draw', cs),
                              if (prizeType != null)
                                _chip(Icons.stars_outlined, prizeType.toString(), cs),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('d MMM, hh:mm a').format(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.grey[600],
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
      ),
    );
  }

  Widget _chip(IconData icon, String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
