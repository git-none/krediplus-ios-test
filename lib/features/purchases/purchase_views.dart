import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../core/utils/presentation.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../payments/payments_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  Future<List<Map<String, dynamic>>>? future;
  PurchaseGroup group = PurchaseGroup.active;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final api = AppScope.of(context).api;
    final results = await Future.wait([api.purchases(), api.qrPurchases()]);
    return [
      ...results[0],
      for (final row in results[1]) {...row, 'type': 'QR'},
    ];
  }

  Future<void> reload() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return KrediEmptyState(
          icon: KrediIcons.offline,
          title: 'No pudimos cargar tus compras',
          message: snapshot.error.toString(),
          actionLabel: 'Reintentar',
          onAction: reload,
        );
      }
      final all = snapshot.data ?? const [];
      final rows = all.where((row) => purchaseGroup(row) == group).toList();
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const KrediScreenTitle(
              'Mis compras',
              subtitle: 'Detalles, facturas y seguimiento de cada compra.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  PurchaseGroup.active: 'En curso',
                  PurchaseGroup.completed: 'Finalizadas',
                  PurchaseGroup.closed: 'Cerradas',
                }.entries)
                  ChoiceChip(
                    label: Text(
                      '${entry.value} (${all.where((row) => purchaseGroup(row) == entry.key).length})',
                    ),
                    selected: group == entry.key,
                    onSelected: (_) => setState(() => group = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const KrediEmptyState(
                icon: KrediIcons.cart,
                title: 'No hay compras en esta sección',
                message: 'Aquí encontrarás todas las compras según su estado.',
              ),
            for (final row in rows) ...[
              KrediOutlineCard(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => jString(row, ['type']) == 'QR'
                          ? QrPurchaseDetailScreen(
                              id: jInt(row, ['id']),
                              commerceFlow: row['commerceFlow'] != false,
                            )
                          : PurchaseDetailScreen(id: jInt(row, ['id'])),
                    ),
                  );
                  if (mounted) await reload();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(KrediIcons.shop, color: KrediColors.coral),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            jString(row, [
                              'offerName',
                              'businessName',
                              'invoiceNumber',
                            ], 'Compra #${jInt(row, ['id'])}'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(KrediIcons.chevron),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      dateLabel(row['createdAtMillis'] ?? row['createdAt']),
                      style: const TextStyle(color: KrediColors.secondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('Estado: ${statusLabel(jString(row, ['status']))}'),
                        Text(
                          purchaseAmount(row),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ver detalle',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: KrediColors.coral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );
}

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({super.key, required this.id});
  final int id;
  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  Future<Map<String, dynamic>>? future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).api.purchaseDetail(widget.id);
  }

  void reload() => setState(
    () => future = AppScope.of(context).api.purchaseDetail(widget.id),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Factura de compra')),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return KrediEmptyState(
              icon: KrediIcons.offline,
              title: 'No se pudo cargar la factura',
              message: snapshot.error.toString(),
              actionLabel: 'Reintentar',
              onAction: reload,
            );
          }
          return InvoiceBody(invoice: snapshot.data ?? const {});
        },
      ),
    ),
  );
}

