import 'dart:io';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../credit/kredi_credit_policy.dart';
import 'api_client.dart';

String _storeSortKey(String raw) {
  var value = raw.trim().toLowerCase();
  for (final article in const ['la ', 'el ', 'las ', 'los ']) {
    if (value.startsWith(article)) {
      value = '${value.substring(article.length)} ${article.trim()}';
      break;
    }
  }
  const from = 'áéíóúüàèìòùâêîôûäëïöü';
  const to =   'aeiouuaeiouaeiouaeiou';
  for (var i = 0; i < from.length; i++) {
    value = value.replaceAll(from[i], to[i]);
  }
  // Mantiene la Ñ agrupada correctamente después de N sin enviarla al final.
  value = value.replaceAll('ñ', 'nz');
  return value.replaceAll(RegExp(r'\s+'), ' ');
}

class KrediApi {
  const KrediApi(this.client);
  final ApiClient client;

  Future<Map<String, dynamic>> login(String username, String password) async =>
      _map(
        await client.post(
          '/auth/mobile/login',
          data: {'username': username.trim(), 'password': password},
        ),
      );

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async =>
      _map(await client.post('/auth/mobile/register', data: payload));

  Future<Map<String, dynamic>> waitRegistrationStatus({
    required int userId,
    required String registrationToken,
    String signature = '',
    int waitSeconds = 18,
  }) async => _map(
    await client.get(
      '/auth/mobile/registration-status/$userId',
      query: {
        'signature': signature,
        'wait': waitSeconds.clamp(1, 18),
      },
      options: Options(
        headers: {'X-Registration-Token': registrationToken},
        receiveTimeout: const Duration(seconds: 25),
      ),
    ),
  );

  Future<Map<String, dynamic>> waitForSync({
    String cursor = '',
    int waitSeconds = 18,
  }) async => _map(
    await client.get(
      '/me/sync',
      query: {
        'cursor': cursor,
        'wait': waitSeconds.clamp(1, 18),
      },
      options: Options(receiveTimeout: const Duration(seconds: 25)),
    ),
  );

  Future<Map<String, dynamic>> identifyRecoveryAccount(
    String identifier,
  ) async => _map(
    await client.post(
      '/auth/recovery/identify',
      data: {'identifier': identifier.trim()},
    ),
  );

  Future<void> requestPasswordRecovery(String identifier) async {
    await client.post(
      '/auth/password-recovery/request',
      data: {'identifier': identifier.trim()},
    );
  }

