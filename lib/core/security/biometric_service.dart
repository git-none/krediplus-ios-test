import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricCapabilities {
  const BiometricCapabilities({
    required this.deviceSupported,
    required this.canCheckBiometrics,
    required this.availableBiometrics,
  });

  final bool deviceSupported;
  final bool canCheckBiometrics;
  final List<BiometricType> availableBiometrics;

  bool get hasEnrolledBiometrics => availableBiometrics.isNotEmpty;
  bool get hasFace => availableBiometrics.contains(BiometricType.face);
  bool get hasFingerprint =>
      availableBiometrics.contains(BiometricType.fingerprint) ||
      availableBiometrics.contains(BiometricType.strong);

  String get displayName => hasFace
      ? 'Face ID'
      : hasFingerprint
          ? 'Touch ID'
          : 'Face ID';
}

class BiometricResult {
  const BiometricResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class BiometricService {
  BiometricService({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<BiometricCapabilities> capabilities() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final canCheck = await _authentication.canCheckBiometrics;
      final available = canCheck
          ? await _authentication.getAvailableBiometrics()
          : const <BiometricType>[];
      return BiometricCapabilities(
        deviceSupported: supported,
        canCheckBiometrics: canCheck,
        availableBiometrics: List<BiometricType>.unmodifiable(available),
      );
    } on PlatformException {
      return const BiometricCapabilities(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: <BiometricType>[],
      );
    } on LocalAuthException {
      return const BiometricCapabilities(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: <BiometricType>[],
      );
    } catch (_) {
      return const BiometricCapabilities(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: <BiometricType>[],
      );
    }
  }

  Future<BiometricResult> authenticateBiometric() => _authenticate(
        biometricOnly: true,
        reason: 'Confirma tu identidad para desbloquear Kredi+.',
      );

  Future<BiometricResult> authenticateDevice() => _authenticate(
        biometricOnly: false,
        reason: 'Confirma el bloqueo de tu dispositivo para entrar a Kredi+.',
      );

  Future<BiometricResult> _authenticate({
    required bool biometricOnly,
    required String reason,
  }) async {
    try {
      final ok = await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
      return BiometricResult(
        success: ok,
        message: ok ? null : 'No se pudo confirmar tu identidad.',
      );
    } on LocalAuthException catch (e) {
      return BiometricResult(success: false, message: _messageFor(e.code));
    } on PlatformException {
      return const BiometricResult(
        success: false,
        message: 'La autenticación biométrica no está disponible ahora.',
      );
    } catch (_) {
      return const BiometricResult(
        success: false,
        message: 'No fue posible iniciar la autenticación biométrica.',
      );
    }
  }

  Future<void> cancel() async {
    try {
      await _authentication.stopAuthentication();
    } catch (_) {}
  }

  String? _messageFor(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return null;
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No hay Face ID configurado en este iPhone.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Este dispositivo no dispone de biometría compatible.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Configura un bloqueo de pantalla seguro en tu dispositivo.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'La biometría está bloqueada temporalmente. Inténtalo más tarde.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'La biometría fue bloqueada. Desbloquea primero el dispositivo.';
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'El sensor biométrico no está disponible en este momento.';
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Usa el método alternativo para continuar.';
      case LocalAuthExceptionCode.authInProgress:
        return 'Ya hay una verificación biométrica en curso.';
      case LocalAuthExceptionCode.uiUnavailable:
        return 'No fue posible mostrar la verificación biométrica.';
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return 'No fue posible validar la biometría.';
      default:
        return 'No fue posible validar la biometría.';
    }
  }
}
