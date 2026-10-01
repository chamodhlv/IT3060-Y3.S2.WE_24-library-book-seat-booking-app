import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../services/seat_service.dart';
import '../../services/auth_service.dart';

/// Shared notifications screen (student & librarian).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final notifs = await SeatService().getNotifications(user.id);
      setState(() {
        _notifications = notifs;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    await SeatService().markAllRead(user.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.primaryGreen)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryDark))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined,
                          size: 48,
                          color: AppTheme.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('No notifications yet',
                          style: GoogleFonts.inter(
                              fontSize: 15, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primaryDark,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _buildNotifCard(_notifications[i]),
                  ),
                ),
    );
  }

  Widget _buildNotifCard(AppNotification n) {
    final icon = _iconFor(n.type);
    final color = _colorFor(n.type);

    return GestureDetector(
      onTap: () async {
        if (!n.isRead) {
          await SeatService().markNotificationRead(n.id);
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.isRead ? AppTheme.divider : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: n.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(n.createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'booking_confirmed':
        return Icons.check_circle_outline_rounded;
      case 'booking_cancelled':
        return Icons.cancel_outlined;
      case 'booking_checkin':
        return Icons.how_to_reg_outlined;
      case 'reminder':
        return Icons.alarm_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'booking_confirmed':
        return AppTheme.successGreen;
      case 'booking_cancelled':
        return AppTheme.errorRed;
      case 'booking_checkin':
        return AppTheme.primaryGreen;
      case 'reminder':
        return AppTheme.warningAmber;
      default:
        return AppTheme.primaryDark;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
