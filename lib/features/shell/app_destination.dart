import 'package:flutter/material.dart';
import '../../core/icons/kredi_icons.dart';

enum AppDestination {
  home('Inicio', KrediIcons.home),
  stores('Tiendas', KrediIcons.storefront),
  purchases('Mis compras', KrediIcons.cart),
  help('Centro de ayuda', KrediIcons.help),
  userSummary('Mi nivel', KrediIcons.dashboard),
  fairs('Comprar', KrediIcons.shop),
  credit('Líneas y cuotas', KrediIcons.credit),
  movements('Actividad', KrediIcons.movements),
  userWallet('Líneas y cuotas', KrediIcons.credit),
  promotions('Beneficios y promociones', KrediIcons.promotions),
  combos('Combos', KrediIcons.combos),
  requests('Pagos', KrediIcons.payments),
  settings('Configuración', KrediIcons.settings),
  qrScanner('Escanear QR', KrediIcons.qr),
  notifications('Notificaciones', KrediIcons.notifications),
  security('Seguridad', KrediIcons.shield),
  profile('Mi cuenta', KrediIcons.profile);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}
