import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../../shared/widgets/kredi_media.dart';
import '../shell/app_destination.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onOpen});
  final ValueChanged<AppDestination>? onOpen;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> future;
  bool started = false;
  final Set<int> _hiddenIds = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      AppScope.of(context).api.notifications().timeout(const Duration(seconds: 15));

  Future<void> reload() async {
    setState(() => future = _load());
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return KrediEmptyState(
              icon: KrediIcons.notifications,
              title: 'No pudimos cargar tus notificaciones',
              message: 'Revisa tu conexión y vuelve a intentarlo.',
              actionLabel: 'Reintentar',
              onAction: reload,
            );
          }
          final rows = [...?snap.data]
            ..removeWhere((item) => _hiddenIds.contains(jInt(item, ['id'])))
            ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
                children: const [
                  SizedBox(height: 84),
                  KrediEmptyState(
                    icon: KrediIcons.notifications,
                    title: 'Sin notificaciones',
                    message: 'Cuando ocurra algo importante en tu cuenta aparecerá aquí.',
                  ),
                ],
              ),
            );
          }

          final groups = _groupRows(rows);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      TextButton.icon(
                        onPressed: _markAllRead,
                        icon: const Icon(KrediIcons.confirm, size: 17),
                        label: const Text('Marcar todas como leídas'),
                      ),
                      TextButton.icon(
                        onPressed: _deleteAll,
                        style: TextButton.styleFrom(foregroundColor: KrediColors.coral),
                        icon: const Icon(KrediIcons.delete, size: 17),
                        label: const Text('Eliminar todas'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                for (final group in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 9),
                    child: Text(
                      group.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: KrediColors.secondary,
                      ),
                    ),
                  ),
                  for (final item in group.value) ...[
                    _DismissibleNotification(
                      item: item,
                      onTap: () => _open(item),
                      onDelete: () => _queueDelete(item),
                    ),
                    const SizedBox(height: 9),
                  ],
                ],
              ],
            ),
          );
        },
      );

  Future<void> _markAllRead() async {
    try {
      await AppScope.of(context)
          .api
          .markAllNotificationsRead()
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
    if (mounted) await reload();
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('¿Eliminar todas las notificaciones?'),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: KrediColors.coral,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(KrediIcons.delete),
                label: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await AppScope.of(context)
          .api
          .deleteAllNotifications()
          .timeout(const Duration(seconds: 12));
      _hiddenIds.clear();
      if (mounted) await reload();
    } catch (_) {
      if (mounted) {
        showKrediMessage(context, 'No pudimos eliminar las notificaciones.');
      }
    }
  }

  Future<void> _queueDelete(Map<String, dynamic> item) async {
    final id = jInt(item, ['id']);
    if (id <= 0 || _hiddenIds.contains(id)) return;
    setState(() => _hiddenIds.add(id));

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notificación eliminada'),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: KrediColors.black,
          onPressed: () {},
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    final reason = await controller.closed;
    if (!mounted) return;
    if (reason == SnackBarClosedReason.action) {
      setState(() => _hiddenIds.remove(id));
      return;
    }

    try {
      await AppScope.of(context)
          .api
          .deleteNotification(id)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!mounted) return;
      setState(() => _hiddenIds.remove(id));
      showKrediMessage(context, 'No pudimos eliminar la notificación.');
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final id = jInt(item, ['id']);
    if (id > 0) {
      try {
        await AppScope.of(context)
            .api
            .markNotificationRead(id)
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

    final rawDetails = item['data'] ?? item['details'];
    final data = rawDetails is Map
        ? Map<String, dynamic>.from(rawDetails)
        : <String, dynamic>{};
    final destination = _destination(jString(data, ['destination']));
    final attachments =
        (item['attachments'] is List ? item['attachments'] as List : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => jString(e, ['path', 'url']).trim().isNotEmpty)
            .toList();

    if (!mounted) return;
    final deleteRequested = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _NotificationDetailScreen(
          item: item,
          attachments: attachments,
          destination: destination,
          onOpenDestination: destination != null && widget.onOpen != null
              ? () {
                  Navigator.of(context).pop(false);
                  widget.onOpen!(destination);
                }
              : null,
        ),
      ),
    );
    if (!mounted) return;
    if (deleteRequested == true) {
      await _queueDelete(item);
    } else {
      await reload();
    }
  }

  AppDestination? _destination(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'purchases' || 'purchase' || 'orders' => AppDestination.purchases,
      'requests' || 'payments' || 'payment' || 'billing' || 'invoice' => AppDestination.requests,
      'credit' || 'creditrequest' || 'credit_request' || 'level' => AppDestination.credit,
      'promotions' || 'promotion' || 'benefits' => AppDestination.promotions,
      'stores' || 'store' || 'business' => AppDestination.stores,
      'notifications' => AppDestination.notifications,
      'profile' || 'account' => AppDestination.profile,
      'security' => AppDestination.security,
      _ => null,
    };
  }
}

