import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../models/app_notification_item.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsProvider>().reload();
    });
  }

  Future<void> _enableNotifications() async {
    await context
        .read<PushNotificationService>()
        .requestPermissionAndSyncToken();
  }

  Future<void> _openNotificationSettings() async {
    await context
        .read<PushNotificationService>()
        .openSystemNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<NotificationsProvider>(
          builder: (context, notifications, _) {
            return Column(
              children: [
                _NotificationsHeader(
                  unreadCount: notifications.unreadCount,
                  onBack: () => Navigator.pop(context),
                  onMarkAllRead: notifications.unreadCount > 0
                      ? () {
                          HapticFeedback.selectionClick();
                          notifications.markAllAsRead();
                        }
                      : null,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                    onRefresh: notifications.reload,
                    child: _buildBody(notifications),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(NotificationsProvider notifications) {
    final showPrompt =
        !notifications.permissionGranted ||
        !notifications.tokenSynced ||
        !notifications.pushAvailable;

    final prompt = showPrompt
        ? _NotificationSettingsPrompt(
            notifications: notifications,
            onEnable: _enableNotifications,
            onOpenSettings: _openNotificationSettings,
          )
        : null;

    if (notifications.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (prompt != null) ...[prompt, const SizedBox(height: 8)],
          const SizedBox(height: 24),
          const _EmptyStateView(),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: notifications.items.length + (prompt != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (prompt != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: prompt,
          );
        }
        final item = notifications.items[index - (prompt != null ? 1 : 0)];
        return _NotificationTile(item: item);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header — rose-gradient curved header (matches the rest of AILA)
// ─────────────────────────────────────────────────────────────

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.onBack,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback onBack;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 26),
      decoration: const BoxDecoration(
        gradient: AppColors.roseGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: AppIcons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              const Spacer(),
              if (onMarkAllRead != null)
                _GlassChip(
                  icon: AppIcons.check_rounded,
                  label: 'تعليم الكل كمقروء',
                  onTap: onMarkAllRead!,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'NOTIFICATIONS',
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'الإشعارات',
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AppIcons.notifications_active_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$unreadCount جديد',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.roseGold),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Notification Card
// ─────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final visual = _resolveVisuals(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<PushNotificationService>().openNotificationItem(item);
          },
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.unread ? AppColors.surfaceVariant : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Icon(visual.icon, color: visual.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 14.5,
                                fontWeight: item.unread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (item.unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.badge,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.body.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            AppIcons.access_time_rounded,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatRelativeTime(item.receivedAt),
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم';
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }

  _NotificationVisuals _resolveVisuals(AppNotificationItem item) {
    switch (item.type) {
      case 'order_status_changed':
      case 'order.created':
        return const _NotificationVisuals(
          icon: AppIcons.local_shipping_rounded,
          color: AppColors.primary,
        );
      case 'wallet_topup_completed':
      case 'wallet.topup.completed':
        return const _NotificationVisuals(
          icon: AppIcons.arrow_downward_rounded,
          color: AppColors.success,
        );
      case 'payment_failed':
      case 'payment.failed':
        return const _NotificationVisuals(
          icon: AppIcons.warning_amber_rounded,
          color: AppColors.badge,
        );
      default:
        return const _NotificationVisuals(
          icon: AppIcons.notifications_none_rounded,
          color: AppColors.roseGold,
        );
    }
  }
}

class _NotificationVisuals {
  const _NotificationVisuals({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: const BoxDecoration(
              gradient: AppColors.blushGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              AppIcons.notifications_none_rounded,
              size: 52,
              color: AppColors.roseGold,
            ),
          ),
          const SizedBox(height: 26),
          const AilaEyebrow('ALL CAUGHT UP'),
          const SizedBox(height: 10),
          Text(
            'لا توجد إشعارات بعد',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'عند وجود تحديث بخصوص طلباتك أو رصيدك سيظهر هنا مباشرة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: 240,
            child: AilaGradientButton(
              label: 'تصفّحي المنتجات',
              icon: AppIcons.shopping_bag_outlined,
              onPressed: () {
                final shell = context.read<AppShellController>();
                shell.goHome();
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Prompt
// ─────────────────────────────────────────────────────────────

class _NotificationSettingsPrompt extends StatelessWidget {
  final NotificationsProvider notifications;
  final VoidCallback onEnable;
  final VoidCallback onOpenSettings;

  const _NotificationSettingsPrompt({
    required this.notifications,
    required this.onEnable,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final bool requiresSettings = notifications.requiresSystemSettings;
    final String label = requiresSettings
        ? 'إعدادات النظام'
        : 'تفعيل الإشعارات';
    final VoidCallback action = requiresSettings ? onOpenSettings : onEnable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              AppIcons.notifications_off_rounded,
              color: AppColors.warning,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'فعّلي الإشعارات للحصول على التحديثات فوراً',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
