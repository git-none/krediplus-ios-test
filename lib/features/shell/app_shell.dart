import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../catalog/catalog_screen.dart';
import '../credit/credit_screen.dart';
import '../generic/generic_screens.dart';
import '../help/help_screen.dart';
import '../home/home_screen.dart';
import '../movements/movements_screen.dart';
import '../notifications/notifications_screen.dart';
import '../payments/payments_screen.dart';
import '../profile/profile_screen.dart';
import '../purchases/purchases_screen.dart';
import '../security/security_screen.dart';
import '../stores/stores_screen.dart';
import 'app_destination.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.qrScannerBuilder});
  final WidgetBuilder? qrScannerBuilder;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination destination = AppDestination.home;
  final List<AppDestination> history = [];
  bool catalogLoaded = false;

  // El lector QR permanece accesible en todas las secciones principales.
  static const bottom = [
    AppDestination.home,
    AppDestination.fairs,
    AppDestination.qrScanner,
    AppDestination.requests,
    AppDestination.profile,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (catalogLoaded) return;
    catalogLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).app.refreshCatalog();
    });
  }

  void open(AppDestination next, {bool fromBottom = false}) {
    if (next == AppDestination.qrScanner) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (routeContext) =>
              widget.qrScannerBuilder?.call(routeContext) ?? const QrScannerScreen(),
        ),
      );
      return;
    }
    if (next == destination) return;
    setState(() {
      if (!fromBottom && destination != AppDestination.home) {
        history.add(destination);
      }
      if (fromBottom) {
        history.clear();
      }
      destination = next;
    });
  }

  void back() => setState(
    () => destination = history.isNotEmpty
        ? history.removeLast()
        : AppDestination.home,
  );

  AppDestination selectedTarget() {
    if (bottom.contains(destination)) return destination;
    if ({
      AppDestination.combos,
      AppDestination.stores,
      AppDestination.fairs,
    }.contains(destination)) {
      return AppDestination.fairs;
    }
    if ({
      AppDestination.purchases,
      AppDestination.requests,
      AppDestination.userSummary,
      AppDestination.userWallet,
      AppDestination.security,
      AppDestination.settings,
      AppDestination.help,
      AppDestination.notifications,
      AppDestination.movements,
    }.contains(destination)) {
      return AppDestination.profile;
    }
    return AppDestination.home;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: destination == AppDestination.home,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && destination != AppDestination.home) {
        back();
      }
    },
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar:
          bottom.contains(destination) &&
              destination != AppDestination.qrScanner
          ? null
          : _topBar(),
      body: SafeArea(
        top:
            bottom.contains(destination) &&
            destination != AppDestination.qrScanner,
        bottom: false,
        // Transición uniforme entre módulos: breve, discreta y sin destellos.
        child: AnimatedSwitcher(
          duration: KrediMotion.page,
          reverseDuration: KrediMotion.standard,
          switchInCurve: KrediMotion.enter,
          switchOutCurve: KrediMotion.exit,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(.02, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(key: ValueKey(destination), child: _body()),
        ),
      ),
      bottomNavigationBar: _BeneficiaryBottomBar(
        items: bottom,
        selected: selectedTarget(),
        onSelected: (d) => open(d, fromBottom: true),
      ),
    ),
  );


  PreferredSizeWidget _topBar() => AppBar(
    toolbarHeight: 60,
    leadingWidth: 58,
    leading: destination == AppDestination.home
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12),
            child: KrediIconButton(
              tooltip: 'Volver',
              onPressed: back,
              icon: KrediIcons.back,
              tone: KrediActionTone.text,
              size: 42,
            ),
          ),
    title: Text(
      destination == AppDestination.home ? 'Kredi+' : destination.label,
      softWrap: true,
    ),
  );

  Widget _body() => switch (destination) {
    AppDestination.home => HomeScreen(
      onOpen: open,
      onOpenNotifications: () => open(AppDestination.notifications),
    ),
    AppDestination.stores => const StoresScreen(),
    AppDestination.purchases => const PurchasesScreen(),
    AppDestination.help => HelpScreen(onOpen: open),
    AppDestination.userSummary => const UserSummaryScreen(),
    AppDestination.fairs || AppDestination.combos => CatalogScreen(
      initialCombos: destination == AppDestination.combos,
    ),
    AppDestination.credit => const CreditScreen(),
    AppDestination.movements => const MovementsScreen(),
    AppDestination.userWallet => const CreditScreen(),
    AppDestination.promotions => const PromotionsScreen(),
    AppDestination.requests => const PaymentsScreen(),
    AppDestination.settings => const SettingsScreen(),
    AppDestination.qrScanner =>
      widget.qrScannerBuilder?.call(context) ?? const QrScannerScreen(),
    AppDestination.notifications => NotificationsScreen(onOpen: open),
    AppDestination.security => const SecurityScreen(),
    AppDestination.profile => ProfileScreen(onOpen: open),
  };
}

String _navLabel(AppDestination d) => switch (d) {
  AppDestination.fairs => 'Comprar',
  AppDestination.requests => 'Pagos',
  _ => d.label,
};

class _BeneficiaryBottomBar extends StatelessWidget {
  const _BeneficiaryBottomBar({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<AppDestination> items;
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KrediColors.border)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: item == AppDestination.qrScanner
                  ? Transform.translate(
                      offset: const Offset(0, -17),
                      child: _QrNavAction(
                        selected: selected == item,
                        onTap: () => onSelected(item),
                      ),
                    )
                  : _NavAction(
                      item: item,
                      selected: selected == item,
                      onTap: () => onSelected(item),
                    ),
            ),
        ],
      ),
    ),
  );
}

class _NavAction extends StatelessWidget {
  const _NavAction({required this.item, required this.selected, required this.onTap});
  final AppDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: item == AppDestination.profile ? 'Cuenta' : _navLabel(item),
        child: KrediPressable(
          key: ValueKey('nav_${item.name}'),
          onTap: onTap,
          pressedScale: .94,
          child: AnimatedContainer(
            duration: KrediMotion.standard,
            curve: KrediMotion.enter,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? KrediColors.softCoral.withValues(alpha: .36) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.04 : 1,
                  duration: KrediMotion.standard,
                  curve: KrediMotion.enter,
                  child: Icon(
                    item.icon,
                    size: 24,
                    color: selected ? KrediColors.coral : const Color(0xFF85878B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item == AppDestination.profile ? 'Cuenta' : _navLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    color: selected ? KrediColors.coral : const Color(0xFF777A7F),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _QrNavAction extends StatelessWidget {
  const _QrNavAction({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: 'Escanear QR',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KrediPressable(
              key: const ValueKey('nav_qrScanner'),
              onTap: onTap,
              pressedScale: .94,
              child: Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: KrediColors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  KrediIcons.qr,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'QR',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: KrediColors.orangeDeep,
              ),
            ),
          ],
        ),
      );
}

