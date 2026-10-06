import 'package:flutter/foundation.dart';
import '../../core/network/kredi_api.dart';
import '../../core/storage/session_store.dart';
import '../../models/app_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.api, this.store);

  final KrediApi api;
  final SessionStore store;

  AppUser? user;
  bool busy = false;
  String? error;
  int? pendingUserId;
  String? pendingChallenge;
  String pendingIdentifier = '';
  int? pendingRegistrationUserId;
  String? pendingRegistrationToken;
  String pendingRegistrationStatus = '';
  bool initialized = false;

  bool get isAuthenticated => user != null;
  bool get needsPin =>
      pendingUserId != null && pendingChallenge != null && user == null;
  bool get hasPendingRegistration =>
      pendingRegistrationUserId != null &&
      (pendingRegistrationToken?.isNotEmpty ?? false);

  Future<void> initialize() async {
    if (initialized) return;
    final cached = await store.loadUser();
    if (cached != null && (await store.refreshToken)?.isNotEmpty == true) {
      try {
        final fresh = await api.me();
        final candidate = AppUser.fromJson(fresh);
        if (candidate.role != UserRole.beneficiary) {
          await store.clearAccountSecurity(candidate.id);
          await store.clear();
        } else {
          user = candidate;
          await store.saveUser(fresh);
        }
      } catch (_) {
        final cachedId = int.tryParse(cached['id']?.toString() ?? '');
        if (cachedId != null && cachedId > 0) {
          await store.clearAccountSecurity(cachedId);
        }
        user = null;
        await store.clear();
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      error = 'Ingresa tu nombre de usuario o correo.';
      notifyListeners();
      return false;
    }
    if (password.length < 8) {
      error = 'La contraseña debe tener al menos 8 caracteres.';
      notifyListeners();
      return false;
    }

    _start();
    try {
      final response = await api.login(normalized, password);
      final registrationToken = response['registrationToken']?.toString() ?? '';
      final responseUserId = int.tryParse(response['userId']?.toString() ?? '');
      if (registrationToken.isNotEmpty &&
          responseUserId != null &&
          responseUserId > 0) {
        pendingRegistrationUserId = responseUserId;
        pendingRegistrationToken = registrationToken;
        pendingRegistrationStatus = response['verificationStatus']?.toString() ?? '';
        pendingIdentifier =
            response['email']?.toString().trim().isNotEmpty == true
            ? response['email'].toString()
            : normalized;
        pendingUserId = null;
        pendingChallenge = null;
        return false;
      }
      pendingUserId = responseUserId;
      pendingChallenge = response['pinChallengeToken']?.toString();
      pendingIdentifier =
          response['email']?.toString().trim().isNotEmpty == true
          ? response['email'].toString()
          : normalized;
      if (pendingUserId == null ||
          pendingChallenge == null ||
          pendingChallenge!.isEmpty) {
        throw const FormatException(
          'El servidor no devolvió el desafío de PIN.',
        );
      }
      return true;
    } catch (e) {
      error = _friendly(e);
      return false;
    } finally {
      _stop();
    }
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    _start();
    try {
      final result = await api.register(payload);
      final uid = int.tryParse(result['userId']?.toString() ?? '');
      final token = result['registrationToken']?.toString() ?? '';
      if (uid == null || uid <= 0 || token.isEmpty) {
        throw const FormatException(
          'El servidor no devolvió la autorización de verificación del registro.',
        );
      }
      pendingRegistrationUserId = uid;
      pendingRegistrationToken = token;
      pendingRegistrationStatus = result['verificationStatus']?.toString() ?? 'NOT_SUBMITTED';
      pendingIdentifier =
          payload['email']?.toString() ?? payload['username']?.toString() ?? '';
      return true;
    } catch (e) {
      error = _friendly(e);
      return false;
    } finally {
      _stop();
    }
  }

  Future<bool> verifyPin(String pin) async {
    final uid = pendingUserId;
    final challenge = pendingChallenge;
    if (uid == null || challenge == null) return false;
    if (pin.length != 6) {
      error = 'Ingresa los 6 números de tu PIN.';
      notifyListeners();
      return false;
    }
    _start();
    try {
      final result = await api.verifyPin(
        userId: uid,
        pin: pin,
        challengeToken: challenge,
        deviceIdHash: await store.deviceIdHash(),
      );
      final access = result['accessToken']?.toString() ?? '';
      final refresh = result['refreshToken']?.toString() ?? '';
      final rawUser = result['user'];
      if (access.isEmpty || refresh.isEmpty || rawUser is! Map) {
        throw const FormatException('Sesión incompleta.');
      }
      final map = Map<String, dynamic>.from(rawUser);
      final candidate = AppUser.fromJson(map);
      if (candidate.role != UserRole.beneficiary) {
        await store.clear();
        throw const FormatException(
          'Este perfil es exclusivo de Kredi+ para PC.',
        );
      }
      await store.saveTokens(access, refresh);
      await store.saveUser(map);
      await store.saveLocalPinVerifier(candidate.id, pin);
      user = candidate;
      pendingUserId = null;
      pendingChallenge = null;
      pendingIdentifier = '';
      pendingRegistrationUserId = null;
      pendingRegistrationToken = null;
      pendingRegistrationStatus = '';
      return true;
    } catch (e) {
      error = _friendly(e);
      return false;
    } finally {
      _stop();
    }
  }

  Future<void> refreshProfile() async {
    if (user == null) return;
    try {
      final fresh = await api.me();
      final candidate = AppUser.fromJson(fresh);
      if (candidate.role != UserRole.beneficiary) {
        await logout();
        return;
      }
      user = candidate;
      await store.saveUser(fresh);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    final currentUserId = user?.id;
    if (currentUserId != null) {
      await store.clearAccountSecurity(currentUserId);
    }
    user = null;
    pendingUserId = null;
    pendingChallenge = null;
    pendingIdentifier = '';
    pendingRegistrationUserId = null;
    pendingRegistrationToken = null;
    pendingRegistrationStatus = '';
    error = null;
    await store.clear();
    notifyListeners();
  }

  Future<void> updateLocalPinVerifier(String pin) async {
    final current = user;
    if (current == null || pin.length != 6) return;
    await store.saveLocalPinVerifier(current.id, pin);
    notifyListeners();
  }

  void completeRegistrationApproval({
    required int userId,
    required String pinChallengeToken,
  }) {
    pendingUserId = userId;
    pendingChallenge = pinChallengeToken;
    pendingRegistrationUserId = null;
    pendingRegistrationToken = null;
    pendingRegistrationStatus = 'VERIFIED';
    error = null;
    notifyListeners();
  }

  void updatePendingRegistrationStatus(String status) {
    pendingRegistrationStatus = status;
    notifyListeners();
  }

  void clearPendingRegistration() {
    pendingRegistrationUserId = null;
    pendingRegistrationToken = null;
    pendingRegistrationStatus = '';
    pendingIdentifier = '';
    error = null;
    notifyListeners();
  }

  void cancelPin() {
    pendingUserId = null;
    pendingChallenge = null;
    pendingIdentifier = '';
    error = null;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void _start() {
    busy = true;
    error = null;
    notifyListeners();
  }

  void _stop() {
    busy = false;
    notifyListeners();
  }

  String _friendly(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('FormatException: ', '');
}