class _DismissibleNotification extends StatelessWidget {
  const _DismissibleNotification({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final id = jInt(item, ['id']);
    if (id <= 0) return _NotificationCard(item: item, onTap: onTap);
    return Dismissible(
      key: ValueKey('notification_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: KrediColors.softCoral,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFC7B9)),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(KrediIcons.delete, color: KrediColors.coral),
            SizedBox(width: 7),
            Text(
              'Eliminar',
              style: TextStyle(color: KrediColors.coral, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: _NotificationCard(item: item, onTap: onTap),
    );
  }
}

class _NotificationDetailScreen extends StatelessWidget {
  const _NotificationDetailScreen({
    required this.item,
    required this.attachments,
    required this.destination,
    required this.onOpenDestination,
  });

  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> attachments;
  final AppDestination? destination;
  final VoidCallback? onOpenDestination;

  Future<void> _requestDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar notificación'),
            content: const Text('La notificación desaparecerá de tu bandeja.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: KrediColors.coral,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final type = jString(item, ['type']);
    final visual = _visual(type);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Notificación'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'delete') _requestDelete(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(KrediIcons.delete, color: KrediColors.coral),
                    SizedBox(width: 10),
                    Text('Eliminar notificación'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: KrediColors.softOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD7A0)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(visual.icon, color: KrediColors.orangeDeep, size: 24),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visual.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: KrediColors.orangeDeep,
                          letterSpacing: .55,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        jString(item, ['title'], 'Notificación'),
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _dateTimeLabel(item),
                        style: const TextStyle(fontSize: 11.5, color: KrediColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              jString(item, ['body', 'message'], 'Sin detalles adicionales.'),
              style: const TextStyle(fontSize: 15, height: 1.58, color: KrediColors.inkSoft),
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Archivos', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final attachment in attachments) ...[
                KrediProofButton(
                  url: jString(attachment, ['path', 'url']),
                  label: jString(attachment, ['label'], 'Ver imagen'),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (onOpenDestination != null && destination != null) ...[
              const SizedBox(height: 30),
              KrediActionButton(
                icon: _actionIcon(destination!),
                label: _actionLabel(destination!, type),
                expanded: true,
                onPressed: onOpenDestination!,
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationVisual {
  const _NotificationVisual(this.icon, this.label, this.accent);
  final IconData icon;
  final String label;
  final Color accent;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item.containsKey('read') ? !jBool(item, ['read']) : item['readAt'] == null;
    final visual = _visual(jString(item, ['type']));
    final attachments = item['attachments'] is List ? item['attachments'] as List : const [];
    return KrediOutlineCard(
      color: unread ? const Color(0xFFFFFBF5) : Colors.white,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(visual.icon, color: visual.accent, size: 23)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        jString(item, ['title'], 'Notificación'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, height: 1.2, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(KrediIcons.statusDot, size: 8, color: KrediColors.orange),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  jString(item, ['body', 'message']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.35, color: KrediColors.secondary),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      visual.label,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: visual.accent),
                    ),
                    const SizedBox(width: 8),
                    const Text('·', style: TextStyle(color: KrediColors.secondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dateTimeLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: KrediColors.secondary),
                      ),
                    ),
                    if (attachments.isNotEmpty) ...[
                      const Icon(KrediIcons.attachment, size: 14, color: KrediColors.orangeDeep),
                      const SizedBox(width: 2),
                      Text(
                        '${attachments.length}',
                        style: const TextStyle(fontSize: 10.5, color: KrediColors.orangeDeep, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Icon(KrediIcons.chevron, size: 20, color: KrediColors.orangeDeep),
          ),
        ],
      ),
    );
  }
}

Map<String, List<Map<String, dynamic>>> _groupRows(List<Map<String, dynamic>> rows) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final result = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final date = _dateOf(row);
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? 'Hoy'
        : day == yesterday
            ? 'Ayer'
            : 'Anteriores';
    result.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(row);
  }
  return result;
}

DateTime _dateOf(Map<String, dynamic> item) {
  for (final key in const ['createdAt', 'created_at', 'sentAt', 'date']) {
    final value = item[key];
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _dateTimeLabel(Map<String, dynamic> item) {
  final date = _dateOf(item);
  if (date.millisecondsSinceEpoch == 0) return 'Fecha no disponible';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final time = DateFormat('HH:mm', 'es').format(date);
  if (day == today) return 'Hoy · $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Ayer · $time';
  return '${DateFormat('dd/MM/yyyy', 'es').format(date)} · $time';
}

_NotificationVisual _visual(String type) {
  final value = type.toUpperCase();
  if (value.contains('BILL') || value.contains('INVOICE')) {
    return const _NotificationVisual(KrediIcons.receipt, 'Pagos y cuotas', KrediColors.orangeDeep);
  }
  if (value.contains('PAY')) {
    return const _NotificationVisual(KrediIcons.payments, 'Pago', KrediColors.green);
  }
  if (value.contains('LEVEL') || value.contains('CREDIT') || value.contains('LINE')) {
    return const _NotificationVisual(KrediIcons.credit, 'Líneas y nivel', KrediColors.orangeDeep);
  }
  if (value.contains('PURCHASE') || value.contains('ORDER')) {
    return const _NotificationVisual(KrediIcons.shop, 'Compra', KrediColors.coral);
  }
  if (value.contains('VERIFY')) {
    return const _NotificationVisual(KrediIcons.identityVerification, 'Verificación', KrediColors.orangeDeep);
  }
  if (value.contains('SECURITY') || value.contains('ACCOUNT') || value.contains('EMAIL') || value.contains('PIN')) {
    return const _NotificationVisual(KrediIcons.shield, 'Seguridad', KrediColors.orangeDeep);
  }
  if (value.contains('PROMO') || value.contains('BENEFIT')) {
    return const _NotificationVisual(KrediIcons.promotions, 'Beneficio', KrediColors.coral);
  }
  if (value.contains('STORE') || value.contains('BUSINESS')) {
    return const _NotificationVisual(KrediIcons.storefront, 'Comercio', KrediColors.orangeDeep);
  }
  return const _NotificationVisual(KrediIcons.notifications, 'Kredi+', KrediColors.orangeDeep);
}

String _actionLabel(AppDestination destination, String type) => switch (destination) {
      AppDestination.requests => 'Ver pagos',
      AppDestination.purchases => 'Ver compra',
      AppDestination.credit => type.toUpperCase().contains('LEVEL') ? 'Ver mi nivel' : 'Ver mis líneas',
      AppDestination.promotions => 'Ver beneficio',
      AppDestination.stores => 'Ver comercio',
      AppDestination.security => 'Revisar seguridad',
      AppDestination.profile => 'Ver mi cuenta',
      _ => 'Abrir',
    };

IconData _actionIcon(AppDestination destination) => switch (destination) {
      AppDestination.requests => KrediIcons.payments,
      AppDestination.purchases => KrediIcons.shop,
      AppDestination.credit => KrediIcons.credit,
      AppDestination.promotions => KrediIcons.promotions,
      AppDestination.stores => KrediIcons.storefront,
      AppDestination.security => KrediIcons.shield,
      _ => KrediIcons.forward,
    };