/// Renderiza el DTO InvoiceDto real: líneas y totales en bolívares.
class InvoiceBody extends StatelessWidget {
  const InvoiceBody({super.key, required this.invoice});
  final Map<String, dynamic> invoice;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    final lines = jList(invoice, [
      'lines',
    ]).whereType<Map>().map((item) => Map<String, dynamic>.from(item));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Kredi+',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SelectableText(
          jString(invoice, ['invoiceNumber']),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(
          dateLabel(invoice['createdAtMillis']),
          style: const TextStyle(color: KrediColors.secondary),
        ),
        const SizedBox(height: 18),
        KrediOutlineCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DataRow('Cliente', jString(invoice, ['customerName'])),
              _DataRow('Correo', jString(invoice, ['customerEmail'])),
              if (jString(invoice, ['fairName']).isNotEmpty)
                _DataRow('Jornada', jString(invoice, ['fairName'])),
              if (jString(invoice, ['fairPlace']).isNotEmpty)
                _DataRow('Lugar', jString(invoice, ['fairPlace'])),
              _DataRow(
                'Método de pago',
                statusLabel(jString(invoice, ['paymentMethod'])),
              ),
              if (jString(invoice, ['paymentReference']).isNotEmpty)
                _DataRow('Referencia', jString(invoice, ['paymentReference'])),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const KrediSectionRow(title: 'Productos facturados'),
        const SizedBox(height: 12),
        for (final line in lines) ...[
          _InvoiceProductCard(line: line, app: app),
          const SizedBox(height: 10),
        ],
        KrediOutlineCard(
          child: Column(
            children: [
              _DataRow(
                'Subtotal',
                moneyBs(jDouble(invoice, ['subtotal', 'total'])),
              ),
              if (jDouble(invoice, ['discountAmount']) > 0)
                _DataRow(
                  'Descuento',
                  moneyBs(jDouble(invoice, ['discountAmount'])),
                ),
              if (jString(invoice, ['promotionName']).isNotEmpty)
                _DataRow('Promoción', jString(invoice, ['promotionName'])),
              const Divider(height: 20),
              _DataRow(
                'Total de la factura',
                moneyBs(jDouble(invoice, ['total'])),
                prominent: true,
              ),
            ],
          ),
        ),
        if (jString(invoice, ['paymentInstructions']).isNotEmpty) ...[
          const SizedBox(height: 16),
          KrediOutlineCard(
            child: SelectableText(jString(invoice, ['paymentInstructions'])),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: invoiceAsText(invoice)),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Factura copiada con productos e importes.'),
                ),
              );
            }
          },
          icon: const Icon(KrediIcons.copyAll),
          label: const Text('Copiar factura'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Mis pagos')),
                body: const SafeArea(child: PaymentsScreen()),
              ),
            ),
          ),
          icon: const Icon(KrediIcons.payments),
          label: const Text('Consultar mis pagos'),
        ),
      ],
    );
  }
}

class QrPurchaseDetailScreen extends StatefulWidget {
  const QrPurchaseDetailScreen({
    super.key,
    required this.id,
    this.commerceFlow = true,
  });
  final int id;
  final bool commerceFlow;
  @override
  State<QrPurchaseDetailScreen> createState() => _QrPurchaseDetailScreenState();
}

