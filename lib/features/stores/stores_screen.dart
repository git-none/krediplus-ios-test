import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../core/utils/presentation.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/checkout_screen.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final query = TextEditingController();
  String category = 'Todas';

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final all = List<Map<String, dynamic>>.from(app.businesses);
        final categories = <String>{'Todas'};
        for (final item in all) {
          final value = jString(item, [
            'category',
            'businessType',
            'type',
          ]).trim();
          if (value.isNotEmpty) categories.add(value);
        }
        final needle = query.text.trim().toLowerCase();
        final filtered = all.where((item) {
          final name = jString(item, [
            'commercialName',
            'legalName',
            'name',
          ]).toLowerCase();
          final itemCategory = jString(item, [
            'category',
            'businessType',
            'type',
          ]).trim();
          final matchesText = needle.isEmpty || name.contains(needle);
          final matchesCategory =
              category == 'Todas' || itemCategory == category;
          return matchesText && matchesCategory;
        }).toList();

        return RefreshIndicator(
          onRefresh: () => app.refreshCatalog(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const KrediScreenTitle('Tiendas'),
              const SizedBox(height: 22),
              KrediSearchField(
                controller: query,
                hint: 'Buscar tiendas',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = categories.elementAt(index);
                    return ChoiceChip(
                      label: Text(item),
                      selected: category == item,
                      onSelected: (_) => setState(() => category = item),
                      selectedColor: KrediColors.softOrange,
                      side: const BorderSide(color: KrediColors.border),
                      labelStyle: TextStyle(
                        color: KrediColors.black,
                        fontWeight: category == item
                            ? FontWeight.w600
                            : FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (app.busy && all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                const KrediEmptyState(
                  icon: KrediIcons.storefront,
                  title: 'No encontramos tiendas',
                  message: 'Prueba otra búsqueda o categoría.',
                )
              else
                for (final item in filtered) ...[
                  _StoreRow(data: item),
                  const Divider(height: 1),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = jString(data, ['commercialName', 'legalName', 'name'], 'Tienda Kredi+');
    final image = AppConfig.publicUrl(
      jString(data, ['logoUrl', 'logoPath', 'imageUrl', 'imagePath', 'image']),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KrediPressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StoreDetailScreen(store: data)),
        ),
        pressedScale: .99,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: KrediColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.95,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFFFF3E1),
                          child: Center(child: Icon(KrediIcons.storefront, color: KrediColors.orangeDeep, size: 42)),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.contain,
                          placeholder: (_, _) => const ColoredBox(
                            color: Color(0xFFF7F7F8),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: Color(0xFFFFF3E1),
                            child: Center(child: Icon(KrediIcons.storefront, color: KrediColors.orangeDeep, size: 42)),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, height: 1.15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.store});
  final Map<String, dynamic> store;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  Future<Map<String, dynamic>>? communityCatalog;
  bool started = false;
  bool buying = false;

  bool get isCommunity =>
      jString(widget.store, ['storeType']).toUpperCase() == 'COMMUNITY_STORE';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final id = jInt(widget.store, ['id']);
    if (isCommunity && id > 0) {
      communityCatalog = AppScope.of(context)
          .api
          .communityStoreCatalog(id)
          .timeout(const Duration(seconds: 15));
    }
  }

  bool _belongsToStore(Map<String, dynamic> item, int storeId, String storeName) {
    if (storeId <= 0) return false;
    for (final key in const [
      'businessId',
      'storeId',
      'merchantId',
      'commerceId',
      'associatedBusinessId',
    ]) {
      if (jInt(item, [key]) == storeId) return true;
    }
    final nested = item['business'];
    if (nested is Map && jInt(Map<String, dynamic>.from(nested), ['id']) == storeId) {
      return true;
    }
    final itemStoreName = jString(item, [
      'businessName',
      'storeName',
      'commerceName',
      'merchantName',
    ]).trim().toLowerCase();
    return itemStoreName.isNotEmpty &&
        itemStoreName == storeName.trim().toLowerCase();
  }

  Future<void> _buyCommunity(String itemType, int itemId) async {
    if (buying || itemId <= 0) return;
    setState(() => buying = true);
    try {
      final purchase = await AppScope.of(context).api.startCommunityStorePurchase(
        jInt(widget.store, ['id']),
        itemType,
        itemId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CommunityStorePurchaseScreen(initial: purchase),
        ),
      );
      if (mounted && isCommunity) {
        setState(() {
          communityCatalog = AppScope.of(context)
              .api
              .communityStoreCatalog(jInt(widget.store, ['id']))
              .timeout(const Duration(seconds: 15));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final app = AppScope.of(context).app;
    final name = jString(
      store,
      ['commercialName', 'legalName', 'name'],
      'Tienda Kredi+',
    );
    final category = jString(store, ['category', 'businessType', 'type']);
    final description = jString(store, ['description', 'details', 'about']);
    final active = jBool(store, ['active'], true);
    final storeId = jInt(store, ['id']);
    final location = [
      jString(store, ['address', 'addressLine']),
      jString(store, ['municipality', 'city']),
      jString(store, ['state']),
    ].where((e) => e.trim().isNotEmpty).toSet().join(' · ');
    final image = AppConfig.publicUrl(
      jString(store, [
        'logoUrl',
        'logoPath',
        'imageUrl',
        'imagePath',
        'image',
      ]),
    );

    if (isCommunity && communityCatalog != null) {
      return FutureBuilder<Map<String, dynamic>>(
        future: communityCatalog,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <String, dynamic>{};
          final products = jList(data, ['products'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final combos = jList(data, ['combos'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return _buildBody(
            context,
            name: name,
            category: category,
            description: description,
            location: location,
            image: image,
            active: active,
            products: products,
            combos: combos,
            loading: snapshot.connectionState != ConnectionState.done,
            loadError: snapshot.hasError,
            onProduct: (row) => _buyCommunity('PRODUCT', jInt(row, ['id'])),
            onCombo: (row) => _buyCommunity('COMBO', jInt(row, ['id'])),
          );
        },
      );
    }

    var products = (app.products as List<Map<String, dynamic>>)
        .where((item) => _belongsToStore(item, storeId, name))
        .toList();
    var combos = (app.combos as List<Map<String, dynamic>>)
        .where((item) => _belongsToStore(item, storeId, name))
        .toList();

    // El catálogo permanente puede venir asociado al comercio por el destino
    // de ventas aunque cada producto/combos no repita businessId.
    if (products.isEmpty &&
        jInt(app.productBusiness ?? const <String, dynamic>{}, ['id']) ==
            storeId) {
      products = List<Map<String, dynamic>>.from(app.products);
    }
    if (combos.isEmpty &&
        jInt(app.comboBusiness ?? const <String, dynamic>{}, ['id']) ==
            storeId) {
      combos = List<Map<String, dynamic>>.from(app.combos)
          .where((item) => jBool(item, ['active'], true))
          .toList();
    }

    final productDestinationMatches =
        jInt(app.productBusiness ?? const <String, dynamic>{}, ['id']) ==
            storeId;
    final comboDestinationMatches =
        jInt(app.comboBusiness ?? const <String, dynamic>{}, ['id']) ==
            storeId;

    return _buildBody(
      context,
      name: name,
      category: category,
      description: description,
      location: location,
      image: image,
      active: active,
      products: products,
      combos: combos,
      loading: false,
      loadError: false,
      productActionLabel:
          productDestinationMatches ? 'Comprar' : 'Ver catálogo',
      comboActionLabel:
          comboDestinationMatches ? 'Comprar' : 'Ver catálogo',
      onProduct: (row) {
        final id = jInt(row, ['id']);
        if (productDestinationMatches && id > 0) {
          app.addProduct(id);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CatalogScreen()),
        );
      },
      onCombo: (row) {
        final id = jInt(row, ['id']);
        if (comboDestinationMatches && id > 0 && app.addCombo(id)) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CatalogScreen(initialCombos: true),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required String name,
    required String category,
    required String description,
    required String location,
    required String image,
    required bool active,
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> combos,
    required bool loading,
    required bool loadError,
    String productActionLabel = 'Comprar',
    String comboActionLabel = 'Comprar',
    required ValueChanged<Map<String, dynamic>> onProduct,
    required ValueChanged<Map<String, dynamic>> onCombo,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comercio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: KrediColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 2.2,
                    child: image.isEmpty
                        ? const _StoreHeroFallback()
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.contain,
                            errorWidget: (_, _, _) =>
                                const _StoreHeroFallback(),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? KrediColors.softGreen
                                    : KrediColors.softError,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                active ? 'Disponible' : 'No disponible',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? KrediColors.green
                                      : KrediColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            category,
                            style: const TextStyle(
                              color: KrediColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            description,
                            style: const TextStyle(
                              height: 1.4,
                              color: KrediColors.inkSoft,
                            ),
                          ),
                        ],
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                KrediIcons.location,
                                size: 18,
                                color: KrediColors.orangeDeep,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: KrediColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Productos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (loadError)
              const KrediEmptyState(
                icon: KrediIcons.offline,
                title: 'No pudimos cargar el catálogo',
                message: 'Actualiza e inténtalo nuevamente.',
              )
            else if (products.isEmpty)
              const KrediEmptyState(
                icon: KrediIcons.inventory,
                title: 'Sin productos disponibles',
                message: 'Este comercio no tiene productos publicados.',
              )
            else
              for (final product in products)
                _StoreInlineCatalogItem(
                  imageUrl: AppConfig.publicUrl(
                    jString(product, ['imageUrl', 'imagePath', 'image']),
                  ),
                  title: jString(product, ['name'], 'Producto'),
                  subtitle: jString(product, ['category']),
                  price: jDouble(product, ['priceUsd', 'price']),
                  badge: jInt(product, ['stock']) > 0
                      ? 'Disponible'
                      : 'Agotado',
                  actionLabel: productActionLabel,
                  enabled: active && jInt(product, ['stock'], 1) > 0,
                  onBuy: () => onProduct(product),
                ),
            const SizedBox(height: 22),
            const Text(
              'Combos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (!loading && !loadError && combos.isEmpty)
              const KrediEmptyState(
                icon: KrediIcons.basket,
                title: 'Sin combos disponibles',
                message: 'Este comercio no tiene combos publicados.',
              )
            else if (!loading && !loadError)
              for (final combo in combos)
                _StoreInlineCatalogItem(
                  imageUrl: AppConfig.publicUrl(
                    jString(combo, [
                      'coverUrl',
                      'imageUrl',
                      'imagePath',
                      'image',
                    ]),
                  ),
                  title: jString(combo, ['name'], 'Combo'),
                  subtitle: jString(combo, ['description']),
                  price: jDouble(combo, ['priceUsd']),
                  badge: 'Combo',
                  actionLabel: comboActionLabel,
                  enabled: active,
                  onBuy: () => onCombo(combo),
                ),
          ],
        ),
      ),
    );
  }
}

class _StoreInlineCatalogItem extends StatelessWidget {
  const _StoreInlineCatalogItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.badge,
    this.actionLabel = 'Comprar',
    required this.enabled,
    required this.onBuy,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final double price;
  final String badge;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: KrediColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 76,
                height: 76,
                child: imageUrl.isEmpty
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
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KrediColors.secondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    price > 0
                        ? moneyUsd(price)
                        : 'Precio no disponible',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: KrediColors.secondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: enabled ? onBuy : null,
                        child: Text(actionLabel),
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

class _StoreHeroFallback extends StatelessWidget {
  const _StoreHeroFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: KrediColors.softOrange,
        child: Center(
          child: Icon(KrediIcons.storefront, size: 56, color: KrediColors.orangeDeep),
        ),
      );
}

class CommunityStoreCatalogScreen extends StatefulWidget {
  const CommunityStoreCatalogScreen({
    super.key,
    required this.storeId,
    this.initialStore,
    this.initialCatalog,
  });

  final int storeId;
  final Map<String, dynamic>? initialStore;
  final Map<String, dynamic>? initialCatalog;

  @override
  State<CommunityStoreCatalogScreen> createState() =>
      _CommunityStoreCatalogScreenState();
}

class _CommunityStoreCatalogScreenState
    extends State<CommunityStoreCatalogScreen> {
  Map<String, dynamic>? catalog;
  String? error;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    catalog = widget.initialCatalog;
    if (catalog != null) {
      busy = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await AppScope.of(context).api.communityStoreCatalog(
        widget.storeId,
      );
      if (mounted) setState(() => catalog = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _buy(String itemType, int itemId) async {
    if (itemId <= 0 || busy) return;
    setState(() => busy = true);
    try {
      final purchase = await AppScope.of(context).api.startCommunityStorePurchase(
        widget.storeId,
        itemType,
        itemId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CommunityStorePurchaseScreen(initial: purchase),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = catalog?['store'] is Map
        ? Map<String, dynamic>.from(catalog!['store'] as Map)
        : (widget.initialStore ?? <String, dynamic>{});
    final products = catalog?['products'] is List
        ? List<Map<String, dynamic>>.from(
            (catalog!['products'] as List).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : <Map<String, dynamic>>[];
    final combos = catalog?['combos'] is List
        ? List<Map<String, dynamic>>.from(
            (catalog!['combos'] as List).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : <Map<String, dynamic>>[];
    final name = jString(store, ['name'], 'Bodega Kredi+');
    final salesEnabled = jInt(store, ['associatedBusinessId']) > 0;
    final location = [
      jString(store, ['municipality']),
      jString(store, ['parish']),
      jString(store, ['community']),
    ].where((e) => e.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: KrediColors.softOrange,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: KrediColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      location,
                      style: const TextStyle(color: KrediColors.secondary),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag(jString(store, ['code'], 'Bodega Kredi+')),
                      const _Tag('QR propio'),
                    ],
                  ),
                ],
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 48),
              const Center(child: CircularProgressIndicator()),
            ] else if (error != null) ...[
              const SizedBox(height: 24),
              KrediEmptyState(
                icon: KrediIcons.offline,
                title: 'No pudimos abrir el catálogo',
                message: 'Actualiza e inténtalo nuevamente.',
              ),
            ] else ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: salesEnabled ? KrediColors.softGreen : KrediColors.softOrange,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KrediColors.border),
                ),
                child: Text(
                  salesEnabled
                      ? 'Compras Kredi+ disponibles.'
                      : 'Catálogo disponible. Compras aún no habilitadas.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: salesEnabled ? KrediColors.green : KrediColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Productos',
                style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (products.isEmpty)
                const KrediEmptyState(
                  icon: KrediIcons.inventory,
                  title: 'Sin productos todavía',
                  message: 'Esta bodega aún no ha publicado productos.',
                )
              else
                for (final product in products)
                  _StoreCatalogItem(
                    imageUrl: AppConfig.publicUrl(
                      jString(product, ['imageUrl', 'imagePath', 'image']),
                    ),
                    title: jString(product, ['name'], 'Producto'),
                    subtitle: jString(product, ['category']),
                    price: jDouble(product, ['priceUsd']),
                    badge: 'Stock ${jInt(product, ['stock'])}',
                    enabled: salesEnabled && jInt(product, ['stock']) > 0,
                    onBuy: () => _buy('PRODUCT', jInt(product, ['id'])),
                  ),
              const SizedBox(height: 24),
              const Text(
                'Combos',
                style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (combos.isEmpty)
                const KrediEmptyState(
                  icon: KrediIcons.basket,
                  title: 'Sin combos todavía',
                  message: 'Cuando la bodega publique combos aparecerán aquí.',
                )
              else
                for (final combo in combos)
                  _StoreCatalogItem(
                    imageUrl: AppConfig.publicUrl(
                      jString(combo, ['coverUrl', 'imageUrl', 'imagePath', 'image']),
                    ),
                    title: jString(combo, ['name'], 'Combo'),
                    subtitle: jString(combo, ['description']),
                    price: jDouble(combo, ['priceUsd']),
                    badge: '${jList(combo, ['items']).length} productos',
                    enabled: salesEnabled,
                    onBuy: () => _buy('COMBO', jInt(combo, ['id'])),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreCatalogItem extends StatelessWidget {
  const _StoreCatalogItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.badge,
    required this.enabled,
    required this.onBuy,
  });
  final String imageUrl;
  final String title;
  final String subtitle;
  final double price;
  final String badge;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: KrediColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF7F7F8),
                      child: Center(
                        child: Icon(
                          KrediIcons.image,
                          color: KrediColors.secondary,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF7F7F8),
                        child: Center(
                          child: Icon(
                            KrediIcons.image,
                            color: KrediColors.secondary,
                          ),
                        ),
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
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: KrediColors.secondary,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    color: KrediColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moneyUsd(price),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: KrediColors.coral,
                ),
              ),
              const SizedBox(height: 8),
              KrediActionButton(
                icon: KrediIcons.checkout,
                label: 'Comprar',
                onPressed: enabled ? onBuy : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class CommunityStorePurchaseScreen extends StatefulWidget {
  const CommunityStorePurchaseScreen({super.key, required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<CommunityStorePurchaseScreen> createState() =>
      _CommunityStorePurchaseScreenState();
}

class _CommunityStorePurchaseScreenState
    extends State<CommunityStorePurchaseScreen> {
  late Map<String, dynamic> data;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    data = Map<String, dynamic>.from(widget.initial);
  }

  Future<void> _confirm() async {
    final id = jInt(data, ['id']);
    if (id <= 0 || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await AppScope.of(context).api.confirmQrPurchase(
        id,
        commerceFlow: true,
      );
      if (mounted) setState(() => data = next);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = jString(data, ['status']);
    final completed = status == 'COMPLETED';
    final awaitingInitial = status == 'AWAITING_INITIAL';
    final offer = jString(data, ['offerName'], 'Compra Kredi+');
    final business = jString(data, ['businessName'], 'Bodega Kredi+');
    final total = jDouble(data, ['totalUsd']);
    const initial = 0.0;
    final financed = total;
    final installmentCount = jInt(data, ['installmentCount']).clamp(0, KrediCreditPolicy.maximumInstallments).toInt();
    final installment = installmentCount > 0 ? total / installmentCount : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar compra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            offer,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(business, style: const TextStyle(color: KrediColors.secondary)),
          const SizedBox(height: 22),
          _PurchaseFact('Total', moneyUsd(total)),
          _PurchaseFact('Inicial', moneyUsd(initial)),
          _PurchaseFact('Financiado', moneyUsd(financed)),
          _PurchaseFact(
            'Cuotas',
            installmentCount > 0
                ? '$installmentCount × ${moneyUsd(installment)}'
                : 'Sin cuotas',
          ),
          const SizedBox(height: 20),
          if (error != null)
            Text(error!, style: const TextStyle(color: KrediColors.danger)),
          if (completed)
            const KrediEmptyState(
              icon: KrediIcons.confirm,
              title: 'Compra aprobada',
              message: 'Tu compra quedó registrada correctamente.',
            )
          else if (awaitingInitial)
            const KrediEmptyState(
              icon: KrediIcons.payments,
              title: 'Compra registrada',
              message:
                  'Tu línea tiene 0% inicial. Las cuotas se activarán al completar la confirmación.',
            )
          else
            FilledButton.icon(
              onPressed: busy ? null : _confirm,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(KrediIcons.check),
              label: const Text('Confirmar compra'),
            ),
        ],
      ),
    );
  }
}

class _PurchaseFact extends StatelessWidget {
  const _PurchaseFact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: KrediColors.secondary),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: KrediColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, color: KrediColors.secondary),
      ),
    );
  }
}
