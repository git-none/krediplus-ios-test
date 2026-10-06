import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../shared/widgets/kredi_fintech.dart';
import 'checkout_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.initialCombos = false});
  final bool initialCombos;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  String category = 'Todo';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.of(context).app;
      if (widget.initialCombos) app.setCatalogTab(0);
      if (app.products.isEmpty && !app.busy) app.refreshCatalog();
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final categories = <String>{'Todo'};
        for (final product in app.products) {
          final value = jString(product, ['category']).trim();
          if (value.isNotEmpty) categories.add(value);
        }
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => app.refreshCatalog(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    const Text(
                      'Comprar',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    KrediSearchField(
                      controller: search,
                      hint: '¿Qué quieres comprar hoy?',
                      onChanged: (_) => setState(() {}),
                    ),
                    if (app.selectedFair != null) ...[
                      const SizedBox(height: 10),
                      _SelectedFairChip(
                        fair: app.selectedFair!,
                        onClear: app.clearFair,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _CatalogTabs(
                      selected: app.catalogTab,
                      onSelected: app.setCatalogTab,
                    ),
                    const SizedBox(height: 18),
                    if (app.error != null)
                      KrediOutlineCard(
                        color: KrediColors.softError,
                        child: Text(
                          app.error!,
                          style: const TextStyle(
                            color: KrediColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    if (app.catalogTab == 1) ...[
                      Row(
                        children: [
                          const Icon(
                            KrediIcons.inventory,
                            size: 18,
                            color: KrediColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Categoría',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: KrediColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: categories.contains(category)
                                    ? category
                                    : 'Todo',
                                isExpanded: true,
                                borderRadius: BorderRadius.circular(16),
                                items: [
                                  for (final item in categories)
                                    DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => category = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Productos',
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${_filteredProducts(app).length} disponibles',
                            style: const TextStyle(
                              color: KrediColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Products(app: app, products: _filteredProducts(app)),
                    ] else if (app.catalogTab == 0) ...[
                      const KrediSectionRow(title: 'Combos Kredi+'),
                      const SizedBox(height: 12),
                      _Combos(app: app, query: search.text),
                    ] else ...[
                      const KrediSectionRow(title: 'Jornadas'),
                      const SizedBox(height: 12),
                      _Fairs(app: app, query: search.text),
                    ],
                  ],
                ),
              ),
            ),
            if (app.cartCount > 0)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      ),
                      icon: const Icon(KrediIcons.checkout),
                      label: Text(
                        'Ver compra · ${app.cartCount} ${app.cartCount == 1 ? 'artículo' : 'artículos'}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filteredProducts(dynamic app) {
    final needle = search.text.trim().toLowerCase();
    return (app.products as List<Map<String, dynamic>>).where((product) {
      final name = jString(product, ['name']).toLowerCase();
      final itemCategory = jString(product, ['category']);
      final matchesText =
          needle.isEmpty ||
          name.contains(needle) ||
          itemCategory.toLowerCase().contains(needle);
      final matchesCategory = category == 'Todo' || itemCategory == category;
      return matchesText && matchesCategory;
    }).toList();
  }
}

class _CatalogTabs extends StatelessWidget {
  const _CatalogTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Combos', 'Productos', 'Jornadas'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: KrediPressable(
              onTap: () => onSelected(i),
              pressedScale: .97,
              child: AnimatedContainer(
                duration: KrediMotion.standard,
                curve: KrediMotion.enter,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected == i ? KrediColors.softOrange : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected == i
                        ? KrediColors.orange
                        : KrediColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected == i ? KrediColors.orangeDeep : KrediColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SelectedFairChip extends StatelessWidget {
  const _SelectedFairChip({required this.fair, required this.onClear});
  final Map<String, dynamic> fair;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final place = jString(fair, ['place']);
    return Material(
      color: KrediColors.softOrange,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: KrediColors.border),
        ),
        child: Row(
          children: [
            const Icon(KrediIcons.eventAvailable, size: 18, color: KrediColors.coral),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                place.isEmpty
                    ? jString(fair, ['name'], 'Jornada activa')
                    : '${jString(fair, ['name'], 'Jornada activa')} · $place',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Salir de la jornada',
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _Products extends StatelessWidget {
  const _Products({required this.app, required this.products});
  final dynamic app;
  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const KrediEmptyState(
        icon: KrediIcons.shop,
        title: 'Sin productos',
        message: 'No encontramos productos con esos filtros.',
      );
    }
    return Column(
      children: [
        for (final product in products) ...[
          _ProductCard(product: product, app: app),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.app});
  final Map<String, dynamic> product;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final id = jInt(product, ['id']);
    final price = app.productPriceUsd(product) as double;
    final promo = app.activePromotion('PRODUCT', id) as Map<String, dynamic>?;
    final finalPrice = app.discountedUsd(price, promo) as double;
    final image = AppConfig.publicUrl(jString(product, ['imageUrl']));
    final business = app.productBusiness;
    return KrediOutlineCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 92,
              height: 92,
              child: image.isEmpty
                  ? Container(
                      color: KrediColors.softCream,
                      child: const Icon(
                        KrediIcons.inventory,
                        color: KrediColors.coral,
                        size: 36,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFF7F7F8),
                        alignment: Alignment.center,
                        child: const Icon(
                          KrediIcons.image,
                          color: KrediColors.secondary,
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jString(product, ['name']),
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  jString(product, ['category']),
                  style: const TextStyle(
                    color: KrediColors.secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                if (promo != null)
                  Text(
                    _usd(price),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: KrediColors.secondary,
                      fontSize: 11.5,
                    ),
                  ),
                Text(
                  _usd(finalPrice),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Existencia: ${jInt(product, ['stock'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KrediColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed:
                            business == null ||
                                jInt(product, ['stock']) <=
                                    (app.productCart[id] ?? 0)
                            ? null
                            : () => app.addProduct(id),
                        icon: const Icon(KrediIcons.add, size: 17),
                        label: Text(
                          jInt(product, ['stock']) <= 0 ? 'Agotado' : 'Agregar',
                        ),
                      ),
                    ),
                    if (business == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Cobro por configurar',
                          style: TextStyle(
                            fontSize: 11,
                            color: KrediColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Combos extends StatelessWidget {
  const _Combos({required this.app, required this.query});
  final dynamic app;
  final String query;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final list = (app.combos as List<Map<String, dynamic>>)
        .where((e) => jBool(e, ['active'], true))
        .where(
          (e) =>
              needle.isEmpty ||
              jString(e, [
                'name',
                'description',
              ]).toLowerCase().contains(needle),
        )
        .toList();
    if (list.isEmpty) {
      return const KrediEmptyState(
        icon: KrediIcons.combos,
        title: 'Sin combos',
        message: 'Aún no hay combos disponibles.',
      );
    }
    return Column(
      children: [
        for (final combo in list) ...[
          _ComboCard(combo: combo, app: app),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.combo, required this.app});
  final Map<String, dynamic> combo;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.publicUrl(jString(combo, ['coverUrl']));
    return KrediPressable(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ComboDetailScreen(combo: combo, app: app),
        ),
      ),
      pressedScale: .99,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: KrediColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C0B0B0C),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: image.isEmpty
              ? const ColoredBox(
                  color: KrediColors.softCream,
                  child: Center(
                    child: Icon(
                      KrediIcons.combos,
                      size: 44,
                      color: KrediColors.orangeDeep,
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: KrediColors.softCream,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: KrediColors.softCream,
                    child: Center(
                      child: Icon(
                        KrediIcons.brokenImage,
                        size: 38,
                        color: KrediColors.secondary,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ComboDetailScreen extends StatefulWidget {
  const _ComboDetailScreen({required this.combo, required this.app});
  final Map<String, dynamic> combo;
  final dynamic app;

  @override
  State<_ComboDetailScreen> createState() => _ComboDetailScreenState();
}

class _ComboDetailScreenState extends State<_ComboDetailScreen> {
  Future<Map<String, dynamic>>? _creditFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _creditFuture ??= AppScope.of(context)
        .api
        .credit()
        .timeout(const Duration(seconds: 15));
  }

  @override
  Widget build(BuildContext context) {
    final combo = widget.combo;
    final app = widget.app;
    final id = jInt(combo, ['id']);
    final basePrice = app.comboPriceUsd(combo) as double;
    final promo = app.activePromotion('COMBO', id) as Map<String, dynamic>?;
    final finalPrice = app.discountedUsd(basePrice, promo) as double;
    final image = AppConfig.publicUrl(jString(combo, ['coverUrl']));
    final lines = jList(combo, ['lines'])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final business = app.comboBusiness;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF8),
        title: const Text('Detalle del combo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: image.isEmpty
                  ? const ColoredBox(
                      color: KrediColors.softCream,
                      child: Center(
                        child: Icon(
                          KrediIcons.combos,
                          size: 52,
                          color: KrediColors.orangeDeep,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: KrediColors.softCream,
                        child: Center(child: Icon(KrediIcons.brokenImage)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            jString(combo, ['name'], 'Combo Kredi+'),
            style: const TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          if (jString(combo, ['description']).trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              jString(combo, ['description']),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: KrediColors.secondary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            '¿Qué incluye?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
          if (lines.isEmpty)
            const KrediEmptyState(
              icon: KrediIcons.inventory,
              title: 'Detalle pendiente',
              message: 'Este combo todavía no tiene productos detallados en el catálogo.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: KrediColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    _ComboProductRow(line: lines[i], app: app),
                    if (i != lines.length - 1)
                      const Divider(height: 1, indent: 78),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: KrediColors.softOrange,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFD39A)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total del combo',
                    style: TextStyle(
                      color: KrediColors.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _usd(finalPrice),
                  style: const TextStyle(
                    color: KrediColors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ComboFinancingCard(
            future: _creditFuture,
            totalUsd: finalPrice,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: KrediColors.border)),
          ),
          child: FilledButton.icon(
            onPressed: business == null
                ? null
                : () {
                    // addCombo es idempotente: si ya estaba seleccionado no lo duplica.
                    app.addCombo(id);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  },
            icon: const Icon(KrediIcons.checkout),
            label: Text(business == null ? 'Compra no disponible' : 'Comprar combo'),
          ),
        ),
      ),
    );
  }
}

class _ComboProductRow extends StatelessWidget {
  const _ComboProductRow({required this.line, required this.app});
  final Map<String, dynamic> line;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final productId = jInt(line, ['productId']);
    final product = app.productById(productId) as Map<String, dynamic>?;
    final image = product == null
        ? ''
        : AppConfig.publicUrl(jString(product, ['imageUrl', 'imagePath', 'image']));
    final quantity = jInt(line, ['quantity'], 1).clamp(1, 999).toInt();
    final unit = jString(line, ['unit']).trim();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 54,
              height: 54,
              child: image.isEmpty
                  ? const ColoredBox(
                      color: KrediColors.softCream,
                      child: Center(
                        child: Icon(KrediIcons.inventory, color: KrediColors.orangeDeep),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: KrediColors.softCream,
                        child: Center(child: Icon(KrediIcons.inventory)),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jString(line, ['name'], 'Producto'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  unit.isEmpty ? '$quantity ${quantity == 1 ? 'unidad' : 'unidades'}' : '$quantity × $unit',
                  style: const TextStyle(fontSize: 11.5, color: KrediColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComboFinancingCard extends StatelessWidget {
  const _ComboFinancingCard({required this.future, required this.totalUsd});
  final Future<Map<String, dynamic>>? future;
  final double totalUsd;

  @override
  Widget build(BuildContext context) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator(minHeight: 3);
        }
        if (snap.hasError || snap.data == null) return const SizedBox.shrink();
        final credit = snap.data!;
        final sendero = jMap(credit, ['senderoLine']) ?? const <String, dynamic>{};
        final altura = jMap(credit, ['alturaLine']) ?? const <String, dynamic>{};
        Map<String, dynamic>? line;
        if (jString(sendero, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE') {
          line = sendero;
        } else if (jBool(altura, ['eligible']) &&
            jString(altura, ['status']).toUpperCase() == 'ACTIVE') {
          line = altura;
        }
        if (line == null) return const SizedBox.shrink();
        final available = jDouble(line, ['availableUsd']);
        final installments = jInt(line, ['maxInstallments'], 2)
            .clamp(1, KrediCreditPolicy.maximumInstallments)
            .toInt();
        final perInstallment = totalUsd / installments;
        final enough = available + .0001 >= totalUsd;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7EA),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFFD8A3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(KrediIcons.credit, size: 20, color: KrediColors.orangeDeep),
                  SizedBox(width: 8),
                  Text('Tu compra con Kredi+', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              _ComboFinanceRow(label: 'Línea disponible', value: _usd(available)),
              const SizedBox(height: 7),
              _ComboFinanceRow(label: 'Cuotas disponibles', value: '$installments'),
              const SizedBox(height: 7),
              _ComboFinanceRow(label: 'Monto por cuota', value: _usd(perInstallment)),
              if (!enough) ...[
                const SizedBox(height: 10),
                const Text(
                  'Tu línea actual no cubre el total de este combo.',
                  style: TextStyle(fontSize: 11.5, color: KrediColors.danger, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ComboFinanceRow extends StatelessWidget {
  const _ComboFinanceRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: KrediColors.secondary),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      );
}

class _Fairs extends StatelessWidget {
  const _Fairs({required this.app, required this.query});
  final dynamic app;
  final String query;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final list = (app.fairs as List<Map<String, dynamic>>)
        .where(
          (e) =>
              jBool(e, ['published'], false) && !jBool(e, ['finalized'], false),
        )
        .where(
          (e) =>
              needle.isEmpty ||
              jString(e, ['name', 'place']).toLowerCase().contains(needle),
        )
        .toList();
    if (list.isEmpty) {
      return const KrediEmptyState(
        icon: KrediIcons.calendar,
        title: 'Sin jornadas activas',
        message: 'El catálogo permanente sigue disponible.',
      );
    }
    return Column(
      children: [
        for (final fair in list) ...[
          KrediOutlineCard(
            onTap: () => app.selectFair(fair),
            child: KrediMenuRow(
              icon: KrediIcons.calendar,
              title: jString(fair, ['name'], 'Jornada Kredi+'),
              subtitle: [
                jString(fair, ['place']),
                jString(fair, ['schedule']),
              ].where((e) => e.trim().isNotEmpty).join(' · '),
              onTap: () => app.selectFair(fair),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

String _usd(double value) => NumberFormat.currency(
  locale: 'es_VE',
  symbol: 'US\$ ',
  decimalDigits: 2,
).format(value);
