import 'package:flutter/foundation.dart';
import 'core/money/money_engine.dart';
import 'core/network/kredi_api.dart';
import 'core/utils/json_read.dart';

class AppController extends ChangeNotifier {
  AppController(this.api);
  final KrediApi api;

  bool busy = false;
  String? error;
  double bcvRate = 0;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> combos = [];
  List<Map<String, dynamic>> fairs = [];
  List<Map<String, dynamic>> banners = [];
  List<Map<String, dynamic>> promotions = [];
  List<Map<String, dynamic>> businesses = [];
  Map<String, dynamic> destinations = {};
  Map<String, dynamic>? selectedFair;
  // 0 = Combos, 1 = Productos, 2 = Jornadas.
  int catalogTab = 0;
  final Map<int, int> productCart = {};
  final Map<int, int> comboCart = {};

  Future<void> refreshCatalog({bool silent = false}) async {
    if (!silent) {
      busy = true;
      error = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        api.products(),
        api.combos(),
        api.fairs(),
        api.banners(),
        api.promotions(),
        api.businesses(),
        api.catalogSalesDestinations(),
        api.bcvRate(),
      ]);
      products = List<Map<String, dynamic>>.from(results[0] as List);
      combos = List<Map<String, dynamic>>.from(results[1] as List);
      fairs = List<Map<String, dynamic>>.from(results[2] as List);
      banners = List<Map<String, dynamic>>.from(results[3] as List);
      promotions = List<Map<String, dynamic>>.from(results[4] as List);
      businesses = List<Map<String, dynamic>>.from(results[5] as List);
      destinations = Map<String, dynamic>.from(results[6] as Map);
      bcvRate = jDouble(Map<String, dynamic>.from(results[7] as Map), ['rate']);
      if (selectedFair != null) {
        final id = jInt(selectedFair!, ['id']);
        selectedFair = fairs.cast<Map<String, dynamic>?>().firstWhere(
          (e) => jInt(e!, ['id']) == id,
          orElse: () => null,
        );
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (!silent) busy = false;
      notifyListeners();
    }
  }

  void selectFair(Map<String, dynamic> fair) {
    selectedFair = fair;
    catalogTab = 0;
    notifyListeners();
  }

  void clearFair() {
    selectedFair = null;
    notifyListeners();
  }

  void setCatalogTab(int index) {
    catalogTab = index;
    notifyListeners();
  }

  Map<String, dynamic>? productById(int id) => products
      .cast<Map<String, dynamic>?>()
      .firstWhere((p) => jInt(p!, ['id']) == id, orElse: () => null);
  Map<String, dynamic>? comboById(int id) => combos
      .cast<Map<String, dynamic>?>()
      .firstWhere((p) => jInt(p!, ['id']) == id, orElse: () => null);

  Map<String, dynamic>? _businessById(int? id) {
    if (id == null) return null;
    return businesses.cast<Map<String, dynamic>?>().firstWhere(
      (b) => jInt(b!, ['id']) == id && (b['active'] ?? true) == true,
      orElse: () => null,
    );
  }

  Map<String, dynamic>? get productBusiness => selectedFair?['business'] is Map
      ? Map<String, dynamic>.from(selectedFair!['business'] as Map)
      : _businessById(jInt(destinations, ['productBusinessId']));
  Map<String, dynamic>? get comboBusiness => selectedFair?['business'] is Map
      ? Map<String, dynamic>.from(selectedFair!['business'] as Map)
      : _businessById(jInt(destinations, ['comboBusinessId']));

  Map<String, dynamic>? paymentContext({required bool forCombos}) {
    if (selectedFair != null) return selectedFair;
    final business = forCombos ? comboBusiness : productBusiness;
    return business;
  }

  void addProduct(int id) {
    comboCart.clear();
    productCart[id] = (productCart[id] ?? 0) + 1;
    notifyListeners();
  }

  void removeProduct(int id) {
    final n = productCart[id] ?? 0;
    if (n <= 1) {
      productCart.remove(id);
    } else {
      productCart[id] = n - 1;
    }
    notifyListeners();
  }

  /// Agrega un combo al carrito de forma idempotente.
  ///
  /// El mismo combo puede abrirse desde banners, jornadas, tiendas o catálogo.
  /// Volver a seleccionarlo desde otra ruta no debe duplicar unidades.
  bool addCombo(int id) {
    productCart.clear();
    final combo = comboById(id);
    if (combo == null) return false;
    if (!comboCart.containsKey(id)) {
      comboCart[id] = 1;
      notifyListeners();
    }
    return true;
  }

  /// Incremento explícito para un control de cantidad (+).
  /// Nunca se usa al navegar o volver a seleccionar el mismo combo.
  bool incrementCombo(int id) {
    productCart.clear();
    final combo = comboById(id);
    if (combo == null) return false;
    comboCart[id] = (comboCart[id] ?? 0) + 1;
    notifyListeners();
    return true;
  }

  void removeCombo(int id) {
    final n = comboCart[id] ?? 0;
    if (n <= 1) {
      comboCart.remove(id);
    } else {
      comboCart[id] = n - 1;
    }
    notifyListeners();
  }

  void clearCart() {
    productCart.clear();
    comboCart.clear();
    notifyListeners();
  }

  int get cartCount =>
      productCart.values.fold(0, (a, b) => a + b) +
      comboCart.values.fold(0, (a, b) => a + b);

  double productPriceUsd(Map<String, dynamic> p) =>
      jDouble(p, ['priceUsd', 'price']);
  double productPriceBs(Map<String, dynamic> p) {
    final direct = jDouble(p, ['priceBs']);
    if (direct > 0) return direct;
    return MoneyEngine.usdToBs(productPriceUsd(p), bcvRate);
  }

  double comboPriceUsd(Map<String, dynamic> c) => jDouble(c, ['priceUsd']);
  double comboPriceBs(Map<String, dynamic> c) {
    final rate = bcvRate > 0 ? bcvRate : jDouble(c, ['bcvRate']);
    if (rate > 0) return MoneyEngine.usdToBs(comboPriceUsd(c), rate);
    return jDouble(c, ['priceBs']);
  }

  Map<String, dynamic>? activePromotion(String targetType, int targetId) {
    final now = DateTime.now();
    for (final p in promotions) {
      if (!jBool(p, ['active'], true)) continue;
      if (jString(p, ['targetType']).toUpperCase() != targetType.toUpperCase()) {
        continue;
      }
      if (jInt(p, ['targetId']) != targetId) continue;
      final s = DateTime.tryParse(jString(p, ['startsAt']));
      final e = DateTime.tryParse(jString(p, ['endsAt']));
      if (s != null && now.isBefore(s)) continue;
      if (e != null && now.isAfter(e)) continue;
      return p;
    }
    return null;
  }

  double discountedUsd(double base, Map<String, dynamic>? promo) {
    if (promo == null) return base;
    final type = jString(promo, ['discountType']).toUpperCase();
    final value = jDouble(promo, ['discountValue']);
    return type.contains('PERCENT')
        ? MoneyEngine.applyPercentDiscount(base, value)
        : MoneyEngine.applyFixedDiscount(base, value);
  }

  double get subtotalUsd {
    double total = 0;
    for (final e in productCart.entries) {
      final p = productById(e.key);
      if (p != null) {
        total +=
            discountedUsd(
              productPriceUsd(p),
              activePromotion('PRODUCT', e.key),
            ) *
            e.value;
      }
    }
    for (final e in comboCart.entries) {
      final c = comboById(e.key);
      if (c != null) {
        total +=
            discountedUsd(comboPriceUsd(c), activePromotion('COMBO', e.key)) *
            e.value;
      }
    }
    return total;
  }

  double get subtotalBs => MoneyEngine.usdToBs(subtotalUsd, bcvRate);
  int get effectiveFairId =>
      selectedFair == null ? 0 : jInt(selectedFair!, ['id']);
}