  Future<void> resetPasswordRecovery({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    await client.post(
      '/auth/password-recovery/reset',
      data: {
        'identifier': identifier.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<void> requestPinRecovery(String identifier) async {
    await client.post(
      '/auth/pin-recovery/request',
      data: {'identifier': identifier.trim()},
    );
  }

  Future<void> resetPinRecovery({
    required String identifier,
    required String code,
    required String newPin,
  }) async {
    await client.post(
      '/auth/pin-recovery/reset',
      data: {
        'identifier': identifier.trim(),
        'code': code.trim(),
        'newPin': newPin,
      },
    );
  }

  Future<void> submitRegistrationVerification({
    required int userId,
    required String registrationToken,
    required String documentNumber,
    required File front,
    File? back,
    required File selfie,
  }) async {
    final form = FormData.fromMap({
      'documentType': 'NATIONAL_ID',
      'documentNumber': documentNumber.trim(),
      'front': await MultipartFile.fromFile(
        front.path,
        filename: front.uri.pathSegments.last,
      ),
      if (back != null)
        'back': await MultipartFile.fromFile(
          back.path,
          filename: back.uri.pathSegments.last,
        ),
      'selfie': await MultipartFile.fromFile(
        selfie.path,
        filename: selfie.uri.pathSegments.last,
      ),
    });
    await client.post(
      '/usuarios/$userId/document-verification',
      data: form,
      options: Options(headers: {'X-Registration-Token': registrationToken}),
    );
  }

  Future<Map<String, dynamic>> verifyPin({
    required int userId,
    required String pin,
    required String challengeToken,
    required String deviceIdHash,
  }) async => _map(
    await client.post(
      '/auth/mobile/verify-pin',
      data: {
        'userId': userId,
        'pin': pin,
        'challengeToken': challengeToken,
        'deviceIdHash': deviceIdHash,
        'deviceName': 'Kredi+ Android Flutter',
        'appVersion': '${AppConfig.versionName}+${AppConfig.versionCode}',
      },
    ),
  );

  Future<Map<String, dynamic>> me() async => _map(await client.get('/me'));

  Future<Map<String, dynamic>> requestAccountDeletion({
    required String email,
  }) async => _map(
    await client.post(
      '${AppConfig.accountDeletionApiUrl}?action=request',
      data: {'email': email.trim().toLowerCase()},
    ),
  );

  Future<Map<String, dynamic>> confirmAccountDeletion({
    required String email,
    required String code,
  }) async => _map(
    await client.post(
      '${AppConfig.accountDeletionApiUrl}?action=confirm',
      data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
    ),
  );

  /// Recompone la experiencia avanzada de inicio usando exclusivamente
  /// endpoints vigentes de la API oficial. No depende del backend móvil legado.
  Future<Map<String, dynamic>> mobileHome() async {
    Future<T> safe<T>(Future<T> Function() action, T fallback) async {
      try {
        return await action().timeout(const Duration(seconds: 15));
      } catch (_) {
        return fallback;
      }
    }

    final results = await Future.wait<dynamic>([
      safe(me, <String, dynamic>{}),
      safe(credit, KrediCreditPolicy.normalizeCredit(<String, dynamic>{})),
      safe(purchases, <Map<String, dynamic>>[]),
      safe(paymentReports, <Map<String, dynamic>>[]),
      safe(notifications, <Map<String, dynamic>>[]),
      safe(businesses, <Map<String, dynamic>>[]),
      safe(banners, <Map<String, dynamic>>[]),
    ]);
    final user = Map<String, dynamic>.from(results[0] as Map);
    final creditData = Map<String, dynamic>.from(results[1] as Map);
    final purchasesData = List<Map<String, dynamic>>.from(results[2] as List);
    final reports = List<Map<String, dynamic>>.from(results[3] as List);
    final notices = List<Map<String, dynamic>>.from(results[4] as List);
    final stores = List<Map<String, dynamic>>.from(results[5] as List);
    final bannerRows = List<Map<String, dynamic>>.from(results[6] as List);

    final installments = creditData['installments'] is List
        ? (creditData['installments'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final pending = installments.where((e) {
      final st = (e['status'] ?? '').toString().toUpperCase();
      return !const {
        'PAID',
        'PAGADO',
        'COMPLETED',
        'COMPLETADO',
        'CANCELLED',
        'CANCELED',
      }.contains(st);
    }).toList();
    final overdue = pending.where((e) {
      final due = DateTime.tryParse((e['dueDate'] ?? '').toString());
      return due != null &&
          due.toLocal().isBefore(DateTime.now()) &&
          (e['status'] ?? '').toString().toUpperCase() != 'PAID';
    }).toList();
    final totalDebt = pending.fold<double>(
      0,
      (a, e) => a + _number(e, const ['amountUsd']),
    );
    final overdueDebt = overdue.fold<double>(
      0,
      (a, e) => a + _number(e, const ['amountUsd']),
    );
    pending.sort(
      (a, b) => (a['dueDate'] ?? '').toString().compareTo(
        (b['dueDate'] ?? '').toString(),
      ),
    );

    final verificationStatus =
        (user['verificationStatus'] ??
                user['verification_status'] ??
                'NOT_SUBMITTED')
            .toString();
    final levelNumber =
        int.tryParse((creditData['level'] ?? user['creditLevel'] ?? 1).toString()) ?? 1;
    final levelRule = KrediCreditPolicy.ruleFor(levelNumber);
    final sendero = creditData['senderoLine'] is Map
        ? Map<String, dynamic>.from(creditData['senderoLine'] as Map)
        : <String, dynamic>{};
    final altura = creditData['alturaLine'] is Map
        ? Map<String, dynamic>.from(creditData['alturaLine'] as Map)
        : <String, dynamic>{};
    final unread = notices.where((row) => row['readAt'] == null).length;

    return <String, dynamic>{
      'level': {
        'number': levelRule.level,
        'name': levelRule.name,
        'score':
            int.tryParse((creditData['creditScorePercentage'] ?? 0).toString()) ?? 0,
        'completedPayments':
            int.tryParse((creditData['completedPayments'] ?? 0).toString()) ?? 0,
        'nextLevelAtPayments':
            int.tryParse((creditData['nextLevelAtPayments'] ?? 0).toString()) ?? 0,
      },
      'verification': {
        'status': verificationStatus,
        'required': !{
          'VERIFIED',
          'APPROVED',
        }.contains(verificationStatus.toUpperCase()),
      },
      'debt': {
        'totalDebtUsd': totalDebt,
        'overdueDebtUsd': overdueDebt,
        'pendingInstallments': pending.length,
      },
      'lines': [sendero, altura],
      'nextPayment': pending.isEmpty ? null : pending.first,
      'stores': stores,
      'banners': bannerRows,
      'unreadNotifications': unread,
      'purchaseCount': purchasesData.length,
      'paymentReportCount': reports.length,
    };
  }

  Future<Map<String, dynamic>> updateProfile({
    required String phone,
    required String state,
    required String municipality,
    required String parish,
    required String community,
    required String address,
  }) async => _map(
    await client.patch(
      '/me/profile',
      data: {
        'phone': phone.trim(),
        'state': state.trim(),
        'municipality': municipality.trim(),
        'parish': parish.trim(),
        'community': community.trim(),
        'address': address.trim(),
      },
    ),
  );

  Future<Map<String, dynamic>> updateProfileContact({
    required String phone,
  }) async => _map(
    await client.patch('/me/profile/contact', data: {'phone': phone.trim()}),
  );

  Future<Map<String, dynamic>> updateProfileLocation({
    required String state,
    required String municipality,
    required String parish,
    required String community,
    required String address,
  }) async => _map(
    await client.patch(
      '/me/profile/location',
      data: {
        'state': state.trim(),
        'municipality': municipality.trim(),
        'parish': parish.trim(),
        'community': community.trim(),
        'address': address.trim(),
      },
    ),
  );

  Future<Map<String, dynamic>> requestEmailChange(String newEmail) async =>
      _map(
        await client.post(
          '/me/email-change/request',
          data: {'newEmail': newEmail.trim()},
        ),
      );

  Future<Map<String, dynamic>> confirmEmailChange({
    required String newEmail,
    required String code,
  }) async => _map(
    await client.post(
      '/me/email-change/confirm',
      data: {'newEmail': newEmail.trim(), 'code': code.trim()},
    ),
  );

  Future<List<Map<String, dynamic>>> registrationCommunities({
    required String state,
    required String municipality,
    required String parish,
  }) async => _list(
    await client.get(
      '/locations/communities',
      query: {'state': state, 'municipality': municipality, 'parish': parish},
    ),
  );

  Future<List<Map<String, dynamic>>> sessions() async =>
      _list(await client.get('/me/sessions'));

  Future<void> revokeSession(String id) async {
    await client.post('/me/sessions/$id/revoke');
  }

  Future<Map<String, dynamic>> bodegaApplication(String code) async =>
      _map(await client.get('/bodega-applications/${Uri.encodeComponent(code.trim().toUpperCase())}'));

  Future<Map<String, dynamic>> submitBodegaEvidence({
    required String code,
    required File face,
    required File document,
    required File establishment,
  }) async {
    final form = FormData.fromMap({
      'face': await MultipartFile.fromFile(
        face.path,
        filename: face.uri.pathSegments.last,
      ),
      'document': await MultipartFile.fromFile(
        document.path,
        filename: document.uri.pathSegments.last,
      ),
      'establishment': await MultipartFile.fromFile(
        establishment.path,
        filename: establishment.uri.pathSegments.last,
      ),
    });
    return _map(
      await client.post(
        '/bodega-applications/${Uri.encodeComponent(code.trim().toUpperCase())}/evidence',
        data: form,
      ),
    );
  }

  Future<Map<String, dynamic>> bcvRate() async =>
      _map(await client.get('/exchange-rate/bcv'));
  Future<List<Map<String, dynamic>>> banks() async =>
      _list(await client.get('/banks'));
  Future<List<Map<String, dynamic>>> products() async =>
      _list(await client.get('/products'));
  Future<List<Map<String, dynamic>>> combos() async =>
      _list(await client.get('/combos'));
  Future<List<Map<String, dynamic>>> fairs() async =>
      _list(await client.get('/fairs'));
  Future<List<Map<String, dynamic>>> banners() async =>
      _list(await client.get('/banners'));
  Future<List<Map<String, dynamic>>> promotions() async =>
      _list(await client.get('/promotions'));
  Future<List<Map<String, dynamic>>> businesses() async {
    final associated = _list(await client.get('/businesses'))
        .map((row) => {...row, 'storeType': 'ASSOCIATED_BUSINESS'})
        .toList();
    List<Map<String, dynamic>> community = [];
    try {
      community = _list(await client.get('/community-stores'))
          .map((row) => {...row, 'storeType': 'COMMUNITY_STORE'})
          .toList();
    } catch (_) {
      // Compatibilidad temporal con backends anteriores al submódulo Bodegas.
    }
    final result = [...community, ...associated];
    result.sort((a, b) {
      final an = _storeSortKey(
        (a['name'] ?? a['commercialName'] ?? a['legalName'] ?? '').toString(),
      );
      final bn = _storeSortKey(
        (b['name'] ?? b['commercialName'] ?? b['legalName'] ?? '').toString(),
      );
      final byName = an.compareTo(bn);
      if (byName != 0) return byName;
      return (a['id'] ?? 0).toString().compareTo((b['id'] ?? 0).toString());
    });
    return result;
  }

  Future<Map<String, dynamic>> communityStoreCatalog(int id) async =>
      _map(await client.get('/community-stores/$id/catalog'));

  Future<Map<String, dynamic>> scanCommunityStore(String rawCode) async =>
      _map(await client.post('/community-stores/scan', data: {'code': rawCode.trim()}));

  Future<Map<String, dynamic>> startCommunityStorePurchase(
    int storeId,
    String itemType,
    int itemId,
  ) async =>
      _map(
        await client.post(
          '/community-stores/$storeId/purchase',
          data: {'itemType': itemType, 'itemId': itemId},
        ),
      );
  Future<Map<String, dynamic>> catalogSalesDestinations() async =>
      _map(await client.get('/catalog-sales-destinations'));

  Future<List<Map<String, dynamic>>> purchases() async =>
      _list(await client.get('/me/purchases'));

  Future<List<Map<String, dynamic>>> purchasesByStatus(String status) async {
    final expected = status.toUpperCase();
    return (await purchases())
        .where(
          (row) => (row['status'] ?? '').toString().toUpperCase() == expected,
        )
        .toList();
  }

  Future<Map<String, dynamic>> purchaseDetail(int id) async =>
      _map(await client.get('/purchases/$id/invoice'));
  Future<Map<String, dynamic>> credit() async =>
      KrediCreditPolicy.normalizeCredit(_map(await client.get('/me/credit')));
  Future<List<Map<String, dynamic>>> creditTransactions() async =>
      _list(await client.get('/me/credimpulso-transactions'));
  Future<List<Map<String, dynamic>>> paymentReports() async =>
      _list(await client.get('/me/payment-reports'));
  Future<List<Map<String, dynamic>>> notifications() async =>
      _list(await client.get('/me/notifications'));

  Future<void> markNotificationRead(int id) async {
    await client.post('/me/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await client.post('/me/notifications/read-all');
  }

  Future<void> deleteNotification(int id) async {
    await client.delete('/me/notifications/$id');
  }

  Future<void> deleteAllNotifications() async {
    await client.delete('/me/notifications');
  }

  Future<Map<String, dynamic>> createPurchase({
    required int fairId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> comboItems,
    required String paymentMethod,
    String? creditLine,
  }) async => _map(
    await client.post(
      '/purchases',
      data: {
        'fairId': fairId,
        'items': items,
        'comboItems': comboItems,
        'paymentMethod': paymentMethod,
        if (creditLine != null && creditLine.trim().isNotEmpty)
          'creditLine': creditLine.trim().toUpperCase(),
      },
    ),
  );

  Future<Map<String, dynamic>> createPurchaseWithProof({
    required int fairId,
    required Map<int, int> productItems,
    required Map<int, int> comboItems,
    required String paymentMethod,
    required String paymentReference,
    required String originBankCode,
    required String originPhone,
    required bool paidFromDifferentPhone,
    required File proof,
  }) async {
    final form = FormData.fromMap({
      'fairId': fairId,
      'items': productItems.entries.map((e) => '${e.key}:${e.value}').join(','),
      'comboItems': comboItems.entries
          .map((e) => '${e.key}:${e.value}')
          .join(','),
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'originBankCode': originBankCode,
      'originPhone': originPhone,
      'paidFromDifferentPhone': paidFromDifferentPhone,
      'proof': await MultipartFile.fromFile(
        proof.path,
        filename: proof.uri.pathSegments.last,
      ),
    });
    return _map(await client.post('/purchases/with-proof', data: form));
  }

  Future<Map<String, dynamic>> uploadPaymentReport({
    required String targetType,
    int? orderId,
    int? installmentId,
    required String method,
    required String originBankCode,
    required String originPhone,
    required String referenceNumber,
    required double amountBs,
    required bool paidFromDifferentPhone,
    String? notes,
    required File proof,
  }) async {
    final data = <String, dynamic>{
      'targetType': targetType,
      'method': method,
      'originBankCode': originBankCode,
      'originPhone': originPhone,
      'referenceNumber': referenceNumber,
      'amountBs': amountBs,
      'paidFromDifferentPhone': paidFromDifferentPhone,
      'proof': await MultipartFile.fromFile(
        proof.path,
        filename: proof.uri.pathSegments.last,
      ),
    };
    if (orderId != null) data['orderId'] = orderId;
    if (installmentId != null) data['installmentId'] = installmentId;
    if (notes != null && notes.trim().isNotEmpty) data['notes'] = notes.trim();
    final form = FormData.fromMap(data);
    return _map(
      await client.post('/me/payment-reports/with-proof', data: form),
    );
  }

  // Compra por QR comercial. El QR ya representa Jornada, Combo u Oferta
  // con precio definido; Kredi+ calcula el plan según el nivel del usuario.
  Future<Map<String, dynamic>> startQrPurchase(String rawCode) async {
    final commercial = !RegExp(
      r'KQ-[A-Z0-9]+',
      caseSensitive: false,
    ).hasMatch(rawCode);
    final row = _map(
      await client.post(
        commercial ? '/commerce/qr/scan' : '/qr/scan',
        data: {'code': rawCode.trim()},
      ),
    );
    return {...row, 'commerceFlow': commercial};
  }

  Future<List<Map<String, dynamic>>> qrPurchases() async {
    final results = await Future.wait([
      client.get('/me/commerce-qr-purchases'),
      client.get('/me/qr-purchases'),
    ]);
    return [
      for (final row in _list(results[0])) {...row, 'commerceFlow': true},
      for (final row in _list(results[1])) {...row, 'commerceFlow': false},
    ];
  }

  Future<Map<String, dynamic>> qrPurchaseSession(
    int id, {
    bool commerceFlow = true,
  }) async => {
    ..._map(
      await client.get(
        commerceFlow ? '/commerce/qr/sessions/$id' : '/qr/sessions/$id',
      ),
    ),
    'commerceFlow': commerceFlow,
  };

  Future<Map<String, dynamic>> confirmQrPurchase(
    int id, {
    bool commerceFlow = true,
  }) async => {
    ..._map(
      await client.post(
        commerceFlow
            ? '/commerce/qr/sessions/$id/confirm'
            : '/qr/sessions/$id/confirm',
      ),
    ),
    'commerceFlow': commerceFlow,
  };

  static double _number(
    Map<String, dynamic> map,
    List<String> keys, [
    double fallback = 0,
  ]) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
}
