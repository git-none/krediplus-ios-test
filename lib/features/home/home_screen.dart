import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../shared/widgets/kredi_brand.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../shell/app_destination.dart';
import '../stores/stores_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpen,
    required this.onOpenNotifications,
  });

  final ValueChanged<AppDestination> onOpen;
  final VoidCallback onOpenNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> future;
  bool loaded = false;
  int _bannerPage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      future = AppScope.of(context).api.mobileHome();
    }
  }

  Future<void> reload() async {
    setState(() => future = AppScope.of(context).api.mobileHome());
    try {
      await future;
    } catch (_) {
      // La pantalla conserva sus accesos aunque falle un resumen remoto.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          final data = snap.data ?? const <String, dynamic>{};
          final loading = snap.connectionState != ConnectionState.done;
          final ready = !loading && !snap.hasError;
          final level = data['level'] is Map
              ? Map<String, dynamic>.from(data['level'] as Map)
              : <String, dynamic>{};
          final lines = jList(data, ['lines'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final sendero = lines.firstWhere(
            (row) => jString(row, ['code']).toUpperCase() == 'SENDERO',
            orElse: () => <String, dynamic>{},
          );
          final altura = lines.firstWhere(
            (row) => jString(row, ['code']).toUpperCase() == 'ALTURA',
            orElse: () => <String, dynamic>{},
          );
          final senderoActive =
              jString(sendero, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE';
          final alturaActive =
              jBool(altura, ['eligible']) &&
              jString(altura, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE';
          final stores = jList(data, ['stores']).whereType<Map>().take(8).toList();
          final banners = jList(data, ['banners'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => jBool(e, ['active'], true))
              .take(6)
              .toList();
          final next = data['nextPayment'];
          final levelNumber = jInt(level, ['number'], 1).clamp(1, 6).toInt();
          final levelName = KrediCreditPolicy.ruleFor(levelNumber).name;

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TopPill(
                            onTap: () => widget.onOpen(AppDestination.userSummary),
                            leading: const KrediBrand(height: 27, compact: true),
                            label: ready ? 'Nivel $levelNumber' : 'Mi nivel',
                          ),
                          const Spacer(),
                          _CircleAction(
                            tooltip: 'Notificaciones',
                            icon: KrediIcons.notifications,
                            showBadge: ready && jInt(data, ['unreadNotifications']) > 0,
                            onTap: widget.onOpenNotifications,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tus líneas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    height: 1.05,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Nivel $levelNumber · $levelName',
                                  style: const TextStyle(
                                    color: KrediColors.secondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (loading)
                        const LinearProgressIndicator(minHeight: 5)
                      else if (snap.hasError)
                        _LoadError(onRetry: reload)
                      else if (!senderoActive && !alturaActive)
                        const _NoActiveLines()
                      else
                        Column(
                          children: [
                            if (senderoActive)
                              _LineCard(
                                icon: KrediIcons.sendero,
                                label: KrediCreditPolicy.senderoName,
                                availableUsd: jDouble(sendero, ['availableUsd']),
                                limitUsd: jDouble(sendero, ['limitUsd']),
                                installments: KrediCreditPolicy.ruleFor(levelNumber).maxInstallments,
                                onTap: () => widget.onOpen(AppDestination.credit),
                              ),
                            if (senderoActive && alturaActive) const SizedBox(height: 10),
                            if (alturaActive)
                              _LineCard(
                                icon: KrediIcons.altura,
                                label: KrediCreditPolicy.alturaName,
                                availableUsd: jDouble(altura, ['availableUsd']),
                                limitUsd: jDouble(altura, ['limitUsd']),
                                installments: KrediCreditPolicy.ruleFor(levelNumber).maxInstallments,
                                onTap: () => widget.onOpen(AppDestination.credit),
                              ),
                          ],
                        ),
                      if (ready && next is Map) ...[
                        const SizedBox(height: 14),
                        _NextPaymentCompact(
                          row: Map<String, dynamic>.from(next),
                          onTap: () => widget.onOpen(AppDestination.requests),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: KrediIcons.receipt,
                              label: 'Comprar',
                              onTap: () => widget.onOpen(AppDestination.fairs),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              icon: KrediIcons.promotions,
                              label: 'Pagar',
                              onTap: () => widget.onOpen(AppDestination.requests),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InstallmentsShortcut(
                        onTap: () => widget.onOpen(AppDestination.credit),
                      ),
                      if (banners.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _HomeBannerCarousel(
                          banners: banners,
                          page: _bannerPage,
                          onPageChanged: (value) => setState(() => _bannerPage = value),
                          onTap: () => widget.onOpen(AppDestination.promotions),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tiendas disponibles',
                              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.onOpen(AppDestination.stores),
                            child: const Text('Ver todas'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (stores.isEmpty)
                        _StoresEmpty(onTap: () => widget.onOpen(AppDestination.stores))
                      else
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: stores.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final store = Map<String, dynamic>.from(stores[index]);
                              return _StoreTile(
                                data: store,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StoreDetailScreen(store: store),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

String _usd(dynamic raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || !value.isFinite) return 'US\$ 0,00';
  return 'US\$ ${NumberFormat('#,##0.00', 'es_VE').format(value)}';
}

String _usdCompact(dynamic raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || !value.isFinite) return 'US\$0';
  return 'US\$${NumberFormat('#,##0', 'es_VE').format(value)}';
}


class _HomeBannerCarousel extends StatefulWidget {
  const _HomeBannerCarousel({
    required this.banners,
    required this.page,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<Map<String, dynamic>> banners;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.banners.isEmpty
        ? 0
        : widget.page.clamp(0, widget.banners.length - 1);
    _controller = PageController(
      initialPage: initial,
      viewportFraction: .94,
    );
  }

  @override
  void didUpdateWidget(covariant _HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.banners.isEmpty) return;
    if (widget.page >= widget.banners.length && _controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(widget.banners.length - 1);
          widget.onPageChanged(widget.banners.length - 1);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePage = widget.banners.isEmpty
        ? 0
        : widget.page.clamp(0, widget.banners.length - 1);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.86,
          child: PageView.builder(
            itemCount: widget.banners.length,
            controller: _controller,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: index == widget.banners.length - 1 ? 0 : 10,
              ),
              child: _HomeBannerCard(
                banner: widget.banners[index],
                onTap: widget.onTap,
              ),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == safePage ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == safePage
                        ? KrediColors.orangeDeep
                        : KrediColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HomeBannerCard extends StatelessWidget {
  const _HomeBannerCard({required this.banner, required this.onTap});
  final Map<String, dynamic> banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.publicUrl(
      jString(banner, ['imagePath', 'imageUrl', 'image']),
    );
    return KrediPressable(
      onTap: onTap,
      pressedScale: .992,
      child: Material(
        color: const Color(0xFFFFF3E1),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: KrediColors.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: image.isEmpty
              ? const Center(
                  child: Icon(
                    KrediIcons.promotions,
                    color: KrediColors.orangeDeep,
                    size: 34,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: image,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: Color(0xFFFFF3E1),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: Color(0xFFFFF3E1),
                    child: Center(
                      child: Icon(
                        KrediIcons.promotions,
                        color: KrediColors.orangeDeep,
                        size: 34,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.label, required this.onTap, this.icon, this.leading});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => KrediPressable(
        onTap: onTap,
        pressedScale: .96,
        child: Material(
          color: Colors.white.withValues(alpha: .72),
          shape: StadiumBorder(side: BorderSide(color: KrediColors.orange.withValues(alpha: .38))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) leading! else Icon(icon, size: 19),
                const SizedBox(width: 7),
                Text(label, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.tooltip, required this.icon, required this.onTap, this.showBadge = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: showBadge,
        child: Tooltip(
          message: tooltip,
          child: KrediPressable(
            onTap: onTap,
            pressedScale: .93,
            child: Material(
              color: Colors.white.withValues(alpha: .72),
              shape: CircleBorder(side: BorderSide(color: KrediColors.orange.withValues(alpha: .38))),
              child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: KrediColors.orangeDeep)),
            ),
          ),
        ),
      );
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.icon,
    required this.label,
    required this.availableUsd,
    required this.limitUsd,
    required this.installments,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final double availableUsd;
  final double limitUsd;
  final int installments;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final availableProgress = limitUsd <= 0
        ? 0.0
        : (availableUsd / limitUsd).clamp(0.0, 1.0).toDouble();
    return KrediPressable(
      onTap: onTap,
      pressedScale: .988,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE9E1D8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0B0B0C),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -42,
              top: -42,
              child: _LineGlow(size: 150),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LineIdentityIcon(icon: icon, locked: locked),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.15,
                            color: KrediColors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: locked ? const Color(0xFFF2F2F3) : KrediColors.softGreen,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          locked ? 'Bloqueada' : 'Activa',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: locked ? KrediColors.secondary : KrediColors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        locked ? KrediIcons.lock : KrediIcons.chevron,
                        size: 19,
                        color: KrediColors.orangeDeep,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locked ? 'Por alcanzar' : _usd(availableUsd),
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.55,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked ? 'Completa el nivel anterior para desbloquearla' : 'Disponible para comprar',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: KrediColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: locked ? 0 : availableProgress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFF2E7D7),
                      color: KrediColors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LineMeta(
                          label: 'Límite',
                          value: _usdCompact(limitUsd),
                        ),
                      ),
                      Container(width: 1, height: 28, color: KrediColors.border),
                      Expanded(
                        child: _LineMeta(
                          label: 'Cuotas',
                          value: '$installments',
                        ),
                      ),
                      Container(width: 1, height: 28, color: KrediColors.border),
                      const Expanded(
                        child: _LineMeta(
                          label: 'Inicial',
                          value: '0%',
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
    );
  }
}

class _LineIdentityIcon extends StatelessWidget {
  const _LineIdentityIcon({required this.icon, required this.locked});
  final IconData icon;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF3F3F4) : KrediColors.softOrange,
          shape: BoxShape.circle,
          border: Border.all(
            color: locked ? KrediColors.border : const Color(0xFFFFD092),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: locked ? KrediColors.secondary : KrediColors.orangeDeep,
        ),
      );
}

class _LineMeta extends StatelessWidget {
  const _LineMeta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: KrediColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      );
}

class _LineGlow extends StatelessWidget {
  const _LineGlow({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0x35FD9C24), Color(0x00FD9C24)],
          ),
        ),
      );
}

class _NoActiveLines extends StatelessWidget {
  const _NoActiveLines();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KrediColors.border),
        ),
        child: const Row(
          children: [
            Icon(KrediIcons.credit, color: KrediColors.secondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No tienes líneas activas en este momento.',
                style: TextStyle(color: KrediColors.secondary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KrediPressable(
        onTap: onTap,
        pressedScale: .97,
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: KrediColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: KrediColors.softOrange,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: KrediColors.orangeDeep),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _InstallmentsShortcut extends StatelessWidget {
  const _InstallmentsShortcut({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KrediPressable(
        onTap: onTap,
        pressedScale: .985,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFDFC0)),
          ),
          child: const Row(
            children: [
              Icon(KrediIcons.credit, color: KrediColors.orangeDeep, size: 21),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis cuotas', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Consulta fechas, montos y estado', style: TextStyle(fontSize: 10.5, color: KrediColors.secondary)),
                  ],
                ),
              ),
              Icon(KrediIcons.chevron, size: 20),
            ],
          ),
        ),
      );
}

class _NextPaymentCompact extends StatelessWidget {
  const _NextPaymentCompact({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(jString(row, ['dueDate']));
    final due = date == null ? 'Próxima cuota' : 'Vence ${DateFormat('dd/MM', 'es').format(date)}';
    final number = jInt(row, ['installmentNumber']);
    return KrediPressable(
      onTap: onTap,
      pressedScale: .99,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: KrediColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(KrediIcons.calendar, color: KrediColors.coral),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(number > 0 ? 'Cuota $number' : 'Próximo pago', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(due, style: const TextStyle(color: KrediColors.secondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_usd(row['amountUsd']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  const Text('Pagar', style: TextStyle(color: KrediColors.orangeDeep, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.data, required this.onTap});
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = jString(data, ['commercialName', 'legalName', 'name'], 'Tienda');
    final image = AppConfig.publicUrl(
      jString(data, ['logoUrl', 'logoPath', 'imageUrl', 'imagePath', 'image']),
    );
    return KrediPressable(
      onTap: onTap,
      pressedScale: .97,
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KrediColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: image.isEmpty
                  ? const ColoredBox(
                      color: KrediColors.softOrange,
                      child: Center(child: Icon(KrediIcons.storefront, color: KrediColors.orangeDeep, size: 30)),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const ColoredBox(color: Color(0xFFF7F7F8)),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: KrediColors.softOrange,
                        child: Center(child: Icon(KrediIcons.storefront, color: KrediColors.orangeDeep, size: 30)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoresEmpty extends StatelessWidget {
  const _StoresEmpty({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KrediPressable(
        onTap: onTap,
        pressedScale: .99,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KrediColors.border),
            ),
            child: const Row(
              children: [
                Icon(KrediIcons.storefront, color: KrediColors.orangeDeep),
                SizedBox(width: 12),
                Expanded(child: Text('Explora las tiendas Kredi+', style: TextStyle(fontWeight: FontWeight.w600))),
                Icon(KrediIcons.chevron),
              ],
            ),
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => KrediPressable(
        onTap: onRetry,
        pressedScale: .99,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KrediColors.border),
            ),
            child: const Row(
              children: [
                Icon(KrediIcons.refresh),
                SizedBox(width: 10),
                Expanded(child: Text('Toca para actualizar tus líneas.', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      );
}
