import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';

enum _Filter { all, unread, urgent }

/// Notification center: business alerts grouped by priority.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService.instance;
  late Future<List<AppAlert>> _future = _service.refresh();
  _Filter _filter = _Filter.all;

  void _reload() {
    setState(() {
      _future = _service.refresh();
    });
  }

  Future<void> _open(AppAlert a) async {
    await _service.markRead([a.id]);
    if (!mounted) return;
    await Navigator.pushNamed(context, a.route, arguments: a.args);
    if (mounted) _reload();
  }

  Future<void> _readAll(List<AppAlert> alerts) async {
    await _service.markRead(alerts.map((a) => a.id));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppAlert>>(
      future: _future,
      builder: (context, snap) {
        final all = snap.data ?? const <AppAlert>[];
        final unreadCount = all.where((a) => !a.read).length;
        final visible = all.where((a) => switch (_filter) {
              _Filter.all => true,
              _Filter.unread => !a.read,
              _Filter.urgent => a.level == AlertLevel.urgent,
            }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: () => _readAll(all),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Tout lire'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(children: [
            PillTabs<_Filter>(
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
              tabs: [
                PillTab(_Filter.all, 'Toutes', count: all.length),
                PillTab(_Filter.unread, 'Non lues', count: unreadCount),
                PillTab(_Filter.urgent, 'Urgentes',
                    count: all
                        .where((a) => a.level == AlertLevel.urgent)
                        .length),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(snap, visible)),
          ]),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<List<AppAlert>> snap, List<AppAlert> visible) {
    if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
    if (!snap.hasData) return const LoadingView();
    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'Tout est en ordre',
        message: 'Aucune notification pour le moment.',
      );
    }

    final children = <Widget>[];
    for (final level in AlertLevel.values) {
      final group = visible.where((a) => a.level == level).toList();
      if (group.isEmpty) continue;
      children.add(SectionHeader(
          title: '${level.label} (${group.length})',
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8)));
      for (final a in group) {
        children.add(Dismissible(
          key: ValueKey(a.id),
          direction:
              a.read ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.done_rounded, color: AppColors.success),
              SizedBox(width: 6),
              Text('Lu', style: TextStyle(color: AppColors.success)),
            ]),
          ),
          confirmDismiss: (_) async {
            await _service.markRead([a.id]);
            _reload();
            return false; // keep it in the list, shown as read
          },
          child: _AlertTile(alert: a, onTap: () => _open(a)),
        ));
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: children,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AppAlert alert;
  final VoidCallback onTap;
  const _AlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = alert;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      color: a.read
          ? context.palette.surfaceAlt.withValues(alpha: 0.6)
          : context.colors.surface,
      border: !a.read,
      shadow: !a.read,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
              icon: a.icon,
              color: a.read ? context.palette.muted : a.color,
              size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(a.title,
                        style: context.text.titleSmall?.copyWith(
                            color: a.read ? context.palette.muted : null),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (!a.read)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(left: 8, top: 4),
                      decoration: BoxDecoration(
                          color: a.color, shape: BoxShape.circle),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(a.message, style: context.text.bodySmall),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.event_rounded,
                      size: 13, color: context.palette.muted),
                  const SizedBox(width: 4),
                  Text(relativeDay(a.date),
                      style: context.text.labelSmall
                          ?.copyWith(color: context.palette.muted)),
                  const Spacer(),
                  Text('Ouvrir',
                      style: context.text.labelSmall
                          ?.copyWith(color: AppColors.brand)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.brand),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
