import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions());

  static const _pinRounds = 20000;

  Future<String?> get accessToken => _secure.read(key: 'access_token');
  Future<String?> get refreshToken => _secure.read(key: 'refresh_token');

  Future<void> saveTokens(String access, String refresh) async {
    await _secure.write(key: 'access_token', value: access);
    await _secure.write(key: 'refresh_token', value: refresh);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user));
  }

  Future<Map<String, dynamic>?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('current_user');
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _secure.delete(key: 'access_token');
    await _secure.delete(key: 'refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  Future<void> setBiometricEnabled(int userId, bool enabled) async {
    final key = 'biometric_enabled_$userId';
    if (enabled) {
      await _secure.write(key: key, value: '1');
    } else {
      await _secure.delete(key: key);
    }
  }

  Future<bool> isBiometricEnabled(int userId) async =>
      await _secure.read(key: 'biometric_enabled_$userId') == '1';

  Future<void> saveLocalPinVerifier(int userId, String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return;
    final random = Random.secure();
    final salt = List<int>.generate(
      24,
      (_) => random.nextInt(256),
    ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    final seed = await _deviceSeed();
    final verifier = _derivePinVerifier(
      pin: pin,
      userId: userId,
      salt: salt,
      seed: seed,
    );
    await _secure.write(key: 'local_pin_salt_$userId', value: salt);
    await _secure.write(key: 'local_pin_hash_$userId', value: verifier);
  }

  Future<bool> hasLocalPinVerifier(int userId) async {
    final salt = await _secure.read(key: 'local_pin_salt_$userId');
    final hash = await _secure.read(key: 'local_pin_hash_$userId');
    return (salt?.isNotEmpty ?? false) && (hash?.isNotEmpty ?? false);
  }

  Future<bool> verifyLocalPin(int userId, String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return false;
    final salt = await _secure.read(key: 'local_pin_salt_$userId');
    final expected = await _secure.read(key: 'local_pin_hash_$userId');
    if (salt == null || salt.isEmpty || expected == null || expected.isEmpty) {
      return false;
    }
    final seed = await _deviceSeed();
    final candidate = _derivePinVerifier(
      pin: pin,
      userId: userId,
      salt: salt,
      seed: seed,
    );
    return _constantTimeEquals(expected, candidate);
  }

  Future<void> clearAccountSecurity(int userId) async {
    await Future.wait([
      _secure.delete(key: 'biometric_enabled_$userId'),
      _secure.delete(key: 'local_pin_salt_$userId'),
      _secure.delete(key: 'local_pin_hash_$userId'),
    ]);
  }

  Future<String> deviceIdHash() async {
    final seed = await _deviceSeed();
    return sha256
        .convert(utf8.encode('com.impulsosocial.nativeapp:$seed'))
        .toString();
  }

  Future<String> _deviceSeed() async {
    var seed = await _secure.read(key: 'device_seed');
    if (seed == null || seed.isEmpty) {
      final random = Random.secure();
      seed = List<int>.generate(
        32,
        (_) => random.nextInt(256),
      ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      await _secure.write(key: 'device_seed', value: seed);
    }
    return seed;
  }

  String _derivePinVerifier({
    required String pin,
    required int userId,
    required String salt,
    required String seed,
  }) {
    var digest = sha256
        .convert(utf8.encode('krediplus-local-pin-v1|$userId|$salt|$seed|$pin'))
        .bytes;
    final suffix = utf8.encode('|$userId|$salt|$seed');
    for (var round = 0; round < _pinRounds; round++) {
      digest = sha256.convert(<int>[...digest, ...suffix]).bytes;
    }
    return base64UrlEncode(digest);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
