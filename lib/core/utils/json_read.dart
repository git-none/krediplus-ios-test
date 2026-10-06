String jString(
  Map<String, dynamic> json,
  Iterable<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) {
      final text = value.toString().trim();
      final normalized = text.toLowerCase();
      if (text.isNotEmpty &&
          !const {'null', 'none', 'undefined', 'n/a', 'nan'}.contains(normalized)) {
        return text;
      }
    }
  }
  return fallback;
}

double jDouble(
  Map<String, dynamic> json,
  Iterable<String> keys, [
  double fallback = 0,
]) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return fallback;
}

int jInt(Map<String, dynamic> json, Iterable<String> keys, [int fallback = 0]) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return fallback;
}

bool jBool(
  Map<String, dynamic> json,
  Iterable<String> keys, [
  bool fallback = false,
]) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
  }
  return fallback;
}

List<dynamic> jList(Map<String, dynamic> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) return value;
  }
  return const [];
}

Map<String, dynamic>? jMap(Map<String, dynamic> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return null;
}
