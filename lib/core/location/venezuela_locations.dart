import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VenezuelaLocations {
  VenezuelaLocations._();
  static final VenezuelaLocations instance = VenezuelaLocations._();

  static const _baseUrl =
      'https://services1.arcgis.com/KW17JmMsgLshtD2K/arcgis/rest/services/Divisi%C3%B3n_Pol%C3%ADtico_Territorial/FeatureServer';
  static const _separator = '\u001F';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 9),
    ),
  );
  final Map<String, List<String>> _municipalities = {};
  final Map<String, List<String>> _parishes = {};

  List<String> get states => const [
    'Amazonas',
    'Anzoátegui',
    'Apure',
    'Aragua',
    'Barinas',
    'Bolívar',
    'Carabobo',
    'Cojedes',
    'Delta Amacuro',
    'Distrito Capital',
    'Falcón',
    'Guárico',
    'Lara',
    'La Guaira',
    'Mérida',
    'Miranda',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'Yaracuy',
    'Zulia',
  ];

  Future<List<String>> municipalities(String state) async {
    final key = state.trim();
    if (key.isEmpty) return const [];
    if (_municipalities[key]?.isNotEmpty == true) return _municipalities[key]!;
    final cached = await _read('municipalities:$key');
    if (cached.isNotEmpty) {
      _municipalities[key] = cached;
      return cached;
    }
    final rows = await _query(
      layer: 2,
      where: "Nb_estado='${_sql(key)}'",
      outFields: 'DPT002_MUNICIPIO_Nb_municip',
    );
    final values =
        rows
            .map((e) => _clean(e['DPT002_MUNICIPIO_Nb_municip']))
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort(_compare);
    if (values.isNotEmpty) {
      _municipalities[key] = values;
      await _write('municipalities:$key', values);
    }
    return values;
  }

  Future<List<String>> parishes(String state, String municipality) async {
    final s = state.trim();
    final m = municipality.trim();
    if (s.isEmpty || m.isEmpty) return const [];
    final cacheKey = '$s|$m';
    if (_parishes[cacheKey]?.isNotEmpty == true) return _parishes[cacheKey]!;
    final cached = await _read('parishes:$s:$m');
    if (cached.isNotEmpty) {
      _parishes[cacheKey] = cached;
      return cached;
    }
    final rows = await _query(
      layer: 1,
      where: "ESTADO='${_sql(s)}' AND MUNICIPIO='${_sql(m)}'",
      outFields: 'PARROQUIA',
    );
    final values =
        rows
            .map((e) => _clean(e['PARROQUIA']))
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort(_compare);
    if (values.isNotEmpty) {
      _parishes[cacheKey] = values;
      await _write('parishes:$s:$m', values);
    }
    return values;
  }

  Future<List<Map<String, dynamic>>> _query({
    required int layer,
    required String where,
    required String outFields,
  }) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/$layer/query',
        queryParameters: {
          'where': where,
          'outFields': outFields,
          'returnGeometry': false,
          'resultRecordCount': 2000,
          'f': 'json',
        },
      );
      final data = r.data ?? const {};
      if (data['error'] is Map) {
        final err = Map<String, dynamic>.from(data['error'] as Map);
        throw Exception(
          err['message']?.toString() ?? 'No fue posible cargar la ubicación.',
        );
      }
      final features = data['features'];
      if (features is! List) return const [];
      return features
          .whereType<Map>()
          .map((feature) => feature['attributes'])
          .whereType<Map>()
          .map((attributes) => Map<String, dynamic>.from(attributes))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kredi_geo_$key');
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(_separator)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _write(String key, List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kredi_geo_$key', values.join(_separator));
  }

  static String _sql(String value) => value.replaceAll("'", "''");
  static String _clean(dynamic value) =>
      value?.toString().trim().replaceFirst(RegExp(r'\.$'), '') ?? '';
  static int _compare(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
}