class _QrPurchaseDetailScreenState extends State<QrPurchaseDetailScreen> {
  Future<Map<String, dynamic>>? future;
  bool busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Map<String, dynamic>> load() => AppScope.of(
    context,
  ).api.qrPurchaseSession(widget.id, commerceFlow: widget.commerceFlow);
  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: const Text(
          'Revisa el total, la inicial y las cuotas. Al confirmar aceptas este plan de compra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar compra'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await AppScope.of(
        context,
      ).api.confirmQrPurchase(widget.id, commerceFlow: widget.commerceFlow);
      if (mounted) await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Compra QR'),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          tooltip: 'Actualizar compra',
          icon: const Icon(KrediIcons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return KrediEmptyState(
              icon: KrediIcons.offline,
              title: 'No se pudo cargar la compra',
              message: snapshot.error.toString(),
              actionLabel: 'Reintentar',
              onAction: refresh,
            );
          }
          final row = snapshot.data ?? const {};
          final app = AppScope.of(context).app;
          final status = jString(row, ['status']).toUpperCase();
          final items = jList(row, [
            'items',
          ]).whereType<Map>().map((item) => Map<String, dynamic>.from(item));
          final expires = DateTime.tryParse(jString(row, ['expiresAt']));
          final canConfirm =
              const {
                'AWAITING_CONFIRMATION',
                'AWAITING_CUSTOMER',
              }.contains(status) &&
              (expires == null || expires.isAfter(DateTime.now()));
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                KrediScreenTitle(
                  jString(row, ['offerName'], 'Compra presencial'),
                  subtitle: jString(row, ['businessName']),
                ),
                const SizedBox(height: 16),
                KrediOutlineCard(
                  child: Column(
                    children: [
                      _DataRow('Estado', statusLabel(status)),
                      _DataRow(
                        'Total',
                        row['totalUsd'] == null
                            ? 'Pendiente de cotización'
                            : moneyUsd(jDouble(row, ['totalUsd'])),
                        prominent: true,
                      ),
                      if (row['initialUsd'] != null)
                        _DataRow(
                          'Inicial',
                          moneyUsd(0),
                        ),
                      if (row['financedUsd'] != null)
                        _DataRow(
                          'Monto financiado',
                          moneyUsd(jDouble(row, ['financedUsd'])),
                        ),
                      if (jInt(row, ['installmentCount']).clamp(0, KrediCreditPolicy.maximumInstallments) > 0)
                        _DataRow(
                          'Plan de cuotas',
                          '${jInt(row, ['installmentCount']).clamp(1, KrediCreditPolicy.maximumInstallments)} × ${moneyUsd(jDouble(row, ['installmentUsd']))}',
                        ),
                      if (jString(row, ['invoiceReference']).isNotEmpty)
                        _DataRow(
                          'Factura del comercio',
                          jString(row, ['invoiceReference']),
                        ),
                    ],
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const KrediSectionRow(title: 'Productos'),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _QrProductCard(item: item, app: app),
                    ),
                ],
                const SizedBox(height: 16),
                KrediOutlineCard(
                  color: status == 'COMPLETED'
                      ? KrediColors.softGreen
                      : KrediColors.softOrange,
                  child: Text(jString(row, ['message'], statusLabel(status))),
                ),
                if (canConfirm) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy ? null : confirm,
                    icon: const Icon(KrediIcons.confirm),
                    label: Text(busy ? 'Confirmando…' : 'Confirmar este plan'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}


Map<String, dynamic>? _catalogProduct(dynamic app, Map<String, dynamic> item) {
  final id = jInt(item, ['productId', 'id']);
  if (id > 0) {
    final byId = app.productById(id);
    if (byId != null) return byId;
  }
  final name = jString(item, ['name', 'productName']).trim().toLowerCase();
  if (name.isEmpty) return null;
  for (final product in app.products as List<Map<String, dynamic>>) {
    if (jString(product, ['name']).trim().toLowerCase() == name) return product;
  }
  return null;
}

String _productImageUrl(dynamic app, Map<String, dynamic> item) {
  final direct = jString(item, [
    'imageUrl',
    'imagePath',
    'productImageUrl',
    'productImagePath',
    'image',
  ]);
  if (direct.isNotEmpty) return AppConfig.publicUrl(direct);
  final product = _catalogProduct(app, item);
  if (product == null) return '';
  return AppConfig.publicUrl(
    jString(product, ['imageUrl', 'imagePath', 'image']),
  );
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 72,
          height: 72,
          child: url.isEmpty
              ? const ColoredBox(
                  color: Color(0xFFF7F7F8),
                  child: Center(
                    child: Icon(
                      KrediIcons.image,
                      color: KrediColors.secondary,
                      size: 26,
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const ColoredBox(
                    color: Color(0xFFF7F7F8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF7F7F8),
                    child: Center(
                      child: Icon(
                        KrediIcons.image,
                        color: KrediColors.secondary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
        ),
      );
}

class _QrProductCard extends StatelessWidget {
  const _QrProductCard({required this.item, required this.app});
  final Map<String, dynamic> item;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final product = _catalogProduct(app, item);
    final quantity = jInt(item, ['quantity'], 1);
    var unitPrice = jDouble(item, ['unitPriceUsd', 'priceUsd']);
    if (unitPrice <= 0 && product != null) {
      unitPrice = app.productPriceUsd(product) as double;
    }
    final name = jString(
      item,
      ['name', 'productName'],
      product == null ? 'Producto' : jString(product, ['name'], 'Producto'),
    );
    final image = _productImageUrl(app, item);
    return KrediOutlineCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProductThumb(url: image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Cantidad: $quantity',
                  style: const TextStyle(
                    color: KrediColors.secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unitPrice > 0
                      ? '${moneyUsd(unitPrice)} c/u'
                      : 'Precio no disponible',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (unitPrice > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Subtotal: ${moneyUsd(unitPrice * quantity)}',
                    style: const TextStyle(
                      color: KrediColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceProductCard extends StatelessWidget {
  const _InvoiceProductCard({required this.line, required this.app});
  final Map<String, dynamic> line;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final quantity = jInt(line, ['quantity'], 1);
    final unitPrice = jDouble(line, ['unitPrice']);
    final image = _productImageUrl(app, line);
    return KrediOutlineCard(
      child: Row(
        children: [
          _ProductThumb(url: image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jString(line, ['productName', 'name'], 'Producto'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$quantity ${jString(line, ['unit'])}',
                  style: const TextStyle(
                    color: KrediColors.secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${moneyBs(unitPrice)} c/u',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'Subtotal: ${moneyBs(quantity * unitPrice)}',
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
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow(this.label, this.value, {this.prominent = false});
  final String label, value;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(color: KrediColors.secondary)),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: prominent ? 21 : 15,
          ),
        ),
      ],
    ),
  );
}
