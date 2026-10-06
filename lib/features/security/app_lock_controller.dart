import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/security/biometric_service.dart';
import '../../core/storage/session_store.dart';
import '../../models/app_user.dart';

class AppLockController extends ChangeNotifier {
  AppLockController(this.store, this.biometrics);

  final SessionStore store;
  final BiometricService biometrics;

  static const Duration lockDelay = Duration(minutes: 1);

  int? _userId;
  DateTime? _backgroundedAt;
  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;
  bool _hasKrediPinFallback = false;
  BiometricCapabilities? _capabilities;
  String? _error;

  int? get userId => _userId;
  bool get enabled => _enabled;
  bool get locked => _enabled && _locked;
  bool get authenticating => _authenticating;
  bool get hasKrediPinFallback => _hasKrediPinFallback;
  BiometricCapabilities? get capabilities => _capabilities;
  String? get error => _error;

  Future<void> bindUser(
    AppUser? user, {
    bool lockImmediately = false,
  }) async {
    if (user == null) {
      clearRuntime();
      return;
    }
    final changed = _userId != user.id;
    _userId = user.id;
    if (changed || _capabilities == null) {
      _capabilities = await biometrics.capabilities();
    }
    _enabled = await store.isBiometricEnabled(user.id);
    _hasKrediPinFallback = await store.hasLocalPinVerifier(user.id);
    if (_enabled && lockImmediately) _locked = true;
    if (!_enabled) _locked = false;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshCapabilities() async {
    _capabilities = await biometrics.capabilities();
    final id = _userId;
    if (id != null) {
      _hasKrediPinFallback = await store.hasLocalPinVerifier(id);
    }
    notifyListeners();
  }

  Future<bool> enableBiometrics({String? krediPin}) async {
    final id = _userId;
    if (id == null) return false;
    _error = null;
    await refreshCapabilities();
    final caps = _capabilities;
    if (caps == null || !caps.deviceSupported || !caps.canCheckBiometrics) {
      _error = 'Este dispositivo no dispone de biometría compatible.';
      notifyListeners();
      return false;
    }
    if (!caps.hasEnrolledBiometrics) {
      _error = 'Configura Face ID en tu iPhone para activarlo.';
      notifyListeners();
      return false;
    }
    if (_hasKrediPinFallback) {
      if (krediPin == null || krediPin.length != 6) {
        _error = 'Confirma tu PIN Kredi+ de 6 dígitos.';
        notifyListeners();
        return false;
      }
      final validPin = await store.verifyLocalPin(id, krediPin);
      if (!validPin) {
        _error = 'El PIN Kredi+ no es correcto.';
        notifyListeners();
        return false;
      }
    }

    final result = await _runAuthentication(biometrics.authenticateBiometric);
    if (!result.success) {
      if (result.message != null) _error = result.message;
      notifyListeners();
      return false;
    }
    await store.setBiometricEnabled(id, true);
    _enabled = true;
    _locked = false;
    _error = null;
    notifyListeners();
    return true;
  }

  Future<void> disableBiometrics() async {
    final id = _userId;
    if (id != null) await store.setBiometricEnabled(id, false);
    await biometrics.cancel();
    _enabled = false;
    _locked = false;
    _error = null;
    _backgroundedAt = null;
    notifyListeners();
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_enabled || _userId == null) return true;
    _error = null;
    final result = await _runAuthentication(biometrics.authenticateBiometric);
    if (result.success) {
      _locked = false;
      _backgroundedAt = null;
      _error = null;
      notifyListeners();
      return true;
    }
    if (result.message != null) _error = result.message;
    notifyListeners();
    return false;
  }

  Future<bool> unlockWithDeviceCredential() async {
    if (!_enabled || _userId == null) return true;
    _error = null;
    final result = await _runAuthentication(biometrics.authenticateDevice);
    if (result.success) {
      _locked = false;
      _backgroundedAt = null;
      _error = null;
      notifyListeners();
      return true;
    }
    if (result.message != null) _error = result.message;
    notifyListeners();
    return false;
  }

  Future<bool> unlockWithKrediPin(String pin) async {
    final id = _userId;
    if (!_enabled || id == null) return true;
    if (pin.length != 6) {
      _error = 'Ingresa los 6 números de tu PIN.';
      notifyListeners();
      return false;
    }
    final valid = await store.verifyLocalPin(id, pin);
    if (!valid) {
      _error = 'El PIN Kredi+ no es correcto.';
      notifyListeners();
      return false;
    }
    _locked = false;
    _backgroundedAt = null;
    _error = null;
    notifyListeners();
    return true;
  }

  Future<void> refreshPinFallback() async {
    final id = _userId;
    if (id == null) return;
    _hasKrediPinFallback = await store.hasLocalPinVerifier(id);
    notifyListeners();
  }

  void handleLifecycle(AppLifecycleState state) {
    if (!_enabled || _userId == null || _authenticating) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.detached) {
      _locked = true;
      notifyListeners();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) >= lockDelay) {
        _locked = true;
        notifyListeners();
      }
    }
  }

  void lockNow() {
    if (!_enabled || _userId == null || _authenticating) return;
    _locked = true;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void clearRuntime() {
    _userId = null;
    _enabled = false;
    _locked = false;
    _authenticating = false;
    _hasKrediPinFallback = false;
    _capabilities = null;
    _backgroundedAt = null;
    _error = null;
    notifyListeners();
  }

  Future<BiometricResult> _runAuthentication(
    Future<BiometricResult> Function() action,
  ) async {
    if (_authenticating) {
      return const BiometricResult(
        success: false,
        message: 'Ya hay una verificación biométrica en curso.',
      );
    }
    _authenticating = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }
}
